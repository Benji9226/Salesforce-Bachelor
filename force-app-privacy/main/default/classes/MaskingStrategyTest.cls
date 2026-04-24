/**
 * Unit tests for the IDEA-1 pluggable masking strategy registry.
 *
 * The tests are organised into one section per strategy plus a
 * dedicated section for MaskingStrategyRegistry. Each strategy is
 * exercised directly (without SOQL) and then the registry is
 * exercised via the @TestVisible TEST_RULES injection, so no real
 * Masking_Rule__mdt records or SeeAllData annotation are required.
 */
@IsTest
private class MaskingStrategyTest {

    // ---------------------------------------------------------------
    // NullStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void nullStrategy_alwaysReturnsNull() {
        MaskingStrategy s = new NullStrategy();
        System.assertEquals(null, s.mask('anything', null), 'non-blank input should null');
        System.assertEquals(null, s.mask('', null), 'blank input should null');
        System.assertEquals(null, s.mask(null, null), 'null input should null');
        System.assertEquals(null, s.mask('x', new Map<String, Object>{ 'ignored' => 'yes' }),
            'params are ignored');
    }

    // ---------------------------------------------------------------
    // RedactStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void redactStrategy_defaultReplacement() {
        MaskingStrategy s = new RedactStrategy();
        System.assertEquals('****', s.mask('john@example.com', null));
        System.assertEquals('****', s.mask('12345', new Map<String, Object>()));
    }

    @IsTest
    static void redactStrategy_customReplacement() {
        MaskingStrategy s = new RedactStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'replacement' => '[REDACTED]' };
        System.assertEquals('[REDACTED]', s.mask('secret', params));
    }

    @IsTest
    static void redactStrategy_blankInputIsPassthrough() {
        MaskingStrategy s = new RedactStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    @IsTest
    static void redactStrategy_nullParamValueFallsBackToDefault() {
        MaskingStrategy s = new RedactStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'replacement' => null };
        System.assertEquals('****', s.mask('secret', params),
            'null replacement param should use default');
    }

    // ---------------------------------------------------------------
    // ScrambleStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void scrambleStrategy_preservesLength() {
        MaskingStrategy s = new ScrambleStrategy();
        String input = 'Hello World 123';
        String output = s.mask(input, null);
        System.assertEquals(input.length(), output.length(),
            'output length must equal input length');
    }

    @IsTest
    static void scrambleStrategy_usesOnlyDefaultAlphabet() {
        MaskingStrategy s = new ScrambleStrategy();
        String output = s.mask('Hello World 123', null);
        for (Integer i = 0; i < output.length(); i++) {
            String ch = output.substring(i, i + 1);
            System.assert(ScrambleStrategy.DEFAULT_ALPHABET.contains(ch),
                'character ' + ch + ' not in default alphabet');
        }
    }

    @IsTest
    static void scrambleStrategy_customAlphabet() {
        MaskingStrategy s = new ScrambleStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'alphabet' => 'X' };
        String output = s.mask('abcd', params);
        System.assertEquals('XXXX', output, 'single-char alphabet produces uniform output');
    }

    @IsTest
    static void scrambleStrategy_blankAlphabetFallsBackToDefault() {
        MaskingStrategy s = new ScrambleStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'alphabet' => '' };
        String output = s.mask('abc', params);
        System.assertEquals(3, output.length());
    }

    @IsTest
    static void scrambleStrategy_nullAlphabetParamFallsBackToDefault() {
        MaskingStrategy s = new ScrambleStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'alphabet' => null };
        String output = s.mask('abc', params);
        System.assertEquals(3, output.length());
    }

    @IsTest
    static void scrambleStrategy_blankInputIsPassthrough() {
        MaskingStrategy s = new ScrambleStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    // ---------------------------------------------------------------
    // HashStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void hashStrategy_isDeterministic() {
        MaskingStrategy s = new HashStrategy();
        String a = s.mask('john@example.com', null);
        String b = s.mask('john@example.com', null);
        System.assertEquals(a, b, 'same input must produce same output');
    }

    @IsTest
    static void hashStrategy_differentInputsDifferentOutputs() {
        MaskingStrategy s = new HashStrategy();
        String a = s.mask('john@example.com', null);
        String b = s.mask('jane@example.com', null);
        System.assertNotEquals(a, b, 'different inputs should not collide on 16 hex chars');
    }

    @IsTest
    static void hashStrategy_defaultLengthIs16() {
        MaskingStrategy s = new HashStrategy();
        String output = s.mask('abc', null);
        System.assertEquals(16, output.length(), 'default length should be 16 hex chars');
    }

    @IsTest
    static void hashStrategy_customLength() {
        MaskingStrategy s = new HashStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'length' => 8 };
        String output = s.mask('abc', params);
        System.assertEquals(8, output.length());
    }

    @IsTest
    static void hashStrategy_lengthZeroReturnsFullDigest() {
        MaskingStrategy s = new HashStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'length' => 0 };
        String output = s.mask('abc', params);
        System.assertEquals(64, output.length(), 'SHA-256 hex = 64 chars');
    }

    @IsTest
    static void hashStrategy_customPrefix() {
        MaskingStrategy s = new HashStrategy();
        Map<String, Object> params = new Map<String, Object>{
            'prefix' => 'H_', 'length' => 8
        };
        String output = s.mask('abc', params);
        System.assert(output.startsWith('H_'), 'output should start with prefix');
        System.assertEquals(10, output.length(), 'prefix (2) + hex (8) = 10');
    }

    @IsTest
    static void hashStrategy_customAlgorithm() {
        MaskingStrategy s = new HashStrategy();
        Map<String, Object> params = new Map<String, Object>{
            'algorithm' => 'SHA-512', 'length' => 0
        };
        String output = s.mask('abc', params);
        System.assertEquals(128, output.length(), 'SHA-512 hex = 128 chars');
    }

    @IsTest
    static void hashStrategy_blankAlgorithmFallsBackToDefault() {
        MaskingStrategy s = new HashStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'algorithm' => '' };
        String output = s.mask('abc', params);
        System.assertEquals(16, output.length(), 'default algo SHA-256 with length 16');
    }

    @IsTest
    static void hashStrategy_blankInputIsPassthrough() {
        MaskingStrategy s = new HashStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    // ---------------------------------------------------------------
    // FormatPreservingStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void formatPreserving_lettersStayLetters() {
        MaskingStrategy s = new FormatPreservingStrategy();
        String output = s.mask('AbcDefXyz', new Map<String, Object>{ 'shift' => 1 });
        System.assertEquals('BcdEfgYza', output,
            'every letter should shift by 1 within its case');
    }

    @IsTest
    static void formatPreserving_digitsStayDigits() {
        MaskingStrategy s = new FormatPreservingStrategy();
        String output = s.mask('0123456789', new Map<String, Object>{ 'shift' => 1 });
        System.assertEquals('1234567890', output, 'digits shift within [0-9]');
    }

    @IsTest
    static void formatPreserving_specialCharsPreserved() {
        MaskingStrategy s = new FormatPreservingStrategy();
        String output = s.mask('a.b@c-d_e!', new Map<String, Object>{ 'shift' => 1 });
        System.assertEquals('b.c@d-e_f!', output, 'special chars must be preserved verbatim');
    }

    @IsTest
    static void formatPreserving_isReversibleWithNegativeShift() {
        MaskingStrategy s = new FormatPreservingStrategy();
        String input = 'Hello123World';
        String encoded = s.mask(input, new Map<String, Object>{ 'shift' => 7 });
        String decoded = s.mask(encoded, new Map<String, Object>{ 'shift' => -7 });
        System.assertEquals(input, decoded,
            'round-trip with opposite shift should recover input');
    }

    @IsTest
    static void formatPreserving_defaultShiftIs13() {
        MaskingStrategy s = new FormatPreservingStrategy();
        String a = s.mask('abc', null);
        String b = s.mask('abc', new Map<String, Object>{ 'shift' => 13 });
        System.assertEquals(b, a, 'null params should match explicit shift=13');
    }

    @IsTest
    static void formatPreserving_blankInputIsPassthrough() {
        MaskingStrategy s = new FormatPreservingStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    // ---------------------------------------------------------------
    // LibraryStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void libraryStrategy_isDeterministic() {
        MaskingStrategy s = new LibraryStrategy();
        String a = s.mask('Alice', null);
        String b = s.mask('Alice', null);
        System.assertEquals(a, b, 'same input must produce same library entry');
    }

    @IsTest
    static void libraryStrategy_defaultLibraryIsFirstName() {
        MaskingStrategy s = new LibraryStrategy();
        String output = s.mask('Alice', null);
        System.assert(LibraryStrategy.FIRST_NAMES.contains(output),
            'default library should be FIRST_NAME, got: ' + output);
    }

    @IsTest
    static void libraryStrategy_lastNameLibrary() {
        MaskingStrategy s = new LibraryStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'libraryName' => 'LAST_NAME' };
        String output = s.mask('Alice', params);
        System.assert(LibraryStrategy.LAST_NAMES.contains(output),
            'output should come from LAST_NAME library');
    }

    @IsTest
    static void libraryStrategy_companyLibrary() {
        MaskingStrategy s = new LibraryStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'libraryName' => 'COMPANY' };
        String output = s.mask('Acme Corp', params);
        System.assert(LibraryStrategy.COMPANIES.contains(output),
            'output should come from COMPANY library');
    }

    @IsTest
    static void libraryStrategy_unknownLibraryReturnsInputUnchanged() {
        MaskingStrategy s = new LibraryStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'libraryName' => 'DOES_NOT_EXIST' };
        String output = s.mask('Alice', params);
        System.assertEquals('Alice', output,
            'unknown library name should pass input through unchanged');
    }

    @IsTest
    static void libraryStrategy_blankLibraryFallsBackToDefault() {
        MaskingStrategy s = new LibraryStrategy();
        Map<String, Object> params = new Map<String, Object>{ 'libraryName' => '' };
        String output = s.mask('Alice', params);
        System.assert(LibraryStrategy.FIRST_NAMES.contains(output),
            'blank library name should fall back to FIRST_NAME');
    }

    @IsTest
    static void libraryStrategy_blankInputIsPassthrough() {
        MaskingStrategy s = new LibraryStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    @IsTest
    static void libraryStrategy_differentInputsUsuallyDifferentOutputs() {
        // Not a strict invariant (collisions are possible with 26 entries),
        // but 4 distinct inputs should almost certainly hit at least 2 buckets.
        MaskingStrategy s = new LibraryStrategy();
        Set<String> outputs = new Set<String>{
            s.mask('Alice', null),
            s.mask('Bob', null),
            s.mask('Carol', null),
            s.mask('Dave', null)
        };
        System.assert(outputs.size() >= 2,
            'four distinct inputs should not all collide: ' + outputs);
    }

    // ---------------------------------------------------------------
    // MaskingStrategyRegistry
    // ---------------------------------------------------------------

    @IsTest
    static void registry_resolvesBuiltInStrategy() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategy s = MaskingStrategyRegistry.resolve('HashStrategy');
        System.assert(s instanceof HashStrategy, 'should return a HashStrategy instance');
    }

    @IsTest
    static void registry_cachesInstance() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategy a = MaskingStrategyRegistry.resolve('HashStrategy');
        MaskingStrategy b = MaskingStrategyRegistry.resolve('HashStrategy');
        System.assert(a == b, 'second resolve should return the cached singleton');
    }

    @IsTest
    static void registry_rejectsBlankClassName() {
        MaskingStrategyRegistry.clearCache();
        try {
            MaskingStrategyRegistry.resolve(null);
            System.assert(false, 'should have thrown');
        } catch (MaskingStrategyRegistry.MaskingStrategyException e) {
            System.assert(e.getMessage().contains('blank'));
        }
    }

    @IsTest
    static void registry_rejectsMissingClass() {
        MaskingStrategyRegistry.clearCache();
        try {
            MaskingStrategyRegistry.resolve('This_Class_Does_Not_Exist_xyz123');
            System.assert(false, 'should have thrown');
        } catch (MaskingStrategyRegistry.MaskingStrategyException e) {
            System.assert(e.getMessage().contains('not found'));
        }
    }

    @IsTest
    static void registry_rejectsNonStrategyClass() {
        MaskingStrategyRegistry.clearCache();
        // MaskingStrategyRegistry is a real class but does not implement
        // MaskingStrategy, which is exactly what we want to test.
        try {
            MaskingStrategyRegistry.resolve('MaskingStrategyRegistry');
            System.assert(false, 'should have thrown');
        } catch (MaskingStrategyRegistry.MaskingStrategyException e) {
            System.assert(e.getMessage().contains('does not implement'));
        }
    }

    @IsTest
    static void registry_applyRulesForField_noRules_returnsInputUnchanged() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>();
        String output = MaskingStrategyRegistry.applyRulesForField(
            'Contact', 'Email', 'john@example.com'
        );
        System.assertEquals('john@example.com', output,
            'no rules = passthrough');
    }

    @IsTest
    static void registry_applyRulesForField_singleRule() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Contact_Email_Redact',
                Is_Active__c = true,
                Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Email',
                Strategy_Class__c = 'RedactStrategy',
                Parameters_JSON__c = '{"replacement":"[REDACTED]"}',
                Order__c = 1
            )
        };
        String output = MaskingStrategyRegistry.applyRulesForField(
            'Contact', 'Email', 'john@example.com'
        );
        System.assertEquals('[REDACTED]', output);
    }

    @IsTest
    static void registry_applyRulesForField_multipleRulesAppliedInOrder() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Contact_Email_Hash',
                Is_Active__c = true,
                Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Email',
                Strategy_Class__c = 'HashStrategy',
                Parameters_JSON__c = '{"length":8}',
                Order__c = 1
            ),
            new Masking_Rule__mdt(
                DeveloperName = 'Contact_Email_Redact',
                Is_Active__c = true,
                Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Email',
                Strategy_Class__c = 'RedactStrategy',
                Parameters_JSON__c = null,
                Order__c = 2
            )
        };
        String output = MaskingStrategyRegistry.applyRulesForField(
            'Contact', 'Email', 'john@example.com'
        );
        System.assertEquals('****', output,
            'hash then redact should yield the redact placeholder');
    }

    @IsTest
    static void registry_applyRulesForField_skipsInactiveRules() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Inactive_Rule',
                Is_Active__c = false,
                Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Email',
                Strategy_Class__c = 'NullStrategy',
                Order__c = 1
            )
        };
        String output = MaskingStrategyRegistry.applyRulesForField(
            'Contact', 'Email', 'keep-me'
        );
        System.assertEquals('keep-me', output, 'inactive rule must be ignored');
    }

    @IsTest
    static void registry_applyRulesForField_handlesMalformedJsonGracefully() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Bad_Json',
                Is_Active__c = true,
                Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Email',
                Strategy_Class__c = 'RedactStrategy',
                Parameters_JSON__c = '{"replacement": not valid json',
                Order__c = 1
            )
        };
        String output = MaskingStrategyRegistry.applyRulesForField(
            'Contact', 'Email', 'secret'
        );
        System.assertEquals('****', output,
            'malformed JSON should fall through to defaults');
    }

    @IsTest
    static void registry_applyRulesForField_handlesNonObjectJsonGracefully() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Array_Json',
                Is_Active__c = true,
                Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Email',
                Strategy_Class__c = 'RedactStrategy',
                Parameters_JSON__c = '[1,2,3]',
                Order__c = 1
            )
        };
        String output = MaskingStrategyRegistry.applyRulesForField(
            'Contact', 'Email', 'secret'
        );
        System.assertEquals('****', output,
            'non-object JSON should fall through to defaults');
    }

    @IsTest
    static void registry_applyRulesBulk_maskesMultipleRecordsAndFields() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Account_Name_Library',
                Is_Active__c = true,
                Object_API_Name__c = 'Account',
                Field_API_Name__c = 'Name',
                Strategy_Class__c = 'LibraryStrategy',
                Parameters_JSON__c = '{"libraryName":"COMPANY"}',
                Order__c = 1
            ),
            new Masking_Rule__mdt(
                DeveloperName = 'Account_Phone_Scramble',
                Is_Active__c = true,
                Object_API_Name__c = 'Account',
                Field_API_Name__c = 'Phone',
                Strategy_Class__c = 'ScrambleStrategy',
                Order__c = 1
            )
        };
        List<SObject> records = new List<SObject>{
            new Account(Name = 'Original Co A', Phone = '555-0100'),
            new Account(Name = 'Original Co B', Phone = '555-0200')
        };
        MaskingStrategyRegistry.applyRules(
            'Account',
            new List<String>{ 'Name', 'Phone' },
            records
        );
        for (SObject so : records) {
            Account a = (Account) so;
            System.assert(LibraryStrategy.COMPANIES.contains(a.Name),
                'Name should be from COMPANY library, got: ' + a.Name);
            System.assertEquals(8, a.Phone.length(),
                'Phone should preserve original length (8)');
        }
    }

    @IsTest
    static void registry_applyRulesBulk_noopOnEmptyInputs() {
        MaskingStrategyRegistry.clearCache();
        System.assertEquals(null,
            MaskingStrategyRegistry.applyRules('Account', null, null));
        System.assertEquals(0,
            MaskingStrategyRegistry.applyRules(
                'Account',
                new List<String>{ 'Name' },
                new List<SObject>()
            ).size());
    }

    @IsTest
    static void registry_applyRulesBulk_leavesUnconfiguredFieldsAlone() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>();
        List<SObject> records = new List<SObject>{
            new Account(Name = 'Should Stay', Phone = '555-0100')
        };
        MaskingStrategyRegistry.applyRules(
            'Account',
            new List<String>{ 'Name', 'Phone' },
            records
        );
        Account a = (Account) records[0];
        System.assertEquals('Should Stay', a.Name);
        System.assertEquals('555-0100', a.Phone);
    }

    @IsTest
    static void registry_applyRulesBulk_handlesNullFieldValues() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategyRegistry.TEST_RULES = new List<Masking_Rule__mdt>{
            new Masking_Rule__mdt(
                DeveloperName = 'Account_Phone_Redact',
                Is_Active__c = true,
                Object_API_Name__c = 'Account',
                Field_API_Name__c = 'Phone',
                Strategy_Class__c = 'RedactStrategy',
                Order__c = 1
            )
        };
        List<SObject> records = new List<SObject>{
            new Account(Name = 'No Phone Inc', Phone = null)
        };
        MaskingStrategyRegistry.applyRules(
            'Account',
            new List<String>{ 'Phone' },
            records
        );
        Account a = (Account) records[0];
        System.assertEquals(null, a.Phone,
            'null phone should pass through RedactStrategy unchanged');
    }
}
