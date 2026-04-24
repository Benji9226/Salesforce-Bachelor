@IsTest
private class PIIDetectionServiceTest {

    // =====================================================================
    // Helpers
    // =====================================================================

    private static void enqueueMockResponse(String jsonBody) {
        if (PIIDetectionService.mockResponseQueue == null) {
            PIIDetectionService.mockResponseQueue = new List<String>();
        }
        PIIDetectionService.mockResponseQueue.add(jsonBody);
    }

    private static void enqueueMockException(Exception e) {
        if (PIIDetectionService.mockExceptionQueue == null) {
            PIIDetectionService.mockExceptionQueue = new List<Exception>();
        }
        PIIDetectionService.mockExceptionQueue.add(e);
    }

    private static String buildSingleResponseJson(String maskedText, Boolean hasPII, Map<String, String> findings) {
        List<String> findingJson = new List<String>();
        if (findings != null) {
            for (String type : findings.keySet()) {
                findingJson.add(
                    '{"type":"' + type + '","original":"' + findings.get(type) + '"}'
                );
            }
        }
        return '{"maskedText":"' + maskedText + '",' +
               '"hasPII":' + hasPII + ',' +
               '"findings":[' + String.join(findingJson, ',') + ']}';
    }

    // =====================================================================
    // Blank / null input fast-paths (no mock needed)
    // =====================================================================

    @IsTest
    static void detectAndMask_nullInput_returnsSuccessWithoutCallout() {
        // Arrange
        String input = null;

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.detectAndMask(input);

        // Assert
        System.assertEquals(true, actual.success, 'Null input should short-circuit to success');
        System.assertEquals(false, actual.hasPII, 'Null input has no PII');
        System.assertEquals(null, actual.maskedText, 'Null input returns null masked text');
        System.assert(actual.findings != null, 'Findings list should be initialised');
        System.assertEquals(0, actual.findings.size(), 'No findings for null input');
    }

    @IsTest
    static void detectAndMask_emptyString_returnsSuccessWithoutCallout() {
        // Arrange
        String input = '';

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.detectAndMask(input);

        // Assert
        System.assertEquals(true, actual.success);
        System.assertEquals(false, actual.hasPII);
        System.assertEquals('', actual.maskedText);
    }

    @IsTest
    static void detectAndMask_whitespaceOnly_returnsSuccessWithoutCallout() {
        // Arrange
        String input = '   \n\t  ';

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.detectAndMask(input);

        // Assert
        System.assertEquals(true, actual.success, 'Whitespace is blank and should short-circuit');
        System.assertEquals(false, actual.hasPII);
    }

    @IsTest
    static void detectAndMaskBatch_nullInput_returnsEmptyList() {
        // Arrange
        List<String> input = null;

        // Act
        List<PIIDetectionService.PIIMaskingResult> actual = PIIDetectionService.detectAndMaskBatch(input);

        // Assert
        System.assert(actual != null, 'Result list should never be null');
        System.assertEquals(0, actual.size(), 'Null input yields no results');
    }

    @IsTest
    static void detectAndMaskBatch_emptyList_returnsEmptyList() {
        // Arrange
        List<String> input = new List<String>();

        // Act
        List<PIIDetectionService.PIIMaskingResult> actual = PIIDetectionService.detectAndMaskBatch(input);

        // Assert
        System.assertEquals(0, actual.size(), 'Empty input yields no results');
    }

    // =====================================================================
    // parseResponse (@TestVisible) - direct JSON parsing
    // =====================================================================

    @IsTest
    static void parseResponse_validPII_populatesAllFields() {
        // Arrange
        String json = '{"maskedText":"Contact [REDACTED-EMAIL]",' +
                      '"hasPII":true,' +
                      '"findings":[{"type":"EMAIL","original":"john@example.com"},' +
                                  '{"type":"PHONE","original":"555-1234"}]}';

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.parseResponse(json);

        // Assert
        System.assertEquals('Contact [REDACTED-EMAIL]', actual.maskedText);
        System.assertEquals(true, actual.hasPII);
        System.assertEquals(2, actual.findings.size(), 'Both findings should be parsed');
        System.assertEquals('EMAIL', actual.findings[0].findingType);
        System.assertEquals('john@example.com', actual.findings[0].original);
        System.assertEquals('PHONE', actual.findings[1].findingType);
    }

