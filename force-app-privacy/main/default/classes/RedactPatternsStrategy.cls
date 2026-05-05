/**
 * Pattern-based redaction for free-text fields like Case.Description,
 * Lead.Description, Task.Description, and any other long text where
 * structured PII can be embedded but the surrounding prose should
 * stay readable.
 *
 * The classic example from the existing org:
 *
 *   Original   "Customer Anna called from +45 12345678 about her CPR
 *              123456-7890 and her credit card 4111-2222-3333-4444.
 *              Email: anna@gmail.com. Salary: 95000."
 *
 *   Redacted   "Customer Anna called from +45 ****  about her CPR
 *              ******-**** and her credit card ****-****-****-****.
 *              Email: ***@***.***. Salary: ******."
 *
 * The prose ("Customer Anna called from", "about her CPR", etc.) stays
 * readable so the masked record is still useful for case-routing QA,
 * sentiment analysis, or LLM testing — but the regex-detectable PII
 * (CPR, credit card, IBAN, email, long digit runs, salary) is gone.
 *
 * Pure-string proper names like "Anna" are NOT removed by this
 * strategy on purpose: regex cannot reliably tell a person name from
 * a city or a product name without a model. For that, chain this
 * strategy with the EinsteinAI option in the Mask Workbench, which
 * routes the same text through PIIDetectionService and removes the
 * model-detectable entities. The two stages are complementary:
 * regex catches structured PII deterministically; the model catches
 * fuzzy entities that regex cannot.
 *
 * This is the strategy that the IDEA-1 catalogue should bind to
 * Case.Description / Lead.Description / Task.Description rows. Until
 * now the same regex pipeline lived only in
 * SafeReportExportController.maskFreeText, which meant the catalogue
 * could not target it without duplicating the regex list. Pulling
 * the patterns into a proper MaskingStrategy class closes that gap
 * and is the SRQ5 "single source of truth" pay-off for free-text PII.
 *
 * Inspired by the Microsoft Presidio "default recognizers" set and
 * the regex catalogue used in Salesforce's Data Detect engine — the
 * specific patterns are kept narrow on purpose so a typo cannot
 * over-redact a whole sentence.
 *
 * Parameters accepted:
 *   - includeEmail (Boolean, default true): mask email addresses to
 *     "***@***.***". Set to false when chaining with FakeEmailStrategy
 *     on a separate field so the same email is not redacted twice.
 *   - includeCpr (Boolean, default true): mask Danish CPR numbers
 *     (NNNNNN-NNNN).
 *   - includeCreditCard (Boolean, default true): mask 16-digit
 *     numbers in the NNNN-NNNN-NNNN-NNNN format.
 *   - includeIban (Boolean, default true): mask IBAN-shaped tokens.
 *   - includeLongDigitRun (Boolean, default true): mask any 9-18
 *     consecutive digits. This is the catch-all for unformatted
 *     phone numbers, account numbers, and order IDs.
 *   - includeSalary (Boolean, default true): mask the literal
 *     "Salary: NNNN" pattern.
 *   - includeCvv (Boolean, default true): mask "CVV: NNN".
 *   - includeExpiry (Boolean, default true): mask "Exp: NN/NN".
 */
public class RedactPatternsStrategy implements MaskingStrategy {

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }
        String masked = input;

        if (readBool(params, 'includeCpr', true)) {
            masked = masked.replaceAll('\\b\\d{6}-\\d{4}\\b', '******-****');
        }
        if (readBool(params, 'includeCreditCard', true)) {
            masked = masked.replaceAll(
                '\\b\\d{4}-\\d{4}-\\d{4}-\\d{4}\\b',
                '****-****-****-****'
            );
        }
        if (readBool(params, 'includeCvv', true)) {
            masked = masked.replaceAll('\\bCVV:\\s*\\d{3}\\b', 'CVV: ***');
        }
        if (readBool(params, 'includeExpiry', true)) {
            masked = masked.replaceAll(
                '\\bExp:\\s*\\d{2}/\\d{2}\\b',
                'Exp: **/**'
            );
        }
        if (readBool(params, 'includeIban', true)) {
            masked = masked.replaceAll(
                '\\b[A-Z]{2}\\d{2}[A-Z0-9]{4,}\\d{7,}[A-Z0-9]{0,16}\\b',
                '****IBAN****'
            );
        }
        if (readBool(params, 'includeLongDigitRun', true)) {
            masked = masked.replaceAll('\\b\\d{9,18}\\b', '****');
        }
        if (readBool(params, 'includeSalary', true)) {
            masked = masked.replaceAll('Salary:\\s*\\d+', 'Salary: ******');
        }
        if (readBool(params, 'includeEmail', true)) {
            masked = masked.replaceAll(
                '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}',
                '***@***.***'
            );
        }
        return masked;
    }

    private Boolean readBool(Map<String, Object> params, String key, Boolean fallback) {
        if (params == null || !params.containsKey(key)) {
            return fallback;
        }
        Object raw = params.get(key);
        if (raw == null) {
            return fallback;
        }
        if (raw instanceof Boolean) {
            return (Boolean) raw;
        }
        String s = String.valueOf(raw).toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
        return fallback;
    }
}
