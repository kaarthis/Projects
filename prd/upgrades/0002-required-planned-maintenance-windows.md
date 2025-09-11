---
title: Required Planned Maintenance Windows for AKS Clusters
wiki: ""
pm-owners: [kaarthis,shasb]
feature-leads: [ye wang]
authors: [kaarthis]
stakeholders: [Ye, Robbie, Stephane, Matthew, Jorge]
approved-by: [] 
---

# Overview 

> Before this feature, AKS customers experienced unexpected disruptions from auto-upgrades and AKS releases because planned maintenance windows were optional and had to be configured individually per cluster. Now, AKS customers are required to create a planned maintenance window before creating any cluster, with the ability to reuse maintenance configurations across multiple clusters for consistent and predictable upgrade experiences.

## Problem Statement / Motivation  

AKS customers frequently report being surprised by cluster disruptions caused by auto-upgrades and AKS release rollouts. This unpredictability stems from two main issues:

1. **Optional Planned Maintenance Windows**: Currently, planned maintenance windows are opt-in, leading many customers to skip this configuration step. Without maintenance windows, clusters are subject to automatic upgrades during default maintenance periods, which may not align with customer business hours or operational requirements.

2. **Cluster-Level Configuration Overhead**: The current [`maintenanceConfigurations` resource](https://github.com/Azure/azure-rest-api-specs/blob/21125481b488d99469d71c0101a7656bc5c80a94/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/stable/2025-02-01/managedClusters.json#L733) is a sub-resource under individual `managedClusters`, requiring customers to configure maintenance windows separately for each cluster. For organizations with multiple clusters, this creates significant operational overhead and increases the risk of inconsistent configurations.

These issues result in:
- Unexpected application downtime during business hours
- Increased operational burden for multi-cluster environments
- Customer loss of confidence in AKS reliability and predictability

## Goals/Non-Goals

### Functional Goals

- Require planned maintenance window configuration for all new AKS clusters.
- Enable reusable maintenance configurations across multiple clusters.
- Support cross-regional resource coverage: maintenance configurations can be referenced by clusters in different regions, with consistent enforcement and time-zone–aware scheduling.
- Provide migration path for existing clusters to adopt the new model.
- Ensure customer awareness through Azure Advisor recommendations, API breaking change board approval, portal banners, and targeted communications to all customers.
- Provide comprehensive support materials including enhanced documentation with Bicep/Terraform samples and knowledge base articles for troubleshooting.

### Non-Functional Goals

- Improve predictability and transparency of cluster maintenance events
- Reduce operational overhead for multi-cluster environments
- Maintain backward compatibility during transition period

### Non-Goals

- Modifying existing auto-upgrade or release rollout mechanisms
- Supporting per-node pool maintenance windows (future consideration)
- Changing emergency security patch deployment procedures
- Modificiations (no addition/removal) of the [different configuration types](https://learn.microsoft.com/en-us/azure/aks/planned-maintenance?tabs=azure-cli#schedule-configuration-types-for-planned-maintenance) is not in the scope of this PRD.

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Platform Engineer | Microsoft.ContainerService/managedClusters/*, Microsoft.ContainerService/maintenanceConfigurations/* | As a platform engineer managing 50+ AKS clusters, I want to define maintenance windows once and apply them to multiple clusters, so I can ensure consistent upgrade behavior across my entire fleet without repetitive configuration. Success: Ability to create one maintenance configuration and associate it with multiple clusters. |
| Cluster Administrator | Microsoft.ContainerService/managedClusters/write, Microsoft.ContainerService/maintenanceConfigurations/read | As a cluster administrator, I want to be required to specify a maintenance window when creating clusters, so I can avoid unexpected disruptions to my production workloads. Success: Cannot create a cluster without specifying a maintenance window. |
| DevOps Engineer | Microsoft.ContainerService/managedClusters/read, Microsoft.ContainerService/maintenanceConfigurations/read | As a DevOps engineer, I want to easily discover when my clusters will undergo maintenance, so I can plan deployments and avoid scheduling conflicts. Success: Clear visibility into maintenance schedules for all clusters. |

## Customers and Business Impact 

**Customer Impact:**
- Only 16.5% of clusters using NodeImage/SecurityPatch channels have Planned Maintenance Windows (PMWs).
- Aligns with OKR [Enable AKS to make promises about workload SLOs](https://dev.azure.com/msazure/CloudNativeCompute/_workitems/edit/29497624).
- Upgrade CSAT score dropped to 160 in CY25, highlighting the need to boost customer satisfaction.

- Large enterprises across telecom, financial services, and healthcare (e.g., AT&T, BlackRock, Kaiser, Epic) have experienced unintended maintenance-triggered disruptions; because many do not use Azure Kubernetes Fleet Manager yet operate multiple clusters, they need reusable, centrally managed maintenance configurations.

### Customer signals and support volume

- Anecdotally, customers are unclear on how to configure and interpret maintenance windows; for example, see [Incident 660151968 (IcM)](https://portal.microsofticm.com/imp/v5/incidents/details/660151968/summary).

| Incident ID       | Summary                                                | Customer symptom/ask                                                                                                                                                                                                                                                                         | Category (SAP path)                                                                                                                                                                  |
|-------------------|--------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2412020040015869  | [Azure Government] Availability drop outside window    | Availability drop observed outside the configured maintenance window.                                                                                                                                                                                                                        | Azure/Kubernetes Service (AKS)/Connectivity/Cannot connect to application hosted on AKS cluster (Ingress)                                                                           |
| 2502250050003435  | {ADDRESSPII} OS SecurityPatch upgrades not applied     | Enabled node OS image SecurityPatch channel and configured a maintenance window; no image upgrades observed across node pools; lacks diagnostics to verify whether auto-upgrade is working; requests guidance on debugging.                                                                  | Azure/Kubernetes Service (AKS)/Create, Upgrade, Scale and Delete operations (cluster or nodepool)/Upgrading the cluster or nodepool                                                 |
| 2504180060004082  | {ALPHANUMERICPII}                                      | Cluster has auto-upgrade enabled for OS image and AKS patch version; asks how to configure maintenance windows to run monthly instead of weekly.                                                                                                                                            | Azure/Kubernetes Service (AKS)/Planned Maintenance (AKS)/Configuring planned maintenance                                                                                            |
| 2503230030001347  | aks                                                    | Requests help troubleshooting why planned OS maintenance upgrade did not trigger despite a configured maintenance window.                                                                                                                                                                    | Azure/Kubernetes Service (AKS)/Planned Maintenance (AKS)/Planned maintenance not working as expected                                                                                |
| 2503170030005591  | Auto-upgraded node image without scheduler             | Reports node image auto-upgrade continued after the maintenance window was deleted (expects no upgrades without a window).                                                                                                                                                                   | Azure/Kubernetes Service (AKS)/Create, Upgrade, Scale and Delete operations (cluster or nodepool)/Node image upgrade                                                                |
| 2501150040009621  | Upgrades outside maintenance window                    | Multiple “Upgrade agent pool node image version” operations occurred outside the configured window, causing production outage; window set to 06:00 UTC every 3rd Saturday; asks why a Tuesday 7 PM EST update occurred outside the planned window.                                           | Azure/Kubernetes Service (AKS)/Planned Maintenance (AKS)/Planned maintenance not working as expected                                                                                |

Outages due to unintended breaking changes coming from AKS releases (without default maintenance)--

**Regression Impact:**
- **Production Outages**: Critical data path failures affecting multi-region deployments
  - [Outage 604655061](https://portal.microsofticm.com/imp/v3/incidents/details/604655061): Azure CNI PodSubnet data path failure impacting customer workloads across regions
  - [Incident 651582493](https://portal.microsofticm.com/imp/v3/incidents/details/651582493): azure-npm v1.6.27 CrashLoopBackOff in East US 2 EUAP
  - [Incident 644343290](https://portal.microsofticm.com/imp/v3/incidents/details/644343290): Azure Monitor metrics service disruption



## Existing Solutions or Expectations 

### Current State

**AKS clusters with planned maintenance windows:**
- Customers manually configure maintenance windows per cluster using `az aks maintenanceconfigurations add`
- Many customers skip maintenance window configuration, leading to unpredictable upgrades
- No mechanism to share maintenance configurations across clusters

**Azure Kubernetes Fleet Manager and AKS clusters:**
Azure Kubernetes Fleet Manager provides [update orchestration](https://learn.microsoft.com/en-us/azure/kubernetes-fleet/update-orchestration?tabs=azure-portal), which enables customers to coordinate and sequence upgrades across multiple AKS clusters. This orchestration helps ensure consistency and control over upgrade rollouts, reducing the risk of application downtime due to staggered or unsynchronized updates.

However, Fleet Manager does not currently provide any native experience for configuring planned maintenance windows. Instead, it defers to the existing AKS model, requiring customers to set up planned maintenance windows individually for each cluster. This means that while update orchestration addresses upgrade sequencing and consistency, customers still face the operational burden and risk of inconsistent maintenance window configurations across their cluster fleet.

**Customer Expectations:**
- Predictable maintenance schedules aligned with business requirements
- Ability to manage maintenance configurations at scale
- Simple migration path from current optional model. If the UX to make a choice on the planned maintenance window is very simple, customers would be ok with having planned maintenance windows be required.

**Gaps in Current Solutions:**
- Maintenance windows are optional, leading to inconsistent adoption
- No reusability across clusters increases management overhead
- Lack of enforcement creates operational risk and increased support volumes when customers are surprised by unexpected upgrades on their clusters.

## Announcement - Blog

Customers have consistently reported frustration with unexpected cluster upgrades that disrupt workloads, often occurring during critical business hours. These disruptions are primarily due to the current opt-in model for planned maintenance windows, where many users either overlook or intentionally skip configuring maintenance windows for their AKS clusters. As a result, clusters are upgraded according to default schedules that may not align with customer operational needs, leading to unpredictable downtime and loss of confidence in AKS reliability.

Previously, customers were required to configure planned maintenance windows individually for each AKS cluster, resulting in repetitive setup and increased risk of inconsistent maintenance schedules across their environments.

To address these concerns, AKS is transitioning from an optional (opt-in) planned maintenance window model to a required (default) model. This is a change in default behavior—not a new feature—and aims to ensure every cluster has a predictable upgrade schedule, reducing unexpected disruptions and improving overall customer experience.

Rollout will occur in two phases:
- Phase 1: Promote maintenanceConfigurations to a top‑level resource so maintenance configurations can be created once and reused across multiple clusters.
- Phase 2: Require a maintenance window at cluster creation for all clusters (Kubernetes version cutoff: TBD).

With this new experience, customers can configure planned maintenance windows at scale by applying a single maintenance configuration across multiple AKS clusters for consistent and efficient upgrade scheduling.


## Migration Strategy and Version Cutoff

### Kubernetes 1.36 Enforcement

Starting with Kubernetes version 1.36, all AKS clusters must have specific maintenance configurations based on their upgrade settings:

**Baseline Requirement (All Clusters):**
- **New clusters without auto-upgrade, node OS upgrade, or node recycle policy**: Must have maintenance configuration with `maintenanceConfigurationType: "default"` when creating clusters on 1.36+
- **Existing clusters without auto-upgrade, node OS upgrade, or node recycle policy**: Must have maintenance configuration with `maintenanceConfigurationType: "default"` when upgrading to 1.36
- **API enforcement**: PUT operations (create/update) will be blocked for clusters without the required maintenance configuration types

**Channel-Specific Requirements:**
- **Auto-upgrade channel enabled**: Must have maintenance configuration with `maintenanceConfigurationType: "aksManagedAutoUpgradeSchedule"` configured
- **Node OS channel enabled OR node recycle policy set**: Must have maintenance configuration with `maintenanceConfigurationType: "aksManagedNodeOSUpgradeSchedule"` configured
- **Multiple channels enabled**: Must have corresponding maintenance configuration types for each enabled channel

**Enforcement Logic:**
- **New clusters**: Cannot be created without the appropriate maintenance configuration type(s) based on their upgrade channel settings. For clusters without any upgrade channels, a maintenance configuration with `maintenanceConfigurationType: "default"` is required.
- **Existing clusters**: Must add the required maintenance configuration type(s) before upgrading to 1.36
- **Channel enablement**: Clusters attempting to enable upgrade channels must have the corresponding maintenance configuration types already referenced

### Migration Path for Existing Clusters

The following migration takes effect whenever customers with existing maintenance configuration do a PUT operation (after the peer resource model is ready and operational)
**Clusters with existing maintenance windows:**
- Automatically migrated to the new API model with zero downtime
- Migration process:
  1. AKS creates corresponding top-level maintenance configuration resources (peer resource) even if a cluster has atleast 1 sub resource (legacy) configuration set.
  2. Cluster resources updated to include `maintenanceConfigurationIds` references
  3. All schedules and configurations preserved exactly as configured
- No customer action requiredgit 

**Example: Managed Cluster After Peer Resource Migration**

After migration, a cluster with all three maintenance configuration types will reference the new top-level resources:

```json
{
  "apiVersion": "2025-03-01",
  "type": "Microsoft.ContainerService/managedClusters",
  "name": "myProductionCluster",
  "location": "eastus",
  "properties": {
    "kubernetesVersion": "1.36.0",
    "maintenanceConfigurationIds": [
      "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myRG/providers/Microsoft.ContainerService/maintenanceConfigurations/default",
      "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myRG/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedNodeOSUpgradeSchedule",
      "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myRG/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedAutoUpgradeSchedule"
    ],
  
      }
}
```

The cluster now references three separate maintenance configuration resources that can be shared with other clusters, eliminating the need for duplicate configurations.

**Clusters without maintenance windows:**
- Must configure maintenance windows before upgrading to 1.36
- Can use existing `az aks update` commands to add maintenance configuration
- Option to share maintenance configurations from other clusters

### Auto-Upgrade Enabled Clusters - Expected Behavior

**Current State Analysis:**
Clusters with auto-upgrade channels enabled represent a critical segment requiring special attention, as these customers have adopted a hands-off approach to cluster management and rely on AKS to handle upgrades automatically. These clusters will eventually auto-upgrade to Kubernetes 1.36, where the maintenance configuration requirement will be enforced.

**Behavior Matrix:**

| Cluster Configuration | Required Maintenance Config | Expected Behavior |
|----------------------|----------------------------|-------------------|
| No auto-upgrade, no node OS channel, no node recycle policy | `default` maintenance configuration | ✅ Manual upgrade to 1.36+ requires default maintenance configuration |
| Auto-upgrade channel enabled | `aksManagedAutoUpgradeSchedule` (required only if auto-upgrade channel is enabled) | ✅ Auto-migrated if exists, continues auto-upgrading; ⚠️ **BLOCKED** if missing |
| Node OS channel enabled OR node recycle policy set | `aksManagedNodeOSUpgradeSchedule` (required only if node OS channel is enabled OR node recycle policy is set) | ✅ Auto-migrated if exists, continues node OS upgrades; ⚠️ **BLOCKED** if missing |
| Multiple channels enabled | Corresponding maintenance configs for each enabled channel | ✅ Auto-migrated if all exist; ⚠️ **BLOCKED** if any required config missing |

**Critical Risk:** Customers without the required maintenance configurations will experience upgrade failures when their clusters attempt to upgrade to Kubernetes 1.36, breaking their operational model.

**Specific Enforcement Rules:**
1. **Baseline clusters** (no upgrade channels): Require `default` maintenance configuration to ensure predictable maintenance schedules
2. **Auto-upgrade enabled**: Must have `aksManagedAutoUpgradeSchedule` to control when automatic minor version upgrades occur
3. **Node OS upgrade enabled**: Must have `aksManagedNodeOSUpgradeSchedule` to control when node image and security patches are applied
4. **Node recycle policy set**: Must have `aksManagedNodeOSUpgradeSchedule` to control when node recycling maintenance occurs
5. **Multiple features enabled**: Must have all corresponding maintenance configurations (cumulative requirement)

**Targeted Communication Strategy:**
Given that these customers rely on AKS for automatic management and may not actively monitor standard communication channels, a focused 3-part communication outreach will be implemented specifically for clusters without maintenance configurations:

1. **High-Priority Alert (90 days before K8s 1.36)**: Direct email to subscription owners and cluster contributors with urgent action required messaging
2. **Escalation Notice (45 days before K8s 1.36)**: Follow-up communication with specific cluster IDs and step-by-step remediation instructions
3. **Final Warning (14 days before K8s 1.36)**: Critical alert with immediate action deadline and support contact information

**Note:** Clusters that receive peer resources through automatic migration of existing maintenance configurations will continue auto-upgrading without interruption and are excluded from this targeted outreach.

### Communication and Process Strategy

**API Breaking Change Management:**
- Submit proposal to Azure API Breaking Change Board for formal approval and governance oversight
- Coordinate with Azure Terraform Provider team 6 months prior to enforcement with detailed migration guides and resource mapping documentation
- Create comprehensive Bicep template samples internally for ARM template compatibility and customer adoption

**Customer Awareness Campaign:**
- **Azure Advisor**: Deploy targeted recommendations 90 days before K8s 1.36 release identifying clusters without maintenance windows
- **Portal Integration**: Display prominent banners in AKS portal blade with migration guidance and timelines
- **Direct Communications**: Send targeted emails to subscription owners with affected clusters, including step-by-step migration instructions
- **Documentation Hub**: Create dedicated migration portal with FAQs, troubleshooting guides, and infrastructure-as-code samples

**Support Infrastructure:**
- **Knowledge Base**: Comprehensive articles covering common migration scenarios, error codes, and resolution steps
- **Sample Library**: Curated Bicep, Terraform, and ARM templates demonstrating maintenance configuration patterns
- **Support Training**: Equip CSS teams with specialized knowledge for handling migration-related inquiries
- **Monitoring Dashboard**: Track adoption rates and identify customers requiring proactive assistance

### Option 1: Required Maintenance Windows with Top-Level Resource (Recommended)

#### Note: Phase 1: promote maintenanceConfigurations to a top‑level resource; Phase 2: require maintenance windows for all clusters (Kubernetes version cutoff TBD).

**Implementation:**
- Promote `maintenanceConfigurations` to a top-level Azure resource
- Require maintenance window specification for all new cluster creation
    - If customers want to just proceed forward with cluster creation without giving careful consideration to date/time for a maintenance window, they can do so by just providing an arbitrary date time (for example, Sunday 2:00)
- Allow multiple clusters to reference the same maintenance configuration
- CLI and portal experiences will only ask for a required day of the week and time window inputs as required, AKS will auto-translate and create maintenance configuration resources with GUID-based names for each required configuration type and reference them. Instead of this simpler UX, if the customer wants to create these maintenance configuration resources themselves with custom names and reference them in AKS cluster, they will have an option to do so.

**Pros:**
- Eliminates unexpected upgrade disruptions
- Reduces operational overhead through reusability
- Provides better resource management and RBAC capabilities

**Cons:**
- Breaking change for cluster creation workflows
- Requires customer workflow adaptation
- Additional complexity in resource dependencies

### Option 2: Optional with Enhanced Guidance

**Implementation:**
- Keep maintenance windows optional but add stronger recommendations
- Improve documentation and portal guidance
- Add warnings for clusters without maintenance windows

**Pros:**
- No breaking changes to existing workflows
- Gradual adoption path

**Cons:**
- Does not solve the core problem of unexpected disruptions
- Continues operational overhead for multi-cluster scenarios

### Option 3: Required but Cluster-Level Only

**Implementation:**
- Make maintenance windows mandatory but keep as sub-resource
- Require configuration during cluster creation

**Pros:**
- Eliminates unexpected disruptions
- Minimal API changes required

**Cons:**
- Does not address multi-cluster operational overhead
- Maintains existing scaling limitations

### Option 4: Fleet-Level Maintenance Configuration via Azure Kubernetes Fleet Manager

**Implementation:**
- Introduce maintenance configuration as a resource/configuration within Azure Kubernetes Fleet Manager
- Allow fleet-level maintenance windows to be defined and applied across all clusters managed by a fleet
- Enable clusters to inherit maintenance schedules from the fleet, with optional overrides at the cluster level

**Pros:**
- Centralized management of maintenance windows for large cluster fleets
- Simplifies operational overhead for organizations using Fleet Manager
- Ensures consistent maintenance schedules across all clusters in a fleet

**Cons:**
- Requires enhancements to Fleet Manager APIs and UX
- May introduce complexity for customers not using Fleet Manager
- Potential challenges in reconciling fleet-level and cluster-level configurations

**Recommended Option:** Option 1 - Required Maintenance Windows with Top-Level Resource

This option fully addresses both customer pain points while providing a foundation for future enhancements.

**Breaking Changes:**
- Cluster creation APIs, CLI, and Portal will require maintenance window specification
- Existing automation scripts will need updates to include maintenance configuration

**Go-to-Market:**
- Position as a reliability and operational efficiency improvement
- Provide migration tools and comprehensive documentation
- Offer customer success support during transition

**Pricing:**
- No additional charges for maintenance configuration resources
- Pricing model remains unchanged

## User Experience 

### API

**New Top-Level Resource:**

_Resource URIs for Maintenance Configuration Types:_

    - **Maintenance Configuration (any name)**
        ```
        /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/maintenanceConfigurations/{maintenanceConfigurationName}
        ```

_Body for maintenance configuration resource with configurable type:_
```json
{
  "apiVersion": "2025-03-01",
  "type": "Microsoft.ContainerService/maintenanceConfigurations",
  "name": "production-weekends",
  "properties": {
    "maintenanceConfigurationType": "default", // "default", "aksManagedAutoUpgradeSchedule", or "aksManagedNodeOSUpgradeSchedule"
    "maintenanceWindow": {
      "schedule": {
        "weekly": {
          "intervalWeeks": 1,
          "dayOfWeek": "Saturday"
        }
      },
      "durationHours": 4,
      "startTime": "02:00",
      "timeZone": "Pacific Standard Time"
    }
  }
}
```

**Examples of Multiple Maintenance Configurations:**
```json
// Production weekend maintenance for default operations
{
  "name": "prod-weekend-default",
  "properties": {
    "maintenanceConfigurationType": "default",
    "maintenanceWindow": { /* schedule */ }
  }
}

