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
- **Air-Gapped Environments**: Customers in regulated industries require isolated registries within their network perimeter.

Currently, AKS only provides native authentication integration with Azure Container Registry (ACR). For custom registries, customers must implement workarounds that are complex, insecure, and difficult to maintain:

1. **Manual Secret Management**: Creating and managing Kubernetes secrets with registry credentials, which requires manual rotation and poses security risks.
2. **Node-Level Configuration**: Manually configuring containerd or other components on each node, which is not supported and breaks with node updates. Some customers will not have permissions on NRG lockdown AKS clusters to be able to make these changes.
3. **DaemonSet based configuration**: Deploying a managed DaemonSet to each node in the cluster that installs and configures kubelet credential provider binaries. DaemonSets may fail to deploy correctly and upgrades or node scaling events often break the configuration, leading to unpredictable authentication failures and increased support burden.

These workarounds result in:
- Operational complexity and maintenance burden due to no native and officially supported way for configuring custom credential providers today.
- Poor cluster operator experience compared to an experience like [AKS ACR integration](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration?tabs=azure-cli)
- Reliability issues during credential rotation and cluster management operations such as upgrades and scaling.

## Goals/Non-Goals

### Functional Goals

- Enable native kubelet credential provider configuration for custom container registries
    - Provide the experience/API at the node pool level to facilitate multi-tenancy seeking customers on the same cluster
    - Provide convenience UX for at-scale definition of the custom credential provider if needed for uniform deployment across an entire cluster (a simplification above the node pool level experience)
