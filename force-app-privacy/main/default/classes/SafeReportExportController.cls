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

    public class RecordFieldRow {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldType;
        @AuraEnabled public String value;
    }

    public class RecordLoadResult {
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String recordName;
        @AuraEnabled public List<RecordFieldRow> fields;
    }

    public class RecordOption {
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
    }

    /**
     * Object types exposed in the Mask Workbench detail-mode tab.
     *
     * The list is kept short on purpose: every entry has to be a real
     * SObject the running user can read, so an unrestricted picker
     * would surface managed-package and platform internals that have
     * no thesis relevance. Adding a new entry here requires no other
     * code changes — loadRecord validates against the schema describe
     * at runtime.
     */
    @TestVisible
    private static final Set<String> ALLOWED_DETAIL_OBJECTS = new Set<String>{
        'Account', 'Contact', 'Lead', 'Opportunity', 'Case'
    };

    /**
     * String-like field types that the per-field masking dropdown can
     * meaningfully target. Booleans, numerics, dates, and lookups are
     * excluded because the IDEA-1 strategies all consume and produce
     * String values; coercing a boolean through a regex masker is
     * confusing for the demo and does not advance any thesis claim.
     */
    @TestVisible
    private static final Set<Schema.DisplayType> MASKABLE_DETAIL_TYPES =
        new Set<Schema.DisplayType>{
            Schema.DisplayType.STRING,
            Schema.DisplayType.TEXTAREA,
            Schema.DisplayType.EMAIL,
            Schema.DisplayType.PHONE,
            Schema.DisplayType.URL,
            Schema.DisplayType.PICKLIST,
            Schema.DisplayType.MULTIPICKLIST
        };

    /**
     * System / audit fields that are uninteresting for masking and
     * just clutter the detail-mode field list.
     */
    private static final Set<String> SYSTEM_FIELDS_LOWER = new Set<String>{
        'id', 'isdeleted', 'systemmodstamp',
        'lastmodifieddate', 'lastmodifiedbyid',
        'createddate', 'createdbyid',
        'lastactivitydate', 'lastvieweddate', 'lastreferenceddate',
        'jigsawcompanyid', 'jigsaw', 'masterrecordid'
    };

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

    /**
     * Lookup helper for the Mask Workbench Record tab.
     *
     * Given an allowlisted object API name and a search term of two
     * or more characters, returns up to 25 records whose name field
     * matches the term (LIKE %term%, case-insensitive). The name
     * field is discovered via `Schema.DescribeFieldResult.isNameField`
     * so this works uniformly across objects with different name
     * field API names (Account.Name, Case.Subject, etc.).
     *
     * The query is `with sharing` — users only see records they have
     * read access to. Empty term, short term, or no matches all
     * collapse to an empty list rather than throwing, so the LWC's
     * type-ahead dropdown can call this every keystroke without
     * try / catch noise.
     */
    @AuraEnabled
    public static List<RecordOption> searchRecords(String objectApi, String searchTerm) {
        try {
            List<RecordOption> empty = new List<RecordOption>();
            if (String.isBlank(objectApi)
                || String.isBlank(searchTerm)
                || searchTerm.length() < 2) {
                return empty;
            }
            if (!ALLOWED_DETAIL_OBJECTS.contains(objectApi)) {
                throw new AuraHandledException('Object not supported in detail mode: ' + objectApi);
            }
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectApi);
            if (targetType == null) {
                throw new AuraHandledException('Unknown object: ' + objectApi);
            }
            Schema.DescribeSObjectResult describe = targetType.getDescribe();
            if (!describe.isAccessible()) {
                throw new AuraHandledException('You do not have access to ' + objectApi + '.');
            }
            String nameFieldApi = null;
            for (Schema.SObjectField sf : describe.fields.getMap().values()) {
                Schema.DescribeFieldResult dfr = sf.getDescribe();
                if (dfr.isNameField()) {
                    nameFieldApi = dfr.getName();
                    break;
                }
            }
            if (nameFieldApi == null) {
                return empty;
            }
            String safeTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            String soql = 'SELECT Id, ' + nameFieldApi +
                          ' FROM ' + objectApi +
                          ' WHERE ' + nameFieldApi + ' LIKE :safeTerm' +
                          ' ORDER BY ' + nameFieldApi +
                          ' LIMIT 25';
            List<RecordOption> options = new List<RecordOption>();
            for (SObject rec : Database.query(soql)) {
                RecordOption opt = new RecordOption();
                opt.recordId = String.valueOf(rec.get('Id'));
                Object nameVal = rec.get(nameFieldApi);
                opt.recordName = nameVal == null ? opt.recordId : String.valueOf(nameVal);
                options.add(opt);
            }
            return options;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Detail-mode loader for the Mask Workbench Record tab.
     *
     * Given an allowlisted object API name and a 15- or 18-character
     * Salesforce Id, returns the record with one RecordFieldRow per
     * maskable string-like field. The query is built dynamically from
     * the schema describe (not from caller-supplied field names) so
     * the SOQL is safe even when the LWC sends arbitrary Ids.
     *
     * The record is read with `with sharing` semantics — a user who
     * lacks read access to the object will see an empty result and
     * an AuraHandledException, never another user's data.
     *
     * Slice 2 explicitly does not write to the database. The
     * returned RecordLoadResult is consumed by the LWC, paired with
     * the existing applyStrategyToColumn dispatcher (called once per
     * field with a single-element list), and discarded on refresh.
     */
    @AuraEnabled
    public static RecordLoadResult loadRecord(String objectApi, String recordId) {
        try {
            if (String.isBlank(objectApi) || String.isBlank(recordId)) {
                throw new AuraHandledException('Object API name and record Id are required.');
            }
            if (!ALLOWED_DETAIL_OBJECTS.contains(objectApi)) {
                throw new AuraHandledException('Object not supported in detail mode: ' + objectApi);
            }
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectApi);
            if (targetType == null) {
                throw new AuraHandledException('Unknown object: ' + objectApi);
            }
            Schema.DescribeSObjectResult describe = targetType.getDescribe();
            if (!describe.isAccessible()) {
                throw new AuraHandledException('You do not have access to ' + objectApi + '.');
            }

            Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
            String nameFieldApi = null;
            List<String> orderedFieldApis = new List<String>();
            Map<String, Schema.DescribeFieldResult> describesByApi =
                new Map<String, Schema.DescribeFieldResult>();

            for (String key : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
                if (!dfr.isAccessible()) {
                    continue;
                }
                String api = dfr.getName();
                if (SYSTEM_FIELDS_LOWER.contains(api.toLowerCase())) {
                    continue;
                }
                if (dfr.isNameField()) {
                    nameFieldApi = api;
                }
                if (!MASKABLE_DETAIL_TYPES.contains(dfr.getType())) {
                    continue;
                }
                orderedFieldApis.add(api);
                describesByApi.put(api, dfr);
            }

            orderedFieldApis.sort();

            List<String> selectFields = new List<String>{ 'Id' };
            if (nameFieldApi != null && !describesByApi.containsKey(nameFieldApi)) {
                selectFields.add(nameFieldApi);
            }
            selectFields.addAll(orderedFieldApis);

            String soql = 'SELECT ' + String.join(selectFields, ', ') +
                          ' FROM ' + objectApi +
                          ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(soql);
            if (records == null || records.isEmpty()) {
                throw new AuraHandledException('Record not found or not accessible: ' + recordId);
            }
            SObject rec = records[0];

            RecordLoadResult result = new RecordLoadResult();
            result.objectLabel = describe.getLabel();
            if (nameFieldApi != null) {
                Object nameVal = rec.get(nameFieldApi);
                result.recordName = nameVal == null ? recordId : String.valueOf(nameVal);
            } else {
                result.recordName = recordId;
            }
            result.fields = new List<RecordFieldRow>();
            for (String api : orderedFieldApis) {
                Object raw = rec.get(api);
                String stringValue = raw == null ? '' : String.valueOf(raw);
                // Skip empty fields — there's nothing to mask if a field
                // has no value, and rendering empty cards in the LWC just
                // dilutes the demo.
                if (String.isBlank(stringValue)) {
                    continue;
                }
                RecordFieldRow row = new RecordFieldRow();
                row.fieldApiName = api;
                Schema.DescribeFieldResult d = describesByApi.get(api);
                row.fieldLabel = d == null ? api : d.getLabel();
                row.fieldType = d == null ? 'STRING' : d.getType().name();
                row.value = stringValue;
                result.fields.add(row);
            }
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Per-column strategy dispatcher used by the Mask Workbench LWC.
     *
     * Given the raw values of a single report or detail-page column,
     * applies the named MaskingStrategy from the IDEA-1 registry to
     * every value and returns a parallel list of masked outputs.
     *
     * Three strategy names are reserved:
     *   - 'None'      -> values are returned unchanged (cheap no-op)
     *   - blank/null  -> equivalent to 'None'
     *   - 'EinsteinAI'-> values are deduped and routed through
     *                    PIIDetectionService.detectAndMaskBatch, which
     *                    is the same Einstein flow that backed the old
     *                    "Run & Mask" button. Blank/dash cells pass
     *                    through untouched so empty rows stay empty.
     *
     * Any other name is passed to MaskingStrategyRegistry.resolve, so
     * the same six strategies that the catalogue uses are available
     * here without code changes.
     *
     * paramsJson is an optional JSON object string (e.g. {"length":8})
     * describing the strategy parameters; malformed JSON falls back to
     * defaults so a typo in the LWC can never throw across the wire.
     */
    @AuraEnabled
    public static List<String> applyStrategyToColumn(
        List<String> values,
        String strategyName,
        String paramsJson
    ) {
        try {
            if (values == null || values.isEmpty()) {
                return new List<String>();
            }
            if (String.isBlank(strategyName) || strategyName == 'None') {
                return values;
            }
            if (strategyName == 'EinsteinAI') {
                return applyEinsteinToColumn(values);
            }
            Map<String, Object> params = parseParamsJson(paramsJson);
            MaskingStrategy strategy = MaskingStrategyRegistry.resolve(strategyName);
            List<String> output = new List<String>();
            for (String v : values) {
                output.add(strategy.mask(v, params));
            }
            return output;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @TestVisible
    private static Map<String, Object> parseParamsJson(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(rawJson);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
        } catch (Exception ignored) {
            // Malformed JSON is intentionally swallowed so that one bad
            // params payload from the LWC cannot break a column.
        }
        return new Map<String, Object>();
    }

    @TestVisible
    private static List<String> applyEinsteinToColumn(List<String> values) {
        Set<String> seen = new Set<String>();
        List<String> uniqueTexts = new List<String>();
        for (String v : values) {
            if (String.isNotBlank(v) && v != '-' && !seen.contains(v)) {
                seen.add(v);
                uniqueTexts.add(v);
            }
        }
        Map<String, String> cache = new Map<String, String>();
        if (!uniqueTexts.isEmpty()) {
            List<PIIDetectionService.PIIMaskingResult> results =
                PIIDetectionService.detectAndMaskBatch(uniqueTexts);
            for (Integer i = 0; i < uniqueTexts.size() && i < results.size(); i++) {
                PIIDetectionService.PIIMaskingResult r = results[i];
                if (r != null && r.success == true && r.hasPII == true) {
                    cache.put(uniqueTexts[i], r.maskedText);
                } else if (r != null && r.success == true) {
                    cache.put(uniqueTexts[i], uniqueTexts[i]);
                } else {
                    cache.put(uniqueTexts[i], maskFreeText(uniqueTexts[i]));
                }
            }
        }
        List<String> output = new List<String>();
        for (String v : values) {
            if (v == null || v == '' || v == '-') {
                output.add(v);
            } else if (cache.containsKey(v)) {
                output.add(cache.get(v));
            } else {
                output.add(v);
            }
        }
        return output;
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

        output.rows = maskRowsByHeader(rawRows, output.headers, columnTypes);
        output.totalRows = output.rows.size();
        return output;
    }

    /**
     * Pure function form of the legacy "Run & Mask" pipeline: takes the
     * raw report rows + headers and returns masked rows using the
     * keyword-driven heuristics (Einstein AI for description-like
     * columns, regex/sentinel masking for everything else).
     *
     * Extracted from runReport so it can be unit-tested directly with
     * synthetic input — the Reports.ReportManager dependency is the
     * only part of runReport that cannot be mocked.
     */
    @TestVisible
    private static List<List<String>> maskRowsByHeader(
        List<List<String>> rawRows,
        List<String> headers,
        List<String> columnTypes
    ) {
        Set<Integer> aiColumns = identifyAIColumns(headers);

        Map<String, String> aiCache = new Map<String, String>();
        if (!aiColumns.isEmpty()) {
            List<String> textsToMask = collectDescriptionTexts(rawRows, aiColumns);
            if (!textsToMask.isEmpty()) {
                aiCache = batchMaskTexts(textsToMask);
            }
        }

        List<List<String>> maskedRows = new List<List<String>>();
        for (List<String> rawRow : rawRows) {
            List<String> maskedRow = new List<String>();
            for (Integer i = 0; i < rawRow.size(); i++) {
                String cellValue = rawRow[i];
                String colType = i < columnTypes.size() ? columnTypes[i] : 'STRING';
                String colHeader = i < headers.size() ? headers[i].toLowerCase() : '';

                if (aiColumns.contains(i)) {
                    maskedRow.add(aiCache.containsKey(cellValue) ? aiCache.get(cellValue) : maskFreeText(cellValue));
                } else {
                    maskedRow.add(maskCellValue(cellValue, colType, colHeader));
                }
            }
            maskedRows.add(maskedRow);
        }
        return maskedRows;
    }

    @TestVisible
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

    @TestVisible
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

    @TestVisible
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

    @TestVisible
    private static String maskCellValue(String value, String colType, String header) {
        if (value == null || value == '' || value == '-') return value;

        if (isSensitiveHeader(header)) {
            return maskByType(value, colType, header);
        }

        return maskFreeText(value);
    }

    @TestVisible
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

    @TestVisible
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

    @TestVisible
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

    @TestVisible
    private static String maskPhone(String phone) {
        if (phone.length() < 4) return '***-****';
        return phone.substring(0, phone.length() - 4).replaceAll('[0-9]', '*') +
               phone.substring(phone.length() - 4);
    }

    @TestVisible
    private static String maskDate(String dateStr) {
        if (dateStr.length() < 2) return '****-**-**';
        return '****-**-' + dateStr.substring(dateStr.length() - 2);
    }

    @TestVisible
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
