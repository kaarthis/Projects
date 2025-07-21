---
title: Required Planned Maintenance Windows for AKS Clusters
wiki: ""
pm-owners: [shasb]
feature-leads: [shasb]
authors: [shasb]
stakeholders: []
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
- Inconsistent maintenance schedules across cluster fleets
- Increased operational burden for multi-cluster environments
- Customer loss of confidence in AKS reliability and predictability

## Goals/Non-Goals

### Functional Goals

- Require planned maintenance window configuration for all new AKS clusters.
- Enable reusable maintenance configurations across multiple clusters
- Promote `maintenanceConfigurations` to a top-level resource alongside `managedClusters`
- Provide migration path for existing clusters to adopt the new model

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

To address these concerns, AKS is transitioning from an optional (opt-in) planned maintenance window model to a required (default) model. Going forward, all AKS clusters must have a planned maintenance window configured at creation. This change is not a new feature, but a shift in default behavior to ensure every cluster has a predictable upgrade schedule, reducing the risk of unexpected disruptions and improving overall customer experience.

With this new user experience, customers can configure planned maintenance windows at scale, applying a single maintenance configuration across multiple AKS clusters to ensure consistent and efficient management of upgrade schedules throughout their environments.


## Migration Strategy and Version Cutoff

### Kubernetes 1.36 Enforcement

Starting with Kubernetes version 1.36, all AKS clusters must have at least one maintenance configuration:
- **New clusters**: Cannot be created without specifying a maintenance configuration
- **Existing clusters**: Must add a maintenance configuration before upgrading to 1.36
- **API enforcement**: PUT operations (create/update) will be blocked for clusters without maintenance configurations

### Migration Path for Existing Clusters

**Clusters with existing maintenance windows:**
- Automatically migrated to the new API model with zero downtime
- Migration process:
  1. AKS creates corresponding top-level maintenance configuration resources
  2. Cluster resources updated to include `maintenanceConfigurationIds` references
  3. All schedules and configurations preserved exactly as configured
- No customer action required

**Clusters without maintenance windows:**
- Must configure maintenance windows before upgrading to 1.36
- Can use existing `az aks update` commands to add maintenance configuration
- Option to share maintenance configurations from other clusters

### Option 1: Required Maintenance Windows with Top-Level Resource (Recommended)

**Implementation:**
- Promote `maintenanceConfigurations` to a top-level Azure resource
- Require maintenance window specification for all new cluster creation
    - If customers want to just proceed forward with cluster creation without giving careful consideration to date/time for a maintenance window, they can do so by just providing an arbitrary date time (for example, Sunday 2:00)
- Allow multiple clusters to reference the same maintenance configuration
- CLI and portal experiences will only ask for a required day of the week and time window inputs as required, AKS will auto-translate and create maintenance configuration resources of the different configuration types and reference them. Instead of this simpler UX, if the customer wants to create these maintenance configuration resources themselves and reference them in AKS cluster, they will have an option to do so.

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

    - **Default Maintenance Configuration**
        ```
        /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/maintenanceConfigurations/default
        ```

    - **AKS Managed Node OS Upgrade Schedule**
        ```
        /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedNodeOSUpgradeSchedule
        ```

    - **AKS Managed Auto Upgrade Schedule**
        ```
        /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedAutoUpgradeSchedule
        ```

_Same body for all the 3 resoruces above:_
```json
{
  "apiVersion": "2025-03-01",
  "type": "Microsoft.ContainerService/maintenanceConfigurations",
  "name": "production-weekends",
  "properties": {
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

**Updated Cluster Resource:**
```json
{
  "apiVersion": "2025-03-01",
  "type": "Microsoft.ContainerService/managedClusters",
  "properties": {
    "maintenanceConfigurationIds": [
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/default",
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedNodeOSUpgradeSchedule",
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedAutoUpgradeSchedule"
    ]
  }
}
```

Note: The requirement is that customers specify at least 1 value for the array above. The simple UX with CLI and portal would auto-generate the three. If the customer wants to override and provide their own maintenance configuration, they are allowed to do that. In the process, they can provide one or all three of the maintenance configuration resources. Either ways, they make an explicit choice on the planned maintenance windows this way.

### CLI Experience

**Customer who will use simple UX at cluster creation**

```bash
az aks create \
  --resource-group myRG \
  --name myCluster \
  --start-time 02:00 \
  --day-of-week Saturday
```

Above command will generate these maintenance configuration resources with an 8-hour window and utcOffset `+00:00`

```
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/default",
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedNodeOSUpgradeSchedule", 
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedAutoUpgradeSchedule"
```

**Customers with existing clusters**

AKS will introduce the required behavior for planned maintenance windows at 1.36 Kubernetes version. Customers with existing clusters will first have to update their clusters to add maintenance configurations before upgrading to 1.36 version where API requests for clusters without maintenance windows configured will be rejected.

```bash
az aks update \
  --resource-group myRG \
  --name myCluster \
  --start-time 02:00 \
  --day-of-week Saturday
```

Above command will generate these maintenance configuration resources with an 8-hour window and utcOffset `+00:00`

```
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/default",
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedNodeOSUpgradeSchedule", 
"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/maintenanceConfigurations/aksManagedAutoUpgradeSchedule"
```

```bash
az aks upgrade \
  --resource-group myRG \
  --name myCluster \
  --kubernetes-version 1.36 
```

**Customer who wants to granularly set up maintenance configuration per each type**

```bash
# Create reusable maintenance configuration
az aks maintenance-configuration create \
  --resource-group myRG \
  --name default \
  --schedule-type weekly \
  --day-of-week Saturday \
  --start-time 02:00 \
  --duration 4 \
  --time-zone "Pacific Standard Time"

# Create cluster with required maintenance configuration
az aks create \
  --resource-group myRG \
  --name myCluster \
  --maintenance-configuration-ids /subscriptions/.../maintenanceConfigurations/default

# List maintenance configurations
az aks maintenance-configuration list --resource-group myRG

# Update maintenance configuration (affects all associated clusters)
az aks maintenance-configuration update \
  --resource-group myRG \
  --name default \
  --start-time 03:00
```

Note: The schema and all other fields/values currently supported by planned maintenance configurations will remain the same.

### Portal Experience

- **Maintenance Configuration Management**: New blade for creating and managing maintenance configurations
- **Cluster Creation Flow**: Required step to select or create maintenance configuration
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
| 2   | Require maintenance configuration for all new AKS cluster creation | High |
| 3   | Enable multiple clusters to reference same maintenance configuration | High |
| 4   | Provide migration path for existing clusters | High |
| 5   | Support RBAC for maintenance configuration resources | Medium |
| 6   | Enable ARM template and Terraform integration | Medium |
| 7   | Provide built-in Azure Policy with Modify and Deny effects to enforce maintenance configuration references | High |

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