    @IsTest
    static void parseResponse_emptyFindings_hasPIIFalse() {
        // Arrange
        String json = '{"maskedText":"Nothing sensitive here","hasPII":false,"findings":[]}';

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.parseResponse(json);

        // Assert
        System.assertEquals('Nothing sensitive here', actual.maskedText);
        System.assertEquals(false, actual.hasPII);
        System.assertEquals(0, actual.findings.size(), 'Empty findings array yields empty list');
    }

    @IsTest
    static void parseResponse_missingFindingsField_returnsEmptyFindingsList() {
        // Arrange
        // Some models omit the findings key entirely when hasPII is false
        String json = '{"maskedText":"Hello world","hasPII":false}';

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.parseResponse(json);

        // Assert
        System.assertEquals(false, actual.hasPII);
        System.assert(actual.findings != null, 'Findings list should be initialised even when absent from JSON');
        System.assertEquals(0, actual.findings.size());
    }

    @IsTest
    static void parseResponse_jsonWithCodeFences_isStripped() {
        // Arrange
        // GPT-4o-mini often wraps JSON in ```json ... ``` fences
        String json = '```json\n' +
                      '{"maskedText":"fenced","hasPII":false,"findings":[]}\n' +
                      '```';

        // Act
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.parseResponse(json);

        // Assert
        System.assertEquals('fenced', actual.maskedText, 'Code fences should be stripped before parsing');
    }

    @IsTest
    static void parseResponse_malformedJson_throws() {
        // Arrange
        String json = 'this is not json at all';
        Boolean threw = false;

        // Act
        try {
            PIIDetectionService.parseResponse(json);
        } catch (Exception e) {
            threw = true;
        }

        // Assert
        System.assert(threw, 'Malformed JSON should throw to the caller (detectAndMask catches it)');
    }

    // =====================================================================
    // parseBatchResponse (@TestVisible)
    // =====================================================================

    @IsTest
    static void parseBatchResponse_validArray_populatesAllIndices() {
        // Arrange
        String json = '[{"index":0,"maskedText":"first masked","hasPII":true},' +
                      '{"index":1,"maskedText":"second clean","hasPII":false}]';

        // Act
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.parseBatchResponse(json, 2);

        // Assert
        System.assertEquals(2, actual.size());
        System.assertEquals('first masked', actual[0].maskedText);
        System.assertEquals(true, actual[0].hasPII);
        System.assertEquals(true, actual[0].success);
        System.assertEquals('second clean', actual[1].maskedText);
        System.assertEquals(false, actual[1].hasPII);
    }

    @IsTest
    static void parseBatchResponse_missingIndex_returnsEmptyList() {
        // Arrange
        // Chunk size 3, but model only returned 2 items - one index is missing
        String json = '[{"index":0,"maskedText":"a","hasPII":false},' +
                      '{"index":2,"maskedText":"c","hasPII":false}]';

        // Act
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.parseBatchResponse(json, 3);

        // Assert
        System.assertEquals(0, actual.size(), 'Any gap in indices should return empty list so caller falls back');
    }

    @IsTest
    static void parseBatchResponse_indexOutOfRange_isIgnored() {
        // Arrange
        // An index beyond the expected size should be silently ignored
        String json = '[{"index":0,"maskedText":"ok","hasPII":false},' +
                      '{"index":1,"maskedText":"ok","hasPII":false},' +
                      '{"index":99,"maskedText":"junk","hasPII":true}]';

        // Act
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.parseBatchResponse(json, 2);

        // Assert
        System.assertEquals(2, actual.size(), 'Only the first two indices are within range');
        System.assertEquals('ok', actual[0].maskedText);
        System.assertEquals('ok', actual[1].maskedText);
    }

    @IsTest
    static void parseBatchResponse_malformedJson_throws() {
        // Arrange
        String json = '{not an array}';
        Boolean threw = false;

        // Act
        try {
            PIIDetectionService.parseBatchResponse(json, 1);
        } catch (Exception e) {
            threw = true;
        }

        // Assert
        System.assert(threw, 'Malformed batch JSON should throw to the caller');
    }

    // =====================================================================
    // detectAndMask - end-to-end with mocked callEinstein
    // =====================================================================

