/**
 * Deterministic dictionary substitution: hashes the input, takes the
 * hash modulo the library size, and returns the library entry at that
 * index. The same input always maps to the same library value, so
 * referential integrity across objects is preserved.
 *
 * This is the free, self-contained version of IDEA-2. When IDEA-2 is
 * implemented properly the hardcoded libraries here will be moved to
 * Static Resources / Custom Metadata so admins can drop in their own
 * lists without a code deploy.
 *
 * Inspired by Salesforce Data Mask's "Replace from Library" feature
 * and Keepit / Own Anonymize's "same input -> same output within a job"
 * referential-integrity guarantee.
 *
 * Parameters accepted:
 *   - libraryName (String, default "FIRST_NAME"): one of FIRST_NAME,
 *     LAST_NAME, COMPANY. Unknown values pass the input through
 *     unchanged so a misconfigured rule can never corrupt data.
 */
public class LibraryStrategy implements MaskingStrategy {
    @TestVisible
    private static final List<String> FIRST_NAMES = new List<String>{
        'Alex', 'Blake', 'Cameron', 'Drew', 'Emery', 'Finley', 'Gray', 'Harper',
        'Indigo', 'Jordan', 'Kai', 'Lane', 'Morgan', 'Nova', 'Oakley', 'Parker',
        'Quinn', 'Reese', 'Sage', 'Tatum', 'Uriel', 'Vesper', 'Winter', 'Xander',
        'Yael', 'Zion'
    };
    @TestVisible
    private static final List<String> LAST_NAMES = new List<String>{
        'Andersen', 'Bak', 'Christensen', 'Dahl', 'Eriksen', 'Frederiksen',
        'Green', 'Hansen', 'Iversen', 'Jensen', 'Knudsen', 'Larsen',
        'Madsen', 'Nielsen', 'Olsen', 'Pedersen', 'Quist', 'Rasmussen',
        'Sorensen', 'Thomsen', 'Ulrich', 'Vestergaard', 'Wulff', 'Xylander',
        'Yde', 'Zacharias'
    };
    @TestVisible
    private static final List<String> COMPANIES = new List<String>{
        'Acme Consulting', 'Beacon Analytics', 'Clearwater Group', 'Delta Systems',
        'Evergreen Partners', 'Forge Industries', 'Granite Labs', 'Horizon Retail',
        'Ivy Logistics', 'Junction Media', 'Keystone Finance', 'Lattice AI',
        'Meridian Health', 'Nimbus Cloud', 'Oak Street Capital', 'Prism Energy',
        'Quantum Foods', 'Redwood Services', 'Summit Manufacturing', 'Triton Marine',
        'Unity Software', 'Vertex Insurance', 'Willow Education', 'Xenon Utilities',
        'Yarrow Biotech', 'Zephyr Transport'
    };

    public String mask(String input, Map<String, Object> params) {
        if (String.isBlank(input)) {
            return input;
        }
        String libraryName = 'FIRST_NAME';
        if (params != null && params.containsKey('libraryName')) {
            Object raw = params.get('libraryName');
            if (raw != null) {
                String candidate = String.valueOf(raw);
                if (String.isNotBlank(candidate)) {
                    libraryName = candidate;
                }
            }
        }
        List<String> library = resolveLibrary(libraryName);
        if (library == null || library.isEmpty()) {
            return input;
        }
        Integer idx = stableIndex(input, library.size());
        return library[idx];
    }

    private List<String> resolveLibrary(String name) {
        if (name == 'FIRST_NAME') {
            return FIRST_NAMES;
        }
        if (name == 'LAST_NAME') {
            return LAST_NAMES;
        }
        if (name == 'COMPANY') {
            return COMPANIES;
        }
        return null;
    }

    /**
     * Deterministic, well-distributed index in [0, modulus) derived
     * from the SHA-256 digest of the input. 6 hex chars = 24 bits,
     * which always fits in a positive Apex Integer and gives ample
     * distribution for libraries of any realistic size.
     */
    @TestVisible
    private Integer stableIndex(String input, Integer modulus) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(input));
        String hex = EncodingUtil.convertToHex(digest).substring(0, 6).toLowerCase();
        Integer value = 0;
        for (Integer i = 0; i < hex.length(); i++) {
            Integer c = hex.charAt(i);
            Integer digit;
            if (c >= 48 && c <= 57) {
                digit = c - 48;
            } else {
                digit = c - 87;
            }
            value = value * 16 + digit;
        }
        return Math.mod(value, modulus);
    }
}
