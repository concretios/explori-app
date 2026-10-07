/**
 * @description       : Aura-enabled controller behind the Explori setup page; lets Explori administrators view and save the Explori Sales Intelligence configuration.
 * @author            : Mayank Singh
 * @group             :
 * @last modified on  : 10-07-2026
 * @last modified by  : Mayank Singh
**/
public with sharing class SetupController {
    /**
     * @description DTO returned to the setup LWC. Deliberately omits the Share ID so it
     *              never reaches the client.
     */
    public class SetupState {
        @AuraEnabled public Boolean configured;
        @AuraEnabled public String productId;
        @AuraEnabled public String organizationId;
    }

    /**
     * @description Returns the current Explori setup state for the admin page.
     *              Requires the Explori_Manage_Config custom permission.
     * @return The current SetupState (never includes the Share ID).
     */
    @AuraEnabled(cacheable=true)
    public static SetupState getSetupState() {
        assertCanManageConfig();
        return currentState();
    }

    /**
     * @description Validates and saves the Explori configuration, then returns the
     *              refreshed state. Requires the Explori_Manage_Config custom permission.
     * @param shareId The Share ID to store.
     * @param productId The Product ID to store (optional).
     * @return The refreshed SetupState (never includes the Share ID).
     */
    @AuraEnabled
    public static SetupState saveConfig(String shareId, String productId) {
        assertCanManageConfig();
        try {
            ConfigService.saveConfig(shareId, productId);
        } catch (ConfigException ex) {
            throw handled(ex.getMessage());
        } catch (Exception ex) {
            // Return a safe, generic message to the client without leaking platform details.
            throw handled('Unable to save Explori configuration.');
        }
        return currentState();
    }

    private static SetupState currentState() {
        SetupState state = new SetupState();
        state.configured = ConfigService.hasShareId();
        state.productId = ConfigService.getProductId();
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