// Production auto-upgrade schedule
{
  "name": "prod-auto-upgrade",
  "properties": {
    "maintenanceConfigurationType": "aksManagedAutoUpgradeSchedule", 
    "maintenanceWindow": { /* schedule */ }
  }
}

// Development environment maintenance
{
  "name": "dev-environment",
  "properties": {
    "maintenanceConfigurationType": "default",
    "maintenanceWindow": { /* schedule */ }
  }
}
```

**Updated Cluster Resource:**
```json
{
  "apiVersion": "2025-03-01",
  "type": "Microsoft.ContainerService/managedClusters",
  "properties": {
    "maintenanceConfigurationIds": [
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/prod-weekend-default",
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/prod-node-os-schedule",
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/prod-auto-upgrade"
    ]
  }
}
```

**Enforcement Logic:**
- Customers can create maintenance configurations with any name they choose
- Each maintenance configuration specifies its type via `maintenanceConfigurationType` property
- Clusters must reference maintenance configurations that match their upgrade channel requirements:
  - **Baseline clusters** (no upgrade channels): Must reference at least one maintenance configuration with `maintenanceConfigurationType: "default"`
  - **Auto-upgrade enabled**: Must reference at least one maintenance configuration with `maintenanceConfigurationType: "aksManagedAutoUpgradeSchedule"`
  - **Node OS/recycle enabled**: Must reference at least one maintenance configuration with `maintenanceConfigurationType: "aksManagedNodeOSUpgradeSchedule"`

Note: Customers can create multiple maintenance configurations of each type within a resource group, enabling flexible scheduling for different cluster groups (e.g., prod-weekend, dev-nightly, staging-monthly).

### CLI Experience

**Customer who will use simple UX at cluster creation**

```bash
# Basic cluster - automatically generates maintenance config with GUID name
az aks create \
  --resource-group myRG \
  --name myCluster \
  --start-time 02:00 \
  --day-of-week Saturday
