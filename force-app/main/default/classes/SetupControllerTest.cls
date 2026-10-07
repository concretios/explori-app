/**
 * @description : Tests for SetupController – permission gating, that a denied user
 *                receives an AuraHandledException, and that no Share ID is ever
 *                returned to the client from getSetupState or saveConfig.
 * @author      : Mayank Singh
 */
@IsTest
public class SetupControllerTest {
    // A distinctive value we can search the serialized response for.
    private static final String SECRET_SHARE = 'TopSecretShare_123';
    private static final String PRODUCT = 'Prod_7';

    @TestSetup
    static void makeUsers() {
        User admin = buildUser('ExploriAdmSc', 'escadm');
        User plain = buildUser('ExploriUsrSc', 'escusr');
        insert new List<User>{ admin, plain };

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Explori_Admin' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = admin.Id, PermissionSetId = ps.Id);
    }

    @IsTest
    static void getSetupStateDeniedUserThrowsAuraHandled() {
        Boolean thrown = false;
        System.runAs(plainUser()) {
            Test.startTest();
            try {
                SetupController.getSetupState();
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A denied user must get an AuraHandledException from getSetupState');
    }

    @IsTest
    static void saveConfigDeniedUserThrowsAuraHandled() {
        Boolean thrown = false;
        System.runAs(plainUser()) {
            Test.startTest();
            try {
                SetupController.saveConfig(SECRET_SHARE, PRODUCT);
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A denied user must get an AuraHandledException from saveConfig');
    }

    @IsTest
    static void getSetupStateBeforeSaveNotConfigured() {
        System.runAs(adminUser()) {
            Test.startTest();
            SetupController.SetupState state = SetupController.getSetupState();
            Test.stopTest();

            System.assertEquals(false, state.configured, 'Should not be configured before any save');
            System.assertEquals(null, state.productId, 'Product ID should be null before any save');
            assertNoShareId(state);
        }
    }

    @IsTest
    static void getSetupStateAfterSaveReturnsNoShareId() {
        System.runAs(adminUser()) {
            Test.startTest();
            SetupController.saveConfig(SECRET_SHARE, PRODUCT);
            SetupController.SetupState state = SetupController.getSetupState();
            Test.stopTest();

            System.assertEquals(true, state.configured, 'Should report configured after a save');
            System.assertEquals(PRODUCT, state.productId, 'Product ID should round-trip to the client');
            assertNoShareId(state);
        }
    }

    @IsTest
    static void saveConfigReturnsNoShareId() {
        System.runAs(adminUser()) {
            Test.startTest();
            SetupController.SetupState state = SetupController.saveConfig(SECRET_SHARE, PRODUCT);
            Test.stopTest();

            System.assertEquals(true, state.configured, 'saveConfig should report configured');
            System.assertEquals(PRODUCT, state.productId, 'Product ID should round-trip to the client');
            assertNoShareId(state);
        }
    }

    @IsTest
    static void saveConfigInvalidInputThrowsAuraHandled() {
        // Permitted user, but the value fails ConfigService validation. The
        // ConfigException must be translated into an AuraHandledException.
        Boolean thrown = false;
        System.runAs(adminUser()) {
            Test.startTest();
            try {
                SetupController.saveConfig('has space & bang!', null);
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A validation failure must surface as AuraHandledException');
    }

    // ---- helpers -------------------------------------------------------

    private static void assertNoShareId(SetupController.SetupState state) {
        // The Share ID must never reach the client. Prove it two ways:
        // the DTO exposes no share field, and the serialized payload does not
        // contain the saved secret value.
        String payload = JSON.serialize(state);
        System.assertEquals(
            false,
            payload.contains(SECRET_SHARE),
            'Serialized SetupState must not contain the Share ID: ' + payload
        );
        System.assertEquals(
            false,
            payload.toLowerCase().contains('shareid'),
            'SetupState must not expose a shareId member'
        );
    }

    private static User adminUser() {
        return [SELECT Id FROM User WHERE LastName = 'ExploriAdmSc' LIMIT 1];
    }

    private static User plainUser() {
        return [SELECT Id FROM User WHERE LastName = 'ExploriUsrSc' LIMIT 1];
    }

    private static User buildUser(String lastName, String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = alias + Datetime.now().getTime();
        return new User(
            FirstName = 'Explori',
            LastName = lastName,
            Alias = alias.left(8),
            Email = alias + '@test.explori.invalid',
            Username = unique + '@test.explori.invalid',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }
}