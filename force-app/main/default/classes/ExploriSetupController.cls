/**
 * @description       : 
 * @author            : Mayank Singh
 * @group             : 
 * @last modified on  : 10-01-2026
 * @last modified by  : Mayank Singh
**/
public with sharing class ExploriSetupController {
    public class SetupState {
        @AuraEnabled public Boolean configured;
        @AuraEnabled public String productId;
        @AuraEnabled public String organizationId;
    }

    @AuraEnabled(cacheable=true)
    public static SetupState getSetupState() {
        assertCanManageConfig();
        return currentState();
    }

    @AuraEnabled
    public static SetupState saveConfig(String shareId, String productId) {
        assertCanManageConfig();
        try {
            ExploriConfigService.saveConfig(shareId, productId);
        } catch (ExploriException ex) {
            throw handled(ex.getMessage());
        } catch (Exception ex) {
            // Log the platform error for debugging while returning a safe message to the client.
            System.debug(LoggingLevel.ERROR, 'Explori saveConfig failed: ' + ex.getMessage());
            throw handled('Unable to save Explori configuration.');
        }
        return currentState();
    }

    private static SetupState currentState() {
        SetupState state = new SetupState();
        state.configured = ExploriConfigService.hasShareId();
        // Share ID is never returned to the client. Only the configured flag and non-sensitive product ID are exposed.
        state.productId = ExploriConfigService.getProductId();
        state.organizationId = UserInfo.getOrganizationId();
        return state;
    }

    private static void assertCanManageConfig() {
        if (!FeatureManagement.checkPermission('Explori_Manage_Config')) {
            throw handled('You do not have permission to manage Explori configuration.');
        }
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}