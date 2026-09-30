# Explori Sales Intelligence

Salesforce package that embeds Explori Sales Intelligence on Account with Canvas Signed Request (POST). Admins save Share ID and Product ID on a setup tab. Those values are injected into the signed request by Apex immediately before Salesforce signs it.

This is source for a future **2GP managed package**. Namespace is not registered yet. Do not hardcode `ns__` prefixes.

## What this package contains

| Area | Source | Role |
| --- | --- | --- |
| ECA / Canvas | `Explori_Sales_Intelligence` | Canvas app, access method **Post**, URL path only |
| Setup UI | LWC `exploriSetup` + tab + `Explori Admin` app | Admin saves Share ID / Product ID |
| Setup Apex | `ExploriSetupController` | LWC entry. Does not return Share ID |
| Config | `ExploriConfigService` + List CS `Explori_Config_List__c` | Protected setting, dataset `Name=default` |
| Account host | Aura `exploriAccountPanel` | Passes `{ recordId }` only |
| Lifecycle | `ExploriCanvasLifecycleHandlerPost` | Adds `shareId`, `productId`, `accountId`, `accountName` after a USER_MODE Account read |

Canvas URL is the host path only, currently:

`https://si.staging.explori.com/`

Do not put `shareId`, `productId`, `companyName`, or `accountName` on that URL.

## Access model

| Metadata | Assign to | Grants |
| --- | --- | --- |
| Custom permission `Explori_Manage_Config` | Via `Explori_Admin` only | Apex may save config |
| Permission set `Explori_Admin` | Salesforce admins | Setup LWC, Setup tab, Admin app, custom permission |
| Permission set `Explori_User` | Sales users | Canvas handler + Account Read / Name. Also listed on the ECA |

`Explori_User` must not include the setup controller, config service, exception class, custom permission, Admin app, Setup tab, or object permissions on `Explori_Config_List__c`.

The custom setting is **Protected**. Subscriber Apex and API cannot read it. Packaged Apex writes it in system mode after `FeatureManagement.checkPermission('Explori_Manage_Config')`. Account queries in the handler run `WITH USER_MODE`.

A sysadmin profile alone cannot save config. The user needs `Explori_Admin`.

## Prerequisites

- Salesforce CLI: [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli)
- VS Code with Salesforce Extension Pack (optional)
- A scratch org or Developer Edition org with Dev Hub if you use scratch orgs

## Project layout

```
force-app/main/default/
  classes/                  Apex + tests (when added)
  lwc/exploriSetup/         Admin setup UI
  aura/exploriAccountPanel/ Account Canvas host
  objects/Explori_Config_List__c/
  permissionsets/           Explori_User, Explori_Admin
  customPermissions/        Explori_Manage_Config
  ExternalClientApplication/
  ExtlClntApp*/             ECA Canvas + OAuth children
  applications/             Explori Admin
  tabs/                     Explori Setup
config/                     Scratch org definition
sfdx-project.json
```

## Configure an org

1. Authorize the org: `sf org login web --alias explori-dev`
2. Deploy: `sf project deploy start --target-org explori-dev`
3. Assign `Explori_Admin` to the person who will paste the Share ID
4. Assign `Explori_User` to people who open Account
5. Open the **Explori Admin** app → **Explori Setup** and save Share ID (Product ID optional)
6. Add **Explori Account Intelligence** to the Account Lightning page (App Builder, Account only)

When a package namespace exists, set `namespacePrefix` on `force:canvasApp` in `exploriAccountPanel.cmp`. Leave it unset until then.

## Common commands

```bash
sf org login web --alias explori-dev
sf org open --target-org explori-dev
sf project deploy start --target-org explori-dev
sf project retrieve start --target-org explori-dev
sf apex run test --target-org explori-dev --code-coverage
```

Retrieve permission metadata after Setup changes:

```bash
sf project retrieve start \
  --metadata CustomPermission:Explori_Manage_Config \
  --metadata PermissionSet:Explori_Admin \
  --metadata PermissionSet:Explori_User \
  --target-org explori-dev
```

## Do not commit

- Consumer secret, `.env`, Heroku config
- Live Share IDs
- `SKIP_AUTH` or mock Canvas servers
- Hardcoded `ns__` names

Retrieved ECA metadata may include a consumer **key**. That is expected. Never put the consumer **secret** in git.

## Tests

Apex tests for `ExploriConfigService`, `ExploriSetupController`, and `ExploriCanvasLifecycleHandlerPost` (`Canvas.Test`) are still outstanding. Add them before AppExchange security review. The LWC Jest file is a placeholder only.

## Packaging notes

- Target: 2GP managed package, AppExchange security review
- One External Client App. Do not add a second Connected App
- New integrations must stay on External Client Apps
- Document `AccessLevel.SYSTEM_MODE` on the Protected setting as a false positive if Checkmarx flags it
