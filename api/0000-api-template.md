# <REPLACE_WITH_TITLE>

**Author(s)**:  <REPLACE_WITH_GH_ENTERPRISE_ALIAS>

**PRD**:        <REPLACE_WITH_LINK>

**Design doc:** <REPLACE_WITH_LINK>

## Required Pre-Requisites

- [ ] This API is a preview API, OR it is a GA API. For GA APIs, all [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist)
  items that can be done prior to GA-ing the API are done. This includes quality, QOS, scalability, buildout (including sovereign), etc - see the LRB list for the full set.

## Brief description of why this change is needed

Simple 1-2 sentence description of how the proposed API change solves the problem posed by the PRD. Why choose this approach?

## REST API proposal

```
<REPLACE_WITH_TYPESPEC>
```

<!--
Include a TypeSpec snippet describing the REST API change you're going to make. TypeSpec is the standard for Azure API specifications going forward. Please ensure that the documentation is complete with doc comments on all models and properties. This snippet should be production quality and compilable with `npx tsp compile`.

**References:**
- [TypeSpec Azure Development Guide](https://github.com/Azure/azure-rest-api-specs/blob/main/documentation/typespec-rest-api-dev-process.md)
- [TypeSpec Azure ARM Tutorial](https://azure.github.io/typespec-azure/docs/getstarted/azure-resource-manager/step01)
- [AKS TypeSpec Examples](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/containerservice/ContainerService.Management)
- https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md
- https://azure.github.io/typespec-azure/docs/intro/
- https://armwiki.azurewebsites.net/api_contracts/guidelines/rpc.html
- https://github.com/Azure/azure-resource-manager-rpc/tree/master/v1.0

```typespec
import "@azure-tools/typespec-azure-resource-manager";

using TypeSpec.Http;
using TypeSpec.Rest;
using Azure.ResourceManager;

@armProviderNamespace
@service({ title: "Service Name" })
namespace Microsoft.ContainerService;

/** Description of the properties */
model FeatureProperties {
  /** Property description. For more information, see https://aka.ms/aks/<feature> */
  propertyName?: string;
}

/** Description of the resource */
model Feature is ProxyResource<FeatureProperties> {
  ...ResourceNameParameter<Feature>;
}

@armResourceOperations
interface Features {
  get is ArmResourceRead<Feature>;
  createOrUpdate is ArmResourceCreateOrReplaceAsync<Feature>;
  delete is ArmResourceDeleteAsync<Feature>;
  listByParent is ArmResourceListByParent<Feature>;
}
```
-->

## CLI Proposal (optional)
