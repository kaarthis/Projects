---
agent: 'agent'
description: 'Convert a PRD into an AKS API proposal'
---

## Role

You are an expert at translating product requirements into technical API specifications for Azure Kubernetes Service. Bridge the gap between product vision and API implementation.

## Context

PRDs (Product Requirements Documents) define what a feature should accomplish from a customer perspective. API proposals define how that feature is exposed through the Azure REST API. This translation requires understanding both the customer journey and Azure API patterns.

## Task

Transform the provided PRD into a structured API proposal following the template at `/api/0000-api-template.md`.

## File Placement

<file_placement_rules>
The API proposal file **must** be placed in a version-based subfolder under `api/` using the target API version.

**Rules:**
1. Use the target API version (provided as input) to determine the folder name
2. Place the API proposal file under `api/<version>/`
3. Name the API proposal file with the same number prefix as the PRD, appending `-api.md`

**Examples:**
| PRD Location | Target API Version | API Proposal Location |
|--------------|--------------------|-----------------------|
| `prd/security/0003-custom-credential-provider.md` | `2025-06-01` | `api/2025-06-01/0003-custom-credential-provider-api.md` |
| `prd/upgrades/0004-health-aware-upgrades.md` | `2025-09-01-preview` | `api/2025-09-01-preview/0004-health-aware-upgrades-api.md` |
| `prd/observability/0005-managed-mesh.md` | `2026-01-01` | `api/2026-01-01/0005-managed-mesh-api.md` |
| `prd/security/supply-chain/0003-admission-control.md` | `2025-06-01` | `api/2025-06-01/0003-admission-control-api.md` |

**Important:** Create the version subdirectory if it doesn't exist.
</file_placement_rules>

## Input

- **PRD Content**: ${input:prd:Paste the PRD content or provide a link}
- **Author**: ${input:author:Your Microsoft alias for the API proposal}
- **Target API Version**: ${input:version:Target API version (Preview or GA)}

## Extraction Process

<extraction_steps>

### Step 1: Extract Key Information from PRD

Identify and extract:
- **Problem Statement**: Customer pain point being addressed
- **User Journeys**: How customers will interact with this feature
- **Personas & Permissions**: Who uses this and what RBAC they need
- **Functional Requirements**: What the feature must do
- **Non-Functional Requirements**: Performance, security, compliance needs
- **API Section**: Any preliminary API ideas from the PRD authors

### Step 2: Map Requirements to API Design

| PRD Element | API Design Element |
|-------------|-------------------|
| User Journey (create/configure) | PUT operation |
| User Journey (view/monitor) | GET operation |
| User Journey (modify) | PATCH or PUT operation |
| User Journey (remove/disable) | DELETE or PUT with disabled state |
| Custom actions | POST operation |
| Permissions per persona | Document required RBAC roles |
| Functional requirements | API properties and behaviors |
| Non-functional requirements | API constraints, validation rules |

### Step 3: Design API Structure

Determine:
- Is this a new property on ManagedCluster?
- Is this a new sub-resource under ManagedCluster?
- Is this a new resource type entirely?
- What operations are needed (CRUD, custom actions)?

### Step 4: Generate Complete API Proposal

Generate TypeSpec specification following Azure ARM patterns. TypeSpec is the standard for Azure API specifications going forward.

**Key Requirements:**
- Use `Azure.Core.armResourceIdentifier` for properties containing ARM resource IDs
- Add doc comments (`/** */`) to all models and properties
- Include `aka.ms/aks/<feature>` documentation links in descriptions

**References:**
- [TypeSpec Azure Development Guide](https://github.com/Azure/azure-rest-api-specs/blob/main/documentation/typespec-rest-api-dev-process.md)
- [TypeSpec Azure ARM Tutorial](https://azure.github.io/typespec-azure/docs/getstarted/azure-resource-manager/step01)
- [AKS TypeSpec Examples](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/containerservice/ContainerService.Management)

**TypeSpec Structure:**
```typespec
import "@azure-tools/typespec-azure-resource-manager";
import "@azure-tools/typespec-azure-core";

using TypeSpec.Http;
using TypeSpec.Rest;
using Azure.Core;

@armProviderNamespace
@service({ title: "Service Name" })
namespace Microsoft.ContainerService;

/** Description with documentation link. See https://aka.ms/aks/<feature> */
model FeatureProperties {
  /** Property description */
  propertyName?: string;
}

/** Resource description */
model Feature is ProxyResource<FeatureProperties> {
  ...ResourceNameParameter<
    Resource = Feature,
    KeyName = "resourceName",
    SegmentName = "myFeatures",
    NamePattern = "^[a-zA-Z0-9]$|^[a-zA-Z0-9][-_a-zA-Z0-9]{0,61}[a-zA-Z0-9]$"
  >;
}

@armResourceOperations
interface Features {
  get is ArmResourceRead<Feature>;
  createOrUpdate is ArmResourceCreateOrReplaceAsync<Feature>;
  delete is ArmResourceDeleteSync<Feature>;
  listByParent is ArmResourceListByParent<Feature>;
}
```

</extraction_steps>

## Output Format

Use the template at [`/api/0000-api-template.md`](/api/0000-api-template.md) as the output format.

## Special Considerations

<prd_considerations>

**Breaking Changes**: If the PRD mentions breaking changes, document:
- What existing behavior changes
- Migration path for existing customers
- API versioning strategy

**Phased Rollout**: If the PRD has multiple phases:
- Generate Preview API for initial phase
- Note what changes for GA API
- Document feature flags if applicable

**Pricing Changes**: If PRD mentions pricing:
- Note any metering requirements in API
- Consider billing-related properties

**Non-Goals**: Respect PRD non-goals:
- Do not add API surface for out-of-scope items
- Note explicitly what's deferred to future API versions

</prd_considerations>

## Validation Checklist

Before finalizing, verify:

- [ ] Every user journey from PRD has a corresponding API operation
- [ ] Every persona's permissions are achievable with the API design
- [ ] Non-functional requirements are reflected (validation, limits, etc.)
- [ ] Breaking changes from PRD are handled appropriately
- [ ] Phased rollout is reflected in API versioning
- [ ] The Brief Description clearly links back to PRD problem statement
- [ ] All models and properties have doc comments (`/** */`)
- [ ] New features include `aka.ms/aks/<feature>` documentation links
- [ ] TypeSpec compiles without errors (`npx tsp compile .`)
