/**
 * Deterministic, format-preserving character substitution (Caesar shift).
 *
 * Each character is shifted within its own category:
 *   - uppercase letters [A-Z] shift within [A-Z]
 *   - lowercase letters [a-z] shift within [a-z]
 *   - digits [0-9] shift within [0-9]
 *   - every other character is kept verbatim
 *
 * This keeps field length and broad "shape" identical to the input
 * (useful for testing against validation rules that require e.g. an
 * all-digit phone number or an @-bearing email). It is deliberately
 * TRIVIALLY REVERSIBLE: the shift size is the whole key, so anyone
 * who sees one plaintext/ciphertext pair can recover the mapping.
 * That is the thesis-relevant contrast with HashStrategy (strong,
 * irreversible, not format-preserving) — the two strategies sit at
 * opposite ends of the privacy-utility frontier.
 *
 * Inspired by Cloud Compliance DataMasker's Apex Action character-map
 * pattern, simplified here to a shift so the registry can demonstrate
 * the strategy contract without requiring the Char_Map__mdt datastore
 * that IDEA-5 will introduce.
 *
 * Parameters accepted:
 *   - shift (Integer, default 13): how many positions to advance each
 *     character within its category. Negative shifts are supported.
 */
public class FormatPreservingStrategy implements MaskingStrategy {
    @TestVisible
    private static final Integer DEFAULT_SHIFT = 13;

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }
        Integer shift = DEFAULT_SHIFT;
        if (params != null && params.containsKey('shift')) {
            Object raw = params.get('shift');
            if (raw != null) {
                shift = Integer.valueOf(raw);
            }
        }
        Integer len = input.length();
        List<Integer> codepoints = new List<Integer>();
        for (Integer i = 0; i < len; i++) {
            Integer cp = input.charAt(i);
            if (cp >= 65 && cp <= 90) {
                cp = 65 + positiveMod(cp - 65 + shift, 26);
            } else if (cp >= 97 && cp <= 122) {
                cp = 97 + positiveMod(cp - 97 + shift, 26);
            } else if (cp >= 48 && cp <= 57) {
                cp = 48 + positiveMod(cp - 48 + shift, 10);
            }
            codepoints.add(cp);
        }
        return String.fromCharArray(codepoints);
    }

    private Integer positiveMod(Integer value, Integer modulus) {
        Integer result = Math.mod(value, modulus);
        if (result < 0) {
            result += modulus;
        }
        return result;
    }
}
