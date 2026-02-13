# AKS RP API implementation DOs and DONTs

## How to Read This Guidance

- ✅ **DO** adopt this pattern. Very few exceptions.
- ✔️ **YOU MAY** consider this pattern if appropriate to your situation.
- ⚠️ **YOU SHOULD NOT** use this pattern. Exceptions are available for special cases.
- ⛔ **DO NOT** adopt this pattern. Very few exceptions.

## Validation

- ⛔ DO NOT accept requests which contain instructions which will be ignored. If the user requests a change we are not going to action, reject the request with a clear error explaining why.
  For example for a field that is an int, allowed values 0-10, currently at 5, if user sends request that says "set to 5", accept that even though it's what we're already at (we didn't 
  ignore their request we're just already there). If they ask for 11, reject that.

## Defaulting

- ⛔ DO NOT change the default value of a property in the API in existing API versions or existing Kubernetes versions.
- ✔️ YOU MAY change the default value of a property in the API for new clusters created with any API version on a new Kubernetes version. 
  For example new clusters created on 1.27 now have a default `maxSurge` of 10% instead of the previous value of 1 for Kubernetes versions <= 1.26.
- ✔️ YOU MAY change the default value of a property in the API for new clusters created with a new API version. 
  For example new clusters created on API version 2023-01-01 have a different default than previous APIs.
- ✅ DO prefer to do defaults changes at a Kubernetes version boundary rather than an API version boundary.
- ✅ DO talk to the AKS API review board before performing any default value changes. They will likely need to be approved by the Azure breaking change board.
- ✅ DO default "on the way in". When a request with a missing value is received by the RP, perform defaulting on that value and _store it in the database_.
- ⛔ DO NOT default "on the way out". We should avoid situations where we have a missing value in the database and that means certain defaults, which we fill in on the GET.
  The GET payload should closely resemble the actual state we have in the database. The larger the difference between what the customer see for a field and what we're acting on internally, 
  the more risk for bugs around "it says X but it is not actually doing X".
- ✅ DO ensure that users can see the defaults we applied on a GET (see above about defaulting "on the way in" for how to achieve this).
- ✔️ YOU MAY have a default of `nil` (omitted in JSON) if that makes sense in the context. In general this makes sense for contexts where the default is "the thing you are configuring does not exist".
  The default `ingress` might be `nil` (not included in GET response). The default `nodeCount` should be an actual integer, not `nil`.

## API modeling

- ✅ DO use pointers for all non-ptr types in the [API datamodel](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp?path=/resourceprovider/server/microsoft.com/containerservice/datamodel/v20240401/types.go&version=GBmaster&_a=contents).
  `*bool`, not `bool`, `*int`, not `int`. Without the ptr, we are unable to differentiate between the user specifying the default value, or the user omitting the value entirely.
- ✔️ YOU MAY use `string` instead of `*string` if you're _sure_ you will never need to differentiate between the empty string and the user omitting the field entirely.
  If there is any doubt, use `*string`.
- ✅ DO specify `omitempty` for all fields.

## Enums

- ✅ DO make sure that your enums are validated in the RP. If the enum supports two values, `Foo` and `Bar`, there should be a unit test in the RP that confirms that ONLY `Foo` and `Bar`
  are accepted. All other values should be rejected with HTTP status code 400 (BadRequest).
- ✅ DO use case-sensitive validation for enums. Accept `Foo` and `Bar`, not `FoO` or `bar`. Being case-insensitive means we also have to be case-preserving which is easy to get wrong
  and more work. See [ARM guidelines](https://armwiki.azurewebsites.net/api_contracts/guidelines/openapi.html#oapi026-do-not-normalize-property-values).
  **Example:** [here](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/10182252?_a=files).
- ✅ DO model enums as non-optional Protobuf enum in the unversioned model. Use `Unspecified` to represent that the user didn't set the enum.
- ✅ DO model enums with N+2 states. The 0 value should be `Unspecified`. The 1 (or 99 if you prefer) value should be `Invalid`. This `Invalid` state should always be rejected by
  validation and exists to handle cases where the user passed an invalid enum value to the versioned API.
  See [this PR](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/12044088) for example.

## PUT as full replace

- ✅ DO use PUT as full replace the resource. If a property is omitted in a resource PUT, that means set that property back to its default (which may mean _clear_ that property, if it has
  no default). Note that ManagedCluster and AgentPool both do not follow this rule, so in the AKS API this only applies to new resource types (not MC/AP).
- ✅ DO apply defaults _every time_ a PUT happens. There is no such thing as "create-only defaults" when PUT is full-replace.
- ❓ OPEN QUESTION on the best practice for dealing with added properties on PUT. Imagine new property "Foo" in v2. If user sets "Foo" in v2, then issues a GET with v1 (which does not
  have the new property "Foo" as it wasn't added until v2) and then a v1 PUT w/ that same GET payload, what should the user see on GET with v2? Should "Foo" be cleared, or no?

## Release timeline

- ⛔ DO NOT merge RP code changes adding API features before the corresponding API review has been approved.
- ⚠️ YOU SHOULD NOT release RP changes for an API that doesn't have a backend implementation. The expectation is that on the RP code complete date for the API version you are targeting,
  the API _and_ its backend is implemented, including E2E tests, unit tests, etc. Exceptions to this rule are occasionally available to meet aggressive dates for preview APIs (never for GA).
  If your feature gets an exception, its backend should still be implemented before the code-complete of the next API version (otherwise why didn't we just target that API version instead?).
  To request an exception to this rule, ask for one during the API review process.
- ✅ DO implement validation in the RP to reject configuration for which a backend implementation is not available (see above rule for when that is allowed).
  We should never accept a user request that contains a payload which we will not act upon (for example because the backend doesn't exist).
