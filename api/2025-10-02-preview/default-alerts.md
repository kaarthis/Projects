# AKS Default Alerts API

**Author(s)**: @<A09FC9DF-230D-647A-A404-4BD811CB0673> @<C1724A89-1962-65AB-B063-F43AA2D28DCC>

**PRD**: [AKS Default Customer-Facing Alerts One-Pager](https://microsoft.sharepoint.com/:w:/t/azurecontainercompute/EV7KIhUtjM9JrTL4gGOjg5UBui0xkCu_7BaXtyjj7hUmmg?e=LlzfXe)

**Design doc:** [Default Alerts Design Doc](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/personalplayground/806166/Default-Alerts-Design-Doc)

**Past Proposal:** [[OLD] Default Alerts API Proposal](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/973849/-OLD-Default-Alerts-API-Proposal)

## Changelog

| Date | Changes |
|--|--|
| 30/10/2025 | Changed the mode names to "Disabled", "CreateOnly", and "Managed". Remove all mentions of "reconcile". |
| 11/11/2025 | Remove CreateOnly option, AKS RP will manage the full lifecycle of the alerts within the MC resource group. Customers will need to use the API to change notification settings. |
| 23/01/2026 | Re-worked the doc, changing the approach we are taking. |

## Required Pre-Requisites

- [x] This API is a preview API, OR it is a GA API. For GA APIs, all [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist)
  items that can be done prior to GA-ing the API are done. This includes quality, QOS, scalability, buildout (including sovereign), etc - see the LRB list for the full set.

## Brief description of why this change is needed

This proposal introduces a new `alertConfigurations` child resource under ManagedCluster to enable automatic creation of Azure Monitor metric alerts for AKS clusters. The child resource approach (following the `maintenanceConfigurations` pattern) allows independent API versioning, clean extensibility for multiple configurations, and dedicated CRUD lifecycle without requiring cluster reconciliation.

### Resource Identity

**Resource ID Format:**

```
/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/alertConfigurations/{configurationName}
```

**Resource Type:** `Microsoft.ContainerService/managedClusters/alertConfigurations`

### Operations

| Operation | Method | Path | Async |
|-----------|--------|------|-------|
| Create/Update | PUT | `.../managedClusters/{cluster}/alertConfigurations/{name}` | Yes |
| Get | GET | `.../managedClusters/{cluster}/alertConfigurations/{name}` | No |
| Delete | DELETE | `.../managedClusters/{cluster}/alertConfigurations/{name}` | Yes |
| List | GET | `.../managedClusters/{cluster}/alertConfigurations` | No |

## REST API proposal

```typespec
import "@azure-tools/typespec-azure-resource-manager";

using TypeSpec.Http;
using TypeSpec.Rest;
using TypeSpec.Lifecycle;
using Azure.ResourceManager;

@armProviderNamespace
@service({ title: "Microsoft.ContainerService" })
namespace Microsoft.ContainerService;

/**
 * The mode of the alert configuration.
 */
union AlertConfigurationMode {
  string,

  /** The alert configuration is disabled. No alerts are created or managed. */
  Disabled: "Disabled",

  /**
   * AKS manages the alerts lifecycle including creation, updates, and deletion.
   * Users receive alerts through the configured notification channel.
   */
  Managed: "Managed",
}

/**
 * The status of an alert.
 */
union AlertStatus {
  string,

  /** The alert is installed and active. */
  Installed: "Installed",

  /** The alert is pending installation. */
  Pending: "Pending",

  /** The alert installation failed. */
  Failed: "Failed",
}

/**
 * The current provisioning state of the alert configuration.
 */
union AlertConfigurationProvisioningState {
  string,

  /** The alert configuration is being created. */
  Creating: "Creating",

  /** The alert configuration is being updated. */
  Updating: "Updating",

  /** The alert configuration is being deleted. */
  Deleting: "Deleting",

  /** The alert configuration has been successfully provisioned. */
  Succeeded: "Succeeded",

  /** The alert configuration provisioning failed. */
  Failed: "Failed",

  /** The alert configuration provisioning was canceled. */
  Canceled: "Canceled",
}

/**
 * Notification settings for the alert configuration.
 * For more information, see https://aka.ms/aks/default-alerts
 */
model AlertNotification {
  /** The resource ID of the Azure Monitor action group to send notifications to. */
  actionGroupId?: Azure.Core.armResourceIdentifier<[
    {
      type: "Microsoft.Insights/actionGroups";
    }
  ]>;
}

/**
 * Properties of the alert configuration.
 * For more information, see https://aka.ms/aks/default-alerts
 */
model AlertConfigurationProperties {
  /** The mode of the alert configuration. Specifies how AKS manages the alerts. */
  mode: AlertConfigurationMode;

  /** Notification settings for the alert configuration. */
  notification: AlertNotification;

  /** The current provisioning state of the alert configuration. */
  @visibility(Lifecycle.Read)
  provisioningState?: AlertConfigurationProvisioningState;
}

/**
 * Alert configuration for a managed cluster. Allows configuring AKS-managed alerts
 * that notify users of important cluster events and conditions.
 * For more information, see https://aka.ms/aks/default-alerts
 */
@added(Versions.v2025_10_02_preview)
@parentResource(ManagedCluster)
model AlertConfiguration
  is Azure.ResourceManager.ProxyResource<AlertConfigurationProperties> {
  ...ResourceNameParameter<
    Resource = AlertConfiguration,
    KeyName = "configurationName",
    SegmentName = "alertConfigurations",
    NamePattern = "^[a-zA-Z0-9]$|^[a-zA-Z0-9][-_a-zA-Z0-9]{0,61}[a-zA-Z0-9]$"
  >;
}

@armResourceOperations
@added(Versions.v2025_10_02_preview)
interface AlertConfigurations {
  /** Gets the specified alert configuration of a managed cluster. */
  get is ArmResourceRead<AlertConfiguration>;

  /** Creates or updates an alert configuration in the specified managed cluster. */
  createOrUpdate is ArmResourceCreateOrReplaceAsync<
    AlertConfiguration,
    LroHeaders = ArmLroLocationHeader<FinalResult = AlertConfiguration> &
      ArmAsyncOperationHeader &
      Azure.Core.Foundations.RetryAfterHeader
  >;

  /** Deletes an alert configuration. */
  delete is ArmResourceDeleteAsync<AlertConfiguration>;

  /** Gets a list of alert configurations in the specified managed cluster. */
  listByManagedCluster is ArmResourceListByParent<AlertConfiguration>;
}
```

## ARM Compliance

### Idempotency

PUT operations for `AlertConfiguration` follow standard ARM create-or-replace semantics and are idempotent with respect to the full resource body:

- The first successful PUT for a given `configurationName` creates the resource and returns `201 Created` (or `202 Accepted` if the operation is long-running).
- Subsequent PUTs with an identical request body are idempotent and return `200 OK`.
- If the resource already exists and the request body differs, the service updates the resource; this update may complete synchronously (returning `200 OK`) or use the long-running operation pattern (returning `202 Accepted`), but the semantics from the client's perspective are still "create or replace".

The TypeSpec definition uses `ArmResourceCreateOrReplaceAsync` for all PUT operations on `AlertConfiguration`, so clients must be prepared for both synchronous (`200/201`) and asynchronous (`202` followed by polling) responses.

### Long-Running Operations

PUT and DELETE may be long-running operations and, when they are, follow the ARM LRO pattern:

1. If the operation cannot be completed immediately, the initial response is `202 Accepted`.
2. The `Azure-AsyncOperation` header provides an operation status URL.
3. The `Location` header provides the final resource URL (for create/update) or the resource URL for verification.
4. The client polls the operation status URL until a terminal state is reached.
5. On success, a final GET to the `Location` (or the resource URI) returns the completed resource with `201 Created` for creates and `200 OK` for updates.

### API Versioning

- New resource type introduced in `2025-10-02-preview`
- Child resource versions independently from ManagedCluster
- Existing ManagedCluster API versions unaffected

### Regional Deployment

- Alert configuration stored in same region as parent cluster
- Azure Monitor alerts created in node resource group (same region)

## Future Extensibility

The child resource design enables future enhancements without breaking changes:

- **Template support** — named templates (e.g., `production-critical`) as a property
- **Threshold customization** — per-alert override properties (e.g., `nodeCpuThresholdPercent`)
- **Multiple configurations** — remove MVP restriction to allow multiple named configurations per cluster

## Appendix: Comparison with Existing Child Resources

| Aspect | alertConfigurations | maintenanceConfigurations | agentPools |
|--------|---------------------|---------------------------|------------|
| Parent | ManagedCluster | ManagedCluster | ManagedCluster |
| PUT Async | Yes | No | Yes |
| DELETE Async | Yes | No | Yes |
| Max per cluster | 1 (MVP) | 3 (named) | 100+ |
| Creates Azure resources | Yes (Metric Alerts) | No | Yes (VMSS) |
| Lifecycle coupling | Moderate | Low | High |

## Appendix: List of Alerts

All alerts will be evaluated in 1 minute intervals with a lookback period of 5 minutes.
Existing alerts: https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-metric-alerts?tabs=portal#recommended-alert-rule-details

New alerts:

| Alert name | Signal and threshold | Severity |
|--|--|--|
| SNAT port exhaustion | LB metric - SNAT connection count where Connection status == Failed | 1 (Error) |
| Disk IOPS saturation | VM metric - Disk IOPS utilization % >90% | 2 (Warning) |
| Disk bandwidth saturation | VM metric - Disk bandwidth utilization % >90% | 2 (Warning) |
| Cluster auto-upgrade notifications | AKS Communications manager | 3 |
| Nodepool auto-upgrade notifications | AKS Communications manager | 3 |
| Cluster auto-upgrade failure | AKS comms manager | 1 (Error) |
| Nodepool auto-upgrade failure | AKS comms manager | 1 (Error) |
| API server overloaded | API server memory usage > 80% | 2 (Warning) |
| ETCD database full | ETCD database usage >25% | 2 (Warning) |

## CLI Proposal (optional)

```
# Create or update an alert configuration
az aks alert-configuration create \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <configuration-name> \
  --mode Managed \
  --action-group-id <action-group-resource-id>

# Get an alert configuration
az aks alert-configuration show \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <configuration-name>

# List alert configurations for a cluster
az aks alert-configuration list \
  --resource-group <resource-group> \
  --cluster-name <cluster-name>

# Delete an alert configuration
az aks alert-configuration delete \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <configuration-name>
```
