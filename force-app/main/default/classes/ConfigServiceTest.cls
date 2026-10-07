/**
 * @description : Tests for ConfigService – permission gating, input validation,
 *                and persistence of the protected Explori configuration.
 * @author      : Mayank Singh
 */
@IsTest
public class ConfigServiceTest {
    private static final String ALLOWED = 'ShareAbc.9_1-2';

    @TestSetup
    static void makeUsers() {
        // Setup-object DML only (User + PermissionSetAssignment) to avoid mixed DML.
        User admin = buildUser('ExploriAdmCfg', 'excfgadm');
        User plain = buildUser('ExploriUsrCfg', 'excfgusr');
        insert new List<User>{ admin, plain };

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Explori_Admin' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = admin.Id, PermissionSetId = ps.Id);
    }

    @IsTest
    static void saveConfigDeniedUserThrows() {
        Boolean thrown = false;
        System.runAs(plainUser()) {
            Test.startTest();
            try {
                ConfigService.saveConfig(ALLOWED, null);
            } catch (ConfigException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A user without Explori_Manage_Config must be rejected');
    }

    @IsTest
    static void saveConfigBlankShareIdThrows() {
        Boolean thrown = false;
        System.runAs(adminUser()) {
            Test.startTest();
            try {
                ConfigService.saveConfig('   ', null);
            } catch (ConfigException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A blank Share ID must be rejected');
    }

    @IsTest
    static void saveConfigTooLongShareIdThrows() {
        Boolean thrown = false;
        String tooLong = 'a'.repeat(256); // limit is 255
        System.runAs(adminUser()) {
            Test.startTest();
            try {
                ConfigService.saveConfig(tooLong, null);
            } catch (ConfigException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A Share ID over 255 characters must be rejected');
    }

    @IsTest
    static void saveConfigInvalidCharsShareIdThrows() {
        Boolean thrown = false;
        System.runAs(adminUser()) {
            Test.startTest();
            try {
                ConfigService.saveConfig('has space & bang!', null);
            } catch (ConfigException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A Share ID with disallowed characters must be rejected');
    }

    @IsTest
    static void saveConfigTooLongProductIdThrows() {
        Boolean thrown = false;
        String tooLong = 'b'.repeat(51); // product id limit is 50
        System.runAs(adminUser()) {
            Test.startTest();
            try {
                ConfigService.saveConfig(ALLOWED, tooLong);
            } catch (ConfigException e) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, thrown, 'A Product ID over 50 characters must be rejected');
    }

    @IsTest
    static void saveConfigValidPersistsAndIsReadable() {
        System.runAs(adminUser()) {
            Test.startTest();
            ConfigService.saveConfig(ALLOWED, 'Prod_42');
            Test.stopTest();

            System.assertEquals(ALLOWED, ConfigService.getShareId(), 'Saved Share ID should be readable');
            System.assertEquals('Prod_42', ConfigService.getProductId(), 'Saved Product ID should be readable');
            System.assertEquals(true, ConfigService.hasShareId(), 'hasShareId should be true after a save');
        }
    }

    @IsTest
    static void saveConfigValidWithoutProductIdPersists() {
        System.runAs(adminUser()) {
            Test.startTest();
            ConfigService.saveConfig(ALLOWED, null);
            Test.stopTest();

            System.assertEquals(ALLOWED, ConfigService.getShareId(), 'Saved Share ID should be readable');
            System.assertEquals(null, ConfigService.getProductId(), 'Product ID should remain null when omitted');
            System.assertEquals(true, ConfigService.hasShareId(), 'hasShareId should be true after a save');
        }
    }

    @IsTest
    static void readersReturnEmptyStateWhenNothingSaved() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // No row saved in this transaction.
            System.assertEquals(null, ConfigService.getShareId(), 'getShareId should be null with no saved row');
            System.assertEquals(null, ConfigService.getProductId(), 'getProductId should be null with no saved row');
            System.assertEquals(false, ConfigService.hasShareId(), 'hasShareId should be false with no saved row');
        }
    }

    // ---- helpers -------------------------------------------------------

    private static User adminUser() {
        return [SELECT Id FROM User WHERE LastName = 'ExploriAdmCfg' LIMIT 1];
    }

    private static User plainUser() {
        return [SELECT Id FROM User WHERE LastName = 'ExploriUsrCfg' LIMIT 1];
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