    @IsTest
    static void detectAndMask_validResponse_returnsSuccess() {
        // Arrange
        String json = buildSingleResponseJson(
            'Contact [REDACTED-EMAIL] for help',
            true,
            new Map<String, String>{ 'EMAIL' => 'john@example.com' }
        );
        enqueueMockResponse(json);
        String input = 'Contact john@example.com for help';

        // Act
        Test.startTest();
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.detectAndMask(input);
        Test.stopTest();

        // Assert
        System.assertEquals(true, actual.success);
        System.assertEquals(true, actual.hasPII);
        System.assertEquals('Contact [REDACTED-EMAIL] for help', actual.maskedText);
        System.assertEquals(1, actual.findings.size());
        System.assertEquals('EMAIL', actual.findings[0].findingType);
    }

    @IsTest
    static void detectAndMask_malformedResponseJson_setsSuccessFalse() {
        // Arrange
        enqueueMockResponse('this is not JSON, the model hallucinated');
        String input = 'Some text';

        // Act
        Test.startTest();
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.detectAndMask(input);
        Test.stopTest();

        // Assert
        System.assertEquals(false, actual.success, 'Parse failure should be caught and surfaced as success=false');
        System.assertEquals(false, actual.hasPII);
        System.assertEquals(input, actual.maskedText, 'Original text should be returned on parse failure');
        System.assert(actual.errorMessage != null, 'Error message should be populated');
    }

    @IsTest
    static void detectAndMask_calloutThrows_setsSuccessFalseWithErrorMessage() {
        // Arrange
        // CalloutException is the typical failure mode for aiplatform.ModelsAPI
        enqueueMockException(new CalloutException('simulated timeout'));
        String input = 'Some text that would have been sent';

        // Act
        Test.startTest();
        PIIDetectionService.PIIMaskingResult actual = PIIDetectionService.detectAndMask(input);
        Test.stopTest();

        // Assert
        System.assertEquals(false, actual.success);
        System.assertEquals(input, actual.maskedText, 'Original text returned when callout fails');
        System.assert(
            actual.errorMessage != null && actual.errorMessage.contains('simulated timeout'),
            'Error message should surface the exception text: ' + actual.errorMessage
        );
    }

    // =====================================================================
    // detectAndMaskBatch - end-to-end with mocked callEinstein
    // =====================================================================

    @IsTest
    static void detectAndMaskBatch_happyPath_singleChunk_returnsAllResults() {
        // Arrange
        String batchJson =
            '[{"index":0,"maskedText":"masked A","hasPII":true},' +
             '{"index":1,"maskedText":"clean B","hasPII":false},' +
             '{"index":2,"maskedText":"masked C","hasPII":true}]';
        enqueueMockResponse(batchJson);
        List<String> input = new List<String>{ 'A', 'B', 'C' };

        // Act
        Test.startTest();
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.detectAndMaskBatch(input);
        Test.stopTest();

        // Assert
        System.assertEquals(3, actual.size());
        System.assertEquals('masked A', actual[0].maskedText);
        System.assertEquals(true, actual[0].hasPII);
        System.assertEquals('clean B', actual[1].maskedText);
        System.assertEquals(false, actual[1].hasPII);
        System.assertEquals('masked C', actual[2].maskedText);
    }

    @IsTest
    static void detectAndMaskBatch_sizeMismatch_fallsBackToIndividualCalls() {
        // Arrange
        // Batch returns only 1 entry for 3 inputs -> size mismatch triggers fallback.
        // Fallback makes 3 individual callEinstein calls, so we need 4 mock responses total:
        //   [0] bogus batch, [1][2][3] individual
        enqueueMockResponse('[{"index":0,"maskedText":"only one","hasPII":true}]');
        enqueueMockResponse(buildSingleResponseJson('fallback A', false, null));
        enqueueMockResponse(buildSingleResponseJson('fallback B', true,
            new Map<String, String>{ 'EMAIL' => 'x@y.com' }));
        enqueueMockResponse(buildSingleResponseJson('fallback C', false, null));
        List<String> input = new List<String>{ 'A', 'B', 'C' };

        // Act
        Test.startTest();
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.detectAndMaskBatch(input);
        Test.stopTest();

        // Assert
        System.assertEquals(3, actual.size());
        System.assertEquals('fallback A', actual[0].maskedText, 'Fallback individual call result for A');
        System.assertEquals('fallback B', actual[1].maskedText, 'Fallback individual call result for B');
        System.assertEquals('fallback C', actual[2].maskedText, 'Fallback individual call result for C');
        System.assertEquals(true, actual[0].success);
        System.assertEquals(true, actual[1].success);
    }

