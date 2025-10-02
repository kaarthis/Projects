---
title: Native Custom Kubelet Credential Provider Support for AKS
wiki: ""
pm-owners: [jackjiang]
feature-leads: [jackjiang]
authors: [shasb, jackjiang]
stakeholders: [benjaminapetersen, anramase, shasb, johsh, gaking, qinhao]
approved-by: [] 
---

# Overview 

> Before this feature, AKS customers had to implement complex and non-ideal workarounds to authenticate to custom container registries. These workarounds could require manual secret management, init containers, and/or third-party solutions.

Previously, customers could attempt to configure the kubelet credential providers directly on AKS nodes, but this required manual node customization or deploying a DaemonSet to inject provider binaries which was is not officially endorsed, and prone to breaking during node upgrades or scaling events. Alternatively, customers could manually create and utilize Kubernetes secrets, which would require passing sensitive credentials in their deployments or manually managing/rotating secrets. 

This document proposes a native experience for configuring kubelet credential providers for seamless and secure authentication to any custom container registry.

## Problem Statement / Motivation  

AKS customers frequently need to pull container images from custom container registries (other than Azure Container Registry) for various business and technical reasons:

- **Enterprise Requirements**: Organizations often have existing container registries (Harbor, Nexus, JFrog Artifactory, Quay.io) that they must or wish to continue using due to compliance, security policies, or existing investments.
- **Multi-Cloud Scenarios**: Customers using multiple cloud providers may need to pull images from registries in other clouds (AWS ECR, Google GCR).
- **Third-Party Vendor Images**: Applications requiring proprietary images hosted in vendor-specific registries.

Currently, AKS only provides native authentication integration with Azure Container Registry (ACR). For custom registries, customers must implement workarounds that are complex, insecure, and difficult to maintain:

1. **Manual Secret Management**: Creating and managing Kubernetes secrets with registry credentials, which requires manual rotation and poses security risks.
2. **Node-Level Configuration**: Manually configuring containerd or other components on each node, which is not supported and breaks with node updates. Some customers will not have permissions on [node resource group (NRG) lockdown](https://learn.microsoft.com/en-us/azure/aks/node-resource-group-lockdown) AKS clusters to be able to make these changes.
3. **DaemonSet based configuration**: Deploying a DaemonSet to each node in the cluster that installs and configures kubelet credential provider binaries. DaemonSets may fail to deploy correctly and upgrades or node scaling events often break the configuration, leading to unpredictable authentication failures and increased support burden.

These workarounds result in:
- Operational complexity and maintenance burden due to no native and officially supported way for configuring custom credential providers today.
- Reliability issues during credential rotation and cluster management operations such as upgrades and scaling.

## Goals/Non-Goals

### Functional Goals

- Enable native kubelet credential provider configuration for custom container registries
    - Provide the experience/API at the node pool level to facilitate multi-tenancy seeking customers on the same cluster
    - Provide convenience UX for at-scale definition of the custom credential provider if needed for uniform deployment across an entire cluster (a simplification above the node pool level experience)
- Define the experience for user to be able to provide binaries to configure their BYO-crendential providers and how those can be configured with the node pool/cluster
- Enable configuration through ARM templates, CLI, and Azure Portal

### Non-Functional Goals

- Ensure that configs and binaries the user presents pass validations before intaking them

### Non-Goals

- This PRD for custom container registry is orthogonal to ACR related integrations inside AKS and will not impact any of those experiences.
- Does not modify Kubernetes upstream credential provider specification (we will align with the upstream configuration specs)

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Platform Engineer | Microsoft.ContainerService/managedClusters/*| As a platform engineer managing multi-cloud infrastructure, I want to configure AKS clusters to authenticate with AWS ECR and Google GCR registries using the kubelet credential providers, so my teams can seamlessly pull images without complex workarounds. Success: Ability to seamlessly configure multiple registry credential providers. |
| Application Developer | Built in Kubernetes `edit` role | As an application developer, I want to deploy applications that use images from various registries without worrying about authentication configuration, so I can focus on application development rather than infrastructure concerns. Success: Transparent image pulling from configured custom registries. |

## Customers and Business Impact 

**Supporting Evidence:**
- GitHub issue [#1940](https://github.com/Azure/AKS/issues/1940) with 28+ upvotes requesting registry configuration support
   - A variety of other GitHub issues opened and seeing popular community engagement further support the need/demand for the feature. Examples include [#3909](https://github.com/Azure/AKS/issues/3909) and [4969](https://github.com/Azure/AKS/issues/4969)
- Customer feedback from enterprise accounts (Volvo for example) highlighting this as a blocker for AKS adoption

**Business Impact:**
- Provides a better native experience for enterprise customers with existing non-ACR registry investments for improved CSAT
- Customers have voiced the inability to use existing registry investments (Harbor, Nexus, JFrog) is an issue when utilizing or looking to adopt AKS

## Existing Solutions or Expectations 

**Current Workarounds:**
1. **Kubernetes Secrets**: Manual creation and management of image pull secrets.
2. **Node Modification**: Manually modifying containerd configuration (unsupported and not a scalable approach)
3. **DaemonSet Approach**: Deploying a DaemonSet to install and configure credential provider binaries on each node, which is unsupported, fragile during upgrades or scaling, and can lead to inconsistent authentication behavior across the cluster.

## What will the announcement look like?

**Announcing Custom Kubelet Credential Provider Support in Azure Kubernetes Service (AKS)**

We are excited to introduce native support for custom kubelet credential providers in AKS, enabling seamless authentication to any container registry including AWS ECR, Google GCR, Harbor, and other enterprise registries. This feature eliminates the need for complex workarounds and provides the same secure, managed experience that customers enjoy with Azure Container Registry.

**Addressing Key Challenges**

This feature addresses a critical gap for enterprise customers who want to or need to pull images from multiple registry sources. Previously, customers had to implement complex workarounds involving manual secret management or third-party solutions. A common workaround has been the DaemonSet-based approach, where customers deploy a DaemonSet to install and configure credential provider binaries on each node. These workarounds are typically unsupported, fragile during cluster upgrades or scaling, and often leads to inconsistent authentication behavior and increased operational overhead.

With native credential provider support, AKS now offers enterprise-grade authentication for any container registry while maintaining the security and reliability standards customers expect from Azure.

**Functionality and Usage**

- **Multi-Registry Support**: Configure authentication for AWS ECR, Google GCR, Harbor, JFrog Artifactory, and other non-Azure registries
- **Familiar Management**: Configure through ARM templates, Azure CLI, and Azure Portal like other Azure resources

**Availability**

The general credential provider feature will be available in all Azure regions where AKS is supported, starting with clusters running an up to date Kubernetes version. 

## Proposal 

**ACR**

The contents of this PRD will treat ACR as explicitly out of scope and focus solely on non-ACR container registries. ACR being a first-class experience in Azure could have a different and more integrated experience than what is laid out here for BYO credential provider with non-Azure registries. 

If a customer tries to pass any binaries that mess with the `acr-credential-provider`, those PUTs will be **rejected**. In a similar vein, existing `acr-credential-provider` binaries that already exist on the node will not count towards the 3 credential provider limit.

This feature enables customers to configure custom kubelet credential providers on AKS clusters through a three-step process:

1. **Customer supplies credential provider binary**: Customers provide their credential provider binaries through a **bring your own bootstrap Azure Container Registry (ACR)**, similar to how they would setup their clusters in [network isolated clusters](https://learn.microsoft.com/azure/aks/concepts-network-isolated).
    Rationale: The bootstrap ACR is chosen to host credential provider binaries because it already participates in the established AKS cluster bootstrapping flow (including network isolated / private clusters) and therefore introduces zero new outbound egress, firewall, FQDN, or service tag requirements. Reusing ACR avoids asking customers to open additional endpoints (which alternatives like Storage Accounts, Files, or external artifact stores would require), keeps private link / private DNS patterns unchanged, and leverages existing enterprise controls (RBAC, image tag versioning, content trust, scanning, logging). This preserves a consistent security and networking model (air‑gapped and policy-restricted clusters “just work”), simplifies operational governance (single artifact source for bootstrap assets), and reduces support and documentation surface versus adding a new artifact distribution mechanism.
    
    The bootstrap ACR used for distributing credential provider binaries should be dedicated solely to the purpose of holding resources needed for cluster bootstrapping and not used for storing or pulling user workload images. Using a dedicated bootstrap ACR only for credential provider binaries enforces least privilege: application node pools/workload identities can be granted fine‑grained pull rights solely to their workload image ACR/repository.

2. **Provider Configuration**: Customers specify the kubelet credential provider configuration at the node pool level through AKS APIs (node pool so that we can facilitate multi-tenancy). Customers provide a **single provider configuration** - one object from providers array  [Kubernetes specification](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/#configure-a-kubelet-credential-provider). AKS validates the configuration against the kubelet credential provider schema before intaking the configuration
3. **Node bootstrapping**: AKS automatically configures credential provider on cluster nodes.


**Breaking Changes:**
- No breaking changes to existing clusters, with the proposed feature being opt-in.

**Pricing:**
- No additional charges for credential provider configuration

### Validations

AKS will perform the following validations to ensure credential provider functionality:

1. **Configuration Validation**: AKS validates the credential provider configuration against the Kubernetes credential provider schema before applying it to nodes. This includes verifying required fields, format compliance, and supported provider types.

2. **Binary Availability Validation**: AKS validates that the credential provider binary referenced in the `binaryImageReference` field can be successfully pulled from the specified bootstrap ACR. This validation occurs during node provisioning and configuration updates.

The results and any errors from these validations will be surfaced in the status of the `credentialProviders` sub-resource, providing clear feedback to customers about configuration issues or binary availability problems.

### Logs

The kubelet credential provider binary itself (as written by the customer) is the customer's responsibility. Any issues with the binary functionality, performance, or compatibility are outside Microsoft's support scope. 

Customers can debug issues with their credential provider binary by using Azure Monitor to query credential provider logs pulled from the nodes.


## User Experience 

### API

**Potential paths**

The key consideration for this feature is multi-tenancy - we should design API in a way that if customer wants to segregate different tenants/teams to different isolated node pools with different registries and credential providers, they should be able to do so.

| Option | Details |
| ----   |  ----   |
| 1      | Introduce a node-pool level API for the credential provider sub-resource. We can utilize Azure policy to do at-scale `deployIfNotExists`* across all node pools in a cluster if a user wants to apply a configuration across their entire cluster  |
| 2      | Introduce the credential provider sub-resource at the cluster level. This will allow users to apply a configuration across whole clusters, but at the same time has the drawback that it is not multi-tenant friendly. |

Number 1 is the recommended option.

**Resource URI - Node Pool Level:**

The credential provider configuration will be accessible as a sub-resource under agent pools:

PUT /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{resourceName}/agentPools/{agentPoolName}/credentialProviders/{credentialProviderName}


Following the established pattern for agent pool sub-resources in the [Azure REST API specification](https://github.com/Azure/azure-rest-api-specs/blob/ff00d10875362d73dfbfadc1ad7c760486187dca/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/stable/2025-02-01/managedClusters.yaml#L1055), a proposed API format with example values is below.

```yaml
{
    "name": "nodepool1",
    "credentialProvider": {
        "binaryImageReference": "aws-ecr-provider:v1.0.0",  # Will point to the bootstrap ACR image tag containing the intended credential provider binary.
        "priority": 0, # to account for the case where multiple providers would match against the same image.
        "config": {
            "provider":{
                "name": "aws-ecr-credential-provider",
                "matchImages": [
                    "*.dkr.ecr.*.amazonaws.com",
                    "*.dkr.ecr.*.amazonaws.com.cn",
                    "*.dkr.ecr-fips.*.amazonaws.com"
                ],
                "defaultCacheDuration": "12h",
                "apiVersion": "credentialprovider.kubelet.k8s.io/v1",
                "env": [
                    {
                        "name": "AWS_PROFILE",
                        "value": "default"
                    }
                ],
                "args": [
                    "--region=us-west-2"
                ],
                "tokenAttributes": {
                    "serviceAccountTokenAudience": "<audience for the token>",
                    "requireServiceAccount": true,
                    "requiredServiceAccountAnnotationKeys": [
                        "example.com/required-annotation-key-1",
                        "example.com/required-annotation-key-2"
                    ],
                    "optionalServiceAccountAnnotationKeys": [
                        "example.com/optional-annotation-key-1",
                        "example.com/optional-annotation-key-2"
                    ]
                }
            }
        }
    }
}
```

#### Setting up the config

As the cred provider will be based off the user passed custom credential provider config, the user should ensure that they create and properly configure the config file for their credential provider.

A user should follow the [upstream guidance](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/#configure-a-kubelet-credential-provider) to set up their credential provider config to ensure that they are adhering to the expected values/input.

Some general points that should be noted:

- A user can configure multiple custom credential providers sub-resources per node pool, with 3 being the upper limit. If they choose to configure multiple credential providers, they will need to make sure that they pass the different binaries and configs to AKS, one binary/config per credential provider sub-resource they would like (see more details in the CLI section)


### CLI Experience

AKS will extend the Azure AKS CLI to support the configuration of credential providers at both node pool level. 

**CLI**

We will be introducing a new group of commands under `az aks credential-provider` that will allow customers to add/delete/update a credential provider. In all these scenarios, specifying the `resoure-group`, `cluster-name`, and `nodepool-name` are required.

**Adding a credential provider**

```bash
az aks credential-provider add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --nodepool-name myNodePool \
    --name aws-ecr-credential-provider \
    --credential-provider-binary-image "aws-ecr-provider:v1.0.0" \
    --credential-provider-config-file ./aws-ecr-config.yaml
```

The passed `--credential-provider-config-file` should [provide one provider from providers array as defined under](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/).

If a customer wants to configure multiple credential providers on the nodepool, they will be expected to run `az aks credential-provider add` multiple times.

- As an example, if I want to add a credential provider for both my ecr and my ghcr registries on my node pool, I'll need to run `az aks credential-provider add` twice, one time for each registry.

**Updating an existing credential provider**

Customers can update an existing credential provider configuration using the `az aks credential-provider update` command and providing the *updated* binaries and config file they want to use:

```bash
az aks credential-provider update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --nodepool-name myNodePool \
    --name aws-ecr-credential-provider \
    --credential-provider-binary-image "aws-ecr-provider:v2.0.0" \
    --credential-provider-config-file ./aws-ecr-config.yaml
```

**Deleting an existing credential provider** 

Customers that want to delete a credential provider config from their node pool can run the `az aks credential-provider delete` command:

```bash
az aks credential-provider delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --nodepool-name myNodePool \
    --name aws-ecr-credential-provider
```

**Listing credential providers**

A command should also be added to allow a user to quickly query their node pool for the existing credential provider resource(s) on it currently, with the output being the list of existing `credential-provider-name` in the specified node pool.

```bash
az aks credential-provider list \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --nodepool-name myNodePool \
```
     
**matchImages resolution**

In the event that >1 provider is configured with the same value in their `matchImage` field (e.g. both my `aws-ecr-provider` and my `ghcr-provider` have `*.ghcr.io/*`, the [upstream behavior](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/#configure-a-kubelet-credential-provider) will be followed. Multiple providers may match against a single image, in which case credentials from all providers will be returned to the kubelet. If multiple providers are called for a single image, the results are combined. If providers return overlapping auth keys, the value from the provider earlier in this list is used (in case of ARM/subresource, we have proposed to handle this via a priority field.)

### Portal Experience

- **Node Pool Configuration Blade**: New section for "Container Registry Authentication" added during node pool addition on the Portal: 
<img width="1214" height="1277" alt="image" src="https://github.com/user-attachments/assets/1c5a7435-983d-49de-93ca-b50ae123b95c" />
- **Credential Provider Setup Wizard**: Step-by-step configuration for setting up one's custom credential provider

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Adoption of custom credential providers | In the trailing 30 days (as of 7/31/2025), there were 48,733,168 clusters that had images from non-Microsoft registries. | 50% adoption from customers using non-ACR/MAR registries within 12 months | High |
| 2   | Reduce support escalations | Number of support cases related to registry authentication | Reduce by 70% | High |

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Customers should be able to configure custom kubelet credential providers for their AKS node pools via API, ARM templates, CLI, and Azure Portal | High |
| 2   | Be able to accept, validate, and apply (or fail) configuration/binaries passed by the customer to set up their custom credential providers | High |
| 3   | Support up to three non-ACR credential providers per node pool | High |
| 4   | Customers should be able to define their credential providers at node pool creation time and/or update existing node pools to add or modify credential providers | High  |
| 5   | Customers should have access to an easy UX for cluster wide configuration of their credential provider changes | High |
| 6   | Customers should be able to pass their credential provider binaries through a bootstrap Azure Container Registry (ACR), and AKS should be able to pull those binaries from the bootstrap ACR | High |
| 7   | Ensure that the error cases documented in this PRD (e.g. repeated binary or config argument passed in the CLI) result in the PUT request being rejected. | High |
| 8   | An unhealthy credential provider resource at the time of node creation/updates should not block node operations. The cred provider sub-resource should show up as unhealthy.

## Test Requirements

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Confirm authentication and successful image pulls from various custom container registries using kubelet credential providers | High |
| 2   | Validate that credential provider configuration is correctly applied during node pool creation and updates | High |
| 3   | Ensure that validation to both the configuration (to ensure that it matches the schema) and the user provided binaries (to ensure they can be pulled successfully from the bootstrap ACR) work and catch cases where the user has provided invalid configuration or binaries before intaking/applying them | High |
| 4   | Ensure that cluster level credential provider configuration propagates correctly to all node pools in a cluster | High |
| 5   | Ensure that credential provider binaries can be successfully pulled from the bootstrap ACR| High |
| 6   | Test that multiple credential providers can be configured per node pool and that they function correctly | High |
| 7   | Ensure that a failure is returned if a user attempts to alter the `acr-credential-provider` in their config and/or binary | High | 
| 8   | Ensure that requests fail properly if the user misconfigures the CLI arguments detailed in the PRD | High | 

# Dependencies and risks 

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|---------|---------|
| 1   | Portal UX design and implementation | AKS Portal Team |
| 2   | Azure Monitor integration for credential provider logs | Azure Monitor Team |

# Compete 

## AWS EKS

AWS EKS offers several mechanisms for container registry authentication:

- **Manual Secret Management**: For non-ECR registries, EKS users can opt for manual creation and management of Kubernetes `imagePullSecrets` in pod specifications.
- **DaemonSet-Based Credential Provider Injection**: Customers can deploy a privileged DaemonSet that mounts host paths (e.g. the kubelet credential provider directory) and copies a custom credential provider binary plus config onto each node. 

## Google GKE

Users of GKE can also utilize imagePullSecrets in their pod specs to authenticate to custom container registries. Or they can configure custom credential provider on the nodes using the DaemonSet based approach.


## Other Managed Kubernetes Services

**CloudSmith**

CloudSmith has already setup and [provided a configuration](https://github.com/cloudsmith-io/cloudsmith-kubernetes-credential-provider) that will allow users to pull images from CloudSmith using a custom kubelet credential provider scoped to CloudSmith registries. 
- Their demo (although still in early stages) does require users to manually go through configs to set everything up.

**Competitive Advantage:**
By providing native, multi-provider credential support, AKS will offer the most comprehensive and enterprise-ready container registry authentication solution in the managed Kubernetes market, supporting true multi-cloud and hybrid scenarios.
