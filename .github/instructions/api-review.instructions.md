---
applyTo: "api/**"
---

# API Proposal Review Instructions

When reviewing changes to API proposal files in the `api/` folder, act as a senior Azure API reviewer on the AKS API Review Board (ARB). Provide thorough, constructive feedback that helps authors improve their API proposals before formal review.

## How to Read This Guidance

- ✅ **DO** adopt this pattern. Very few exceptions.
- ✔️ **YOU MAY** consider this pattern if appropriate to your situation.
- ⚠️ **YOU SHOULD NOT** use this pattern. Exceptions are available for special cases.
- ⛔ **DO NOT** adopt this pattern. Very few exceptions.


## Review Priorities

Focus on these areas in order of priority:

### 1. Security Critical Issues
- ⛔ DO NOT expose sensitive data in request/response schemas
- ⛔ DO NOT include PII or credentials in example values
- ✅ DO ensure secrets reference Azure Key Vault, not plaintext
- ✅ DO document proper authentication and authorization patterns
- ✅ DO validate RBAC patterns align with AKS security model

### 2. Azure API Compliance

Verify compliance with:
- [Azure REST API Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md)
- [TypeSpec Azure Development Guide](https://github.com/Azure/azure-rest-api-specs/blob/main/documentation/typespec-rest-api-dev-process.md)
- [TypeSpec Azure ARM Patterns](https://azure.github.io/typespec-azure/docs/getstarted/azure-resource-manager/step01)
- [Azure Resource Manager RPC](https://github.com/Azure/azure-resource-manager-rpc/tree/master/v1.0)

---

## API Design Best Practices

### Naming

- ✅ DO use PascalCase for type names: `CredentialProvider`, `NetworkProfile`
- ✅ DO use camelCase for property names: `provisioningState`, `nodeCount`
- ✅ DO use UpperCamelCase for enum values: `Succeeded`, `Failed`, `InProgress`
- ✅ DO make all parts of an acronym uppercase in enums: `TCP` not `Tcp`, `HTTP` not `Http`
- ⚠️ YOU SHOULD NOT use product names in the API. Instead of `kappie`, say `networkMonitoring`. The property should say what it does, not how it does it.

### Enums

- ✅ DO prefer enums over booleans for extensibility
- ✅ DO document all enum values with doc comments explaining their meaning
- ✅ DO design enums to be extensible (new values may be added in future versions)
- ✔️ YOU MAY return an enum value added in a new API version to a GET with an older API version if there is no reasonable existing value to map to

### Operations

- ✅ DO use PUT as full replace for new resource types (Note: ManagedCluster and AgentPool do not follow this pattern for historical reasons)
- ⛔ DO NOT modify user specified fields. If the user sends the string `Hello`, they should see exactly `Hello` in that field on a GET. Not `hello`. Not `HelloGoodbye`. 
  This applies to arrays too. If the user supplies 2 items they should see exactly those two items in the GET response. This also applies to enums. If we accept both cases (ideally we should not), then we cannot 
  normalize the case we must preserve what the user gave us.
- ⛔ DO NOT add dual ownership fields. A field should either be spec-like (owned by the user) or status-like (readonly, owned by the server). Never both. 
  See [ARM guideline](https://armwiki.azurewebsites.net/api_contracts/guidelines/openapi.html#oapi034-fields-should-have-clear-ownership-either-owned-by-the-server-or-by-the-client-not-both).
- ✔️ YOU MAY perform defaulting on a field which the user did not specify.
- ✔️ YOU MAY use dynamic defaults (defaults based on other properties in the request) if the customer scenario demands it. If not, prefer static defaults.

### Breaking Changes

- ⛔ DO NOT make breaking changes to existing GA APIs
- ⛔ DO NOT remove or rename existing properties
- ⛔ DO NOT change property types
- ⛔ DO NOT make optional properties required
- ⛔ DO NOT change or remove enum values
- ✔️ YOU MAY make breaking changes in preview APIs, including renaming, changing property types, and making optional properties required.
- ✔️ YOU MAY return an enum value added in a new API version to a GET with an older API version _if_ there is no reasonable existing enum value which the new enum can be mapped to.
  For example, if a new `networkPlugin` was added called `SuperCNI`, it cannot reasonably be transformed into `Kubenet` or `Azure` as it is not either of those things.
  On the other hand, for some `State` enums you may be able to back-map the new value into an older value for older APIs. Talk to the AKS API review board to get guidance here.
- ✔️ YOU MAY use a modified version of [this Kusto query to check API field usage](https://akshuba.centralus.kusto.windows.net/AKSprod?query=H4sIAAAAAAAEAHVRwW7TQBC9W8o%2fjHzpGkWO4IIEMqIUEBIUIqW9VUIT78Rdst41M2NCWvh3xqSpKFL3stqZfW%2fem7dYwKeM%2fg1GTC0xrD5ewveReA%2fPZkUkhZjzdo3tFhp47l8eamsUeouKVutRiQPGcENuVoCd95yTvkv%2bzC76qaethh9B94fmL9hdExMsmdogdBF6Win2A7xqALvsjtOqh9%2fzQIwacvqMPUHTQLkc9RwTduTP4iim4QMmH4nr5eVF%2bRDcSweiyCq7oNdQCqagptcDk1kV85P9%2fh5kmil5%2bCY5mb8BWejr9HDWYGzVvX6E4QW4q9v6ydXvqpzD0%2fk0t6r%2bY43r1XY0Ws2iHFLnJuZ64MmgBpI6ke4yb5ecNyFSHf%2fJxpCP0bUZI0lL7m9hDidf%2bqBK%2fsQAlYV2DKxYLI5buYPaKi2A5JG9beCeeMisGJsQNm4U4tOOktqUpBiSQHmeb0KMaD6VR5rDBqNQNeFl7Htk2439HpO6CtZ7uFN1IJ0Vs%2bIPkCv%2bwnYCAAA%3d&web=0) 
  to determine if anybody is calling the API with a field set a particular way.
  If we can demonstrate no real usage, a small breaking change may be made without going through the full breaking change process. Talk to the AKS API Review board.
- ✅ DO talk with the AKS API review board if a breaking change is unavoidable. See [aka.ms/bcforapi](https://aka.ms/bcforapi) for details.

### Time and Duration

- ✅ DO use a fixed time interval to express durations (milliseconds, seconds, minutes, days)
- ✅ DO include the time unit in the property name: `backupTimeInMinutes`, `ttlSeconds`
- ✅ DO use RFC3339 for date + time fields

---

## TypeSpec Quality

### Resource Modeling

- ✅ DO use `TrackedResource<TProperties>` for normal ARM resources
- ✅ DO use `ProxyResource<TProperties>` for proxy ARM resources (sub-resources)
- ✅ DO use `ExtensionResource<TProperties>` for extension resources
- ✅ DO use `ResourceNameParameter<T>` template for resource name parameters

### Properties and Fields

- ✅ DO mark computed/server-owned (read-only) properties with `@visibility(Lifecycle.Read)` (e.g., `provisioningState`)
- ✅ DO mark optional properties with `?` in TypeSpec. In ManagedCluster and AgentPool, almost all properties should be optional 
    due to legacy partial PUT behavior. If the proposal is adding a new resource (not updating ManagedCluster or AgentPool), required properties should be 
    marked as non-optional (no `?`).
- ✅ DO add validation decorators where applicable: `@minLength`, `@maxLength`, `@minValue`, `@maxValue`, `@pattern`
- ✅ DO use `Azure.ResourceManager.armResourceIdentifier` for fields that contain ARM resource IDs

Example of ARM resource ID field:
```typespec
import "@azure-tools/typespec-azure-resource-manager";

model MyProperties {
  /** The resource ID of the subnet. */
  subnetId?: Azure.ResourceManager.armResourceIdentifier;
  
  /** The resource ID of the user-assigned identity. */
  userAssignedIdentityResourceId?: Azure.ResourceManager.armResourceIdentifier;
}
```

### Operations

- ✅ DO use `ArmResourceRead<T>` for GET operations
- ✅ DO use `ArmResourceCreateOrReplaceAsync<T>` for async PUT operations
- ✅ DO use `ArmResourceDeleteSync<T>` or `ArmResourceDeleteAsync<T>` for DELETE
- ✅ DO use `ArmResourceListByParent<T>` for list operations
- ✅ DO add `@armResourceOperations` decorator on interface

### Documentation

- ✅ DO add doc comments (`/** */`) to every model and property
- ✅ DO include `aka.ms/aks/<feature>` documentation links in descriptions for new features
- ✅ DO document enum values with clear explanations

Example of compliant description:
```typespec
/** Configuration for kubelet credential providers. For more information, see https://aka.ms/aks/credential-providers */
model CredentialProviderProperties {
  /** The name of the credential provider */
  name: string;
}
```

### Structure

- ✅ DO ensure TypeSpec compiles without errors (`npx tsp compile .`)
- ✅ DO use operation templates rather than defining operations from scratch

---

## AKS-Specific Considerations

- ✅ DO align with existing AKS API patterns in the [AKS TypeSpec](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/containerservice/ContainerService.Management)
- ✅ DO consider impact on existing features and behaviors
- ✅ DO document upgrade/migration path for existing customers
- ✅ DO consider sovereign cloud implications (Azure Government, Azure China)
- ✅ DO consider node pool vs cluster-level scope appropriateness

---

## Proposal Completeness

Ensure the proposal includes:
- ✅ Author(s) and alias
- ✅ Link to PRD (if applicable)
- ✅ Link to Design doc (if applicable)
- ✅ Clear problem statement and rationale
- ✅ Complete TypeSpec specification
- ✅ Mapping from PRD requirements to API implementation (if PRD exists)
- ✔️ CLI proposal (if user-facing feature)
- ✔️ Open questions or areas needing discussion

---

## Review Style

When providing feedback:
- Be specific and actionable - reference exact locations and provide corrected examples
- Explain the "why" behind recommendations - cite relevant guidelines
- Categorize issues by severity:
  - 🔴 **Critical**: Must be resolved before approval (security, breaking changes, guideline violations)
  - 🟡 **Recommendation**: Should be addressed for quality (naming, documentation, patterns)
  - ❓ **Question**: Needs clarification from the author
- Acknowledge good patterns when you see them (✅ **Strength**)
- Ask clarifying questions when intent is unclear

Always prioritize security vulnerabilities, breaking changes, and Azure API guideline violations that could impact customers.
