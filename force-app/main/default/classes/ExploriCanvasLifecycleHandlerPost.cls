/**
 * Canvas lifecycle handler for Explori Sales Intelligence.
 * Runs immediately before Salesforce signs the request.
 * Adds only custom parameters Explori does not already get from Canvas context.
 */
global with sharing class ExploriCanvasLifecycleHandlerPost implements Canvas.CanvasLifecycleHandler {

    global Set<Canvas.ContextTypeEnum> excludeContextTypes() {
        // Keep ORGANIZATION, USER, and RECORD_DETAIL in the signed request.
        return new Set<Canvas.ContextTypeEnum>();
    }

    global void onRender(Canvas.RenderContext renderContext) {
        if (renderContext == null || renderContext.getEnvironmentContext() == null) {
            throw new Canvas.CanvasRenderException('Explori canvas context is unavailable.');
        }
        Canvas.EnvironmentContext env = renderContext.getEnvironmentContext();
    
        String shareId = ExploriConfigService.getShareId();
        if (String.isBlank(shareId)) {
            throw new Canvas.CanvasRenderException(
                'Explori is not configured. Ask an administrator to save a Share ID.'
            );
        }
    
        Map<String, Object> incoming = readExistingParameters(env.getParametersAsJSON());
        String requestedId = firstNonBlank(
            stringValue(incoming.get('accountId')),
            stringValue(incoming.get('recordId'))
        );
        Account account = findVisibleAccount(requestedId);
        if (account == null) {
            throw new Canvas.CanvasRenderException(
                'Explori can only open on an Account you can access.'
            );
        }
    
        Map<String, Object> params = new Map<String, Object>{
            'shareId' => shareId,
            'productId' => ExploriConfigService.getProductId(),
            'accountId' => account.Id,
            'accountName' => account.Name
        };
        env.setParametersAsJSON(JSON.serialize(params));
    }

    private static Map<String, Object> readExistingParameters(String json) {
        if (String.isBlank(json) || json == '{}') {
            return new Map<String, Object>();
        }
        try {
            Map<String, Object> parsed =
                (Map<String, Object>) System.JSON.deserializeUntyped(json);
            return parsed == null ? new Map<String, Object>() : parsed;
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }

    private static String stringValue(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value);
        return String.isBlank(text) ? null : text;
    }

    private static String firstNonBlank(String first, String second) {
        return String.isNotBlank(first) ? first : second;
    }

    private static Account findVisibleAccount(String accountId) {
        if (String.isBlank(accountId)) {
            return null;
        }
        try {
            Id recId = Id.valueOf(accountId);
            if (recId.getSobjectType() != Account.SObjectType) {
                return null;
            }
            List<Account> rows = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :recId
                WITH USER_MODE
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception e) {
            return null;
        }
    }
}