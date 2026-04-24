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
}
