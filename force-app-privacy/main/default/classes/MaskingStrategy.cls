/**
 * Contract for a single-field masking strategy.
 *
 * Implementations must be stateless and safe to cache as singletons
 * by MaskingStrategyRegistry. They must be null-safe: passing in a
 * blank input should return a deterministic, non-throwing value
 * (typically the input itself or null, depending on the strategy).
 *
 * Parameters are passed as a plain Map keyed by strategy-specific names;
 * each strategy documents its own accepted keys in its class javadoc.
 *
 * Inspired by the pluggable Apex Action pattern used by Cloud Compliance
 * DataMasker (pcldm.DM_OfbuscationService), simplified to a single method
 * and generalised so that any Apex class implementing this interface can
 * be wired up from a Masking_Rule__mdt record without code changes.
 */
public interface MaskingStrategy {
    String mask(String input, Map<String, Object> params);
}