    @IsTest
    static void detectAndMaskBatch_calloutThrows_fallsBackToIndividualCalls() {
        // Arrange
        // Batch call throws -> caught in processBatchChunk -> fallback to 3 individual detectAndMask calls.
        enqueueMockException(new CalloutException('batch failed'));
        enqueueMockResponse(buildSingleResponseJson('ind A', false, null));
        enqueueMockResponse(buildSingleResponseJson('ind B', false, null));
        enqueueMockResponse(buildSingleResponseJson('ind C', false, null));
        List<String> input = new List<String>{ 'A', 'B', 'C' };

        // Act
        Test.startTest();
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.detectAndMaskBatch(input);
        Test.stopTest();

        // Assert
        System.assertEquals(3, actual.size());
        System.assertEquals('ind A', actual[0].maskedText);
        System.assertEquals('ind B', actual[1].maskedText);
        System.assertEquals('ind C', actual[2].maskedText);
        for (PIIDetectionService.PIIMaskingResult r : actual) {
            System.assertEquals(true, r.success, 'Each fallback call succeeded individually');
        }
    }

    @IsTest
    static void detectAndMaskBatch_allIndividualFallbacksAlsoFail_stillReturnsResults() {
        // Arrange
        // Every call throws; detectAndMask still returns a result per input (success=false).
        enqueueMockException(new CalloutException('batch fail'));
        enqueueMockException(new CalloutException('ind 1 fail'));
        enqueueMockException(new CalloutException('ind 2 fail'));
        List<String> input = new List<String>{ 'X', 'Y' };

        // Act
        Test.startTest();
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.detectAndMaskBatch(input);
        Test.stopTest();

        // Assert
        System.assertEquals(2, actual.size(), 'One result per input even when all callouts fail');
        System.assertEquals(false, actual[0].success);
        System.assertEquals('X', actual[0].maskedText, 'Original preserved on failure');
        System.assertEquals(false, actual[1].success);
        System.assertEquals('Y', actual[1].maskedText);
    }

    @IsTest
    static void detectAndMaskBatch_exceedsBatchSize_processesMultipleChunks() {
        // Arrange
        // BATCH_SIZE is 10 -> 12 inputs should produce 2 chunks of 10 and 2.
        String chunk1Json = buildBatchJson(10);
        String chunk2Json = buildBatchJson(2);
        enqueueMockResponse(chunk1Json);
        enqueueMockResponse(chunk2Json);

        List<String> input = new List<String>();
        for (Integer i = 0; i < 12; i++) {
            input.add('text ' + i);
        }

        // Act
        Test.startTest();
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.detectAndMaskBatch(input);
        Test.stopTest();

        // Assert
        System.assertEquals(12, actual.size(), 'Both chunks should be concatenated into the final result list');
        for (PIIDetectionService.PIIMaskingResult r : actual) {
            System.assertEquals(true, r.success);
        }
    }

    @IsTest
    static void detectAndMaskBatch_blankInputInChunk_isPreservedInPromptAsEmpty() {
        // Arrange
        // Blank entries are sent to Einstein as "(empty)" placeholder; the model
        // still returns an entry for each index. We don't inspect the prompt here,
        // but we assert that the end-to-end flow survives a blank input.
        enqueueMockResponse(
            '[{"index":0,"maskedText":"real masked","hasPII":true},' +
             '{"index":1,"maskedText":"","hasPII":false}]'
        );
        List<String> input = new List<String>{ 'john@example.com', '' };

        // Act
        Test.startTest();
        List<PIIDetectionService.PIIMaskingResult> actual =
            PIIDetectionService.detectAndMaskBatch(input);
        Test.stopTest();

        // Assert
        System.assertEquals(2, actual.size());
        System.assertEquals('real masked', actual[0].maskedText);
        System.assertEquals('', actual[1].maskedText);
    }

    // =====================================================================
    // Additional batch-construction helper (kept near the test that uses it)
    // =====================================================================

    private static String buildBatchJson(Integer size) {
        List<String> items = new List<String>();
        for (Integer i = 0; i < size; i++) {
            items.add('{"index":' + i + ',"maskedText":"m' + i + '","hasPII":false}');
        }
        return '[' + String.join(items, ',') + ']';
    }
}
