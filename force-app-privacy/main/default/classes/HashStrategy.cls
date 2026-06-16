/**
 * Deterministic irreversible transformation via a cryptographic hash.
 *
 * The same input always produces the same output, which preserves
 * referential integrity across objects (a hashed email on a Contact
 * will equal the same hashed email on any related Case). Without the
 * original value there is no practical way to recover it, so the
 * output is suitable wherever an irreversible, non-recoverable
 * transformation is required and no re-identification key will ever be stored.
 *
 * Inspired by Keepit's "Hashing" technique.
 *
 * Parameters accepted:
 *   - algorithm (String, default "SHA-256"): any algorithm supported by
 *     Crypto.generateDigest (MD5, SHA1, SHA-256, SHA-512).
 *   - length (Integer, default 16): number of hex characters to keep
 *     from the front of the digest. Set to 0 to keep the full digest.
 *   - prefix (String, default ""): literal text to prepend to the hex.
 */
public class HashStrategy implements MaskingStrategy {
    @TestVisible
    private static final String DEFAULT_ALGORITHM = 'SHA-256';
    @TestVisible
    private static final Integer DEFAULT_LENGTH = 16;

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }
        String algorithm = DEFAULT_ALGORITHM;
        Integer length = DEFAULT_LENGTH;
        String prefix = '';
        if (params != null) {
            if (params.containsKey('algorithm')) {
                Object raw = params.get('algorithm');
                if (raw != null) {
                    String candidate = String.valueOf(raw);
                    if (String.isNotBlank(candidate)) {
                        algorithm = candidate;
                    }
                }
            }
            if (params.containsKey('length')) {
                Object raw = params.get('length');
                if (raw != null) {
                    length = Integer.valueOf(raw);
                }
            }
            if (params.containsKey('prefix')) {
                Object raw = params.get('prefix');
                if (raw != null) {
                    prefix = String.valueOf(raw);
                }
            }
        }
        Blob digest = Crypto.generateDigest(algorithm, Blob.valueOf(input));
        String hex = EncodingUtil.convertToHex(digest);
        if (length > 0 && hex.length() > length) {
            hex = hex.substring(0, length);
        }
        return prefix + hex;
    }
}
