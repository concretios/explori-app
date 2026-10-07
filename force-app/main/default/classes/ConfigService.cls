/**
 * @description       : Reads and writes the protected Explori Sales Intelligence configuration (Share ID and Product ID) used by Explori's Apex and Canvas handler.
 * @author            : Mayank Singh
 * @group             :
 * @last modified on  : 10-07-2026
 * @last modified by  : Mayank Singh
**/
public with sharing class ConfigService {
    private static final String CONFIG_NAME = 'default';
    private static final Integer SHARE_ID_MAX = 255;
    private static final Integer PRODUCT_ID_MAX = 50;
    private static final Pattern ID_PATTERN = Pattern.compile('^[A-Za-z0-9._-]+$');

    private static final IdRule SHARE_RULE = new IdRule('Share ID', SHARE_ID_MAX, true);
    private static final IdRule PRODUCT_RULE = new IdRule('Product ID', PRODUCT_ID_MAX, false);


    /**
     * @description Returns the configured Share ID, or null when none is saved.
     * @return The stored Share ID.
     */
    public static String getShareId() {
        Settings__c row = Settings__c.getValues(CONFIG_NAME);
        return row == null ? null : row.Share_Id__c;
    }

    /**
     * @description Returns the configured Product ID, or null when none is saved.
     * @return The stored Product ID.
     */
    public static String getProductId() {
        Settings__c row = Settings__c.getValues(CONFIG_NAME);
        return row == null ? null : row.Product_Id__c;
    }

    /**
     * @description Indicates whether a non-blank Share ID has been configured.
     * @return True when a Share ID is saved.
     */
    public static Boolean hasShareId() {
        return String.isNotBlank(getShareId());
    }

    /**
     * @description Validates and persists the Explori configuration. Gated by the
     *              Explori_Manage_Config custom permission; upserts in SYSTEM_MODE.
     * @param rawShareId The Share ID to store (required).
     * @param rawProductId The Product ID to store (optional).
     */
    public static void saveConfig(String rawShareId, String rawProductId) {
        // Gate first: the upsert below runs in SYSTEM_MODE and bypasses CRUD/sharing,
        // so this custom permission is the only thing that authorizes a save.
        if (!FeatureManagement.checkPermission('Explori_Manage_Config')) {
            throw new ConfigException('You do not have permission to save Explori configuration.');
        }
        String shareId = normalizeId(rawShareId, SHARE_RULE);
        String productId = normalizeId(rawProductId, PRODUCT_RULE);
        Settings__c row = Settings__c.getValues(CONFIG_NAME);
        if (row == null) {
            row = new Settings__c(Name = CONFIG_NAME);
        }
        row.Share_Id__c = shareId;
        row.Product_Id__c = productId;

        /*
         * SYSTEM_MODE is intentional.
         * Access is controlled by the Explori_Manage_Config custom permission above.
         * Users with this permission may not have write access to the protected
         * List Custom Setting, so SYSTEM_MODE is required to persist the configuration.
         */
        Database.UpsertResult result =
            Database.upsert(row, Settings__c.Name, false, AccessLevel.SYSTEM_MODE);
        if (!result.isSuccess()) {
            throw new ConfigException('Unable to save Explori configuration.');
        }
    }

    private static String normalizeId(String raw, IdRule rule) {
        String value = raw == null ? null : raw.trim();
        if (String.isBlank(value)) {
            if (rule.required) {
                throw new ConfigException('A ' + rule.label + ' is required.');
            }
            return null;
        }
        if (value.length() > rule.maxLen || !ID_PATTERN.matcher(value).matches()) {
            throw new ConfigException('The ' + rule.label + ' is not valid.');
        }
        return value;
    }

    private class IdRule {
        private final String label;
        private final Integer maxLen;
        private final Boolean required;
        private IdRule(String label, Integer maxLen, Boolean required) {
            this.label = label;
            this.maxLen = maxLen;
            this.required = required;
        }
    }
}