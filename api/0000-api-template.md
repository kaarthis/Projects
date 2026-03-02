# <REPLACE_WITH_TITLE>

**Author(s)**:  <REPLACE_WITH_GH_ENTERPRISE_ALIAS>

**PRD**:        <REPLACE_WITH_LINK>

**Design doc:** <REPLACE_WITH_LINK>

**Preview proposal (if GA):** <REPLACE_WITH_LINK_OR_NA>

## Required Pre-Requisites

- [ ] If this is a preview API, preview LRB criteria have been done. If this is a GA API, all 
  [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist)
  items that can be done prior to GA-ing the API are done. This includes quality, QOS, scalability, buildout (including sovereign), etc.

## Brief description of why this change is needed

Simple 1-2 sentence description of how the proposed API change solves the problem posed by the PRD. Why choose this approach?

## REST API proposal

```diff
<REPLACE_WITH_TYPESPEC_DIFF>
```

<!--
Include a TypeSpec diff describing the REST API change you're going to make in git patch format (the same
format used by `git format-patch`). Lines prefixed with `+` are new additions, lines prefixed with `-` are
removals, and lines with no prefix (context lines) are unchanged existing code for reference.

TypeSpec is the standard for Azure API specifications going forward. Please ensure that the documentation is
complete with doc comments on all models and properties. This snippet should be production quality.

**References:**
- [TypeSpec Azure Development Guide](https://github.com/Azure/azure-rest-api-specs/blob/main/documentation/typespec-rest-api-dev-process.md)
- [TypeSpec Azure ARM Tutorial](https://azure.github.io/typespec-azure/docs/getstarted/azure-resource-manager/step01)
- [AKS TypeSpec Examples](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/containerservice/resource-manager/Microsoft.ContainerService/aks)
- https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md
- https://azure.github.io/typespec-azure/docs/intro/
- https://armwiki.azurewebsites.net/api_contracts/guidelines/rpc.html
- https://github.com/Azure/azure-resource-manager-rpc/tree/master/v1.0

```diff
--- a/specification/containerservice/ContainerService.Management/aks/models.tsp
+++ b/specification/containerservice/ContainerService.Management/aks/models.tsp
@@ -XX,6 +XX,11 @@ model ExistingModel {
   /** Existing property description */
   existingProperty?: string;
+
+  /** New property description. For more information, see https://aka.ms/aks/<feature> */
+  newProperty?: string;
 }

--- /dev/null
+++ b/specification/containerservice/ContainerService.Management/aks/NewFeature.tsp
@@ -0,0 +1,35 @@
+import "@azure-tools/typespec-azure-resource-manager";
+
+using TypeSpec.Http;
+using TypeSpec.Rest;
+using Azure.ResourceManager;
+
+@armProviderNamespace
+@service({ title: "Service Name" })
+namespace Microsoft.ContainerService;
+
+/** Description of the properties */
+model FeatureProperties {
+  /** Property description. For more information, see https://aka.ms/aks/<feature> */
+  propertyName?: string;
+}
+
+/** Description of the resource */
+model Feature is ProxyResource<FeatureProperties> {
+  ...ResourceNameParameter<
+    Resource = Feature,
+    KeyName = "resourceName",
+    SegmentName = "myFeatures",
+    NamePattern = "^[a-zA-Z0-9]$|^[a-zA-Z0-9][-_a-zA-Z0-9]{0,61}[a-zA-Z0-9]$"
+  >;
+}
+
+@armResourceOperations
+interface Features {
+  get is ArmResourceRead<Feature>;
+  createOrUpdate is ArmResourceCreateOrReplaceAsync<Feature>;
+  delete is ArmResourceDeleteWithoutOkAsync<Feature>;
+  listByParent is ArmResourceListByParent<Feature>;
+}
```
-->

## Sample JSON

```
<REPLACE_WITH_1-2_JSON_SAMPLES>
```

## CLI Proposal (optional)
