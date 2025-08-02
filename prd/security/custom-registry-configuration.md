---
title: Custom Registry Configuration for AKS Node Pools
wiki: "https://aka.ms/aks/custom-registry-config"
pm-owners: ["@AKS-PM-Team"]
feature-leads: ["@AKS-Engineering-Lead"]
authors: ["@AKS-PM-Team"]
stakeholders: ["@Customers-with-custom-registries", "@Container-Registry-Team"]
approved-by: [] 
---

# Custom Registry Configuration for AKS Node Pools

## Problem Statement / Motivation

> Before this feature, AKS customers had to manually configure various configurations or set up custom resources, such as DaemonSets, to do the configuration to direct pulls to their custom container registries. These solutions would be tedious and could break during cluster upgrades or scaling operations. 
> Now, AKS customers can configure their node pools to pull from their non-Microsoft registries through an AKS native experience that is resilient to cluster operations and persists across the node lifecycle.

Container images are the foundation of Kubernetes applications, and AKS customers often need to pull images from various registry sources beyond Azure Container Registry (ACR). While AKS offers native integration with ACR, customers using other registries face significant challenges:

1. **Complex containerd Configuration**: Customers must manually edit containerd configuration files on each node for their different registries.

2. **Inconsistent Cluster Operations**: During upgrades, scaling, or other cluster operations, custom containerd configurations are often lost, causing unexpected application failures and downtime.

3. **Operational Overhead**: DevOps teams spend significant time troubleshooting and maintaining registry configurations rather than focusing on application development.

4. **Non-Persistent Settings**: Changes to containerd registry configurations don't persist through node recycling events, requiring teams to manually have to reapply configurations or turn to makeshift solutions like daemonsets to apply their configurations for them.

These pain points are particularly acute for customers with:
- Organizations deeply integrated with non-Microsoft registry solutions like Harbor, JFrog Artifactory, Nexus, or Quay.io
- Regulated industries requiring air-gapped or isolated registry deployments

## Goals/Non-Goals

### Functional Goals

- Create a native experience for configuring custom non-ACR registry endpoints in AKS
- Enable configuration at the node pool.
   - Introduce an optional UX for users for cluster wide configuration
- Ensure that configurations persists across node operations (e.g. upgrades)
- Allow configuration through all AKS management interfaces (Portal, CLI, ARM templates, Terraform)
- Enable user configuration to propogate without the user having to manually re-configure their pod deployment YAMLs

### Non-Functional Goals

- Ensure that configs the user presents pass validations before intaking and applying to the node

### Non-Goals

- Users are expected to upkeep their custom registries, and ensure that images they need are present in their registries. 
- No gaurantees/SLAs extended to the user's custom registries, nor their images that sit on those custom registries.
- Registry authentication and credential management (these will be addressed in a separate PRD)


## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Cluster Administrator | Microsoft.ContainerService/managedClusters/*, Microsoft.ContainerService/managedClusters/agentPools/* | As a cluster administrator, I want to configure my AKS cluster to connect to our enterprise JFrog Artifactory registry. I should be able to provide registry configuration and have my node pools connected the registry endpoints. My success criteria include: registry configurations persisting through cluster upgrades and node recycling operations. |
| DevOps Engineer | Microsoft.ContainerService/managedClusters/read, Microsoft.ContainerService/managedClusters/agentPools/read, Microsoft.ContainerService/managedClusters/write | As a DevOps engineer, I need to configure specific node pools to pull from different registries based on different teams' requirements. I want to easily define which node pools pull from which custom registry. Success means workloads on specific node pools can access their designated registries. |
| Application Developer | Microsoft.ContainerService/managedClusters/read | As an application developer, I want to deploy my applications to AKS without worrying about having to reconfigure my deployment manifests. I should be able to reference an image from my deployment manifest and set/forget it. Success means focusing on application development without dealing with registry configuration. |

## Customers and Business Impact

There is material demand for AKS to be able to easily support pulls from non-ACR/MCR registries:

- GitHub issues with many upvotes, such as the [ability to define a registry mirror](https://github.com/Azure/AKS/issues/1940) or [support image pulls from custom defined registries](https://github.com/Azure/AKS/issues/4969)
- Customer feedback from enterprise customers, such as JFrog, citing the need to be able to configure custom registries without having to resort to daemonsets
- Internal telemetry:
   - [Representative data](https://dataexplorer.azure.com/clusters/apadata.westus/databases/AKS?query=H4sIAAAAAAAAA12Oy4oCMRBF9%2F0VRVYt%2BIJZOyAKwyC6GN03NUnZBqyuppL4wo83GWEQa1Nwz7lw56ttsxFH34wthWZxTCGSNkv0x2t1h%2FOBlGDnmUJE7uETsJX6Y%2BoGGfJpRJceOwe%2BtGH2%2FFuKGdIlUiZOGH33pZL6zC0GqivI92wcMIDBW1KyOvZihmDmix8zfFc4Y%2FZWJcg%2Bjq1wMdf%2FptlIB7k4KVFVpoXEjOpvBFZSF%2BsB%2FF5ft2RF1JGW%2BM9owFGwDw4ssjIOAQAA) shows that, within a 30 day sample size (30 days leading up to Aug 1st, 2025), ~48.6 million clusters had images sitting on them that were non-ACR/MAR.
   - In another query of [image pull attempts](https://dataexplorer.azure.com/clusters/akshuba.centralus/databases/AKSccplogs?query=H4sIAAAAAAAAA7WTTU%2FDMAyG7%2FsVVi60ULENzkNwQBy4II0bGiik3ohokiofjCF%2BPE42usDGl4Bc2sSO%2Fdp%2BcnI%2BPg%2B3ePqA2rveM8zv0CJcWBTS4aVUOPZctXAEfGaK4aAuOx%2BL3BkNoxGwi9A0WDMy4aNHXfeAlvPcBwcjENxhkY7iUugcnyHccQeMNxSlXkBr0ZEAVm052n5zHISg%2FZQyk2%2FKD1KROcZwHxu7aMx4KoOlfbk8Ti43wTYkmgqxXPjieIcVV9dssleynQqG1auKsisWaqO4pEaAnE4L6bTxqFq%2FKLpwZQXeOG%2BlnhWubaRfm0hsn5VXgwn5sKDvtZlrthH7zJrQvunkKmdqhRI2Fp0%2BG0b%2BFGiWyaH77eX1x2QuKMWtfMJlC%2BI40%2BBM0L4o4XaR66hWk%2B1AyO4cweFauzeeN6%2BxqAGCN9wu5Z%2B8oS6efIe83G8LfUtzRuAnFP6OxL%2Bn8T2RGZU%2FJzNvxH%2FQuSX%2BJqFfUvptUjde60rAmtpE2hrYXvaAWrSChhcnNQISqWtiabA%2FgN2c234GawUH8b6xNdqIfuZWoxMvDGWf%2BjEFAAA%3D) over the past 10 days, ~33% of images were from non-ACR/MAR registries. 

Key business metrics impacted:

- **Customer Satisfaction**: Improved CSAT customers with multi-registry needs
- **Migration Acceleration**: Reduced friction for customers migrating from self-managed K8s or other K8s services, or those that already have their own container registry estate, to AKS

## Existing Solutions or Expectations

Customers currently use several approaches to configure custom registry endpoints, each with significant limitations:

1. [**Manual containerd Configuration**](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#registry-configuration---examples):
   - Requires access to each node to modify `/etc/containerd/config.toml`
   - Configurations lost during node upgrades/recycling
   - Difficult to manage at scale across multiple node pools

2. **Custom DaemonSets**:
   - Deploy DaemonSets that modify containerd configuration on each node
   - Complex to implement and upkeep
   - Breaks during upgrades if not carefully managed, introducing overhead

## What will the announcement look like?

**Announcing Custom Registry Configuration for Azure Kubernetes Service**

We are excited to introduce native custom registry configuration for AKS, enabling users to seamlessly connect your AKS nodes to any custom container registry endpoint. This feature eliminates the complexity of managing containerd registry configurations while ensuring reliability across cluster operations.

**Addressing Key Challenges**

Organizations operate varied environments that may necessitate pulling container images from different registries, including enterprise solutions like Harbor or JFrog Artifactory, and other cloud providers' registries such as AWS ECR or Google GCR. Previously, configuring containerd to work with these diverse registries required manual node-level configuration that was prone to breaking during cluster operations or required users to implement workarounds like daemonsets to do the configuration, introducing operational overhead and reliability issues.

**Functionality and Usage**

With custom registry configuration, AKS now offers seamless configuration for custom container registry endpoints that persist through cluster scaling and upgrades with minimal user input required for maintenance. 

**Availability**

TIMING TBD!!!

For more information, visit our [documentation](https://aka.ms/aks/custom-registry) to learn how you can streamline your container registry configuration experience.

## Proposal

### Native containerd Registry Configuration

Introduce a node-pool level handle for users to pass a YAML configuration to AKS to dictate how they would like their containerd config to be setup as far as registry mirrors go. Once configured, image pulls should be able to be redirected from a specified endpoint to any number of user specified mirrors, with fallbacks in place. 

This approach provides an AKS native experience to manage the containerd registry configuration on each node allowing customers to configure registry mirrors and additional connection settings while abstracting the burden of manually modifying pod manifests and configurations.

**Benefits of this approach**

1. Takes advantage of upstream containerd runtime capabilities 
2. Provides a consistent experience across all cluster operations
3. Supports the widest range of registry types and configuration options
4. Aligns with the standard containerd configuration approach
5. Minimizes complexity and maintenance overhead for customers

**Breaking Changes:**
- No breaking changes to existing clusters, as the new configuration is purely additive.

**Go-to-Market:**
- Position as enterprise readiness and multi-cloud enablement feature
- Target large enterprise customers with existing registry investments or users who simply use to utilize a non-Microsoft container registry

**Pricing:**
- No additional charges for custom registry configuration
- Standard AKS pricing applies for cluster resources
- Prices of a user's own custom registries are out of the scope of consideration, and should be something the user manages themselves

### Validations 

AKS will intake a user provided configuration file and apply it to a node level component. To ensure that no invalid configurations are applied (which can affect the node), AKS should validate the user provided configuration against the [containerd schema](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#registry-configuration---examples), including required fields are present, format is correct, and values passed are expected.

*There is additional validation concerns highlighted below when it comes to taking >1 server per config. That will be highlighted in section **Semantics for supporting >1 server per config***

### Logs

Anything to do with the custom registry is outside Microsoft's scope, and the responsibility of the user to diagnose.

For issues with the containerd runtime, users can parse logs written to the standard `/var/log/pods` that the containerd CRI outputs logs to.

Otherwise,customers can debug issues with by using Azure Monitor to query logs related to the containerd runtime and images pulled for the nodes.

## User Experience

### API 

A subresource will be introduced under agent pools.

`PUT /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{resourceName}/agentPools/{agentPoolName}/customRegistry/{customRegistryConfig}`

Following the established pattern for agent pool sub-resources in the [Azure REST API specification](https://github.com/Azure/azure-rest-api-specs/blob/20fc03c5ce458893e6a2d4c4552d1f4e47c7b292/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/stable/2025-05-01/managedClusters.json#L1055), a proposed API format could look like:

```yaml
{
  "properties": {
    "customRegistryConfig": {
      "customRegistries": [
        {
          "server": "*.quay.io/*",
          "mirrors": [
            {
              "endpoint": "*.dkr.ecr.*.amazonaws.com",
              "capabilities": ["pull", "push", "resolve"]
            },
            {
              "endpoint": "artifactory.*.com/artifactory/*",
              "capabilities": ["pull"]
            }
          ],
          "fallback": "server"
        }
      ],
      "timeout": "10m"
    }
  }
}
```
In the spirit of keeping with the upstream convention, some of the properties retain names that reflect what they're called [upstream](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#registry-configuration---examples).

More details about the fields are below.

### Setting up the user config

The user will be expected to pass a YAML config formatted like so:

```yaml
customRegistries:
  - server: "*.quay.io/*"
    mirrors:
      - endpoint: "*.dkr.ecr.*.amazonaws.com"
        capabilities: ["pull", "resolve", "push"]
      - endpoint: "artifactory.*.com/artifactory/*"
        capabilities: ["pull"]
    fallback: "server"
  timeout: "10m"
```
- **Server** - Serves as the default registry server for a given host namespace, and acts as the authoritative source for image operations unless overridden by mirrors specified underneath. 
- **Mirrors** – The mirrors that containerd will attempt to resolve image pushes from. If multiple mirrors are listed, then containerd will attempt to resolve them in the order they are listed. 
- **Fallback** – The destination that pulls will resolve to if all the listed mirrors fail to resolve. 

**Capabilities**

[Upstream introduces](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#capabilities-field) `pull`, `push`, and `resolve` as capabilities one can give to their endpoints.

- **Pull** - Allows pulling images from the associated endpoint. Used for any registry/mirror from which you want to fetch images.

- **Push** - Allows pushing images to the registry in question. Only give this to registrires where you'd want to push/update images in.

- **Resolve** - Allows converting an image tag (e.g. `latest`) into its immutable digest. This should only be given to registries you trust. It will allow you to accurately map the tags to the digest to pull the exact image with the specified digest.
   - As an example: if you pull an image by `:latest` with the capability resolve, containerd will ask the registry to resolve image tagged with `:latest` to it's actual digest at the moment (e.g. `sha256:abcdef123456`). Containerd will then use that digest to pull the exact image with that digest.

When all fields are defined, pulls will focus on **mirrors** first, then move to **fallback**, and ultimately resolve to **server** if nothing works. 

When multiple mirror endpoints are defined they’d take precedence by list order, then move over to fallback then server.

- As an example, if I specify multiple hosts in the config and give them all **push** capabilities, containerd will consider all those hosts as valid destinations for uploading (pushing) images. However:
   - Containerd will try the endpoints in the order they are listed in the configuration (top down).
   - Containerd will use the first endpoint that is available and accepts the push.
   - If the first endpoint fails, containerd will move to the next one. If they all fail, containerd will move to the fallback, then original server, and finally fail the operation if everything is down.
- This mimics [upstream functionality](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#server-field).

#### Scenarios

**Default**

If someone has their pod YAML setup as follows:

```yaml
apiVersion: v1 
kind: Pod 
metadata: 
... 
spec: 
   containers: 
   -  name: example-container 
      image: myregistry.quay.io/*/ 
```

the config should look like:

```yaml
customRegistries:
  - server: "*.quay.io/*"
    mirrors:
      - endpoint: "*.dkr.ecr.*.amazonaws.com"
        capabilities: ["pull", "resolve", "push"]
      - endpoint: "artifactory.*.com/artifactory/*"
        capabilities: ["pull"]
    fallback: "server"
  timeout: "10m"
```
This will attempt to resolve all image pulls from quay.io/*/ to the mirrors, and resolve to the primary quay registry if both mirrors fail. 

**Multiple registries**

Let's take a scenario where we need to configure for two teams, with sample deployments from each team looking like:

```yaml
# Team 1 usually pulls from JFrog
apiVersion: v1 
kind: Pod 
metadata: 
... 
spec: 
   containers: 
   -  name: JFrog_Artifactory 
      image: artifactory.*.com/artifactory/* 

# Team 2 usually pulls from Quay
apiVersion: v1 
kind: Pod 
metadata: 
... 
spec: 
   containers: 
   -  name: Quay_Registry 
      image: quay.io/*/ 
```

The config should look something like:

```yaml
customRegistries:
  - server: "quay.io/*/"
    mirrors:
      - endpoint: "quay.io/primary_registry/"
        capabilities: ["pull", "resolve", "push"]
      - endpoint: "quay.io/backup_registry/"
        capabilities: ["pull"]
    fallback: "server"
  - server: "artifactory.*.com/artifactory/*"
    mirrors:
      - endpoint: "artifactory.*.com/artifactory/registry_1"
        capabilities: ["pull", "resolve", "push"]
      - endpoint: "artifactory.*.com/artifactory/registry_2"
        capabilities: ["pull"]
    fallback: "artifactory.*.com/artifactory/registry_3"
```

If a team wants to be able to be more flexible on the same registry platform, they can setup their `servers` with different tags to catch pulls from different deployments. 

Let's assume we have a frontend/backend team that both uses JFrog:

```yaml

# frontend teams pull from JFrog, tag their images with frontend
apiVersion: v1 
kind: Pod 
metadata: 
... 
spec: 
   containers: 
   -  name: frontend_dev 
      image: artifactory.*.com/artifactory/frontend 

# backend teams pull from JFrog, tag their images with backend
apiVersion: v1 
kind: Pod 
metadata: 
... 
spec: 
   containers: 
   -  name: backend_dev 
      image: artifactory.*.com/artifactory/backend 
```

the config should be setup like so:

```yaml
customRegistries: 
  - server: “artifactory.*.com/artifactory/frontend” 
    mirrors: 
          # insert frontend mirrors here 
    fallback: 
      “server” 
  - server: “artifactory.*.com/artifactory/backend” 
    mirrors: 
           # insert backend mirrors here 
    fallback: 
      “server” 
```

**Supporting >1 server per config**

Since there is only one `hosts.toml` in a node pool, we are unable to config multiple "customRegistry" objects and have a single server associated to each object. We would need to be able to accept user config for that defines multiple servers, and [configure containerd accordingly](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#setup-a-local-mirror-for-docker)

As far as governing how we accept these configs (e.g. checks/validations in place), there are a few options:
- (preferred) We can document out some best practices (e.g. ensure that your `server`s are populated with unique endpoints) and clarify other capabilities (e.g. okay to have multiple mirror endpoints, containerd tries from top down).
- We can implement some logic that checks the user provided config to ensure that it follows the general [containerd schema](https://github.com/containerd/containerd/blob/0def98e462706286e6eaeff4a90be22fda75e761/docs/hosts.md#setup-a-local-mirror-for-docker).

**Recursion not supported**

Matching with the behavior of containerd upstream, recursion is not supported for specified mirrors. This means that you cannot specify a nested mirror and expect image pulls to resolve correctly to the mirror; each mirror must be a separate, top level definition.  

Let's say I want to have all pulls to `quay.io/*/` get pointed first to `quay.io/primary_registry`, but attempt to go to `primary1` then `primary2`. This will not work.

```yaml
customRegistries:
  - server: "quay.io/*/"
    mirrors:
      - endpoint: "quay.io/primary_registry/"
        capabilities: ["pull", "resolve", "push"]
          - endpoint: "quay.io/primary1_registry/"
            capabilities: ["pull"]
          - endpoint: "quay.io/primary2_registry/"
            capabilities: ["pull"]
    fallback: "server"
```

### Configuration Interface

#### Azure CLI

We can add into the `az aks nodepool` family of commands a few parameters to allow users to configure their custom registries. Generally, it will be a single parameter, accepting the yaml name as input:

`--custom-registries <insert_name>.yaml`

If a user wants to configure custom registries when adding a nodepool, they can do so like so:

```bash
az aks nodepool add \
 --resource-group myRg \
 --name myAKSCluster \
 --custom-registries my-yaml.yaml
```

If a user wants to update the configuration in their existing node pool, they'll do so like:

```bash
az aks nodepool update \
 --resource-group myRg \
 --name myAKSCluster \
 --custom-registries my-yaml.yaml
```

The thought is that there is no need to account for a delete operation; if a user wants to change what registries they will pull from, they can just update the nodepool with a new configuration. A node pool should always require images to be pulled from *somewhere*, and the user can always utilize `az aks nodepool update` to make these new changes.

#### Azure Portal

When adding or updating a node pool in one's AKS cluster, a user should see:

- A section in the AKS cluster configuration option that will present users with an in browser editor, and a pre-filled config for users to fill out themselves. 
- Alternatively, user should have the option to upload a yaml file they setup.

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Increase in the number of images from custom registries in AKS clusters | # of clusters/node pools with an image from a custom registry sitting on it | The running 30 day total is ~48.6 million clusters. The number should increase ~20% in a year and image pull frequency should also improve | High |
| 3   | Reduce support escalations | Number of customer complaints regarding inability to use custom registries | No more complaints (or if ones surface, be able to direct customers to this feature) | High |

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Customers should be able to configure the setup of custom registries in their containerd runtime for their AKS node pools via API, ARM templates, CLI, and Azure portal | High |
| 2   | Take in and be able to validate customer provided configurations for custom registries | High |
| 3   | Image pulls for complex setups (e.g. >1 endpoint) should resolve as they are described on this PRD in the cases of a registry being down or failure to pull the image | High |
| 4   | Customers should be able to setup custom registries at node pool creation time and/or update existing node pools to add or modify credential providers | High  |
| 5   | Customers should have access to an easy UX for cluster wide configuration of their credential provider changes | High |
| 6   | Applied configurations should stay persistent within the node pool through node pool operations (e.g. upgrades) | High |
| 7   | Ensure that the user defined timeout will cancel the operation once the time specified elapses | High |
| 7   | Generic logs for a customer's containerd runtime should be passed to Azure Monitor and accessible by the customer for debugging and auditing purposes | Medium |

## Test Requirements

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Confirm image pulls are successfully routed to customer defined custom registries | High |
| 2   | Validate that the containerd runtime for applied node pools are configured per the provided config | High |
| 3   | Ensure that validation to both the configuration (to ensure that it matches the schema) work and catch cases where the user has provided invalid configuration or binaries before intaking/applying them | High |
| 4   | Ensure that failovers from mirror -> fallback -> server, and from list order for multiple mirrors/servers work as expected (top down) | High |
| 5   | Ensure that customers are able to update their configs via the update command | High |
| 6   | Ensure that capabilities (pull, push, resolve) function as expected | High |
| 7   | Ensure that operations with every endpoint faulty (e.g. all are down) fail and a clear error image is shown | High |
| 8   | Ensure that requests fail properly if the user misconfigures the CLI arguments detailed in the PRD | High | 
| 9   | Ensure that logs are passed to Azure Monitor/persist in the default `/var/log/pods` directory, and can be queried by customers for debugging | Medium |


