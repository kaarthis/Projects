---
title: OIDC Issuer Enabled by Default for AKS Clusters
wiki: ""
pm-owners: [shasb]
feature-leads: [shasb, huishao]
authors: [shasb]
stakeholders: [weinongw, mok, anramase, benpetersen]
approved-by: [] 
---

# Overview 

## Problem Statement / Motivation  

Currently, AKS customers who want to use workload identity (the recommended approach for secure, keyless authentication between Kubernetes workloads and Azure services) must manually enable the OIDC issuer feature when creating or updating their clusters.

This manual enablement also creates friction for AKS addons and extensions that wish to leverage workload identity, as they cannot assume the OIDC issuer is available by default. Relying on the Instance Metadata Service (IMDS) as a fallback for authentication is not secure. IMDS exposes credentials at the node level, which means any pod running on the node could potentially access these credentials if not properly isolated. This increases the risk of credential leakage and lateral movement within the cluster. In contrast, OIDC issuer-based workload identity provides pod-level identity and scoping, significantly reducing the attack surface and aligning with zero-trust security principles.
Examples of addons/extensions/features that require explicit OIDC issuer enablement today:
- Azure Key Vault Secrets Provider ([docs](https://learn.microsoft.com/azure/aks/csi-secrets-store-identity-access#enable-oidc-issuer))
- KAITO Addon for Azure Kubernetes Service ([docs](https://learn.microsoft.com/azure/aks/ai-toolchain-operator#create-an-aks-cluster-with-the-ai-toolchain-operator-add-on-enabled))


## Goals/Non-Goals

### Functional Goals

- Enable OIDC issuer by default on all AKS clusters without any option to opt-out
- Capture migration plan for existing clusters which don't have OIDC issuer on

### Non-Goals

- Any changes to the opt-in behavior of the optional workload identity [webhook](https://github.com/Azure/azure-rest-api-specs/blob/65e7f567edbbe60f14573dae9e162d1b164ebde5/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/stable/2025-02-01/managedClusters.json#L6964)

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Cluster Administrator | Microsoft.ContainerService/managedClusters/* | As a cluster administrator, I want new AKS clusters all AKS features/addons/extensions to be pre-configured with the most secure authentication flow without requiring me to explicitly opt-in and configure things on the cluster |

## Customers and Business Impact 

Business impact:
- Enables 100% of addons/extensions to move to workload identity based Entra authentication.
- Is in alignment with [Security objective](https://dev.azure.com/msazure/CloudNativeCompute/_workitems/edit/31629181) and more specifically the key result of [100% of AKS clusters requiring access to Azure workloads are using workload identity](https://dev.azure.com/msazure/CloudNativeCompute/_workitems/edit/10929677)

## Existing Solutions or Expectations 

Currently, customers must:
1. Create an AKS cluster
2. Separately enable OIDC issuer using `az aks update --enable-oidc-issuer`
3. Use workload identity for authentication.

Customer expectations:
- Seamless integration with Azure services
- Default security best practices
- Minimal configuration overhead
- Consistent behavior across all new clusters

## What will the announcement look like?

**Announcing OIDC Issuer Enabled by Default for Azure Kubernetes Service (AKS)**

We are thrilled to introduce OIDC issuer enabled by default, a new enhancement designed to streamline secure authentication between your Kubernetes workloads and Azure services. With this change, all new AKS clusters will automatically have OIDC issuer enabled, making it easier than ever to implement workload identity for keyless authentication.

**Addressing Key Challenges**

Previously, customers had to manually enable OIDC issuer as an additional step after cluster creation, which created friction in the onboarding process and sometimes led to delays in implementing proper security practices. This change eliminates that friction by making OIDC issuer available immediately on new clusters.

With OIDC issuer enabled by default, all AKS features, addons, and extensions can seamlessly use workload identity out of the box, eliminating reliance on IMDS-based authentication and significantly improving security by providing pod-level identity and reducing the risk of credential exposure.

IMDS-based authentication, while convenient, presents several security drawbacks. IMDS exposes managed identity credentials at the node level, meaning any pod running on the node—regardless of its intended permissions—can potentially access these credentials if network policies or pod isolation are not strictly enforced. This broad exposure increases the risk of lateral movement and credential leakage within the cluster. Attackers who compromise a single pod could gain access to credentials intended for other workloads, violating the principle of least privilege. In contrast, OIDC-based workload identity issues tokens scoped to individual pods, ensuring that only the intended workload can access specific Azure resources, thereby aligning with zero-trust security principles and minimizing the attack surface.

**Functionality and Usage**

All new AKS clusters will automatically have OIDC issuer enabled, allowing you to:
- Immediately configure workload identity for secure service-to-service authentication
- All AKS features, addons, extensions that require Entra authentication now use workload identity
- Leverage Azure's recommended zero-trust authentication patterns from day one
- Reduce the time and complexity of setting up secure authentication

**Availability**

This change will be available in all Azure regions where AKS is supported, starting with AKS version 1.35 and later. Existing clusters will be automatically migrated to have OIDC issuer enabled by default when they upgrade to Kubernetes version 1.35 or higher.

By enabling OIDC issuer by default, 100% of AKS addons, features, and extensions can seamlessly adopt workload identity for authentication. This ensures consistent, secure, and keyless access to Azure resources across all workloads, eliminating the need for less secure alternatives and manual configuration. As a result, customers benefit from improved security posture, reduced operational overhead, and a unified authentication experience for all AKS-integrated solutions.

## Proposal 
### Option 1: Enable OIDC issuer by default with no opt-out (Recommended)
**Pros:**
- Ensures all clusters are secured by default
- Eliminates configuration friction for customers with respect to workload identity usage in addons, extensions, features, and customer's own workloads.
- Simplifies documentation, support, and compliance

**Cons:**
- Removes flexibility for customers who may not need OIDC issuer. While the issuer URL is a publicly accessible endpoint, we should note that it doesn't expose any customer data and that it only makes available the discovery documents for this issuer.

### Option 2: Enable OIDC issuer by default with opt-out
**Pros:**
- Provides a secure default while allowing flexibility for customers with specific needs
- Reduces support burden and aligns with industry trends
- Maintains a consistent onboarding experience for most users

**Cons:**
- Slightly increases complexity in cluster creation options
- Some customers may inadvertently opt out and miss security benefits

**Recommended Option:** Option 1 - Enable OIDC issuer by default with no opt-out. Rationale - Fewer permutations on user experience, in alignemnt with security, and avoids the risk of customer unknowingly opting out without understanding the implications on authentication.

**Breaking Changes:** 

- Customers who have built automation, integrations, or policies that depend on the value of the `iss` (issuer) field in Kubernetes service account tokens may experience breaking changes, as this value will change when the OIDC issuer is enabled on the cluster.

**Go-to-Market:** Position as a security and usability improvement that aligns with Microsoft's zero-trust recommendations.

**Pricing:** No changes to pricing model.

## User Experience 

### API

Updates to the AKS API specification:
- The `managedCluster` resource will always have the `oidcIssuerProfile` enabled by default for all new clusters, so the enabled field can be removed; there is no opt-out.
- The `oidcIssuerProfile` object will include an `issuerURL` field to allow customers to discover the OIDC issuer endpoint.

```json
{
  "oidcIssuerProfile": {
    "issuerURL": "https://oidc.prod-aks.azure.com/..."
  }
}
```

### CLI Experience

Updates to Azure CLI:
- `az aks create` will enable OIDC issuer by default
- Update help text to reflect the new default behavior

Example:
```bash
# Creates cluster with OIDC issuer enabled by default
az aks create --resource-group myRG --name myCluster
```

### Portal Experience

Updates to Azure Portal:
- Clear indication that OIDC issuer is enabled by default
- Tooltip explaining the benefits of workload identity

### Policy Experience

New built-in policy definitions:
- "AKS clusters should have OIDC issuer enabled" - Audit policy to ensure compliance
- "Require OIDC issuer on AKS clusters" - Enforcement policy for strict environments

Policy initiative updates:
- Add OIDC issuer requirement to existing AKS security initiatives
- Include in recommended security baselines for AKS

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Improved customer onboarding experience | Reduction in time from cluster creation to workload identity configuration | 50% reduction in average time | High |
| 2   | Reduced support burden | Decrease in support tickets related to workload identity setup | 30% reduction in related tickets | High |
| 3   | Increased workload identity adoption | Percentage of new clusters using workload identity within 30 days | 60% adoption rate | Medium |
| 4   | Better security posture | Reduction in clusters using service principal authentication | 40% reduction in SP usage | Medium |
| 5   | Consistent cluster behavior | Percentage of new clusters with OIDC issuer enabled | 95% (accounting for opt-outs) | High |

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   | Enable OIDC issuer by default on all new AKS clusters | High |
| 2   | Provide opt-out mechanism for customers who don't need OIDC issuer | High |
| 3   | Maintain backward compatibility for existing clusters | High |
| 4   | Support all AKS cluster configurations (public, private, etc.) | High |
| 5   | Update documentation and quickstart guides | Medium |
| 6   | Provide clear telemetry for OIDC issuer usage patterns | Medium |

## Test Requirements 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   | Automated tests for default OIDC issuer enablement | High |
| 2   | Tests for opt-out functionality | High |
| 3   | Backward compatibility tests for existing clusters | High |
| 4   | Performance tests to ensure no degradation in cluster creation time | Medium |
| 5   | Integration tests with workload identity scenarios | Medium |
| 6   | End-to-end tests covering all supported cluster configurations | Medium |

# Dependencies and risks 

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|---------|---------|
| 1   | OIDC issuer service availability and scalability | AKS Control Plane Team |
| 2   | Updated Azure CLI and PowerShell modules | Azure CLI Team |
| 3   | Portal UI updates for cluster creation flow | AKS Portal Team |
| 4   | Documentation updates across all channels | AKS Documentation Team |
| 5   | Policy definitions and initiatives | Azure Policy Team |
| 6   | Telemetry and monitoring infrastructure | AKS Telemetry Team |

**Risks:**
- Potential performance impact on cluster creation (Low risk - OIDC issuer enablement is lightweight)
- Customer confusion about new default behavior (Medium risk - mitigated by clear documentation)
- Increased load on OIDC issuer service (Low risk - service designed for scale)

# Compete 

## GKE 

Google Kubernetes Engine (GKE) offers Workload Identity as a feature that must be explicitly enabled during cluster creation or update. They require customers to:
1. Enable Workload Identity on the cluster
2. Configure node pools with Workload Identity enabled
3. Set up service account bindings

GKE does not enable this by default, requiring explicit customer action.

## EKS

Amazon Elastic Kubernetes Service (EKS) provides IAM roles for service accounts (IRSA) which offers similar functionality to workload identity. However:
1. IRSA requires explicit setup and configuration
2. Customers must create and associate IAM roles
3. No default enablement of the underlying infrastructure

EKS does not enable IRSA-related features by default, requiring manual configuration.

**Competitive Advantage:** By enabling OIDC issuer by default, AKS will provide a superior out-of-the-box experience for secure workload authentication compared to both GKE and EKS, reducing friction and improving security posture from day one.
