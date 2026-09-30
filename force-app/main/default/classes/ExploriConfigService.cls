public with sharing class ExploriConfigService {
    private ExploriConfigService() {}

    private static final String CONFIG_NAME = 'default';
    private static final Integer SHARE_ID_MAX = 255;
    private static final Integer PRODUCT_ID_MAX = 50;
    private static final Pattern ID_PATTERN = Pattern.compile('^[A-Za-z0-9._-]+$');

    public static String getShareId() {
        Explori_Config_List__c row = Explori_Config_List__c.getValues(CONFIG_NAME);
        return row == null ? null : row.Share_Id__c;
    }

    public static String getProductId() {
        Explori_Config_List__c row = Explori_Config_List__c.getValues(CONFIG_NAME);
        return row == null ? null : row.Product_Id__c;
    }

    public static Boolean hasShareId() {
        return String.isNotBlank(getShareId());
    }

    public static void saveConfig(String rawShareId, String rawProductId) {
        if (!FeatureManagement.checkPermission('Explori_Manage_Config')) {
            throw new ExploriException('You do not have permission to save Explori configuration.');
        }

        String shareId = normalizeId(rawShareId, 'Share ID', SHARE_ID_MAX, true);
        String productId = normalizeId(rawProductId, 'Product ID', PRODUCT_ID_MAX, false);

        Explori_Config_List__c row = Explori_Config_List__c.getValues(CONFIG_NAME);
        if (row == null) {
            row = new Explori_Config_List__c(Name = CONFIG_NAME);
        }
        row.Share_Id__c = shareId;
        row.Product_Id__c = productId;

        Database.UpsertResult result =
            Database.upsert(row, Explori_Config_List__c.Name, false, AccessLevel.SYSTEM_MODE);
        if (!result.isSuccess()) {
            throw new ExploriException('Unable to save Explori configuration.');
        }
    }

    private static String normalizeId(String raw, String label, Integer maxLen, Boolean required) {
        String value = raw == null ? null : raw.trim();
        if (String.isBlank(value)) {
            if (required) {
                throw new ExploriException('A ' + label + ' is required.');
            }
            return null;
        }
        if (value.length() > maxLen || !ID_PATTERN.matcher(value).matches()) {
            throw new ExploriException('The ' + label + ' is not valid.');
        }
        return value;
    }
}