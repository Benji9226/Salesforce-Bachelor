/**
 * Central dispatcher for the IDEA-1 pluggable-strategy registry.
 *
 * Loads active Masking_Rule__mdt rows for a given {Object, Field},
 * instantiates the configured strategy class via Type.forName, parses
 * its JSON parameters, and applies the strategy to the input value.
 * Multiple rules bound to the same field are applied in ascending
 * Order__c order (NULLS LAST), enabling simple pipelines such as
 * "hash then prefix" without code changes.
 *
 * Strategy instances are cached for the lifetime of the transaction,
 * which is safe because MaskingStrategy implementations are contractually
 * stateless.
 *
 * Tests inject Masking_Rule__mdt fixtures via the @TestVisible
 * TEST_RULES field instead of relying on SOQL against real CMDT rows,
 * so no SeeAllData annotation or test-only CMDT records are required.
 */
public with sharing class MaskingStrategyRegistry {

    @TestVisible
    private static List<Masking_Rule__mdt> TEST_RULES;

    private static final Map<String, MaskingStrategy> STRATEGY_CACHE =
        new Map<String, MaskingStrategy>();

    /**
     * Resolve a strategy class name to a cached singleton instance.
     * Throws MaskingStrategyException if the class does not exist or
     * does not implement MaskingStrategy.
     */
    public static MaskingStrategy resolve(String className) {
        if (String.isBlank(className)) {
            throw new MaskingStrategyException('Strategy class name cannot be blank');
        }
        if (STRATEGY_CACHE.containsKey(className)) {
            return STRATEGY_CACHE.get(className);
        }
        Type t = Type.forName(className);
        if (t == null) {
            throw new MaskingStrategyException('Strategy class not found: ' + className);
        }
        Object instance;
        try {
            instance = t.newInstance();
        } catch (Exception e) {
            throw new MaskingStrategyException(
                'Failed to instantiate ' + className + ': ' + e.getMessage()
            );
        }
        if (!(instance instanceof MaskingStrategy)) {
            throw new MaskingStrategyException(
                className + ' does not implement MaskingStrategy'
            );
        }
        MaskingStrategy strategy = (MaskingStrategy) instance;
        STRATEGY_CACHE.put(className, strategy);
        return strategy;
    }

    /**
     * Apply every active Masking_Rule__mdt row matching {objectApi, fieldApi}
     * to the input value, in Order__c order. Returns the (potentially
     * transformed) value. If no rules match, the input is returned as-is.
     */
    public static String applyRulesForField(String objectApi, String fieldApi, String input) {
        List<Masking_Rule__mdt> rules = loadRules(objectApi, fieldApi);
        String output = input;
        for (Masking_Rule__mdt rule : rules) {
            MaskingStrategy strategy = resolve(rule.Strategy_Class__c);
            Map<String, Object> params = parseParams(rule.Parameters_JSON__c);
            output = strategy.mask(output, params);
        }
        return output;
    }

    /**
     * Bulk variant: apply the configured rules for each field of each
     * record. Mutates the SObjects in place and returns them for
     * convenience. Fields with no configured rule are left untouched.
     *
     * Callers are responsible for DML. This keeps the registry free
     * of assumptions about sharing rules, transactions, or governor
     * limit strategies.
     */
    public static List<SObject> applyRules(String objectApi, List<String> fieldApis, List<SObject> records) {
        if (records == null || records.isEmpty() || fieldApis == null || fieldApis.isEmpty()) {
            return records;
        }
        Map<String, List<Masking_Rule__mdt>> rulesByField =
            new Map<String, List<Masking_Rule__mdt>>();
        for (String fieldApi : fieldApis) {
            rulesByField.put(fieldApi, loadRules(objectApi, fieldApi));
        }
        for (SObject record : records) {
            for (String fieldApi : fieldApis) {
                List<Masking_Rule__mdt> rules = rulesByField.get(fieldApi);
                if (rules == null || rules.isEmpty()) {
                    continue;
                }
                Object currentRaw = record.get(fieldApi);
                String current = currentRaw == null ? null : String.valueOf(currentRaw);
                for (Masking_Rule__mdt rule : rules) {
                    MaskingStrategy strategy = resolve(rule.Strategy_Class__c);
                    Map<String, Object> params = parseParams(rule.Parameters_JSON__c);
                    current = strategy.mask(current, params);
                }
                record.put(fieldApi, current);
            }
        }
        return records;
    }

    /**
     * Clears the transaction-local strategy cache. Exposed for tests
     * so that a test run that changes TEST_RULES never sees a stale
     * instance from a previous invocation.
     */
    @TestVisible
    private static void clearCache() {
        STRATEGY_CACHE.clear();
    }

    private static List<Masking_Rule__mdt> loadRules(String objectApi, String fieldApi) {
        if (TEST_RULES != null) {
            List<Masking_Rule__mdt> filtered = new List<Masking_Rule__mdt>();
            for (Masking_Rule__mdt r : TEST_RULES) {
                if (r.Is_Active__c == true
                    && r.Object_API_Name__c == objectApi
                    && r.Field_API_Name__c == fieldApi) {
                    filtered.add(r);
                }
            }
            return filtered;
        }
        return [
            SELECT Strategy_Class__c, Parameters_JSON__c, Order__c, Is_Active__c,
                   Object_API_Name__c, Field_API_Name__c, DeveloperName
            FROM Masking_Rule__mdt
            WHERE Is_Active__c = TRUE
              AND Object_API_Name__c = :objectApi
              AND Field_API_Name__c = :fieldApi
            ORDER BY Order__c NULLS LAST, DeveloperName ASC
        ];
    }

    private static Map<String, Object> parseParams(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(rawJson);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
        } catch (Exception e) {
            // Malformed parameter JSON is treated as "no parameters" so
            // that a single bad row does not halt an entire masking run.
        }
        return new Map<String, Object>();
    }

    public class MaskingStrategyException extends Exception {}
}
