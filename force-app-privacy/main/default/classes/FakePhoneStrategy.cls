/**
 * Deterministic, format-preserving fake phone-number substitution.
 *
 * Replaces every digit in the input with another digit derived from
 * the SHA-256 hash of the input plus the digit's position. Non-digit
 * characters (spaces, dashes, parentheses, '+', dots, slashes) are
 * preserved verbatim, so a Danish-formatted "+45 12 34 56 78" stays
 * "+45 ## ## ## ##" shape and a US-formatted "(415) 555-0100" stays
 * "(###) ###-####" shape.
 *
 * The key thesis-relevant trade-off vs. FormatPreservingStrategy:
 *
 *   * FormatPreservingStrategy applies the same Caesar shift to every
 *     digit, which means the relationship between adjacent digits is
 *     preserved (123 always shifts to 456 with shift=3). That is
 *     trivially reversible from a single known plaintext.
 *
 *   * FakePhoneStrategy hashes the entire input, so two different
 *     phone numbers produce uncorrelated outputs even when they share
 *     a prefix. Recovering the original from the masked value would
 *     require breaking SHA-256, which moves the strategy into the
 *     pseudonymisation regime of GDPR Art. 4(5).
 *
 * Determinism: same input -> same output, every time, without any
 * cross-row state. This preserves referential integrity (the same
 * customer's phone on Contact and Lead masks to the same fake
 * number), which is what makes the masked dataset useful for cross-
 * object joins in a sandbox demo.
 *
 * Inspired by the NIST SP 800-38G FF1/FF3-1 format-preserving
 * encryption family — same shape, different content — but uses a
 * cryptographic hash instead of a tweakable cipher because Apex has
 * no native FPE primitive and a hash is sufficient when re-identifi-
 * cation back to the original number is not required.
 *
 * Parameters accepted:
 *   - keepLastN (Integer, default 0): number of trailing digits to
 *     preserve verbatim. Set to 4 to mask the country/area code but
 *     keep the last four digits (helpful for the "I'll text you the
 *     code" UX patterns). Set to 0 (default) to mask every digit.
 *   - salt (String, default ""): literal text mixed into the hash so
 *     two orgs (or two refresh cycles) can deterministically produce
 *     different fake phones for the same input — useful when the
 *     same dataset is masked for two different test environments and
 *     the masked phones must not collide across them.
 */
public class FakePhoneStrategy implements MaskingStrategy {
    @TestVisible
    private static final Integer DEFAULT_KEEP_LAST_N = 0;
    @TestVisible
    private static final String DEFAULT_SALT = '';

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }

        Integer keepLastN = readIntParam(params, 'keepLastN', DEFAULT_KEEP_LAST_N);
        if (keepLastN < 0) {
            keepLastN = 0;
        }
        String salt = readStringParam(params, 'salt', DEFAULT_SALT);

        Integer totalDigits = countDigits(input);
        Integer keep = Math.min(keepLastN, totalDigits);
        Integer digitsToReplace = totalDigits - keep;

        Blob digest = Crypto.generateDigest(
            'SHA-256', Blob.valueOf(salt + '|' + input)
        );
        String hex = EncodingUtil.convertToHex(digest).toLowerCase();

        Integer len = input.length();
        Integer digitIdx = 0;
        List<Integer> codepoints = new List<Integer>();
        for (Integer i = 0; i < len; i++) {
            Integer cp = input.charAt(i);
            if (cp >= 48 && cp <= 57) {
                if (digitIdx < digitsToReplace) {
                    Integer hexCharIdx = Math.mod(digitIdx, hex.length());
                    Integer hexVal = hexCharToInt(hex.charAt(hexCharIdx));
                    Integer newDigit = Math.mod(hexVal, 10);
                    cp = 48 + newDigit;
                }
                digitIdx++;
            }
            codepoints.add(cp);
        }
        return String.fromCharArray(codepoints);
    }

    @TestVisible
    private Integer countDigits(String input) {
        Integer count = 0;
        for (Integer i = 0; i < input.length(); i++) {
            Integer cp = input.charAt(i);
            if (cp >= 48 && cp <= 57) {
                count++;
            }
        }
        return count;
    }

    private Integer hexCharToInt(Integer cp) {
        if (cp >= 48 && cp <= 57) {
            return cp - 48;
        }
        return cp - 87;
    }

    private Integer readIntParam(Map<String, Object> params, String key, Integer fallback) {
        if (params == null || !params.containsKey(key)) {
            return fallback;
        }
        Object raw = params.get(key);
        if (raw == null) {
            return fallback;
        }
        try {
            return Integer.valueOf(raw);
        } catch (Exception e) {
            return fallback;
        }
    }

    private String readStringParam(Map<String, Object> params, String key, String fallback) {
        if (params == null || !params.containsKey(key)) {
            return fallback;
        }
        Object raw = params.get(key);
        if (raw == null) {
            return fallback;
        }
        return String.valueOf(raw);
    }
}
