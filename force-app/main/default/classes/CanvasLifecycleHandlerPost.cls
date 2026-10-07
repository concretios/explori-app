/**
 * Canvas lifecycle handler for Explori Sales Intelligence.
 * Runs immediately before Salesforce signs the request.
 * Adds only custom parameters Explori does not already get from Canvas context.
 */
global with sharing class CanvasLifecycleHandlerPost implements Canvas.CanvasLifecycleHandler {
    
	/*
     * 'global' is required by the Canvas.CanvasLifecycleHandler interface so
     * Salesforce can invoke this handler. In a managed package, global members
     * become part of the public API and cannot be changed or removed after release.
     * Keep global scope limited to the required interface methods.
     */

     /**
     * @description Canvas lifecycle callback listing the context types to exclude
     *              from the signed request. Returns an empty set so all context is kept.
     * @return Set of context types to exclude (none).
     */
    global Set<Canvas.ContextTypeEnum> excludeContextTypes() {
        // Keep ORGANIZATION, USER, and RECORD_DETAIL in the signed request.
        return new Set<Canvas.ContextTypeEnum>();
    }

    /**
     * @description Runs before Salesforce signs the Canvas request. Validates configuration
     *              and Account visibility, then sets only the four custom parameters.
     * @param renderContext The Canvas render context supplied by the platform.
     */
    global void onRender(Canvas.RenderContext renderContext) {
        if (renderContext == null || renderContext.getEnvironmentContext() == null) {
            throw new Canvas.CanvasRenderException('Explori canvas context is unavailable.');
        }
        Canvas.EnvironmentContext env = renderContext.getEnvironmentContext();
    
        String shareId = ConfigService.getShareId();
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
    
        /*
         * Send only these four custom parameters. Everything else Explori needs
         * (organization, user, record context) already travels in the signed Canvas
         * request, so the signed payload is kept minimal and free of extra data.
         */
        Map<String, Object> params = new Map<String, Object>{
            'shareId' => shareId,
            'productId' => ConfigService.getProductId(),
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
        } catch (JSONException e) {
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
        /*
         * Catch only StringException for an invalid Id value. An invalid or malformed
         * ID is treated as an inaccessible account, while other platform exceptions
         * are allowed to propagate instead of being silently treated as no access.
         */
        try {
            Id recId = Id.valueOf(accountId);
            if (recId.getSobjectType() != Account.SObjectType) {
                return null;
            }
        } catch (System.StringException e) {
            return null; // not a valid Id → treat as no accessible account
        }
        /*
         * USER_MODE enforces the running user's sharing and field-level security.
         * This prevents Explori from opening an Account the current user cannot access.
         * Do not change this query to SYSTEM_MODE.
         */
        Id recId = Id.valueOf(accountId);
        List<Account> rows = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :recId
            WITH USER_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
}