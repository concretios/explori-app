/**
 * @description       : 
 * @author            : Mayank Singh
 * @group             : 
 * @last modified on  : 09-30-2026
 * @last modified by  : Mayank Singh
**/
({
    doInit: function (component) {
        var recordId = component.get("v.recordId") || "";
        component.set(
            "v.canvasParams",
            JSON.stringify({
                recordId: recordId
            })
        );
    }
})