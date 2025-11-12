---
title: Integrated Admission Control for AKS Supply Chain Security
wiki: ""
pm-owners: []
feature-leads: []
authors: []
stakeholders: []
approved-by: [] 
---

# Overview 

## Problem Statement / Motivation  

Before integrated admission control, AKS customers had to cobble together fragmented solutions across multiple tools and platforms to enforce image signing, verification, and vulnerability management policies, with no consistent way to manage or protect these controls. Now, AKS customers can enable comprehensive, tamper-proof admission control through a single AKS API that seamlessly integrates first-party and third-party security solutions to enforce supply chain security policies at the cluster boundary.

**Current State:**

Customers today face significant challenges in implementing robust supply chain security:

1. **Fragmented Workflow**: Image signing, verification, and vulnerability management are handled by disparate tools with no unified orchestration
2. **Incomplete First-Party Capabilities**: Azure's native signing and verification solutions lack comprehensive coverage for enterprise scenarios
3. **Third-Party Integration Gaps**: Popular solutions like Twistlock (Palo Alto), Prisma Cloud, and Aqua Security require complex, manual integration with AKS clusters
4. **Tamper Risk**: Admission controllers deployed directly into clusters can be modified or disabled by cluster administrators or compromised workloads
5. **Inconsistent Policy Enforcement**: No standardized mechanism to ensure policies are enforced across all clusters in an organization

This fragmentation creates security gaps, operational overhead, and compliance risk, particularly for enterprises with strict supply chain security requirements (e.g., SLSA compliance, Executive Order 14028).

## Goals/Non-Goals

### Functional Goals

1. **Unified Admission Control Platform**: Provide a single AKS API surface for enabling, configuring, and managing admission control policies
2. **First-Party Integration**: Deeply integrate Azure Container Registry signing,  image integrity verification capabilities (Notation/Notary v2 signatures), Azure Defender for Containers vulnerability scanning, and Azure Policy
3. **Third-Party Ecosystem Support**: Enable seamless integration with leading third-party admission controllers (Twistlock, Prisma Cloud, Aqua, OPA/Gatekeeper, Kyverno)
4. **Tamper-Proof Architecture**: Ensure admission control configuration and enforcement cannot be bypassed or modified except through the AKS control plane API
5. **Centralized Management**: Support Azure Policy integration for organization-wide governance and compliance reporting
6. **Comprehensive Policy Coverage**: Support image signing verification, vulnerability scanning gates, SBOM validation, and custom policy enforcement

### Non-Functional Goals

1. **Performance**: Admission control decisions must complete within 500ms for p95 to avoid impacting pod startup times
2. **Reliability**: 99.9% availability SLA for admission control service with graceful degradation
3. **Security**: 
   - Admission control infrastructure isolated from tenant workloads
   - Encryption of policy configurations at rest and in transit
   - Audit logging of all admission decisions
4. **Compliance**: Support for SOC 2, ISO 27001, FedRAMP, and SLSA compliance requirements
5. **Telemetry**: 
   - Metrics on admission decisions (allowed/denied/errors)
   - Policy effectiveness analytics
   - Performance monitoring dashboards
6. **Supportability**: 
   - Diagnostic tooling for troubleshooting policy rejections
   - Clear error messages indicating specific policy failures
   - Customer-accessible admission decision logs

### Non-Goals

1. **Runtime Security**: This feature focuses on admission-time controls; runtime detection and response remain in Defender for Containers
2. **Custom Admission Logic**: Customers requiring fully custom admission logic should use OPA/Gatekeeper or Kyverno integrations; this is not a general-purpose policy engine
3. **Image Scanning**: AKS will not provide its own vulnerability scanner; integration with existing scanners (Azure Defender, third-party) is in scope
4. **Certificate Management**: While the feature will integrate with signing solutions, certificate lifecycle management remains the responsibility of Azure Key Vault or third-party PKI
5. **Multi-Cluster Policy Distribution**: Initial release focuses on per-cluster configuration; fleet-wide policy management via Azure Policy will be addressed in future iterations

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Security Architect | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/write<br>Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Authorization/policyAssignments/write | As a security architect, I want to design and enforce organization-wide supply chain security policies across all AKS clusters. I should be able to define signing requirements, vulnerability thresholds, and compliance gates centrally using Azure Policy, and receive compliance dashboards showing policy adherence across my fleet. Success: 100% of production clusters enforce signed image requirements with zero bypass incidents. |
| Cluster Operator | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/write<br>Microsoft.ContainerService/managedClusters/admissionControl/write<br>Microsoft.ContainerService/managedClusters/admissionControl/read | As a cluster operator, I want to enable and configure admission control for my AKS cluster through the AKS API without deploying any in-cluster resources manually. I should be able to integrate with our existing Prisma Cloud deployment and ACR signing infrastructure in under 30 minutes. Success: Admission control is active and cannot be disabled by cluster admins; clear audit trail of all configurations. |
| Application Developer | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/listClusterUserCredentials/action | As a developer, I want clear, actionable feedback when my container images are rejected by admission policies. I should receive specific errors indicating whether the issue is missing signatures, failing vulnerability scans, or policy violations, with links to remediation documentation. Success: 90% of admission failures resolved without contacting support. |
| Compliance Officer | Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Authorization/policyAssignments/read<br>Microsoft.Security/assessments/read | As a compliance officer, I want to demonstrate that all production AKS clusters enforce supply chain security policies consistent with our security framework (SLSA L3, NIST 800-190). I should have access to audit reports showing admission decisions and policy compliance over time. Success: Generate compliance reports for auditors in under 1 hour. |
| Third-Party ISV (e.g., Aqua Security) | N/A (integration partner) | As a security vendor, I want to integrate my admission controller with AKS through a well-documented partner API that allows AKS customers to enable my solution via the AKS control plane. I should receive webhook callbacks for admission decisions and be able to provide rich policy metadata. Success: Customers can enable our solution in 3 clicks with no YAML editing. |