```

Above command will automatically generate maintenance configuration resources with GUID names and appropriate `maintenanceConfigurationType` based on the cluster's upgrade channels. AKS will create unique maintenance configurations for this cluster without requiring customer-specified names.

**Customers with existing clusters**

AKS will introduce the required behavior for planned maintenance windows at 1.36 Kubernetes version. Customers with existing clusters will first have to update their clusters to add maintenance configurations before upgrading to 1.36 version where API requests for clusters without maintenance windows configured will be rejected.

```bash
az aks update \
  --resource-group myRG \
  --name myCluster \
  --start-time 02:00 \
  --day-of-week Saturday
```

Above command will generate these maintenance configuration resources with GUID-based names, an 8-hour window and utcOffset `+00:00`

```
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/{guid-1}",
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/{guid-2}", 
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/{guid-3}"
```

```bash
az aks upgrade \
  --resource-group myRG \
  --name myCluster \
  --kubernetes-version 1.36 
```

**Customer who wants to granularly set up maintenance configuration per each type**

```bash
# Create reusable maintenance configurations with custom names
az aks maintenance-configuration create \
  --resource-group myRG \
  --name "production-weekends" \
  --type "default" \
  --schedule-type weekly \
  --day-of-week Saturday \
  --start-time 02:00 \
  --duration 4 \
  --time-zone "Pacific Standard Time"

