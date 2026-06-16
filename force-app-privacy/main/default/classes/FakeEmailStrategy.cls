/**
 * Deterministic, realistic-looking fake email substitution.
 *
 * Designed to answer the thesis question "what does a realistic
 * masked output look like to a downstream user who needs to QA a
 * report or demo a sandbox?". The other built-in strategies all
 * destroy the email shape (HashStrategy returns hex, ScrambleStrategy
 * returns random chars, FormatPreservingStrategy turns the domain into
 * gibberish), so a support engineer or sales-ops user looking at the
 * masked column has no way to tell whether the column even *was* an
 * email. This strategy keeps the column's identity obvious while
 * removing the PII inside it.
 *
 * Algorithm:
 *   1. Split the input on '@'. If there is no '@', fall back to the
 *      Library/Hash combo on the whole string and append a default
 *      domain — it is still useful in the report preview but not
 *      strictly format-preserving.
 *   2. Build a deterministic local part by hashing the input and
 *      indexing into LibraryStrategy.FIRST_NAMES / LAST_NAMES. The
 *      same input always maps to the same fake email so referential
 *      integrity is preserved across objects (a Contact's masked
 *      Email matches its Lead's masked Email if the originals matched).
 *   3. Preserve the original domain by default so the column still
 *      visually reads as an email from the same provider. An admin
 *      can override this with the `domain` parameter — useful when
 *      the original domain itself is sensitive (an employer name,
 *      for instance).
 *
 * Inspired by the "Replace From Library" pattern in Salesforce Data
 * Mask and the Faker.js `internet.email()` helper, but stripped down
 * to the two libraries this org already ships and made deterministic
 * via SHA-256 so no hidden RNG state leaks across invocations.
 *
 * Parameters accepted:
 *   - domain (String, default: preserve original): when set, replace
 *     the original domain with this literal value. Empty string is
 *     ignored (treated the same as not providing the parameter).
 *   - style (String, default "firstdotlast"): how to compose the
 *     local part. Supported values:
 *       * "firstdotlast"  -> cathrine.andersen
 *       * "firstlast"     -> cathrineandersen
 *       * "firstnum"      -> cathrine42 (deterministic 2-digit suffix)
 *     Unknown values fall back to "firstdotlast".
 *   - fallbackDomain (String, default "example.com"): only used when
 *     the input has no '@' so the algorithm has to invent a domain.
 */
public class FakeEmailStrategy implements MaskingStrategy {
    @TestVisible
    private static final String DEFAULT_STYLE = 'firstdotlast';
    @TestVisible
    private static final String DEFAULT_FALLBACK_DOMAIN = 'example.com';

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }

        String overrideDomain = readStringParam(params, 'domain', null);
        String style = readStringParam(params, 'style', DEFAULT_STYLE);
        String fallbackDomain = readStringParam(
            params, 'fallbackDomain', DEFAULT_FALLBACK_DOMAIN
        );

        String localPart;
        String domain;
        Integer atIdx = input.indexOf('@');
        if (atIdx > 0 && atIdx < input.length() - 1) {
            domain = String.isNotBlank(overrideDomain)
                ? overrideDomain
                : input.substring(atIdx + 1);
        } else {
            domain = String.isNotBlank(overrideDomain)
                ? overrideDomain
                : fallbackDomain;
        }

        localPart = buildLocalPart(input, style);
        return localPart + '@' + domain;
    }

    /**
     * Compose a deterministic local part from the input. The first
     * 6 hex chars of SHA-256(input) drive the library lookups, and
     * the next 2 hex chars (mod 100) drive the optional numeric
     * suffix. Using disjoint hash slices keeps style="firstnum"
     * uncorrelated with style="firstdotlast" for the same input,
     * which makes the strategy safer to chain (e.g. "first try
     * firstdotlast, on collision fall back to firstnum") in a
     * future iteration without re-keying.
     */
    private String buildLocalPart(String input, String style) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(input));
        String hex = EncodingUtil.convertToHex(digest);

        Integer firstSlice = hexSliceToInt(hex, 0, 6);
        Integer lastSlice = hexSliceToInt(hex, 6, 12);
        Integer numSlice = hexSliceToInt(hex, 12, 14);

        String first = LibraryStrategy.FIRST_NAMES[
            Math.mod(firstSlice, LibraryStrategy.FIRST_NAMES.size())
        ].toLowerCase();
        String last = LibraryStrategy.LAST_NAMES[
            Math.mod(lastSlice, LibraryStrategy.LAST_NAMES.size())
        ].toLowerCase();

        if (style == 'firstlast') {
            return first + last;
        }
        if (style == 'firstnum') {
            Integer suffix = Math.mod(numSlice, 100);
            String padded = suffix < 10 ? '0' + String.valueOf(suffix) : String.valueOf(suffix);
            return first + padded;
        }
        return first + '.' + last;
    }

    @TestVisible
    private Integer hexSliceToInt(String hex, Integer startIdx, Integer endIdx) {
        String slice = hex.substring(startIdx, endIdx).toLowerCase();
        Integer value = 0;
        for (Integer i = 0; i < slice.length(); i++) {
            Integer c = slice.charAt(i);
            Integer digit;
            if (c >= 48 && c <= 57) {
                digit = c - 48;
            } else {
                digit = c - 87;
            }
            value = value * 16 + digit;
        }
        return value;
    }

    private String readStringParam(Map<String, Object> params, String key, String fallback) {
        if (params == null || !params.containsKey(key)) {
            return fallback;
        }
        Object raw = params.get(key);
        if (raw == null) {
            return fallback;
        }
        String candidate = String.valueOf(raw);
        return String.isBlank(candidate) ? fallback : candidate;
    }
}
