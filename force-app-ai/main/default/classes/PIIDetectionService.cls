public with sharing class PIIDetectionService {

    private static final String MODEL_NAME = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

    private static final Integer BATCH_SIZE = 10;

    private static final String PII_CATEGORIES =
        'Categories to detect: person names, email addresses, phone numbers, ' +
        'SSNs, CPR numbers, dates of birth, physical addresses, financial account numbers, ' +
        'credit card numbers, IBANs, medical record numbers, salary/income figures.';

    private static final String PROMPT_TEMPLATE =
        'You are a PII detection engine. Analyze the following text and replace ' +
        'any personally identifiable information with typed placeholders.\n\n' +
        PII_CATEGORIES + '\n\n' +
        'Return ONLY valid JSON in this exact format:\n' +
        '{\n' +
        '  "maskedText": "the text with PII replaced by [REDACTED-TYPE]",\n' +
        '  "findings": [\n' +
        '    {"type": "EMAIL", "original": "john@example.com"},\n' +
        '    {"type": "PHONE", "original": "555-123-4567"}\n' +
        '  ],\n' +
        '  "hasPII": true\n' +
        '}\n\n' +
        'If no PII is found, return the original text unchanged with an empty findings array and hasPII false.\n\n' +
        'Text to analyze:\n---\n';

    private static final String BATCH_PROMPT_TEMPLATE =
        'You are a PII detection engine. Analyze each numbered text below and replace ' +
        'any personally identifiable information with typed placeholders like [REDACTED-TYPE].\n\n' +
        PII_CATEGORIES + '\n\n' +
        'Return ONLY a valid JSON array with one object per text, in order:\n' +
        '[\n' +
        '  {"index": 0, "maskedText": "text with PII replaced", "hasPII": true},\n' +
        '  {"index": 1, "maskedText": "text unchanged if no PII", "hasPII": false}\n' +
        ']\n\n' +
        'Texts to analyze:\n';

    public class PIIMaskingResult {
        public String maskedText;
        public List<PIIFinding> findings;
        public Boolean hasPII;
        public Boolean success;
        public String errorMessage;
    }

    public class PIIFinding {
        public String findingType;
        public String original;
    }

    public static PIIMaskingResult detectAndMask(String text) {
        PIIMaskingResult result = new PIIMaskingResult();
        result.findings = new List<PIIFinding>();

        if (String.isBlank(text)) {
            result.maskedText = text;
            result.hasPII = false;
            result.success = true;
            return result;
        }

        try {
            String aiResponse = callEinstein(PROMPT_TEMPLATE + text + '\n---');
            result = parseResponse(aiResponse);
            result.success = true;
        } catch (Exception e) {
            result.maskedText = text;
            result.hasPII = false;
            result.success = false;
            result.errorMessage = e.getTypeName() + ': ' + e.getMessage();
        }

        return result;
    }

    public static List<PIIMaskingResult> detectAndMaskBatch(List<String> texts) {
        List<PIIMaskingResult> results = new List<PIIMaskingResult>();

        if (texts == null || texts.isEmpty()) {
            return results;
        }

        for (Integer batchStart = 0; batchStart < texts.size(); batchStart += BATCH_SIZE) {
            Integer batchEnd = Math.min(batchStart + BATCH_SIZE, texts.size());
            List<String> chunk = new List<String>();
            for (Integer i = batchStart; i < batchEnd; i++) {
                chunk.add(texts[i]);
            }
            List<PIIMaskingResult> chunkResults = processBatchChunk(chunk);
            results.addAll(chunkResults);
        }

        return results;
    }

    private static List<PIIMaskingResult> processBatchChunk(List<String> chunk) {
        String prompt = BATCH_PROMPT_TEMPLATE;
        for (Integer i = 0; i < chunk.size(); i++) {
            String text = chunk[i];
            prompt += '[' + i + ']: ' + (String.isBlank(text) ? '(empty)' : text) + '\n';
        }

        try {
            String aiResponse = callEinstein(prompt);
            List<PIIMaskingResult> parsed = parseBatchResponse(aiResponse, chunk.size());
            if (parsed.size() == chunk.size()) {
                return parsed;
            }
        } catch (Exception e) {
            // Fall through to individual calls
        }

        List<PIIMaskingResult> fallback = new List<PIIMaskingResult>();
        for (String text : chunk) {
            fallback.add(detectAndMask(text));
        }
        return fallback;
    }

    @TestVisible
    private static List<PIIMaskingResult> parseBatchResponse(String jsonResponse, Integer expectedSize) {
        String cleaned = stripCodeFences(jsonResponse);
        List<Object> items = (List<Object>) JSON.deserializeUntyped(cleaned);

        List<PIIMaskingResult> results = new List<PIIMaskingResult>();
        for (Integer i = 0; i < expectedSize; i++) {
            results.add(new PIIMaskingResult());
        }

        for (Object item : items) {
            Map<String, Object> obj = (Map<String, Object>) item;
            Integer idx = (Integer) obj.get('index');
            if (idx != null && idx >= 0 && idx < expectedSize) {
                PIIMaskingResult r = new PIIMaskingResult();
                r.maskedText = (String) obj.get('maskedText');
                r.hasPII = (Boolean) obj.get('hasPII');
                r.findings = new List<PIIFinding>();
                r.success = true;
                results[idx] = r;
            }
        }

        for (PIIMaskingResult r : results) {
            if (r.success == null) {
                return new List<PIIMaskingResult>();
            }
        }

        return results;
    }

    private static String stripCodeFences(String text) {
        String cleaned = text.trim();
        if (cleaned.startsWith('```')) {
            Integer firstNewline = cleaned.indexOf('\n');
            Integer lastFence = cleaned.lastIndexOf('```');
            if (firstNewline > 0 && lastFence > firstNewline) {
                cleaned = cleaned.substring(firstNewline + 1, lastFence).trim();
            }
        }
        return cleaned;
    }

    private static String callEinstein(String prompt) {
        aiplatform.ModelsAPI.createGenerations_Request request =
            new aiplatform.ModelsAPI.createGenerations_Request();
        request.modelName = MODEL_NAME;

        aiplatform.ModelsAPI_GenerationRequest body =
            new aiplatform.ModelsAPI_GenerationRequest();
        body.prompt = prompt;
        request.body = body;

        aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
        aiplatform.ModelsAPI.createGenerations_Response response =
            modelsAPI.createGenerations(request);

        return response.Code200.generation.generatedText;
    }

    @TestVisible
    private static PIIMaskingResult parseResponse(String jsonResponse) {
        PIIMaskingResult result = new PIIMaskingResult();
        result.findings = new List<PIIFinding>();

        String cleaned = stripCodeFences(jsonResponse);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

        result.maskedText = (String) parsed.get('maskedText');
        result.hasPII = (Boolean) parsed.get('hasPII');

        List<Object> findingsRaw = (List<Object>) parsed.get('findings');
        if (findingsRaw != null) {
            for (Object f : findingsRaw) {
                Map<String, Object> fMap = (Map<String, Object>) f;
                PIIFinding finding = new PIIFinding();
                finding.findingType = (String) fMap.get('type');
                finding.original = (String) fMap.get('original');
                result.findings.add(finding);
            }
        }

        return result;
    }
}
