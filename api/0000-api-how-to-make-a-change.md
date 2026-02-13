# How to Make a Change to the API

Before you do this, make sure you understand the
[API release process](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/232501/API-Review-Process?anchor=understanding-api-version-timelines).

## Steps

0. **Understand best practices:** Read the [AKS API Best Practices](../.github/instructions/api-review.instructions.md).

1. **API review:** Go through the
   [API Review Process](README.md) and get approvals. As part of this process you should have determined which API version your feature is going into.

2. **Design doc review:** Ensure that your design document is reviewed and approved before starting on backend implementation.

3. **HCP/Protobuf (data storage):** Make the HCP/Protobuf changes required to support your feature. Merge this and tag it.
   - Example: [Add Karpenter NodeProvisioningDefaultPoolsMode enum](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/11889462)

4. **AFEC for preview features:** Add the AFEC flag for your feature, if it's a preview feature.

5. **Backend (rp-async, overlaymgr, etc):** Make the backend changes needed to support your feature. These changes will likely be in rp-async or overlaymgr,
   or possibly both. This is what the service does when your new option(s) are set in the API.
   - Example: [Update OverlayMgr to support Karpenter disabled default pools](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/11910065?_a=files&path=/overlaymgr/server/helmvalues/addonvalues/karpenter_overlay.go)

6. **Frontend (rp-sync):** Make the frontend changes in validation and datamodel to accept the new field, validate it, and set it in the proto model.
   - If making a preview API change, make sure to check your AFEC flag _and_ a toggle with logic like:
     ```text
     if toggle off, reject
     ...
     if afec off, reject (w/ clear error about AFEC flag they need to register)
     ```
   - The toggle is for controlling what region(s) (if any) support this feature. Note that _once you turn the toggle on_, you can't turn it off again as users
     may have started using the feature and turning the toggle off will break them. The toggle is for one-time feature enablement at rollout and for early testing.
   - It is **strongly** recommended that you write an `integration_test.go` style test for your feature that confirms the happy-path. See more about validators
     and testing at [Validation Best Practices](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/580711/Validation-Best-Practices).
   - Example: [Add nodeProvisioningProfile.defaultNodePools field](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/11910684)

7. **TypeSpec:** Make the TypeSpec changes. The TypeSpec branch availability will be posted in the **AKS API channel** on Teams.
