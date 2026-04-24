/**
 * Replaces any non-blank input with a fixed placeholder.
 *
 * Parameters accepted:
 *   - replacement (String, default "****"): the literal string to return.
 *
 * Blank input is passed through unchanged so that empty fields are
 * not accidentally populated with a placeholder value.
 */
public class RedactStrategy implements MaskingStrategy {
    @TestVisible
    private static final String DEFAULT_REPLACEMENT = '****';

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }
        String replacement = DEFAULT_REPLACEMENT;
        if (params != null && params.containsKey('replacement')) {
            Object raw = params.get('replacement');
            if (raw != null) {
                replacement = String.valueOf(raw);
            }
        }
        return replacement;
    }
}
