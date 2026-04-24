/**
 * Non-deterministic replacement with random characters, preserving input length.
 *
 * This is the closest equivalent of Salesforce Data Mask's "Replace with
 * Random Characters or Numbers" option. Every invocation produces a
 * different result even for the same input, so referential integrity
 * across objects is NOT preserved.
 *
 * Parameters accepted:
 *   - alphabet (String, default A-Z a-z 0-9): character pool to draw from.
 */
public class ScrambleStrategy implements MaskingStrategy {
    @TestVisible
    private static final String DEFAULT_ALPHABET =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }
        String alphabet = DEFAULT_ALPHABET;
        if (params != null && params.containsKey('alphabet')) {
            Object raw = params.get('alphabet');
            if (raw != null) {
                String candidate = String.valueOf(raw);
                if (String.isNotBlank(candidate)) {
                    alphabet = candidate;
                }
            }
        }
        Integer alphaLen = alphabet.length();
        Integer inputLen = input.length();
        List<String> pieces = new List<String>();
        for (Integer i = 0; i < inputLen; i++) {
            Integer idx = Math.mod(Crypto.getRandomInteger(), alphaLen);
            if (idx < 0) {
                idx += alphaLen;
            }
            pieces.add(alphabet.substring(idx, idx + 1));
        }
        return String.join(pieces, '');
    }
}
