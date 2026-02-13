# API Gotchas

Some things that might surprise you about our Swagger, and should be fixed.

## Async (aka Long Running Operations or LRO)

See: [Async API Reference](https://github.com/Azure/azure-resource-manager-rpc/blob/master/v1.0/async-api-reference.md)

1. All our async APIs return the `Azure-AsyncOperation` header. But anything that returns 202/accepted also returns a `Location` header. This is mostly POSTs and DELETEs
   (but one GET?).
   [Example](https://dataexplorer.azure.com/clusters/aks/databases/AKSprod?query=H4sIAAAAAAAAA03MMQ7CMAxA0b2n8NhKDKgTS9nKiEDhAqZYJIPtyHGKWnF4OqHO/+lfTMVHed01jDOJl+YLn0hGEN1zcPRaYBigP/b/cjOaUqFHYtoAZzgDvrU9xW4jpTKjpZVg0iredvBcQDMZelK5ItNht/4BTtFC7H8AAAA=).
   We should update our Swagger to reflect this.
2. Many examples don't document the `Azure-AsyncOperation` header, or they do but the URL they show is actually for `Location` not for `AsyncOperation`.
3. Our `Azure-AsyncOperation` URL is `Microsoft.ContainerService/locations/<location>/operations/<opid>` instead of `operationsstatus` as mentioned in the async reference
   above, but we think this is okay. `Location` uses `Microsoft.ContainerService/locations/<location>/operationresults/<opid>` which matches the spec.
4. Like other clients, even though POST itself does not return a 200, we document a 200 as a way of showing what you will get from the `Location` header — but see next point.
5. Our location URL does not ever return 200 or a response body when successful; it will instead return 204. But our Swagger documents 200 for several POST actions and is
   incorrect. Changing the Swagger to 204 is a breaking change because it will alter the signature of generated clients. Instead we want to fix the location header to give
   a 200 and a result body. This would actually fulfill the spec above too.
   - This also means we always return internal server error for failures rather than echoing client error or actual internal error. And we can't tell if
     `getoperationresults` is failing. See #19245967.
6. There is a new `final-state-via` that should indicate what we should use, but only abort uses it at this time.
7. Often we return a response body with 202 (e.g. abort nodeimage) but shouldn't.
8. Before an operation fails, we still leak error details even if the message is still enqueued/in progress.

## Validation

1. Read-only is not rigorously validated, so things like `nodeImageVersion` often pass through.
2. See also: [Other RP-level validation quirks that aren't specific to Swagger](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/369885/RP-improvments-)

## Partial PUT and required fields

Partial PUT means that we treat PUT like it's a PATCH. This is technically incorrect as per the HTTP RFC, but lots of Azure services do it because in a time long long ago
ARM recommended it.

1. Many fields are required on create, but NOT required on update (because of the PATCH semantics of update). This means in the Swagger many fields are not marked `required`
   which otherwise would be. Examples include fields like `AgentPool.VMSize`.

## Enum casing inconsistencies

Enum casing in the Swagger is inconsistent. There's some `likeSo`, more `LikeSo`, and a few `like-so`. Unfortunately, because of the Azure breaking change restrictions
it's hard to fix this. **Going forward please use `UpperCamelCase`**.

## PUT AgentPool vs ManagedCluster

Because they have separate logic, not everything in an AgentPool is updatable through ManagedCluster. We're fixing those as we find them, but as long as the
validation/mutation is separate, people miss one or the other.

1. For AgentPools, they can be created with ManagedCluster on initial PUT, but subsequent ManagedCluster PUTs with new AgentPools will have those new agent pools ignored.
   We should at least error in this case.

## Enum case sensitivity

There are some enums in the API (`OSSKU` is a good example) which are case-insensitive but do not preserve case. See `ConvertStringToOSSKU`.

## Related

1. [A problem with AKS PUTs - Overview](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/personalplayground/773554/A-problem-with-AKS-PUTs)