## Customers and Business Impact 

**Target Customers:**

- **Regulated Industries**: Financial services, healthcare, and government organizations with strict supply chain security and compliance requirements (SLSA, FedRAMP, SOC 2)
- **Large Enterprises**: Organizations managing 50+ AKS clusters that require centralized policy enforcement and governance
- **Security-Conscious ISVs**: Software vendors building on AKS who need to demonstrate supply chain security to their customers

**Customer Impact:**

Customers face significant operational overhead and security risk managing fragmented admission control solutions. This feature eliminates manual deployment complexity, prevents policy tampering, and provides a unified platform for enforcing supply chain security across their AKS fleet. Organizations can achieve compliance requirements faster, reduce security incidents from unverified or vulnerable images, and gain centralized visibility into policy enforcement across all clusters.

**Business Impact:**

- **Revenue Protection**: Prevent churn of enterprise customers struggling with admission control complexity
- **Revenue Growth**: Enable net-new sales in regulated industries where supply chain security is a gating requirement
- **Azure Consumption**: Drive increased ACR Premium usage (signing features), Defender for Containers adoption, and Azure Policy consumption
- **OKR Alignment**: 
  - **FY25 Q3 Security OKR**: Increase % of AKS clusters with supply chain security controls
  - **FY25 Q4 Compliance OKR**: Support FedRAMP High authorization requirements for AKS

## Existing Solutions or Expectations 

**Current Customer Approaches:**

1. **Self-Managed OPA/Gatekeeper**: 
  - Customers deploy Gatekeeper via Helm and write Rego policies
  - **Gaps**: Steep learning curve, no integration with Azure services, vulnerable to tampering, complex lifecycle management
  
2. **Azure Policy for Kubernetes**: 
  - Uses Gatekeeper under the hood for policy enforcement
  - **Gaps**: Limited to deny-based policies, no image signing verification, no vulnerability scanning integration
  
3. **Microsoft Defender for Containers (MDC)**: 
  - Provides vulnerability scanning and runtime threat detection
  - **Gaps**: Not designed for admission control, no real-time blocking at deployment time, requires manual policy translation, limited signature verification integration
  
4. **AKS Image Integrity (Preview)**: 
  - Validates Notation/Notary v2 signatures for container images
  - **Gaps**: Limited to signature verification only, no vulnerability or policy integration, separate configuration from other security controls, no support for third-party signing solutions
  
5. **Third-Party Solutions (Aqua, Prisma, Twistlock)**: 
  - Rich policy engines with integrated scanning and signing
  - **Gaps**: Require separate licensing, complex installation, no AKS lifecycle integration, can be disabled by cluster admins

**Key Challenge**: Today's solutions are fragmented—vulnerability scanning (MDC), signature verification (Image Integrity), and policy enforcement (Azure Policy/Gatekeeper) operate independently with no unified orchestration or tamper-proof enforcement mechanism.

**Competitive Landscape:**

- **AWS EKS**: EKS Pod Identity Webhook + integration with AWS Signer, ECR scanning, and partner solutions through AWS Marketplace
- **GKE**: Binary Authorization (built-in signing verification), GKE Policy Controller (managed OPA), Container Analysis API integration
- **Customer Expectations**: 
  - **Managed Service**: Customers expect AKS to manage the admission control infrastructure (no manual deployments)
  - **Tamper-Proof**: Control plane enforcement that cluster admins cannot bypass
  - **Ecosystem Compatibility**: Work with existing tools (ACR, Defender, third-party vendors)
  - **Zero-Trust Architecture**: Deny-by-default with explicit allow policies
