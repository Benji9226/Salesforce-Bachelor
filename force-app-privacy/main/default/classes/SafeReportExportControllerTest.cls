@IsTest
private class SafeReportExportControllerTest {

    // =====================================================================
    // maskEmail
    // =====================================================================

    @IsTest
    static void maskEmail_typicalAddress_masksLocalAndDomain() {
        // Arrange
        String input = 'john.doe@example.com';
        String expected = 'j***@e***.com';

        // Act
        String actual = SafeReportExportController.maskEmail(input);

        // Assert
        System.assertEquals(expected, actual, 'Typical email should mask all but first char of local and domain');
    }

    @IsTest
    static void maskEmail_singleCharLocal_hitsElseBranch() {
        // Arrange
        String input = 'a@example.com';
        String expected = 'a***@e***.com';

        // Act
        String actual = SafeReportExportController.maskEmail(input);

        // Assert
        System.assertEquals(expected, actual, 'Single-char local takes the else branch and appends ***');
    }

    @IsTest
    static void maskEmail_shortDomain_hitsElseBranch() {
        // Arrange
        String input = 'user@b';
        String expected = 'u***@***';

        // Act
        String actual = SafeReportExportController.maskEmail(input);

        // Assert
        System.assertEquals(expected, actual, 'Domain length <= 2 should fall back to ***');
    }

    @IsTest
    static void maskEmail_noAtSign_returnsSentinel() {
        // Arrange
        String input = 'notAnEmail';
        String expected = '***@***.***';

        // Act
        String actual = SafeReportExportController.maskEmail(input);

        // Assert
        System.assertEquals(expected, actual, 'Input without @ should return the no-email sentinel');
    }

    // =====================================================================
    // maskPhone
    // =====================================================================

    @IsTest
    static void maskPhone_longNumber_keepsLastFour() {
        // Arrange
        String input = '4512345678';
        String expected = '******5678';

        // Act
        String actual = SafeReportExportController.maskPhone(input);

        // Assert
        System.assertEquals(expected, actual, 'All digits except the last four should be masked');
    }

    @IsTest
    static void maskPhone_shortNumber_returnsSentinel() {
        // Arrange
        String input = '123';
        String expected = '***-****';

        // Act
        String actual = SafeReportExportController.maskPhone(input);

        // Assert
        System.assertEquals(expected, actual, 'Phones shorter than 4 chars return the short-phone sentinel');
    }

    @IsTest
    static void maskPhone_exactlyFour_returnsDigitsUnmasked() {
        // Arrange
        // length - 4 == 0, so the replaceAll on an empty prefix is a no-op
        String input = '1234';
        String expected = '1234';

        // Act
        String actual = SafeReportExportController.maskPhone(input);

        // Assert
        System.assertEquals(expected, actual, 'Phone of length 4 keeps all four digits');
    }

    @IsTest
    static void maskPhone_nonDigitPrefix_leavesNonDigitsIntact() {
        // Arrange
        // The prefix branch replaces ONLY [0-9]; '+', spaces and hyphens are preserved
        String input = '+45 12 34 56 78';
        String expected = '+** ** ** *6 78';

        // Act
        String actual = SafeReportExportController.maskPhone(input);

        // Assert
        System.assertEquals(expected, actual, 'Non-digit chars in the prefix should be preserved; only digits are replaced');
    }

    // =====================================================================
    // maskDate
    // =====================================================================

    @IsTest
    static void maskDate_fullIsoDate_keepsLastTwoChars() {
        // Arrange
        String input = '1990-05-15';
        String expected = '****-**-15';

        // Act
        String actual = SafeReportExportController.maskDate(input);

        // Assert
        System.assertEquals(expected, actual, 'Date keeps the last two characters');
    }

    @IsTest
    static void maskDate_singleChar_returnsFullSentinel() {
        // Arrange
        String input = '1';
        String expected = '****-**-**';

        // Act
        String actual = SafeReportExportController.maskDate(input);

        // Assert
        System.assertEquals(expected, actual, 'Inputs shorter than 2 chars return the full date sentinel');
    }

    // =====================================================================
    // maskFreeText
    // =====================================================================

