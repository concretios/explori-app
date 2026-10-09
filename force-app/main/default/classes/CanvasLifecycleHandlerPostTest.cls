/**
 * @description : Tests for CanvasLifecycleHandlerPost using Canvas.Test. Verifies the
 *                handler blocks rendering when the record is not a visible Account, and
 *                that the signed payload carries only the Account name.
 * @author      : Mayank Singh
 */
@IsTest
public class CanvasLifecycleHandlerPostTest {
    // Well-formed Account Id built from the key prefix so it is not hardcoded.
    private static final String ABSENT_ACCOUNT_ID =
        Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix()
            + '0'.repeat(12) + 'AAA';

    @IsTest
    static void onRenderRecordNotAccountThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Canvas.CanvasLifecycleHandler handler = new CanvasLifecycleHandlerPost();
            Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
            // A User Id (005) is a valid Id but not an Account.
            mock.getEnvironmentContext().setParametersAsJSON(
                JSON.serialize(new Map<String, Object>{ 'accountId' => UserInfo.getUserId() })
            );

            Boolean thrown = false;
            Test.startTest();
            try {
                Canvas.Test.testCanvasLifecycle(handler, mock);
            } catch (System.CanvasException e) {
                thrown = true;
            }
            Test.stopTest();
            System.assertEquals(true, thrown, 'A non-Account record must block rendering');
        }
    }

    @IsTest
    static void onRenderAccountNotVisibleThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Canvas.CanvasLifecycleHandler handler = new CanvasLifecycleHandlerPost();
            Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
            // Well-formed Account Id that does not exist => USER_MODE query returns nothing.
            mock.getEnvironmentContext().setParametersAsJSON(
                JSON.serialize(new Map<String, Object>{ 'accountId' => ABSENT_ACCOUNT_ID })
            );

            Boolean thrown = false;
            Test.startTest();
            try {
                Canvas.Test.testCanvasLifecycle(handler, mock);
            } catch (System.CanvasException e) {
                thrown = true;
            }
            Test.stopTest();
            System.assertEquals(true, thrown, 'An inaccessible Account must block rendering');
        }
    }

    @IsTest
    static void onRenderHappyPathSendsOnlyAccountName() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account acct = new Account(Name = 'Acme Canvas Co');
            insert acct;

            Canvas.CanvasLifecycleHandler handler = new CanvasLifecycleHandlerPost();
            Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
            // Include extra keys to prove the handler rebuilds the payload rather than appending.
            mock.getEnvironmentContext().setParametersAsJSON(
                JSON.serialize(new Map<String, Object>{
                    'accountId' => acct.Id,
                    'recordId' => acct.Id,
                    'sessionToken' => 'should-be-dropped'
                })
            );

            Test.startTest();
            Canvas.Test.testCanvasLifecycle(handler, mock);
            Test.stopTest();

            Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
                mock.getEnvironmentContext().getParametersAsJSON()
            );

            System.assertEquals(1, sent.size(), 'Exactly one parameter must be sent: ' + sent.keySet());
            System.assertEquals(true, sent.containsKey('accountName'), 'accountName must be present');
            System.assertEquals('Acme Canvas Co', (String) sent.get('accountName'), 'Account Name should be the resolved Account');

            System.assertEquals(false, sent.containsKey('shareId'), 'shareId must not be present');
            System.assertEquals(false, sent.containsKey('productId'), 'productId must not be present');
            System.assertEquals(false, sent.containsKey('accountId'), 'accountId must not be present');
            System.assertEquals(false, sent.containsKey('recordId'), 'recordId must not be forwarded');
            System.assertEquals(false, sent.containsKey('sessionToken'), 'Unexpected incoming keys must be dropped');
        }
    }

    @IsTest
    static void excludeContextTypesReturnsEmptySet() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // The handler keeps all context types in the signed request.
            Set<Canvas.ContextTypeEnum> excluded = new CanvasLifecycleHandlerPost().excludeContextTypes();
            System.assertNotEquals(null, excluded, 'excludeContextTypes must not return null');
            System.assertEquals(true, excluded.isEmpty(), 'No context types should be excluded');
        }
    }

    @IsTest
    static void onRenderNullContextThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Direct invocation with a null RenderContext exercises the null-context guard.
            Boolean thrown = false;
            Test.startTest();
            try {
                new CanvasLifecycleHandlerPost().onRender(null);
            } catch (Exception e) {
                thrown = true;
                System.assertEquals(
                    true,
                    e.getMessage().contains('unavailable'),
                    'Null context should report an unavailable canvas context: ' + e.getMessage()
                );
            }
            Test.stopTest();
            System.assertEquals(true, thrown, 'A null RenderContext must block rendering');
        }
    }

    @IsTest
    static void onRenderBlankParamsThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // No record id is supplied => no visible Account.
            Canvas.CanvasLifecycleHandler handler = new CanvasLifecycleHandlerPost();
            Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
            mock.getEnvironmentContext().setParametersAsJSON('{}');

            Boolean thrown = false;
            Test.startTest();
            try {
                Canvas.Test.testCanvasLifecycle(handler, mock);
            } catch (System.CanvasException e) {
                thrown = true;
            }
            Test.stopTest();
            System.assertEquals(true, thrown, 'Blank incoming parameters must block rendering');
        }
    }

    @IsTest
    static void onRenderMalformedAccountIdThrows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // A non-blank but invalid Id value is treated as an inaccessible Account.
            Canvas.CanvasLifecycleHandler handler = new CanvasLifecycleHandlerPost();
            Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
            mock.getEnvironmentContext().setParametersAsJSON(
                JSON.serialize(new Map<String, Object>{ 'accountId' => 'not-a-real-id' })
            );

            Boolean thrown = false;
            Test.startTest();
            try {
                Canvas.Test.testCanvasLifecycle(handler, mock);
            } catch (System.CanvasException e) {
                thrown = true;
            }
            Test.stopTest();
            System.assertEquals(true, thrown, 'A malformed Account Id must block rendering');
        }
    }
}