- Define the experience for user to be able to provide binaries to configure their BYO-crendential providers and how those can be configured with the node pool/cluster
- Enable configuration through ARM templates, CLI, and Azure Portal
- Allow customers that have clusters which meet the specifications to utilize [projected Service Account Tokens](https://github.com/kubernetes/enhancements/blob/master/keps/sig-auth/4412-projected-service-account-tokens-for-kubelet-image-credential-providers/README.md) for their credential provider.

### Non-Functional Goals

- Ensure that configs and binaries the user presents pass validations before intaking them


### Non-Goals

- Does not replace existing ACR integration (ACR remains the recommended registry for Azure workloads)
- Does not modify Kubernetes upstream credential provider specification (we will align with the upstream configuration specs)

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Platform Engineer | Microsoft.ContainerService/managedClusters/*| As a platform engineer managing multi-cloud infrastructure, I want to configure AKS clusters to authenticate with AWS ECR and Google GCR registries using the kubelet credential providers, so my teams can seamlessly pull images without complex workarounds. Success: Ability to seamlessly configure multiple registry credential providers. |
| DevOps Engineer | Microsoft.ContainerService/managedClusters/write | As a DevOps engineer, I want to configure authentication to our enterprise Harbor registry without managing static secrets, so I can ensure secure and reliable image pulls for our applications. Success: AKS native credential provider configuration that handles automatic token refresh. |
| Application Developer | Microsoft.ContainerService/managedClusters/read | As an application developer, I want to deploy applications that use images from various registries without worrying about authentication configuration, so I can focus on application development rather than infrastructure concerns. Success: Transparent image pulling from configured custom registries. |

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
2. **Node Modification**: Manually modifying containerd configuration (unsupported)
3. **DaemonSet Approach**: Deploying a DaemonSet to install and configure credential provider binaries on each node, which is unsupported, fragile during upgrades or scaling, and can lead to inconsistent authentication behavior across the cluster.

## What will the announcement look like?

**Announcing Custom Kubelet Credential Provider Support in Azure Kubernetes Service (AKS)**

We are excited to introduce native support for custom kubelet credential providers in AKS, enabling seamless authentication to any container registry including AWS ECR, Google GCR, Harbor, and other enterprise registries. This feature eliminates the need for complex workarounds and provides the same secure, managed experience that customers enjoy with Azure Container Registry.

Customers on Kubernetes version 1.34+ will be able to further configure and utilize [projected Service Account Tokens](https://github.com/kubernetes/enhancements/blob/master/keps/sig-auth/4412-projected-service-account-tokens-for-kubelet-image-credential-providers/README.md) for their credential provider, allowing them to tie credentials to workload specific service accounts for enhanced security and access controls. 

**Addressing Key Challenges**

This feature addresses a critical gap for enterprise customers who want to or need to pull images from multiple registry sources. Previously, customers had to implement complex workarounds involving manual secret management or third-party solutions. A common workaround has been the DaemonSet-based approach, where customers deploy a DaemonSet to install and configure credential provider binaries on each node. These workarounds are typically unsupported, fragile during cluster upgrades or scaling, and often leads to inconsistent authentication behavior and increased operational overhead.

With native credential provider support, AKS now offers enterprise-grade authentication for any container registry while maintaining the security and reliability standards customers expect from Azure.

**Functionality and Usage**

- **Multi-Registry Support**: Configure authentication for AWS ECR, Google GCR, Harbor, JFrog Artifactory, and other non-Azure registries
- **Familiar Management**: Configure through ARM templates, Azure CLI, and Azure Portal like other Azure resources

**Availability**

The general credential provider feature will be available in all Azure regions where AKS is supported, starting with clusters running an up to date Kubernetes version. 

Customers who want to utilize projected Service Account Tokens for their credential provider will need to be on Kubernetes version 1.34+.

## Proposal 

**Implementation Overview:**

This feature enables customers to configure custom kubelet credential providers on AKS clusters through a three-step process:

1. **Binary Distribution**: Customers provide their credential provider binaries through a bootstrap Azure Container Registry (ACR), similar to how they would setup their clusters in network isolated clusters
2. **Provider Configuration**: Customers specify the kubelet credential provider configuration at the node pool level through AKS APIs
3. **Runtime Integration**: AKS automatically configures kubelet on cluster nodes to use the specified credential providers

**Detailed Implementation:**

**Step 1: Bootstrap ACR for Binary Distribution**
- Customers push their custom credential provider binaries to a designated bootstrap ACR
- Similar to network isolated clusters, AKS pulls these binaries during node provisioning
- Binaries are validated and deployed to the appropriate kubelet credential provider directory
   - Support for versioning and updates are provided through ACR image tags (e.g. `http://myacr.azurecr.io/credprovider:latest`)

**Step 2: Credential Provider Configuration**
- Customers provide a single credential provider configuration following the upstream [Kubernetes specification](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/#configure-a-kubelet-credential-provider)
- Configuration is specified at the agent pool level to enable multi-tenancy scenarios
- AKS validates the configuration against the kubelet credential provider schema before intaking the configuration

**Step 3: Node Pool Level Configuration**
- Credential provider configuration is modeled as a sub-resource under agent pools in the AKS API
- Each agent pool can have up to 3 (we propose to start with three for now) credential provider configuration
   - Multiple credential provider configs per node pool will support scenarios where different node pools need multiple different registry authentication
- Configuration is applied during node provisioning and maintained across upgrades
- Whenever the customer updates the credentialProviders sub-resource with a new binary, a node restart would be required.

**Benefits of above approach:**
- Is in general alignment with Kubernetes upstream specifications
- Leverages familiar bootstrap ACR pattern from network isolated clusters. This way we avoid asking the customers to configure additional egress endpoints for other storage locations.
- Provides granular control at node pool level for multi-tenant scenarios

**Breaking Changes:**
- No breaking changes to existing clusters
- New configuration is purely additive

**Go-to-Market:**
- Position as enterprise readiness and multi-cloud enablement feature
- Target large enterprise customers with existing registry investments

**Pricing:**
- No additional charges for credential provider configuration
- Standard AKS pricing applies for cluster resources

### Validations

AKS will perform the following validations to ensure credential provider functionality:

1. **Configuration Validation**: AKS validates the credential provider configuration against the Kubernetes credential provider schema before applying it to nodes. This includes verifying required fields, format compliance, and supported provider types.

2. **Binary Availability Validation**: AKS validates that the credential provider binary referenced in the `binaryImageTag` field can be successfully pulled from the specified bootstrap ACR. This validation occurs during node provisioning and configuration updates.

The results and any errors from these validations will be surfaced in the status of the `credentialProviders` sub-resource, providing clear feedback to customers about configuration issues or binary availability problems.

### Logs

The kubelet credential provider binary itself (as written by the customer) is the customer's responsibility. Any issues with the binary functionality, performance, or compatibility are outside Microsoft's support scope. 

Customers can debug issues with their credential provider binary by using Azure Monitor to query credential provider logs pulled from the nodes, providing visibility into binary execution and authentication flows.

### Bootstrapping registry and implications

The design choice to leverage a bootstrap Azure Container Registry (ACR) for distributing credential provider binaries follows the established pattern used in [network isolated AKS clusters](https://github.com/Azure/azure-rest-api-specs/blob/ff00d10875362d73dfbfadc1ad7c760486187dca/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/stable/2025-02-01/managedClusters.json#L5134) and provides significant architectural and security benefits:

- **No Additional Egress Requirements**: By reusing the bootstrap ACR pattern, customers don't need to configure additional egress endpoints or firewall rules beyond what's already required for AKS cluster operations
- **Private Endpoint Support**: Customers can configure private endpoints for their bootstrap ACR, ensuring that credential provider binary distribution occurs entirely within their private network perimeter
- **Consistent Network Architecture**: Aligns with existing network isolation patterns that enterprise customers have already implemented for their AKS clusters

This approach ensures that customers can maintain their existing network security posture while enabling custom credential provider functionality, making it suitable for highly regulated environments and air-gapped scenarios.

**Bootstrap container registry are only for cluster bootstrapping and not for user workloads:**

The bootstrap ACR used for distributing credential provider binaries should be dedicated solely to the purpose of holding resources needed for cluster bootstrapping and not used for storing or pulling user workload images. This separation ensures:

- **Clear Permission Boundaries**: The bootstrap ACR requires different access patterns and security policies than registries used for application images
- **Operational Isolation**: Credential provider binary updates and application image deployments operate on different lifecycles and should not interfere with each other
- **Security Best Practices**: Mixing infrastructure binaries with application images in the same registry can complicate security policies and audit trails

Customers should maintain separate registries for their application workloads and use the bootstrap ACR exclusively for credential provider binary distribution.

## User Experience 

### API

**Resource URI - Node Pool Level:**

The credential provider configuration will be accessible as a sub-resource under agent pools:

```
PUT /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{resourceName}/agentPools/{agentPoolName}/credentialProviders/{credentialProviderName}
```

Following the established pattern for agent pool sub-resources in the [Azure REST API specification](https://github.com/Azure/azure-rest-api-specs/blob/ff00d10875362d73dfbfadc1ad7c760486187dca/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/stable/2025-02-01/managedClusters.json#L1055), a proposed API format with example values is below.

```json
{
    "agentPoolProfiles": [
        {
            "name": "nodepool1",
            "credentialProvider": {
                "binaryImageTag": "aws-ecr-provider:v1.0.0",  # Will point to the bootstrap ACR image tag containing the intended credential provider binary.
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
                        # Token attributes are optional and only needed if the user wants to configure the credential provider to use projected service account tokens. 
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
    ]
}
```

#### Utilizing Projected Service Account Tokens

With the release of Kubernetes 1.34, the capability introduced in [KEP-4412](https://github.com/kubernetes/enhancements/blob/master/keps/sig-auth/4412-projected-service-account-tokens-for-kubelet-image-credential-providers/README.md) to allow kubelet credential providers to use projected Service Account Tokens is expected to graduate to stable. This capability will allow a pod to utilize it's own identity (in the form of a service account) to pull images from a custom container registry.

Users will setup this feature through their credential provider configuration. A new field, `tokenAttributes`, will be introduced to allow for the configuration of the projected Service Account Token attributes. 

```bash
# Example credential provider configuration with projected Service Account Token attributes
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: acr-credential-provider
    ... 
    tokenAttributes:
      serviceAccountTokenAudience: my-audience
      requireServiceAccount: true
      requiredServiceAccountAnnotationKeys:
      - domain.io/identity-id
      - domain.io/identity-type
      optionalServiceAccountAnnotationKeys:
      - domain.io/some-optional-annotation
      - domain.io/annotation-that-does-not-exist
```

- `serviceAccountTokenAudience`: (Required) Specifies the audience for the token when making requests to the registry
- `requireServiceAccount`: (Optional, defaults to false) When true, only pods with a service account will use this provider
- `requiredServiceAccountAnnotationKeys`: (Optional) List of annotation keys that must be present on the pod's service account for the provider to be used
- `optionalServiceAccountAnnotationKeys`: (Optional) Additional annotation keys that will be included in the token if present on the service account

For more details on these fields and their usage, please refer to the [KEP-4412 documentation](https://github.com/kubernetes/enhancements/blob/master/keps/sig-auth/4412-projected-service-account-tokens-for-kubelet-image-credential-providers/README.md#design-details).

Please note that this will also require users to [set up Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/), and if they intend to utilize it, have the proper annotations for their Service Accounts.

#### Setting up the config

As the cred provider will be based off the user passed custom credential provider config, how they set up their custom credential provider will dicate how the credential provider is ultimately configured. 

A user should follow the [upstream guidance](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/#configure-a-kubelet-credential-provider) to set up their credential provider config, and refer to the previous section for the portion related to Service Account Tokens.

Some general points that should be noted:

- When a user user can configure multiple credential providers (with our upper limit being 3) if they have the need. The configuration may look something like:
``` bash
apiVersion: kubelet.config.k8s.io/v1 
kind: CredentialProviderConfig 
providers: 
  - name: acr-credential-provider # credential provider 1
    matchImages: 
      - "*.azurecr.io/*" 
    defaultCacheDuration: "10m" 
 ... 
      optionalServiceAccountAnnotationKeys: 
      - domain.io/some-optional-annotation 
      - domain.io/annotation-that-does-not-exist 
  - name: eks-credential-provider # credential provider 2
    matchImages: 
      - "*.dkr.ecr.*.amazonaws.com/*" 
    defaultCacheDuration: "1m" 
 ... 
      optionalServiceAccountAnnotationKeys: 
      - domain.io/some-optional-annotation 
      - domain.io/annotation-that-does-not-exist 
```
- There is no upper limit on the domains one can include in each credential provider's `matchImages`.
- For all domains within each credential provider's `matchImages`, any image pulls in one's pod YAML that corresponds to the specified domain will be routed to utilize that credential provider.

### CLI Experience

AKS will extend the Azure AKS CLI to support the configuration of credential providers at both node pool and optionally, the cluster level.

#### Node Pool Level Configuration

**Creating a node pool**

Customers that create a new AKS node pool can specify the credential provider configuration using the `az aks nodepool create` command, and add in the `--credential-provider-name`, `--credential-provider-binary-image-tag`, and `--credential-provider-config-file` parameters to set up their credential provider:

```bash
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool \
    --node-count 3 \
    --credential-provider-name aws-ecr \
    --credential-provider-binary-image-tag "aws-ecr-provider:v1.0.0" \
    --credential-provider-config-file ./aws-ecr-config.json
```

**Updating an existing node pool**

Customers can update an existing AKS node pool to add or modify the credential provider configuration using the `az aks nodepool update` command:

```bash
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool \
    --credential-provider-name aws-ecr \
    --credential-provider-binary-image-tag "aws-ecr-provider:v1.0.0" \
    --credential-provider-config-file ./aws-ecr-config.json
```
*Recall that updating the credential provider at any time will require a node pool restart*

#### Cluster Level Commands

For customers who want to apply the same credential provider configuration across all node pools within a cluster, AKS will provide commands to set the credential provider at the cluster level. This is particularly useful for uniform deployments across an entire cluster.

```bash
# Apply credential provider to all node pools
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --set-credential-provider-for-all-nodepools \
    --credential-provider-name aws-ecr \
    --credential-provider-binary-image-tag "aws-ecr-provider:v1.0.0" \
    --credential-provider-config-file ./aws-ecr-config.json
```

### Portal Experience

- **Cluster Configuration Blade**: New section for "Container Registry Authentication"
- **Credential Provider Setup Wizard**: Step-by-step configuration for setting up one's custom credential provider
- **Azure Monitor Logs**: Users should be able to pull logs related to credential provider authentication events for troubleshooting


# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Adoption of custom credential providers | % of customers using native credential providers vs existing workloads | 50% adoption for customers using non-ACR registries within 12 months | High |
| 2   | Improve enterprise customer satisfaction | Customer satisfaction scores for multi-registry scenarios | Increase by 40% | High |
| 3   | Reduce support escalations | Number of support cases related to registry authentication | Reduce by 70% | High |

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Customers should be able to configure custom kubelet credential providers for their AKS node pools via API, ARM templates, CLI, and Azure Portal | High |
| 2   | Be able to accept, validate, and apply (or fail) configuration/binaries passed by the customer to set up their custom credential providers | High |
| 3   | Support up to three credential providers per node pool | High |
| 4   | Customers should be able to define their credential providers at node pool creation time and/or update existing node pools to add or modify credential providers | High  |
| 5   | Customers should be able to easily choose to propagate their changes for a specific node pool to all node pools in their cluster | High |
| 6   | Customers should be able to pass their credential provider binaries through a bootstrap Azure Container Registry (ACR), and AKS should be able to pull those binaries from the bootstrap ACR | High |
| 7   | Generic logs for Azure Credential Provider should be passed to Azure Monitor and accessible by the customer for debugging and auditing purposes | Medium |

## Test Requirements

| No. | Requirement | Priority  |
|-----|-----------------------------------------------|----------|
| 1   | Confirm authentication and successful image pulls from various custom container registries using kubelet credential providers | High |
| 2   | Validate that credential provider configuration is correctly applied during node pool creation and updates | High |
| 3   | Ensure that validation to both the configuration (to ensure that it matches the schema) and the user provided binaries (to ensure they can be pulled successfully from the bootstrap ACR) work and catch cases where the user has provided invalid configuration or binaries before intaking/applying them | High |
| 4   | Ensure that cluster level credential provider configuration propagates correctly to all node pools in a cluster | High |
| 5   | Ensure that credential provider binaries can be successfully pulled from the bootstrap ACR| High |
| 6   | Test that multiple credential providers can be configured per node pool and that they function correctly | High |
| 7   | Verify that projected Service Account Tokens can be used with credential providers for service account scoped auth/n | Medium |
| 8   | Ensure that logs are passed to Azure Monitor and can be queried by customers for debugging | Medium |

# Dependencies and risks 

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|---------|---------|
| 1   | Upstream KEP-4412 in Kubernetes 1.34 for projected Service Account Tokens | Upstream |
| 2   | Portal UX design and implementation | AKS Portal Team |
| 3   | Azure Monitor integration for credential provider logs | Azure Monitor Team |

# Compete 

## AWS EKS

AWS EKS offers several mechanisms for container registry authentication:

- **Manual Secret Management**: For non-ECR registries, EKS users can opt for manual creation and management of Kubernetes `imagePullSecrets` in pod specifications.

- **[Private Certificate Authority](https://aws.amazon.com/blogs/containers/use-private-certificates-to-enable-a-container-repository-in-amazon-eks/)**: Users can configure their EKS ndooes to use a custom container registry via private certificates installed onto the nodes to securely connect to a container image repo and pull images.

## Google GKE

Users of GKE can also utilize imagePullSecrets in their pod specs to authenticate to custom container registries.

Alternatively, users can take advantage of GKE's ability to [configure containerd](https://cloud.google.com/kubernetes-engine/docs/how-to/customize-containerd-configuration) via a user provided YAML to authenticate to custom registries via a certificate stored in Google Secret Manager.


## Other Managed Kubernetes Services

**CloudSmith**

CloudSmith has already setup and [provided a configuration](https://github.com/cloudsmith-io/cloudsmith-kubernetes-credential-provider) that will allow users to pull images from CloudSmith using a custom kubelet credential provider scoped to CloudSmith registries. 
- Their demo (although still in early stages) does require users to manually go through configs to set everything up.

**Competitive Advantage:**
By providing native, multi-provider credential support, AKS will offer the most comprehensive and enterprise-ready container registry authentication solution in the managed Kubernetes market, supporting true multi-cloud and hybrid scenarios.