    @IsTest
    static void maskFreeText_cprPattern_isMasked() {
        // Arrange
        String input = 'CPR 123456-7890 on file';
        String expected = 'CPR ******-**** on file';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'Danish CPR pattern should be masked');
    }

    @IsTest
    static void maskFreeText_creditCardPattern_isMasked() {
        // Arrange
        String input = 'Card 1234-5678-9012-3456 charged';
        String expected = 'Card ****-****-****-**** charged';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'Credit card pattern should be masked');
    }

    @IsTest
    static void maskFreeText_cvvPattern_isMasked() {
        // Arrange
        String input = 'CVV: 123 expires soon';
        String expected = 'CVV: *** expires soon';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'CVV pattern should be masked');
    }

    @IsTest
    static void maskFreeText_expiryPattern_isMasked() {
        // Arrange
        String input = 'Exp: 12/25 noted';
        String expected = 'Exp: **/** noted';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'Expiry date pattern should be masked');
    }

    @IsTest
    static void maskFreeText_ibanPattern_isMasked() {
        // Arrange
        String input = 'IBAN DE89370400440532013000 verified';
        String expected = 'IBAN ****IBAN**** verified';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'IBAN pattern should be masked');
    }

    @IsTest
    static void maskFreeText_longDigitRun_isMasked() {
        // Arrange
        // 10 consecutive digits triggers \b\d{9,18}\b
        String input = 'Ref 1234567890 processed';
        String expected = 'Ref **** processed';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, '9-18 digit run should be masked');
    }

    @IsTest
    static void maskFreeText_salaryPattern_isMasked() {
        // Arrange
        String input = 'Salary: 50000 per year';
        String expected = 'Salary: ****** per year';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'Salary: <digits> pattern should be masked');
    }

    @IsTest
    static void maskFreeText_emailInText_isMasked() {
        // Arrange
        String input = 'Contact john@example.com for details';
        String expected = 'Contact ***@***.*** for details';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'Email inside free text should be masked');
    }

    @IsTest
    static void maskFreeText_cleanText_isUnchanged() {
        // Arrange
        String input = 'Nothing sensitive here';
        String expected = 'Nothing sensitive here';

        // Act
        String actual = SafeReportExportController.maskFreeText(input);

        // Assert
        System.assertEquals(expected, actual, 'Clean text should pass through unchanged');
    }

    // =====================================================================
    // isSensitiveHeader - every keyword in the set
    // =====================================================================

    @IsTest
    static void isSensitiveHeader_everyKeyword_returnsTrue() {
        // Arrange
        List<String> sensitiveKeywords = new List<String>{
            'email', 'e-mail', 'phone', 'mobile', 'fax',
            'birthdate', 'birth date', 'date of birth', 'dob',
            'ssn', 'social security', 'cpr', 'national id',
            'credit card', 'card number', 'iban', 'bank',
            'salary', 'income', 'compensation',
            'street', 'address', 'mailing', 'home'
        };

        // Act + Assert (loop over every keyword; each iteration is its own AAA micro-cycle)
        for (String keyword : sensitiveKeywords) {
            Boolean exactMatch = SafeReportExportController.isSensitiveHeader(keyword);
            Boolean embeddedMatch = SafeReportExportController.isSensitiveHeader('Customer ' + keyword + ' value');

            System.assert(exactMatch, 'Exact header "' + keyword + '" should be classified as sensitive');
            System.assert(embeddedMatch, 'Header embedding "' + keyword + '" should be classified as sensitive');
        }
    }

    @IsTest
    static void isSensitiveHeader_accountName_returnsFalse() {
        // Arrange
        String header = 'account name';

        // Act
        Boolean actual = SafeReportExportController.isSensitiveHeader(header);

        // Assert
        System.assertEquals(false, actual, '"account name" should not be classified as sensitive');
    }

    @IsTest
    static void isSensitiveHeader_industry_returnsFalse() {
        // Arrange
        String header = 'industry';

        // Act
        Boolean actual = SafeReportExportController.isSensitiveHeader(header);

        // Assert
        System.assertEquals(false, actual, '"industry" should not be classified as sensitive');
    }

    @IsTest
    static void isSensitiveHeader_idColumn_returnsFalse() {
        // Arrange
        String header = 'id';

        // Act
        Boolean actual = SafeReportExportController.isSensitiveHeader(header);

        // Assert
        System.assertEquals(false, actual, '"id" should not be classified as sensitive');
    }

    // =====================================================================
    // maskByType - every branch
    // =====================================================================

    @IsTest
    static void maskByType_emailHeader_delegatesToMaskEmail() {
        // Arrange
        String value = 'john@example.com';
        String expected = 'j***@e***.com';

        // Act
        String actualEmail = SafeReportExportController.maskByType(value, 'EMAIL', 'email');
        String actualEmailAlt = SafeReportExportController.maskByType(value, 'STRING', 'customer e-mail');

        // Assert
        System.assertEquals(expected, actualEmail, 'Header "email" should delegate to maskEmail');
        System.assertEquals(expected, actualEmailAlt, 'Header containing "e-mail" should delegate to maskEmail');
    }

    @IsTest
    static void maskByType_phoneHeader_delegatesToMaskPhone() {
        // Arrange
        String value = '4512345678';
        String expected = '******5678';

        // Act
        String actualPhone = SafeReportExportController.maskByType(value, 'PHONE', 'phone');
        String actualMobile = SafeReportExportController.maskByType(value, 'STRING', 'mobile');
        String actualFax = SafeReportExportController.maskByType(value, 'STRING', 'fax');

        // Assert
        System.assertEquals(expected, actualPhone, '"phone" header should delegate to maskPhone');
        System.assertEquals(expected, actualMobile, '"mobile" header should delegate to maskPhone');
        System.assertEquals(expected, actualFax, '"fax" header should delegate to maskPhone');
    }

    @IsTest
    static void maskByType_dateHeader_delegatesToMaskDate() {
        // Arrange
        String value = '1990-05-15';
        String expected = '****-**-15';

        // Act
        // NOTE: Apex identifiers are case-insensitive, so `actualBirthdate` and
        // `actualBirthDate` would collide. Use distinct names instead.
        String actualBirthdate = SafeReportExportController.maskByType(value, 'DATE', 'birthdate');
        String actualBirthdateWithSpace = SafeReportExportController.maskByType(value, 'DATE', 'birth date');
        String actualDob = SafeReportExportController.maskByType(value, 'DATE', 'dob');

        // Assert
        System.assertEquals(expected, actualBirthdate, '"birthdate" should delegate to maskDate');
        System.assertEquals(expected, actualBirthdateWithSpace, '"birth date" should delegate to maskDate');
        System.assertEquals(expected, actualDob, '"dob" should delegate to maskDate');
    }

    @IsTest
    static void maskByType_addressHeader_returnsAddressSentinel() {
        // Arrange
        String streetValue = '123 Main St';
        String mailingValue = 'PO Box 10';
        String expected = '*** Masked Address ***';

        // Act
        String actualStreet = SafeReportExportController.maskByType(streetValue, 'STRING', 'street');
        String actualMailing = SafeReportExportController.maskByType(mailingValue, 'STRING', 'mailing address');

        // Assert
        System.assertEquals(expected, actualStreet, 'Street header should return the address sentinel');
        System.assertEquals(expected, actualMailing, 'Mailing header should return the address sentinel');
    }

    @IsTest
    static void maskByType_salaryHeader_returnsSalarySentinel() {
        // Arrange
        String value = '95000';
        String expected = '******';

        // Act
        String actualSalary = SafeReportExportController.maskByType(value, 'NUMBER', 'salary');
        String actualIncome = SafeReportExportController.maskByType(value, 'NUMBER', 'annual income');
        String actualComp = SafeReportExportController.maskByType(value, 'NUMBER', 'compensation');

        // Assert
        System.assertEquals(expected, actualSalary, '"salary" should return salary sentinel');
        System.assertEquals(expected, actualIncome, '"income" should return salary sentinel');
        System.assertEquals(expected, actualComp, '"compensation" should return salary sentinel');
    }

    @IsTest
    static void maskByType_otherSensitiveHeader_returnsDefaultSentinel() {
        // Arrange
        // ssn, iban, bank etc. are sensitive but fall through to the default *** sentinel
        String expected = '***';

        // Act
        String actualSsn = SafeReportExportController.maskByType('123-45-6789', 'STRING', 'ssn');
        String actualIban = SafeReportExportController.maskByType('DE89370400440532013000', 'STRING', 'iban');
        String actualBank = SafeReportExportController.maskByType('Danske Bank', 'STRING', 'bank');

        // Assert
        System.assertEquals(expected, actualSsn, 'SSN header should fall through to default sentinel');
        System.assertEquals(expected, actualIban, 'IBAN header should fall through to default sentinel');
        System.assertEquals(expected, actualBank, 'Bank header should fall through to default sentinel');
    }

    // =====================================================================
    // maskCellValue - passthrough and delegation branches
    // =====================================================================

    @IsTest
    static void maskCellValue_null_passesThrough() {
        // Arrange
        String value = null;

        // Act
        String actual = SafeReportExportController.maskCellValue(value, 'STRING', 'email');

        // Assert
        System.assertEquals(null, actual, 'Null value should pass through unchanged');
    }

    @IsTest
    static void maskCellValue_empty_passesThrough() {
        // Arrange
        String value = '';

        // Act
        String actual = SafeReportExportController.maskCellValue(value, 'STRING', 'email');

        // Assert
        System.assertEquals('', actual, 'Empty string should pass through unchanged');
    }

    @IsTest
    static void maskCellValue_dash_passesThrough() {
        // Arrange
        String value = '-';

        // Act
        String actual = SafeReportExportController.maskCellValue(value, 'STRING', 'email');

        // Assert
        System.assertEquals('-', actual, 'Dash (Salesforce null-equivalent) should pass through unchanged');
    }

    @IsTest
    static void maskCellValue_sensitiveHeader_routesToMaskByType() {
        // Arrange
        String value = 'john@example.com';
        String expected = 'j***@e***.com';

        // Act
        String actual = SafeReportExportController.maskCellValue(value, 'EMAIL', 'email');

        // Assert
        System.assertEquals(expected, actual, 'Sensitive header should route through maskByType');
    }

    @IsTest
    static void maskCellValue_nonSensitiveHeader_routesToMaskFreeText_cleanInput() {
        // Arrange
        String value = 'Technology';
        String expected = 'Technology';

        // Act
        String actual = SafeReportExportController.maskCellValue(value, 'STRING', 'industry');

        // Assert
        System.assertEquals(expected, actual, 'Non-sensitive header + clean text should be unchanged');
    }

    @IsTest
    static void maskCellValue_nonSensitiveHeader_routesToMaskFreeText_dirtyInput() {
        // Arrange
        // Sensitive pattern inside a "notes" column still gets caught by regex masking
        String value = 'Ref 1234567890 done';
        String expected = 'Ref **** done';

        // Act
        String actual = SafeReportExportController.maskCellValue(value, 'STRING', 'notes');

        // Assert
        System.assertEquals(expected, actual, 'Non-sensitive header with dirty content should be caught by maskFreeText');
    }

    // =====================================================================
    // identifyAIColumns
    // =====================================================================

    @IsTest
    static void identifyAIColumns_findsDescriptionNotesAndComment() {
        // Arrange
        List<String> headers = new List<String>{
            'Account Name',   // idx 0 - not AI
            'Description',    // idx 1 - AI
            'Internal Notes', // idx 2 - AI
            'Rep Comment',    // idx 3 - AI
            'Industry'        // idx 4 - not AI
        };

        // Act
        Set<Integer> actual = SafeReportExportController.identifyAIColumns(headers);

        // Assert
        System.assertEquals(3, actual.size(), 'Exactly three AI-handled columns expected');
        System.assert(actual.contains(1), 'Description column should be detected at index 1');
        System.assert(actual.contains(2), 'Notes column should be detected at index 2');
        System.assert(actual.contains(3), 'Comment column should be detected at index 3');
    }

    @IsTest
    static void identifyAIColumns_noMatches_returnsEmptySet() {
        // Arrange
        List<String> headers = new List<String>{ 'Name', 'Industry', 'Revenue' };

        // Act
        Set<Integer> actual = SafeReportExportController.identifyAIColumns(headers);

        // Assert
        System.assert(actual.isEmpty(), 'No AI columns should be detected in a non-text report');
    }

    // =====================================================================
    // collectDescriptionTexts
    // =====================================================================

    @IsTest
    static void collectDescriptionTexts_dedupesAndSkipsNullEmptyDash() {
        // Arrange
        List<List<String>> rows = new List<List<String>>{
            new List<String>{ 'A', 'hello world', 'x' },
            new List<String>{ 'B', 'hello world', 'y' }, // duplicate - deduped
            new List<String>{ 'C', '', 'z' },            // empty - skipped
            new List<String>{ 'D', '-', 'w' },           // dash - skipped
            new List<String>{ 'E', null, 'v' },          // null - skipped
            new List<String>{ 'F', 'another text', 'u' }
        };
        Set<Integer> aiColumns = new Set<Integer>{ 1 };

        // Act
        List<String> actual = SafeReportExportController.collectDescriptionTexts(rows, aiColumns);

        // Assert
        System.assertEquals(2, actual.size(), 'Should collect exactly 2 unique non-empty descriptions');
        System.assert(actual.contains('hello world'), 'Unique description should be collected');
        System.assert(actual.contains('another text'), 'Second unique description should be collected');
    }

    @IsTest
    static void collectDescriptionTexts_columnIndexOutOfBounds_isIgnored() {
        // Arrange
        List<List<String>> rows = new List<List<String>>{
            new List<String>{ 'A' } // only one column at index 0
        };
        Set<Integer> aiColumns = new Set<Integer>{ 5 }; // deliberately out of bounds

        // Act
        List<String> actual = SafeReportExportController.collectDescriptionTexts(rows, aiColumns);

        // Assert
        System.assert(actual.isEmpty(), 'Out-of-bounds column indices should be silently ignored');
    }

    // =====================================================================
    // @AuraEnabled entry points
    //
    // The Reports API cannot be fully mocked in an isolated unit test.
    // These smoke tests exercise the public surface so that coverage
    // reaches the method bodies; happy-path Reports.ReportManager behavior
    // is covered by the integration tests run against seeded reports.
    // =====================================================================

    @IsTest
    static void searchReports_nullTerm_executesWithoutError() {
        // Arrange
        String searchTerm = null;

        // Act
        Test.startTest();
        List<SafeReportExportController.ReportOption> actual =
            SafeReportExportController.searchReports(searchTerm);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, actual, 'searchReports should return a list (possibly empty) for null term');
    }

    @IsTest
    static void searchReports_validSearchTerm_executesWithoutError() {
        // Arrange
        String searchTerm = 'Account';

        // Act
        Test.startTest();
        List<SafeReportExportController.ReportOption> actual =
            SafeReportExportController.searchReports(searchTerm);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, actual, 'searchReports should return a list for a valid search term');
    }

    @IsTest
    static void searchReports_shortSearchTerm_skipsLikeFilter() {
        // Arrange
        // Terms shorter than 2 chars should skip the LIKE clause branch
        String searchTerm = 'a';

        // Act
        Test.startTest();
        List<SafeReportExportController.ReportOption> actual =
            SafeReportExportController.searchReports(searchTerm);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, actual, 'searchReports with a 1-char term should still return a list');
    }

    @IsTest
    static void runRawReport_invalidId_throwsExpectedException() {
        // Arrange
        String invalidReportId = '00O000000000000';
        Boolean threw = false;

        // Act
        Test.startTest();
        try {
            SafeReportExportController.runRawReport(invalidReportId);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        // Assert
        System.assert(threw, 'Running a report with an invalid Id should throw');
    }

    @IsTest
    static void runAndMaskReport_invalidId_throwsExpectedException() {
        // Arrange
        String invalidReportId = '00O000000000000';
        Boolean threw = false;

        // Act
        Test.startTest();
        try {
            SafeReportExportController.runAndMaskReport(invalidReportId);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        // Assert
        System.assert(threw, 'Running a report with an invalid Id should throw');
    }

    // =====================================================================
    // applyStrategyToColumn — per-column dispatcher used by the Mask Workbench
    // =====================================================================

    @IsTest
    static void applyStrategyToColumn_nullValues_returnsEmptyList() {
        // Arrange
        List<String> values = null;

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'RedactStrategy', null);

        // Assert
        System.assertNotEquals(null, actual, 'should never return null');
        System.assert(actual.isEmpty(), 'null input should produce empty list');
    }

    @IsTest
    static void applyStrategyToColumn_emptyValues_returnsEmptyList() {
        // Arrange
        List<String> values = new List<String>();

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'RedactStrategy', null);

        // Assert
        System.assert(actual.isEmpty(), 'empty input should produce empty list');
    }

    @IsTest
    static void applyStrategyToColumn_noneStrategy_passesThrough() {
        // Arrange
        List<String> values = new List<String>{ 'a@b.com', 'foo', '' };

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'None', null);

        // Assert
        System.assertEquals(values, actual, '"None" must return the input unchanged');
    }

    @IsTest
    static void applyStrategyToColumn_blankStrategy_passesThrough() {
        // Arrange
        List<String> values = new List<String>{ 'a', 'b' };

        // Act
        List<String> actualNull =
            SafeReportExportController.applyStrategyToColumn(values, null, null);
        List<String> actualEmpty =
            SafeReportExportController.applyStrategyToColumn(values, '', null);

        // Assert
        System.assertEquals(values, actualNull, 'null strategy must passthrough');
        System.assertEquals(values, actualEmpty, 'empty strategy must passthrough');
    }

    @IsTest
    static void applyStrategyToColumn_redact_redactsEveryNonBlankValue() {
        // Arrange
        List<String> values = new List<String>{ 'a@b.com', 'foo', '' };

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'RedactStrategy', null);

        // Assert
        System.assertEquals(3, actual.size());
        System.assertEquals('****', actual[0]);
        System.assertEquals('****', actual[1]);
        System.assertEquals('', actual[2], 'blank values pass through RedactStrategy unchanged');
    }

    @IsTest
    static void applyStrategyToColumn_hashWithParams_truncatesToLength() {
        // Arrange
        List<String> values = new List<String>{ 'abc' };
        String paramsJson = '{"length":8}';

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'HashStrategy', paramsJson);

        // Assert
        System.assertEquals(8, actual[0].length(),
            'paramsJson must reach the strategy and truncate the digest');
    }

    @IsTest
    static void applyStrategyToColumn_invalidStrategy_throwsAuraHandledException() {
        // Arrange
        List<String> values = new List<String>{ 'x' };
        Boolean threw = false;
        String typeName;

        // Act
        try {
            SafeReportExportController.applyStrategyToColumn(values, 'NoSuchStrategy', null);
        } catch (Exception e) {
            threw = true;
            typeName = e.getTypeName();
        }

        // Assert
        System.assert(threw, 'unknown strategy should throw');
        System.assertEquals('System.AuraHandledException', typeName,
            'underlying exception must be wrapped for the LWC layer');
    }

    @IsTest
    static void applyStrategyToColumn_malformedParamsJson_fallsBackToDefaults() {
        // Arrange
        // 16 hex chars is the HashStrategy default length
        List<String> values = new List<String>{ 'abc' };
        String malformed = '{"length":';

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'HashStrategy', malformed);

        // Assert
        System.assertEquals(16, actual[0].length(),
            'malformed JSON must fall back to HashStrategy defaults');
    }

    @IsTest
    static void applyStrategyToColumn_nonObjectParamsJson_fallsBackToDefaults() {
        // Arrange
        List<String> values = new List<String>{ 'abc' };
        String arrayJson = '[1,2,3]';

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'HashStrategy', arrayJson);

        // Assert
        System.assertEquals(16, actual[0].length(),
            'JSON arrays must fall back to defaults rather than crash');
    }

    @IsTest
    static void applyStrategyToColumn_einstein_dedupesAndAppliesMaskedText() {
        // Arrange
        // Three values, two of which are duplicates -> one Einstein call,
        // result re-applied to both occurrences.
        List<String> values = new List<String>{
            'Contact john@example.com',
            'Contact john@example.com',
            ''
        };
        // Match the BATCH_PROMPT_TEMPLATE response shape produced by Einstein.
        PIIDetectionService.mockResponseQueue = new List<String>{
            '[{"index":0,"maskedText":"Contact [REDACTED-EMAIL]","hasPII":true}]'
        };

        // Act
        Test.startTest();
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'EinsteinAI', null);
        Test.stopTest();

        // Assert
        System.assertEquals(3, actual.size());
        System.assertEquals('Contact [REDACTED-EMAIL]', actual[0]);
        System.assertEquals('Contact [REDACTED-EMAIL]', actual[1],
            'duplicate values should reuse the cached AI output');
        System.assertEquals('', actual[2], 'blank cells must stay blank');
    }

    @IsTest
    static void applyStrategyToColumn_einstein_emptyInput_isNoop() {
        // Arrange
        List<String> values = new List<String>{ '', '-', null };

        // Act
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'EinsteinAI', null);

        // Assert
        System.assertEquals(values.size(), actual.size());
        System.assertEquals('', actual[0]);
        System.assertEquals('-', actual[1]);
        System.assertEquals(null, actual[2]);
    }

    @IsTest
    static void applyStrategyToColumn_einstein_aiFailureFallsBackToRegex() {
        // Arrange
        // Force every Einstein call to throw, which routes through the
        // regex-based maskFreeText fallback inside applyEinsteinToColumn.
        PIIDetectionService.mockExceptionQueue = new List<Exception>{
            new SafeReportExportControllerTestException('forced AI outage'),
            new SafeReportExportControllerTestException('forced AI outage'),
            new SafeReportExportControllerTestException('forced AI outage')
        };
        List<String> values = new List<String>{ 'Contact 1234567890 done' };

        // Act
        Test.startTest();
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'EinsteinAI', null);
        Test.stopTest();

        // Assert
        System.assertEquals('Contact **** done', actual[0],
            'Einstein outage should fall back to the regex maskFreeText path');
    }

    // =====================================================================
    // parseParamsJson - direct exercise of the helper
    // =====================================================================

    @IsTest
    static void parseParamsJson_blank_returnsEmptyMap() {
        System.assert(SafeReportExportController.parseParamsJson(null).isEmpty());
        System.assert(SafeReportExportController.parseParamsJson('').isEmpty());
    }

    @IsTest
    static void parseParamsJson_validObject_returnsParsedMap() {
        // Arrange
        String raw = '{"length":8,"prefix":"H_"}';

        // Act
        Map<String, Object> actual = SafeReportExportController.parseParamsJson(raw);

        // Assert
        System.assertEquals(8, actual.get('length'));
        System.assertEquals('H_', actual.get('prefix'));
    }

    // =====================================================================
    // applyStrategyToColumn — additional Einstein branches
    // =====================================================================

    @IsTest
    static void applyStrategyToColumn_einstein_textWithoutPiiPassesThrough() {
        // Arrange
        // Einstein returns hasPII=false → cache puts the text unchanged.
        PIIDetectionService.mockResponseQueue = new List<String>{
            '[{"index":0,"maskedText":"clean text","hasPII":false}]'
        };
        List<String> values = new List<String>{ 'clean text' };

        // Act
        Test.startTest();
        List<String> actual =
            SafeReportExportController.applyStrategyToColumn(values, 'EinsteinAI', null);
        Test.stopTest();

        // Assert
        System.assertEquals('clean text', actual[0],
            'no-PII responses must pass the original text through unchanged');
    }

    // =====================================================================
    // maskRowsByHeader — direct test of the runReport mask pipeline
    // =====================================================================

    @IsTest
    static void maskRowsByHeader_emptyRows_returnsEmptyList() {
        // Arrange
        List<List<String>> rawRows = new List<List<String>>();
        List<String> headers = new List<String>{ 'Email', 'Description' };
        List<String> types = new List<String>{ 'EMAIL', 'STRING' };

        // Act
        List<List<String>> actual =
            SafeReportExportController.maskRowsByHeader(rawRows, headers, types);

        // Assert
        System.assert(actual != null && actual.isEmpty(), 'empty input must produce empty output');
    }

    @IsTest
    static void maskRowsByHeader_sensitiveHeader_routesThroughMaskByType() {
        // Arrange
        // No AI column means the batchMaskTexts path is skipped entirely
        // and every cell goes through the keyword pipeline.
        List<List<String>> rawRows = new List<List<String>>{
            new List<String>{ 'Acme Inc', 'john@example.com', '4512345678' }
        };
        List<String> headers = new List<String>{ 'Account Name', 'Email', 'Phone' };
        List<String> types = new List<String>{ 'STRING', 'EMAIL', 'PHONE' };

        // Act
        List<List<String>> actual =
            SafeReportExportController.maskRowsByHeader(rawRows, headers, types);

        // Assert
        System.assertEquals(1, actual.size());
        System.assertEquals('Acme Inc', actual[0][0],
            'non-sensitive clean text passes maskFreeText unchanged');
        System.assertEquals('j***@e***.com', actual[0][1], 'email column should be masked');
        System.assertEquals('******5678', actual[0][2], 'phone column should be masked');
    }

    @IsTest
    static void maskRowsByHeader_descriptionColumn_invokesEinsteinAndCachesResults() {
        // Arrange
        // Two rows, same description text → batched Einstein call returns
        // a single masked entry that the cache fans out to both rows.
        PIIDetectionService.mockResponseQueue = new List<String>{
            '[{"index":0,"maskedText":"Contact [REDACTED-EMAIL] later","hasPII":true}]'
        };
        List<List<String>> rawRows = new List<List<String>>{
            new List<String>{ 'A', 'Contact john@example.com later' },
            new List<String>{ 'B', 'Contact john@example.com later' }
        };
        List<String> headers = new List<String>{ 'Account Name', 'Description' };
        List<String> types = new List<String>{ 'STRING', 'STRING' };

        // Act
        Test.startTest();
        List<List<String>> actual =
            SafeReportExportController.maskRowsByHeader(rawRows, headers, types);
        Test.stopTest();

        // Assert
        System.assertEquals(2, actual.size());
        System.assertEquals('Contact [REDACTED-EMAIL] later', actual[0][1]);
        System.assertEquals('Contact [REDACTED-EMAIL] later', actual[1][1],
            'duplicate description rows must reuse the cached AI output');
    }

    @IsTest
    static void maskRowsByHeader_descriptionColumn_aiFailureFallsBackToRegex() {
        // Arrange
        // Force every Einstein call to throw, which routes the description
        // through PIIDetectionService.detectAndMask's catch block.
        PIIDetectionService.mockExceptionQueue = new List<Exception>{
            new SafeReportExportControllerTestException('forced AI outage'),
            new SafeReportExportControllerTestException('forced AI outage'),
            new SafeReportExportControllerTestException('forced AI outage'),
            new SafeReportExportControllerTestException('forced AI outage')
        };
        List<List<String>> rawRows = new List<List<String>>{
            new List<String>{ 'A', 'Ref 1234567890 done' }
        };
        List<String> headers = new List<String>{ 'Account Name', 'Description' };
        List<String> types = new List<String>{ 'STRING', 'STRING' };

        // Act
        Test.startTest();
        List<List<String>> actual =
            SafeReportExportController.maskRowsByHeader(rawRows, headers, types);
        Test.stopTest();

        // Assert
        // batchMaskTexts → success=false branch → maskFreeText fallback in batchMaskTexts.
        System.assertEquals('Ref **** done', actual[0][1],
            'AI outage should fall through to maskFreeText');
    }

    @IsTest
    static void maskRowsByHeader_descriptionColumn_emptyDescriptionStaysEmpty() {
        // Arrange
        // No texts to mask → batchMaskTexts is skipped and the cell falls
        // through the maskFreeText fallback in the for-loop.
        List<List<String>> rawRows = new List<List<String>>{
            new List<String>{ 'A', '' },
            new List<String>{ 'B', '-' }
        };
        List<String> headers = new List<String>{ 'Name', 'Description' };
        List<String> types = new List<String>{ 'STRING', 'STRING' };

        // Act
        List<List<String>> actual =
            SafeReportExportController.maskRowsByHeader(rawRows, headers, types);

        // Assert
        System.assertEquals('', actual[0][1], 'empty description stays empty');
        System.assertEquals('-', actual[1][1], 'dash description stays as dash');
    }

    @IsTest
    static void maskRowsByHeader_columnIndexOutOfBounds_usesSafeDefaults() {
        // Arrange
        // Row has more cells than headers/types → the per-cell defaults
        // ("STRING" type, blank header) are exercised.
        List<List<String>> rawRows = new List<List<String>>{
            new List<String>{ 'a', 'b', 'extra-cell' }
        };
        List<String> headers = new List<String>{ 'Account Name' };
        List<String> types = new List<String>{ 'STRING' };

        // Act
        List<List<String>> actual =
            SafeReportExportController.maskRowsByHeader(rawRows, headers, types);

        // Assert
        // Extra cells take the maskFreeText path with header=''. Clean
        // text returns unchanged.
        System.assertEquals(3, actual[0].size());
        System.assertEquals('a', actual[0][0]);
        System.assertEquals('b', actual[0][1]);
        System.assertEquals('extra-cell', actual[0][2],
            'extra cells should fall through maskFreeText cleanly');
    }

    // =====================================================================
    // batchMaskTexts — exercised through maskRowsByHeader with @TestVisible access
    // =====================================================================

    @IsTest
    static void batchMaskTexts_caches_hasPiiTrue_no_PIIfalse_andFailure() {
        // Arrange
        // First batch call succeeds with a mixed result (PII + no-PII),
        // and a second item later forces the failure path.
        PIIDetectionService.mockResponseQueue = new List<String>{
            '[{"index":0,"maskedText":"masked one","hasPII":true},' +
            '{"index":1,"maskedText":"clean two","hasPII":false}]'
        };
        List<String> texts = new List<String>{ 'one', 'two' };

        // Act
        Test.startTest();
        Map<String, String> actual = SafeReportExportController.batchMaskTexts(texts);
        Test.stopTest();

        // Assert
        System.assertEquals('masked one', actual.get('one'),
            'PII branch caches the masked text');
        System.assertEquals('two', actual.get('two'),
            'no-PII branch caches the original text');
    }

    // =====================================================================
    // loadRecord — detail-mode field loader for the Record tab
    // =====================================================================

    @IsTest
    static void loadRecord_blankObject_throws() {
        Boolean threw = false;
        String typeName;
        try {
            SafeReportExportController.loadRecord('', '001000000000000');
        } catch (Exception e) {
            threw = true;
            typeName = e.getTypeName();
        }
        System.assert(threw, 'blank object api must throw');
        System.assertEquals('System.AuraHandledException', typeName);
    }

    @IsTest
    static void loadRecord_blankRecordId_throws() {
        Boolean threw = false;
        try {
            SafeReportExportController.loadRecord('Account', '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'blank record id must throw');
    }

    @IsTest
    static void loadRecord_disallowedObject_throws() {
        // Arrange
        // User is a real SObject in the org but is intentionally
        // outside the allowlist to keep the detail picker focused on
        // PII-relevant business records.
        Boolean threw = false;
        try {
            SafeReportExportController.loadRecord('User', UserInfo.getUserId());
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'disallowed object must throw');
    }

    @IsTest
    static void loadRecord_unknownId_throws() {
        // Arrange — well-formed but non-existent Account Id
        String fakeId = '001000000000000AAA';
        Boolean threw = false;
        try {
            SafeReportExportController.loadRecord('Account', fakeId);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'non-existent id must throw');
    }

    @IsTest
    static void loadRecord_account_returnsNameAndMaskableFields() {
        // Arrange
        Account a = new Account(
            Name = 'Test Co',
            Phone = '+45 12 34 56 78',
            Website = 'https://example.com',
            BillingCity = 'Copenhagen'
        );
        insert a;

        // Act
        SafeReportExportController.RecordLoadResult result =
            SafeReportExportController.loadRecord('Account', a.Id);

        // Assert
        System.assertEquals('Account', result.objectLabel);
        System.assertEquals('Test Co', result.recordName,
            'Name field value should populate recordName');
        System.assert(result.fields.size() > 0, 'at least one maskable field should be present');

        Map<String, SafeReportExportController.RecordFieldRow> byApi =
            new Map<String, SafeReportExportController.RecordFieldRow>();
        for (SafeReportExportController.RecordFieldRow row : result.fields) {
            byApi.put(row.fieldApiName, row);
        }
        System.assert(byApi.containsKey('Name'), 'Name should be in maskable fields');
        System.assertEquals('Test Co', byApi.get('Name').value);
        System.assert(byApi.containsKey('Phone'), 'Phone should be in maskable fields');
        System.assertEquals('+45 12 34 56 78', byApi.get('Phone').value);
        System.assert(byApi.containsKey('Website'), 'Website should be in maskable fields');
        System.assertEquals('https://example.com', byApi.get('Website').value);
        System.assert(byApi.containsKey('BillingCity'), 'BillingCity should be in maskable fields');
        System.assertEquals('Copenhagen', byApi.get('BillingCity').value);

        // System / audit fields must not appear
        System.assert(!byApi.containsKey('Id'),
            'Id should be excluded from the maskable field list');
        System.assert(!byApi.containsKey('CreatedDate'),
            'CreatedDate is a system field and must be filtered out');

        // Reference fields must not appear (Account.OwnerId / ParentId)
        System.assert(!byApi.containsKey('OwnerId'),
            'reference fields are not maskable and must be filtered out');
    }

    @IsTest
    static void loadRecord_account_emptyFieldsAreFilteredOut() {
        // Arrange — Account with only Name set; everything else is null.
        Account a = new Account(Name = 'Empty Co');
        insert a;

        // Act
        SafeReportExportController.RecordLoadResult result =
            SafeReportExportController.loadRecord('Account', a.Id);

        // Assert
        // Empty fields have nothing to mask, so they must not appear in
        // the field list. Only the populated Name should come back.
        for (SafeReportExportController.RecordFieldRow row : result.fields) {
            System.assertNotEquals('', row.value,
                'empty fields must be filtered out of the LWC payload (got '
                + row.fieldApiName + ')');
        }
        Boolean foundName = false;
        for (SafeReportExportController.RecordFieldRow row : result.fields) {
            if (row.fieldApiName == 'Name') {
                foundName = true;
                System.assertEquals('Empty Co', row.value);
            }
            System.assertNotEquals('Description', row.fieldApiName,
                'unset Description must not survive the empty-field filter');
        }
        System.assert(foundName, 'Populated Name field should remain in the response');
    }

    @IsTest
    static void loadRecord_contact_recordNameUsesNameField() {
        // Arrange
        // LeadSource is required by an org-level validation rule on Contact
        // in this sandbox; supplying it keeps the test independent of admin
        // configuration drift.
        Contact c = new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            Email = 'jane@example.com',
            LeadSource = 'Web'
        );
        insert c;

        // Act
        SafeReportExportController.RecordLoadResult result =
            SafeReportExportController.loadRecord('Contact', c.Id);

        // Assert
        System.assertEquals('Contact', result.objectLabel);
        System.assertEquals('Jane Doe', result.recordName,
            'Contact.Name is a compound field whose value is the standard concatenation');

        Boolean foundEmail = false;
        for (SafeReportExportController.RecordFieldRow row : result.fields) {
            if (row.fieldApiName == 'Email') {
                foundEmail = true;
                System.assertEquals('jane@example.com', row.value);
                System.assertEquals('EMAIL', row.fieldType);
            }
        }
        System.assert(foundEmail, 'Email field should be exposed in detail mode');
    }

    // =====================================================================
    // searchRecords — type-ahead lookup for the Record tab
    // =====================================================================

    @IsTest
    static void searchRecords_blankInputs_returnEmptyList() {
        System.assert(
            SafeReportExportController.searchRecords('', 'Acme').isEmpty(),
            'blank object api should produce empty list, not throw');
        System.assert(
            SafeReportExportController.searchRecords('Account', '').isEmpty(),
            'blank term should produce empty list');
        System.assert(
            SafeReportExportController.searchRecords('Account', null).isEmpty(),
            'null term should produce empty list');
    }

    @IsTest
    static void searchRecords_shortTerm_returnsEmptyList() {
        // Arrange — a real record exists but term is one character.
        insert new Account(Name = 'Acme Industries');

        // Act
        List<SafeReportExportController.RecordOption> actual =
            SafeReportExportController.searchRecords('Account', 'A');

        // Assert
        System.assert(actual.isEmpty(),
            'one-character terms must short-circuit before SOQL to keep type-ahead cheap');
    }

    @IsTest
    static void searchRecords_disallowedObject_throws() {
        Boolean threw = false;
        try {
            SafeReportExportController.searchRecords('User', 'admin');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'objects outside the allowlist must throw');
    }

    @IsTest
    static void searchRecords_account_matchesByNamePrefix() {
        // Arrange
        insert new List<Account>{
            new Account(Name = 'Acme Industries'),
            new Account(Name = 'Acme Logistics'),
            new Account(Name = 'Beta Corp')
        };

        // Act
        List<SafeReportExportController.RecordOption> actual =
            SafeReportExportController.searchRecords('Account', 'Acme');

        // Assert
        System.assertEquals(2, actual.size(), 'two Acme accounts should match');
        Set<String> names = new Set<String>();
        for (SafeReportExportController.RecordOption opt : actual) {
            names.add(opt.recordName);
            System.assertNotEquals(null, opt.recordId, 'every option must carry an Id');
        }
        System.assert(names.contains('Acme Industries'));
        System.assert(names.contains('Acme Logistics'));
        System.assert(!names.contains('Beta Corp'),
            'non-matching accounts must not leak through');
    }

    @IsTest
    static void searchRecords_contact_matchesByNameField() {
        // Arrange — Contact's name field is the compound Name (FirstName + LastName).
        insert new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            LeadSource = 'Web'
        );
        insert new Contact(
            FirstName = 'John',
            LastName = 'Smith',
            LeadSource = 'Web'
        );

        // Act
        List<SafeReportExportController.RecordOption> actual =
            SafeReportExportController.searchRecords('Contact', 'Doe');

        // Assert
        System.assertEquals(1, actual.size());
        System.assertEquals('Jane Doe', actual[0].recordName);
    }

    @IsTest
    static void searchRecords_noMatches_returnsEmptyList() {
        // Arrange
        insert new Account(Name = 'Acme Industries');

        // Act
        List<SafeReportExportController.RecordOption> actual =
            SafeReportExportController.searchRecords('Account', 'ZzzNotAMatch');

        // Assert
        System.assert(actual.isEmpty(), 'a term with no matches must return an empty list');
    }

    private class SafeReportExportControllerTestException extends Exception {}
}