az aks maintenance-configuration create \
  --resource-group myRG \
  --name "prod-auto-upgrade-schedule" \
  --type "aksManagedAutoUpgradeSchedule" \
  --schedule-type weekly \
  --day-of-week Sunday \
  --start-time 01:00 \
  --duration 6 \
  --time-zone "Pacific Standard Time"

# Create cluster with required maintenance configuration references
az aks create \
  --resource-group myRG \
  --name myCluster \
  --maintenance-configuration-ids \
    "/subscriptions/.../maintenanceConfigurations/production-weekends" \
    "/subscriptions/.../maintenanceConfigurations/prod-auto-upgrade-schedule"

# List maintenance configurations
az aks maintenance-configuration list --resource-group myRG

# Update maintenance configuration (affects all associated clusters)
az aks maintenance-configuration update \
  --resource-group myRG \
  --name "production-weekends" \
  --start-time 03:00
```

Note: The schema and all other fields/values currently supported by planned maintenance configurations will remain the same.

### Portal Experience

- **Maintenance Configuration Management**: New blade for creating and managing maintenance configurations with custom names
- **Cluster Creation Flow**: Required step to specify maintenance window (day of week and start time) with auto-generated GUID-based maintenance configurations, or option to select existing maintenance configurations
- **Multi-Cluster View**: Dashboard showing which clusters use which maintenance configurations
- **Migration Wizard**: Guided experience for existing clusters to adopt new model

### Policy Experience

While making planned maintenance a sibling resource helps with defining one maintenance window configuration that can be shared by multiple clusters, it still requires customers to add references to this shared maintenance configuration resource from all their AKS clusters. If customer has hundreds of AKS clusters, we have a few options on how to simplify the addition of these references:

**Option A: Azure Policy built-in policies with Modify and Deny effects**

Azure Policy can help customers at scale by automatically modifying existing AKS clusters to add references to shared maintenance configuration resources. This is achieved using built-in policies with the "Modify" effect, which can update resource properties to include the required `maintenanceConfigurationIds`. Resources can be targeted for modification in two main ways:

- **Scope-based targeting:** Apply the policy at the subscription or resource group level to update all AKS clusters within that scope.
- **Tag-based targeting:** Apply the policy to clusters with specific tags (e.g., `environment=production`), enabling selective updates based on business or operational criteria.

This approach allows organizations to efficiently enforce maintenance window requirements and ensure consistent configuration across large collection of clusters, minimizing manual effort and reducing the risk of missed updates.

Policy with `Deny` effect can be used on Day N to ensure different groups of clusters (however user defines them - dev, staging, prod,...) conform to chosen maintenance configuration windows.

AKS can provide built-in policies to customers with parameters for day of the week (required), time (required), and other inputs as optional.

_Pros:_
- Enables bulk updates of maintenance configuration references across large numbers of clusters.
- Flexible targeting via scope or tags for selective enforcement.
- Azure Policy is available with all ARM resources without any additional overhead of enrollment to a grouping resource (such as Fleet Manager)

_Cons:_
- Requires customers to understand and manage Azure Policy.

**Option B: Leverage Fleet Manager to update maintenance configuration references at-scale**
Fleet Manager's `updateRuns` API can be enhanced to support bulk modification and addition of `maintenanceConfigurationIds` across managed clusters. This would allow customers to specify a set of maintenance configuration resources and apply them to all or selected clusters within a fleet in a single operation.

**How it works:**
- Extend `updateRuns` to accept a list of `maintenanceConfigurationIds` as part of the update payload.
- Fleet Manager orchestrates the update, ensuring each managed cluster references the specified maintenance configurations.
- Optionally, support targeting clusters by tags, names, or other fleet-level selectors for granular control.

**Pros:**
- Centralized, scalable management of maintenance windows for large fleets.
- Integrates with existing Fleet Manager orchestration workflows.

**Cons:**
- Only available to customers using Fleet Manager; not applicable for standalone clusters

## Recommendation: Option A (Azure Policy built-in policies)

Option A is recommended for enforcing maintenance window references at scale. Azure Policy offers broad applicability, allowing organizations to automate updates across all AKS clusters without requiring enrollment in Fleet Manager. Its flexibility—supporting scope- and tag-based targeting—enables selective enforcement and minimizes manual effort. Azure Policy is natively available for ARM resources, ensuring a consistent experience for all customers, including those managing standalone clusters. While Fleet Manager enhancements (Option B) would benefit customers already using fleet orchestration, Option A delivers immediate value and operational simplicity for the widest range of AKS users.

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Eliminate unexpected cluster disruptions | % of clusters with planned maintenance windows | 100% for all clusters >= 1.36 | High |
| 2   | Improve customer satisfaction with upgrade predictability | Customer satisfaction scores for upgrade experience | Inc from 160 to 162 by 1.36 version | High |
| 3   | Reduce support escalations | Number of support cases related to unexpected upgrades | 10 per quarter to 0 by 1.36 version | Medium |

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Promote maintenanceConfigurations to top-level Azure resource | High |
| 2   | Require specific maintenance configurations based on cluster upgrade settings | High |
| 3   | Enforce aksManagedAutoUpgradeSchedule for clusters with auto-upgrade channel enabled | High |
| 4   | Enforce aksManagedNodeOSUpgradeSchedule for clusters with node OS channel or node recycle policy | High |
| 5   | Require default maintenance configuration for baseline clusters (no upgrade channels) | High |
| 6   | Enable multiple clusters to reference same maintenance configuration | High |
| 7   | Provide migration path for existing clusters | High |
| 8   | Support RBAC for maintenance configuration resources | Medium |
| 9   | Enable ARM template and Terraform integration | Medium |
| 10  | Provide built-in Azure Policy with Modify and Deny effects to enforce maintenance configuration references | High |

## Test Requirements

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Automated tests for cluster creation failure without maintenance config | High |
| 2   | Integration tests for multi-cluster maintenance configuration sharing | High |
| 3   | End-to-end tests for upgrade scheduling within maintenance windows | High |
| 4   | Migration scenario testing for existing clusters | Medium |
| 5   | Automated tests for Azure Policy enforcement of maintenance configuration references across clusters | Medium |

**Key Risks:**
- Customer resistance to breaking changes in cluster creation workflows

# Compete 

## GKE 

Google Kubernetes Engine (GKE) offers maintenance windows through their maintenance policy feature, but:
- Maintenance windows are optional, not required
- Configuration is per-cluster only
- No reusable maintenance configurations across clusters
- Limited flexibility in scheduling options

For more details on configuring maintenance windows and exclusions, refer to:
- [Google Kubernetes Engine (GKE) Maintenance Windows](https://cloud.google.com/kubernetes-engine/docs/how-to/maintenance-windows-and-exclusions)

## EKS

Amazon Elastic Kubernetes Service (EKS) provides maintenance windows, but:
- Maintenance windows are optional
- No concept of reusable maintenance configurations
- Limited to node group maintenance only
- Cluster control plane updates follow AWS-managed schedules

For more details on configuring maintenance windows and exclusions, refer to:
- [Amazon Elastic Kubernetes Service (EKS) Maintenance Windows](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html)

**Competitive Advantage:**
By requiring maintenance windows and enabling reusable configurations, AKS will provide superior predictability and operational efficiency compared to both GKE and EKS, positioning AKS as the most enterprise-ready managed Kubernetes service for production workloads.
