public with sharing class PIIDetectionService {

    private static final String MODEL_NAME = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

    private static final String PROMPT_TEMPLATE =
        'You are a PII detection engine. Analyze the following text and replace ' +
        'any personally identifiable information with typed placeholders.\n\n' +
        'Categories to detect: person names, email addresses, phone numbers, ' +
        'SSNs, CPR numbers, dates of birth, physical addresses, financial account numbers, ' +
        'credit card numbers, IBANs, medical record numbers, salary/income figures.\n\n' +
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

        String cleaned = jsonResponse.trim();
        if (cleaned.startsWith('```')) {
            Integer firstNewline = cleaned.indexOf('\n');
            Integer lastFence = cleaned.lastIndexOf('```');
            if (firstNewline > 0 && lastFence > firstNewline) {
                cleaned = cleaned.substring(firstNewline + 1, lastFence).trim();
            }
        }

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
