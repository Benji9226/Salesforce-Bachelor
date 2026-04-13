public with sharing class SafeReportExportController {

    private static final Integer MAX_AI_CALLS = 50;
    private static Integer aiCallCount = 0;

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

        output.rows = new List<List<String>>();
        Reports.ReportFactWithDetails factMap = (Reports.ReportFactWithDetails) results.getFactMap().get('T!T');

        if (factMap != null && factMap.getRows() != null) {
            for (Reports.ReportDetailRow row : factMap.getRows()) {
                List<Reports.ReportDataCell> cells = row.getDataCells();
                List<String> rowValues = new List<String>();

                for (Integer i = 0; i < cells.size(); i++) {
                    String cellValue = String.valueOf(cells[i].getLabel());
                    if (applyMasking) {
                        String colType = i < columnTypes.size() ? columnTypes[i] : 'STRING';
                        String colHeader = i < output.headers.size() ? output.headers[i].toLowerCase() : '';
                        cellValue = maskCellValue(cellValue, colType, colHeader);
                    }
                    rowValues.add(cellValue);
                }
                output.rows.add(rowValues);
            }
        }

        output.totalRows = output.rows.size();
        return output;
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
            'description', 'notes', 'comment',
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
        if (header.contains('description') || header.contains('notes') || header.contains('comment')) {
            return maskWithAI(value);
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

    private static String maskWithAI(String value) {
        if (aiCallCount >= MAX_AI_CALLS) {
            return maskFreeText(value);
        }

        aiCallCount++;
        PIIDetectionService.PIIMaskingResult result = PIIDetectionService.detectAndMask(value);

        if (result.success && result.hasPII) {
            return result.maskedText;
        }
        if (result.success && !result.hasPII) {
            return value;
        }
        return maskFreeText(value);
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
