/**
 * Always returns null, regardless of input.
 *
 * This is the closest equivalent of Salesforce Data Mask's "Delete"
 * option and Keepit's "Data redaction (Nullify values)".
 *
 * Parameters accepted: none.
 */
public class NullStrategy implements MaskingStrategy {
    public String mask(String input, Map<String, Object> params) {
        return null;
    }
}
