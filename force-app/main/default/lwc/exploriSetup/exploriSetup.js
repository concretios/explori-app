/**
 * @description       : 
 * @author            : Mayank Singh
 * @group             : 
 * @last modified on  : 09-30-2026
 * @last modified by  : Mayank Singh
**/
import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getSetupState from "@salesforce/apex/ExploriSetupController.getSetupState";
import saveConfig from "@salesforce/apex/ExploriSetupController.saveConfig";

export default class ExploriSetup extends LightningElement {
    shareId = "";
    productId = "";
    configured = false;
    saving = false;
    wiredResult;

    get saveDisabled() {
        return this.saving || !this.shareId;
    }

    @wire(getSetupState)
    wiredState(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.configured = data.configured;
            this.productId = data.productId || "";
        } else if (error) {
            this.toast("Error", this.messageFrom(error), "error");
        }
    }

    handleShareId(event) {
        this.shareId = event.target.value;
    }

    handleProductId(event) {
        this.productId = event.target.value;
    }

    async handleSave() {
        this.saving = true;
        try {
            await saveConfig({
                shareId: this.shareId,
                productId: this.productId
            });
            this.shareId = "";
            await refreshApex(this.wiredResult);
            this.toast("Saved", "Explori configuration updated.", "success");
        } catch (error) {
            this.toast("Error", this.messageFrom(error), "error");
        } finally {
            this.saving = false;
        }
    }

    messageFrom(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : "Unknown error";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}