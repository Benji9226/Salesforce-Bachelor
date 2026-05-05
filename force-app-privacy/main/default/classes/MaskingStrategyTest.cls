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

    // ---------------------------------------------------------------
    // FakeEmailStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void fakeEmail_blankInputIsPassthrough() {
        MaskingStrategy s = new FakeEmailStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    @IsTest
    static void fakeEmail_isDeterministic() {
        MaskingStrategy s = new FakeEmailStrategy();
        String a = s.mask('anna@gmail.com', null);
        String b = s.mask('anna@gmail.com', null);
        System.assertEquals(a, b, 'same input must produce same fake email');
    }

    @IsTest
    static void fakeEmail_keepsOriginalDomainByDefault() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask('anna@gmail.com', null);
        System.assert(output.endsWith('@gmail.com'),
            'default behaviour must preserve the original domain, got: ' + output);
    }

    @IsTest
    static void fakeEmail_localPartIsFromLibrary() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask('anna@gmail.com', null);
        String localPart = output.substring(0, output.indexOf('@'));
        System.assert(localPart.contains('.'),
            'default firstdotlast style should contain a dot: ' + localPart);
        List<String> halves = localPart.split('\\.');
        System.assertEquals(2, halves.size(),
            'firstdotlast should produce exactly first.last, got: ' + localPart);
        Boolean firstFromLib = false;
        for (String n : LibraryStrategy.FIRST_NAMES) {
            if (halves[0] == n.toLowerCase()) { firstFromLib = true; break; }
        }
        Boolean lastFromLib = false;
        for (String n : LibraryStrategy.LAST_NAMES) {
            if (halves[1] == n.toLowerCase()) { lastFromLib = true; break; }
        }
        System.assert(firstFromLib,
            'first half must come from FIRST_NAMES library: ' + halves[0]);
        System.assert(lastFromLib,
            'last half must come from LAST_NAMES library: ' + halves[1]);
    }

    @IsTest
    static void fakeEmail_overrideDomain() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask(
            'anna@gmail.com',
            new Map<String, Object>{ 'domain' => 'fakecorp.test' }
        );
        System.assert(output.endsWith('@fakecorp.test'),
            'override domain must be honoured: ' + output);
    }

    @IsTest
    static void fakeEmail_styleFirstLast() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask(
            'anna@gmail.com',
            new Map<String, Object>{ 'style' => 'firstlast' }
        );
        String localPart = output.substring(0, output.indexOf('@'));
        System.assert(!localPart.contains('.'),
            'firstlast style must not contain a dot: ' + localPart);
    }

    @IsTest
    static void fakeEmail_styleFirstNum_endsWithTwoDigits() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask(
            'anna@gmail.com',
            new Map<String, Object>{ 'style' => 'firstnum' }
        );
        String localPart = output.substring(0, output.indexOf('@'));
        System.assert(localPart.length() >= 3,
            'firstnum should produce at least name+two digits: ' + localPart);
        String tail = localPart.substring(localPart.length() - 2);
        System.assert(tail.isNumeric(),
            'firstnum must end with two digits, got: ' + tail);
    }

    @IsTest
    static void fakeEmail_unknownStyleFallsBackToFirstDotLast() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask(
            'anna@gmail.com',
            new Map<String, Object>{ 'style' => 'unsupported_style_xyz' }
        );
        String localPart = output.substring(0, output.indexOf('@'));
        System.assert(localPart.contains('.'),
            'unknown style must fall back to firstdotlast: ' + localPart);
    }

    @IsTest
    static void fakeEmail_inputWithNoAtSignUsesFallbackDomain() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask('not-an-email', null);
        System.assert(output.endsWith('@example.com'),
            'no-@ input must fall back to example.com: ' + output);
    }

    @IsTest
    static void fakeEmail_overrideFallbackDomain() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask(
            'not-an-email',
            new Map<String, Object>{ 'fallbackDomain' => 'redacted.local' }
        );
        System.assert(output.endsWith('@redacted.local'),
            'fallbackDomain must be honoured for no-@ input: ' + output);
    }

    @IsTest
    static void fakeEmail_differentInputsProduceDifferentOutputs() {
        MaskingStrategy s = new FakeEmailStrategy();
        Set<String> outputs = new Set<String>{
            s.mask('anna@gmail.com', null),
            s.mask('bob@gmail.com', null),
            s.mask('carol@gmail.com', null),
            s.mask('dave@gmail.com', null)
        };
        System.assert(outputs.size() >= 2,
            'four distinct inputs should not all collide: ' + outputs);
    }

    @IsTest
    static void fakeEmail_blankOverrideDomainFallsBackToOriginal() {
        MaskingStrategy s = new FakeEmailStrategy();
        String output = s.mask(
            'anna@gmail.com',
            new Map<String, Object>{ 'domain' => '' }
        );
        System.assert(output.endsWith('@gmail.com'),
            'blank override must fall back to original domain: ' + output);
    }

    // ---------------------------------------------------------------
    // FakePhoneStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void fakePhone_blankInputIsPassthrough() {
        MaskingStrategy s = new FakePhoneStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    @IsTest
    static void fakePhone_isDeterministic() {
        MaskingStrategy s = new FakePhoneStrategy();
        String a = s.mask('+45 12 34 56 78', null);
        String b = s.mask('+45 12 34 56 78', null);
        System.assertEquals(a, b, 'same input must produce same fake phone');
    }

    @IsTest
    static void fakePhone_preservesNonDigitCharacters() {
        MaskingStrategy s = new FakePhoneStrategy();
        String input = '+45 (12) 34-56.78';
        String output = s.mask(input, null);
        System.assertEquals(input.length(), output.length(),
            'output length must equal input length');
        for (Integer i = 0; i < input.length(); i++) {
            Integer cp = input.charAt(i);
            if (!(cp >= 48 && cp <= 57)) {
                System.assertEquals(input.substring(i, i + 1),
                    output.substring(i, i + 1),
                    'non-digit at index ' + i + ' must be preserved');
            }
        }
    }

    @IsTest
    static void fakePhone_replacesDigitsWithDigits() {
        MaskingStrategy s = new FakePhoneStrategy();
        String output = s.mask('+45 12 34 56 78', null);
        for (Integer i = 0; i < output.length(); i++) {
            Integer cp = output.charAt(i);
            String ch = output.substring(i, i + 1);
            // Either it was a non-digit (preserved verbatim) or it is a digit.
            Boolean isDigit = cp >= 48 && cp <= 57;
            Boolean isPreservedNonDigit = ' +-()._/'.contains(ch);
            System.assert(isDigit || isPreservedNonDigit,
                'every char must be a digit or a preserved separator, got: ' + ch);
        }
    }

    @IsTest
    static void fakePhone_outputDiffersFromInput() {
        MaskingStrategy s = new FakePhoneStrategy();
        // SHA-256 collisions producing the same digit pattern are
        // astronomically unlikely; if this assert ever fails for a
        // realistic phone number we have a real bug, not a flake.
        String input = '+45 12 34 56 78';
        String output = s.mask(input, null);
        System.assertNotEquals(input, output,
            'masked phone should differ from the original');
    }

    @IsTest
    static void fakePhone_keepLastNPreservesTrailingDigits() {
        MaskingStrategy s = new FakePhoneStrategy();
        String input = '555-123-4567';
        String output = s.mask(
            input,
            new Map<String, Object>{ 'keepLastN' => 4 }
        );
        System.assertEquals(input.length(), output.length());
        System.assert(output.endsWith('4567'),
            'keepLastN=4 must preserve last four digits, got: ' + output);
    }

    @IsTest
    static void fakePhone_keepLastNLargerThanDigitCountKeepsAll() {
        MaskingStrategy s = new FakePhoneStrategy();
        String input = '12-34';
        String output = s.mask(
            input,
            new Map<String, Object>{ 'keepLastN' => 999 }
        );
        System.assertEquals(input, output,
            'keepLastN larger than digit count must preserve every digit');
    }

    @IsTest
    static void fakePhone_negativeKeepLastNTreatedAsZero() {
        MaskingStrategy s = new FakePhoneStrategy();
        String inputA = s.mask('555-123-4567',
            new Map<String, Object>{ 'keepLastN' => -3 });
        String inputB = s.mask('555-123-4567', null);
        System.assertEquals(inputB, inputA,
            'negative keepLastN must behave identically to default');
    }

    @IsTest
    static void fakePhone_saltChangesOutput() {
        MaskingStrategy s = new FakePhoneStrategy();
        String unsalted = s.mask('555-123-4567', null);
        String salted = s.mask(
            '555-123-4567',
            new Map<String, Object>{ 'salt' => 'org-A' }
        );
        System.assertNotEquals(unsalted, salted,
            'salt should change the deterministic output');
    }

    @IsTest
    static void fakePhone_differentInputsProduceDifferentOutputs() {
        MaskingStrategy s = new FakePhoneStrategy();
        Set<String> outputs = new Set<String>{
            s.mask('+45 11 11 11 11', null),
            s.mask('+45 22 22 22 22', null),
            s.mask('+45 33 33 33 33', null),
            s.mask('+45 44 44 44 44', null)
        };
        System.assert(outputs.size() >= 2,
            'four distinct inputs should not all collide: ' + outputs);
    }

    @IsTest
    static void fakePhone_inputWithNoDigitsPassthrough() {
        MaskingStrategy s = new FakePhoneStrategy();
        String input = 'no digits here';
        String output = s.mask(input, null);
        System.assertEquals(input, output,
            'input with zero digits must be returned verbatim');
    }

    // ---------------------------------------------------------------
    // RedactPatternsStrategy
    // ---------------------------------------------------------------

    @IsTest
    static void redactPatterns_blankInputIsPassthrough() {
        MaskingStrategy s = new RedactPatternsStrategy();
        System.assertEquals(null, s.mask(null, null));
        System.assertEquals('', s.mask('', null));
    }

    @IsTest
    static void redactPatterns_masksDanishCpr() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('CPR is 123456-7890 today', null);
        System.assert(output.contains('******-****'),
            'CPR pattern must be redacted: ' + output);
        System.assert(!output.contains('123456-7890'));
    }

    @IsTest
    static void redactPatterns_masksCreditCard() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('Card 4111-2222-3333-4444 expires soon', null);
        System.assert(output.contains('****-****-****-****'),
            'credit card must be redacted: ' + output);
    }

    @IsTest
    static void redactPatterns_masksCvvAndExpiry() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('CVV: 123 and Exp: 12/25', null);
        System.assert(output.contains('CVV: ***'), 'CVV must be redacted: ' + output);
        System.assert(output.contains('Exp: **/**'), 'Exp must be redacted: ' + output);
    }

    @IsTest
    static void redactPatterns_masksEmail() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('Contact me at anna@gmail.com please', null);
        System.assert(output.contains('***@***.***'),
            'email must be redacted: ' + output);
        System.assert(!output.contains('anna@gmail.com'));
    }

    @IsTest
    static void redactPatterns_masksLongDigitRun() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('Account 123456789 owes us', null);
        System.assert(output.contains('****'),
            'long digit run must be redacted: ' + output);
        System.assert(!output.contains('123456789'));
    }

    @IsTest
    static void redactPatterns_masksSalary() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('Salary: 95000 per month', null);
        System.assert(output.contains('Salary: ******'),
            'salary must be redacted: ' + output);
    }

    @IsTest
    static void redactPatterns_keepsSurroundingProse() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask('Customer Anna phoned at 11am', null);
        System.assert(output.contains('Customer Anna phoned at'),
            'prose without structured PII must stay readable: ' + output);
    }

    @IsTest
    static void redactPatterns_includeEmailFalseLeavesEmailAlone() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask(
            'Email anna@gmail.com',
            new Map<String, Object>{ 'includeEmail' => false }
        );
        System.assert(output.contains('anna@gmail.com'),
            'includeEmail=false must leave email untouched: ' + output);
    }

    @IsTest
    static void redactPatterns_includeCprFalseLeavesCprAlone() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask(
            'CPR 123456-7890',
            new Map<String, Object>{ 'includeCpr' => false }
        );
        System.assert(output.contains('123456-7890'),
            'includeCpr=false must leave CPR untouched: ' + output);
    }

    @IsTest
    static void redactPatterns_chainedMasksAllPatterns() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String input =
            'Anna called from +45 12345678 about CPR 123456-7890, ' +
            'card 4111-2222-3333-4444 CVV: 123 Exp: 12/25, ' +
            'email anna@gmail.com Salary: 95000';
        String output = s.mask(input, null);
        System.assert(!output.contains('123456-7890'), 'CPR leaked: ' + output);
        System.assert(!output.contains('4111-2222-3333-4444'), 'card leaked: ' + output);
        System.assert(!output.contains('anna@gmail.com'), 'email leaked: ' + output);
        System.assert(!output.contains('Salary: 95000'), 'salary leaked: ' + output);
        System.assert(output.contains('Anna called from'),
            'prose must remain: ' + output);
    }

    @IsTest
    static void redactPatterns_stringTrueParamIsAccepted() {
        MaskingStrategy s = new RedactPatternsStrategy();
        // JSON.deserializeUntyped occasionally hands us "true" / "false"
        // as strings depending on how the catalogue stored them; the
        // strategy must tolerate both forms.
        String output = s.mask(
            'Email anna@gmail.com',
            new Map<String, Object>{ 'includeEmail' => 'true' }
        );
        System.assert(output.contains('***@***.***'),
            'string "true" must enable the email regex: ' + output);
    }

    @IsTest
    static void redactPatterns_stringFalseParamIsAccepted() {
        MaskingStrategy s = new RedactPatternsStrategy();
        String output = s.mask(
            'Email anna@gmail.com',
            new Map<String, Object>{ 'includeEmail' => 'false' }
        );
        System.assert(output.contains('anna@gmail.com'),
            'string "false" must disable the email regex: ' + output);
    }

    // ---------------------------------------------------------------
    // Registry round-trip for the three new strategies
    // ---------------------------------------------------------------

    @IsTest
    static void registry_resolvesFakeEmailStrategy() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategy s = MaskingStrategyRegistry.resolve('FakeEmailStrategy');
        System.assert(s instanceof FakeEmailStrategy);
    }

    @IsTest
    static void registry_resolvesFakePhoneStrategy() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategy s = MaskingStrategyRegistry.resolve('FakePhoneStrategy');
        System.assert(s instanceof FakePhoneStrategy);
    }

    @IsTest
    static void registry_resolvesRedactPatternsStrategy() {
        MaskingStrategyRegistry.clearCache();
        MaskingStrategy s = MaskingStrategyRegistry.resolve('RedactPatternsStrategy');
        System.assert(s instanceof RedactPatternsStrategy);
    }
}
