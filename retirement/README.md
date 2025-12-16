# Retirements and Breaking Changes
Use this folder for proposals for Retirements and Breaking Changes.

## What is a breaking change? [aka.ms/CPEXBreakingChangeProcess](https://aka.ms/CPEXBreakingChangesProcess) 
A breaking change can consist of configuration or deployment changes or API-related breaking changes. If a customer is no longer able to do something they could before, consider if the change is minimal (requires only a breaking change) or feature/service level (requires a retirement).
* Breaking changes typically require 90 days notice from announcement before the change can be made.

### Steps for a breaking change
* Create a breaking change proposal.
* Get approvals from AKS Leads (same as PRD).
* Get approvals from Breaking Change Board. See office hours at: [aka.ms/CPEXBreakingChangeProcess](https://aka.ms/CPEXBreakingChangesProcess) or contact [azbreakchangereview@microsoft.com](mailto:azbreakchangereview@microsoft.com).
* After approval is received, continue with your breaking change.

### What to include in a breaking change proposal
* Summary of change (what can customers no longer do)
* Customer Impact (Customer count, sub count, S500 subs, cluster/node pool count)
* Communication plan (Including a template of your AzComms)
* Migration plan (What will you recommend customer migrate to? Is there an alternative)

## What is a Retirement? [aka.ms/CPEXretirements](https://aka.ms/CPEXretirements) 
If you are retiring a feature or service, you will want to go through the CPEX retirement process.

*   General guidance for deprecating GA'd features is to go through the 3-year retirement process. CVP approval can be sought to shorten this time span. See [AKS Retirement common scenarios and requirements](https://microsoft.sharepoint.com/:w:/t/APEXProgram/EWezmtaQICRNhgBqMPDdhdEBPnXHlL9R5AREijaOXAocjg?e=ijiFP6) to view requirements for your retirement scenario.
*   CPEX has two retirement trains every year (March and September). Make sure you plan accordingly and have all of the necessary content prepared at least a month in advance. If you miss a train, your retirement will be delayed by 6 months at least.

_Example: A preview feature which was never successful is now being replaced by a new feature. We want to migrate customers to the new feature and retire the code, documentation, and experience of the old preview feature._

### Announcement, Retirement, and Removal

**Announcement:** When you announce that a feature will no longer be supported. 
- You should have an approved retirement plan before you release your announcement to customers. 
- You should always include retirement and removal dates in your announcement.
- You should always provide an alternative option or migration path for customers.

**Retirement:** When a feature is no longer supported and you cannot enable the feature (new enablements).
- Existing customers using the feature are now unsupported.
- Customers should not be able to enable the feature on new clusters/node pools.
- You should track how customer usage reduces and reach out to high usage customers as needed to help their migrations.

**Removal:** When a feature is removed from AKS and existing users will likely experience breakage.
- Usage should be reduced when removal occurs.
- Customers should be made aware of expected breakage when removal occurs.
- Example of removal steps:    
   1. Archive the public document, add a callout on the new feature (if any)
   1. Cleanup the E2E coverage for it
   1. Cleanup the codebase logic for it
   1. Cleanup the preview feature flag
   1. Publish new API with deprecated property