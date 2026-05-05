// Smoke test for the new realistic-fake masking strategies. Run with:
//   sf apex run --file scripts/apex/realistic-fakes-smoke.apex --target-org my-sandbox

System.debug('=== Realistic-fake masking smoke test ===');

MaskingStrategy nameLib   = MaskingStrategyRegistry.resolve('LibraryStrategy');
MaskingStrategy fakeEmail = MaskingStrategyRegistry.resolve('FakeEmailStrategy');
MaskingStrategy fakePhone = MaskingStrategyRegistry.resolve('FakePhoneStrategy');
MaskingStrategy redactPat = MaskingStrategyRegistry.resolve('RedactPatternsStrategy');

Map<String, Object> firstParams = new Map<String, Object>{ 'libraryName' => 'FIRST_NAME' };
Map<String, Object> lastParams  = new Map<String, Object>{ 'libraryName' => 'LAST_NAME' };
Map<String, Object> coParams    = new Map<String, Object>{ 'libraryName' => 'COMPANY' };

System.debug('FirstName Anna       -> ' + nameLib.mask('Anna', firstParams));
System.debug('LastName  Jensen     -> ' + nameLib.mask('Jensen', lastParams));
System.debug('Company   Acme Corp  -> ' + nameLib.mask('Acme Corp', coParams));

System.debug('Email mymail@gmail.com -> ' + fakeEmail.mask('mymail@gmail.com', null));
System.debug('Email anna@gmail.com   -> ' + fakeEmail.mask('anna@gmail.com', null));
String e1 = fakeEmail.mask('anna@gmail.com', null);
String e2 = fakeEmail.mask('anna@gmail.com', null);
System.debug('Same input twice gives same output: ' + (e1 == e2));

System.debug('Phone +45 12 34 56 78  -> ' + fakePhone.mask('+45 12 34 56 78', null));
System.debug('Phone (415) 555-0100   -> ' + fakePhone.mask('(415) 555-0100', null));
System.debug('Phone keepLastN=4      -> ' + fakePhone.mask('+45 12 34 56 78', new Map<String, Object>{ 'keepLastN' => 4 }));

String descRaw = 'Customer Anna phoned at 11am. CPR 123456-7890, card 4111-2222-3333-4444 CVV: 123 Exp: 12/25, email anna@gmail.com. Salary: 95000.';
System.debug('Description raw:    ' + descRaw);
System.debug('Description masked: ' + redactPat.mask(descRaw, null));

System.debug('=== End smoke test ===');
