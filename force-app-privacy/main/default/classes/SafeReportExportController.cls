public with sharing class SafeReportExportController {

    public class ReportOption {
        @AuraEnabled public String reportId;
        @AuraEnabled public String reportName;
    }

    public class ExportResult {
        @AuraEnabled public List<String> headers;
        @AuraEnabled public List<List<String>> rows;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public String reportName;
    }

    @AuraEnabled
    public static List<ReportOption> searchReports(String searchTerm) {
        List<ReportOption> options = new List<ReportOption>();
        String query = 'SELECT Id, Name FROM Report WHERE Format = \'Tabular\'';
        if (searchTerm != null && searchTerm.length() >= 2) {
            String safeTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            query += ' AND Name LIKE :safeTerm';
        }
        query += ' ORDER BY Name LIMIT 50';
        for (Report r : Database.query(query)) {
            ReportOption opt = new ReportOption();
            opt.reportId = r.Id;
            opt.reportName = r.Name;
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled
    public static ExportResult runRawReport(String reportId) {
        return runReport(reportId, false);
    }

    @AuraEnabled
    public static ExportResult runAndMaskReport(String reportId) {
        return runReport(reportId, true);
    }

    private static ExportResult runReport(String reportId, Boolean applyMasking) {
        Reports.ReportResults results = Reports.ReportManager.runReport(reportId, true);

        ExportResult output = new ExportResult();
        output.reportName = results.getReportMetadata().getName();

        Reports.ReportExtendedMetadata extMeta = results.getReportExtendedMetadata();
        Map<String, Reports.DetailColumn> columnMap = extMeta.getDetailColumnInfo();
        List<String> columnOrder = results.getReportMetadata().getDetailColumns();

        output.headers = new List<String>();
        List<String> columnTypes = new List<String>();
        for (String colName : columnOrder) {
            Reports.DetailColumn col = columnMap.get(colName);
            output.headers.add(col.getLabel());
            columnTypes.add(col.getDataType().name());
        }

        List<List<String>> rawRows = new List<List<String>>();
        Reports.ReportFactWithDetails factMap = (Reports.ReportFactWithDetails) results.getFactMap().get('T!T');

        if (factMap != null && factMap.getRows() != null) {
            for (Reports.ReportDetailRow row : factMap.getRows()) {
                List<Reports.ReportDataCell> cells = row.getDataCells();
                List<String> rowValues = new List<String>();
                for (Integer i = 0; i < cells.size(); i++) {
                    rowValues.add(String.valueOf(cells[i].getLabel()));
                }
                rawRows.add(rowValues);
            }
        }

        if (!applyMasking) {
            output.rows = rawRows;
            output.totalRows = rawRows.size();
            return output;
        }

        Set<Integer> aiColumns = identifyAIColumns(output.headers);

        Map<String, String> aiCache = new Map<String, String>();
        if (!aiColumns.isEmpty()) {
            List<String> textsToMask = collectDescriptionTexts(rawRows, aiColumns);
            if (!textsToMask.isEmpty()) {
                aiCache = batchMaskTexts(textsToMask);
            }
        }

        output.rows = new List<List<String>>();
        for (List<String> rawRow : rawRows) {
            List<String> maskedRow = new List<String>();
            for (Integer i = 0; i < rawRow.size(); i++) {
                String cellValue = rawRow[i];
                String colType = i < columnTypes.size() ? columnTypes[i] : 'STRING';
                String colHeader = i < output.headers.size() ? output.headers[i].toLowerCase() : '';

                if (aiColumns.contains(i)) {
                    maskedRow.add(aiCache.containsKey(cellValue) ? aiCache.get(cellValue) : maskFreeText(cellValue));
                } else {
                    maskedRow.add(maskCellValue(cellValue, colType, colHeader));
                }
            }
            output.rows.add(maskedRow);
        }

        output.totalRows = output.rows.size();
        return output;
    }

    private static Set<Integer> identifyAIColumns(List<String> headers) {
        Set<Integer> aiCols = new Set<Integer>();
        for (Integer i = 0; i < headers.size(); i++) {
            String h = headers[i].toLowerCase();
            if (h.contains('description') || h.contains('notes') || h.contains('comment')) {
                aiCols.add(i);
            }
        }
        return aiCols;
    }

    private static List<String> collectDescriptionTexts(List<List<String>> rows, Set<Integer> aiColumns) {
        Set<String> seen = new Set<String>();
        List<String> unique = new List<String>();
        for (List<String> row : rows) {
            for (Integer col : aiColumns) {
                if (col < row.size()) {
                    String val = row[col];
                    if (val != null && val != '' && val != '-' && !seen.contains(val)) {
                        seen.add(val);
                        unique.add(val);
                    }
                }
            }
        }
        return unique;
    }

    private static Map<String, String> batchMaskTexts(List<String> texts) {
        Map<String, String> cache = new Map<String, String>();
        List<PIIDetectionService.PIIMaskingResult> results = PIIDetectionService.detectAndMaskBatch(texts);

        for (Integer i = 0; i < texts.size() && i < results.size(); i++) {
            PIIDetectionService.PIIMaskingResult r = results[i];
            if (r.success && r.hasPII) {
                cache.put(texts[i], r.maskedText);
            } else if (r.success && !r.hasPII) {
                cache.put(texts[i], texts[i]);
            } else {
                cache.put(texts[i], maskFreeText(texts[i]));
            }
        }

        return cache;
    }

    private static String maskCellValue(String value, String colType, String header) {
        if (value == null || value == '' || value == '-') return value;

        if (isSensitiveHeader(header)) {
            return maskByType(value, colType, header);
        }

        return maskFreeText(value);
    }

    private static Boolean isSensitiveHeader(String header) {
        Set<String> sensitiveKeywords = new Set<String>{
            'email', 'e-mail', 'phone', 'mobile', 'fax',
            'birthdate', 'birth date', 'date of birth', 'dob',
            'ssn', 'social security', 'cpr', 'national id',
            'credit card', 'card number', 'iban', 'bank',
            'salary', 'income', 'compensation',
            'street', 'address', 'mailing', 'home'
        };

        for (String keyword : sensitiveKeywords) {
            if (header.contains(keyword)) return true;
        }
        return false;
    }

    private static String maskByType(String value, String colType, String header) {
        if (header.contains('email') || header.contains('e-mail')) {
            return maskEmail(value);
        }
        if (header.contains('phone') || header.contains('mobile') || header.contains('fax')) {
            return maskPhone(value);
        }
        if (header.contains('birthdate') || header.contains('birth date') || header.contains('dob')) {
            return maskDate(value);
        }
        if (header.contains('street') || header.contains('address') || header.contains('mailing')) {
            return '*** Masked Address ***';
        }
        if (header.contains('salary') || header.contains('income') || header.contains('compensation')) {
            return '******';
        }

        return '***';
    }

    private static String maskEmail(String email) {
        if (!email.contains('@')) return '***@***.***';
        String[] parts = email.split('@');
        String local = parts[0].length() > 1
            ? parts[0].substring(0, 1) + '***'
            : parts[0] + '***';
        String domain = parts[1].length() > 2
            ? parts[1].substring(0, 1) + '***' + parts[1].substring(parts[1].lastIndexOf('.'))
            : '***';
        return local + '@' + domain;
    }

    private static String maskPhone(String phone) {
        if (phone.length() < 4) return '***-****';
        return phone.substring(0, phone.length() - 4).replaceAll('[0-9]', '*') +
               phone.substring(phone.length() - 4);
    }

    private static String maskDate(String dateStr) {
        if (dateStr.length() < 2) return '****-**-**';
        return '****-**-' + dateStr.substring(dateStr.length() - 2);
    }

    private static String maskFreeText(String text) {
        String masked = text;
        masked = masked.replaceAll('\\b\\d{6}-\\d{4}\\b', '******-****');
        masked = masked.replaceAll('\\b\\d{4}-\\d{4}-\\d{4}-\\d{4}\\b', '****-****-****-****');
        masked = masked.replaceAll('\\bCVV:\\s*\\d{3}\\b', 'CVV: ***');
        masked = masked.replaceAll('\\bExp:\\s*\\d{2}/\\d{2}\\b', 'Exp: **/**');
        masked = masked.replaceAll('\\b[A-Z]{2}\\d{2}[A-Z0-9]{4,}\\d{7,}[A-Z0-9]{0,16}\\b', '****IBAN****');
        masked = masked.replaceAll('\\b\\d{9,18}\\b', '****');
        masked = masked.replaceAll('Salary:\\s*\\d+', 'Salary: ******');
        masked = masked.replaceAll('[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}', '***@***.***');
        return masked;
    }
}
