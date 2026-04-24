/**
 * IDEA-1 playground — see every active Masking_Rule__mdt in action
 * against real records in the org.
 *
 * Usage:
 *   sf apex run --target-org my-sandbox --file scripts/apex/idea1-playground.apex
 * or paste into Developer Console > Execute Anonymous.
 *
 * This script NEVER commits DML. Everything is preview-only. You can
 * run it as many times as you like and nothing in the sandbox changes.
 */

// 1. Print every active rule currently configured in the org
List<Masking_Rule__mdt> activeRules = [
    SELECT DeveloperName, Object_API_Name__c, Field_API_Name__c,
           Strategy_Class__c, Parameters_JSON__c, Order__c
    FROM Masking_Rule__mdt
    WHERE Is_Active__c = TRUE
    ORDER BY Object_API_Name__c, Field_API_Name__c, Order__c NULLS LAST
];

System.debug('=== ACTIVE MASKING RULES (' + activeRules.size() + ' total) ===');
for (Masking_Rule__mdt r : activeRules) {
    System.debug(
        String.format(
            '  {0}.{1}  -> {2}  params={3}  order={4}',
            new List<Object>{
                r.Object_API_Name__c,
                r.Field_API_Name__c,
                r.Strategy_Class__c,
                r.Parameters_JSON__c == null ? '(none)' : r.Parameters_JSON__c,
                r.Order__c == null ? '(end)' : String.valueOf(r.Order__c)
            }
        )
    );
}

if (activeRules.isEmpty()) {
    System.debug('  (no rules yet — create one in Setup > Custom Metadata Types > Masking Rule)');
    return;
}

// 2. For each distinct Object, pick up to 5 records and show before/after
//    for every configured field. Uses in-memory mutation only (no DML).
Set<String> distinctObjects = new Set<String>();
for (Masking_Rule__mdt r : activeRules) {
    distinctObjects.add(r.Object_API_Name__c);
}

for (String objectName : distinctObjects) {
    Set<String> fieldSet = new Set<String>();
    for (Masking_Rule__mdt r : activeRules) {
        if (r.Object_API_Name__c == objectName) {
            fieldSet.add(r.Field_API_Name__c);
        }
    }
    List<String> fieldList = new List<String>(fieldSet);

    // Build a SOQL that selects Id + every configured field
    String soql = 'SELECT Id, ' + String.join(fieldList, ', ')
                + ' FROM ' + objectName
                + ' LIMIT 5';

    List<SObject> records;
    try {
        records = Database.query(soql);
    } catch (Exception e) {
        System.debug('!! Could not query ' + objectName + ': ' + e.getMessage());
        continue;
    }

    System.debug('\n=== ' + objectName + ' (' + records.size() + ' records sampled) ===');

    // Snapshot originals before mutation
    List<Map<String, Object>> originals = new List<Map<String, Object>>();
    for (SObject rec : records) {
        Map<String, Object> snapshot = new Map<String, Object>();
        for (String f : fieldList) {
            snapshot.put(f, rec.get(f));
        }
        snapshot.put('Id', rec.get('Id'));
        originals.add(snapshot);
    }

    // Apply all configured rules (in-memory only)
    MaskingStrategyRegistry.applyRules(objectName, fieldList, records);

    // Print before/after per record, per field
    for (Integer i = 0; i < records.size(); i++) {
        SObject after = records[i];
        Map<String, Object> before = originals[i];
        System.debug('  record ' + before.get('Id'));
        for (String f : fieldList) {
            Object beforeVal = before.get(f);
            Object afterVal = after.get(f);
            System.debug(
                '    ' + f + ':  ' +
                (beforeVal == null ? '(null)' : String.valueOf(beforeVal)) +
                '   ->   ' +
                (afterVal == null ? '(null)' : String.valueOf(afterVal))
            );
        }
    }
}

System.debug('\n=== DONE ===');
System.debug('This was preview-only. No records were modified in the sandbox.');
System.debug('To actually persist masked values, add `update records;` inside the loop.');
