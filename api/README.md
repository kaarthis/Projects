# API Change Proposals

1. First, determine if your change is a new feature or an update of an existing feature. 
   If it's a new feature (or you're unsure) please reach out to the Airlock team to track your feature in the [new LRB process](https://dev.azure.com/msazure/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/187537/LRB-Launch-Reviews).
2. For major features such as entirely new service, or major new AddOn, make sure the name of the product is approved via 
   PMM review before proposing to use it in AKS API.
3. Create an API review doc from [the template](0000-api-template.md). Use the provided copilot prompts.
4. Place the document under the appropriate directory (see [directory structure](#directory-structure)).
5. Post a link to your new document in the [AKS API Channel](https://teams.microsoft.com/l/channel/19%3a106ed06b2a3745b1a7ee5c573ab098c6%40thread.skype/AKS%2520API%2520channel?groupId=e121dbfd-0ec1-40ea-8af5-26075f6a731b&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47). 
   API review board members will take a look at it asynchronously. They may ask for a meeting if the change needs more detailed discussion.
   Please ping on this request if you haven't seen some responses within 24-48 hours.
6. After a week of asynchronous review, if there is no resolution/approval, you can request a meeting with the
   API review board members. Please use **[API Review Meeting Required]** in the email title.

**Do NOT merge the service PRs until the change is explicitly approved by @AKS API Review Board. It needs to be approved by 2 dev leads and 1 PM, and approvals by your direct manager don't count**

_This process should be lightweight!_
If it is taking more than ~15 minutes to create the API review document please let the API review board members know.

Post design questions to [AKS Design Office Hour](https://teams.microsoft.com/l/channel/19%3a670a332002e2479fa971d1db40fa860b%40thread.skype/AKS%2520Design%2520Office%2520Hour?groupId=e121dbfd-0ec1-40ea-8af5-26075f6a731b&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47) if you have questions

## Timeline

1. Proposal is generated and sent to Teams channel/Email thread.
2. AKS API Review Board will have 1 week to review proposal and discuss.
3. If proposal still needs approvals after 1 week (5 business days), a meeting can be created to finalize approval or next steps.

## Escalation Channel order

1. Teams channel
2. Email
3. Separate Meeting

## Azure Breaking Change Policy

https://dev.azure.com/msazure/AzureWiki/_wiki/wikis/AzureWiki.wiki/37684/Breaking-Changes


## Directory Structure

```
api/
    2026-02-01/
        feature-a-proposal.md
    2026-02-02-preview/
        feature-b-proposal.md
```
