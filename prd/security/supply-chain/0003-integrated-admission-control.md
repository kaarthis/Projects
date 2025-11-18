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

Before integrated admission control, AKS customers had to cobble together fragmented solutions across multiple tools and platforms to enforce image signing, verification, vulnerability management, and security configuration policies/ best practices, with no consistent way to manage or protect these controls. Now, AKS customers can enable comprehensive, tamper-proof admission control through the Azure Portal and AKS API that seamlessly integrates Microsoft-owned security services to enforce supply chain security and best practices at the cluster boundary.

**Current State:**

Customers today face significant challenges in implementing robust supply chain security:

1. **Fragmented Workflow**: Image signing verification, vulnerability scanning, security misconfiguration detection, and best practices validation are handled by disparate tools with no unified orchestration
2. **Incomplete First-Party Integration**: Azure's native services—Microsoft Defender for Containers (MDC), Azure Container Registry (ACR), and Image Integrity—lack a cohesive admission control layer to enforce policies at deployment time
3. **No Misconfiguration Prevention**: While MDC identifies security misconfigurations and compliance violations, there is no mechanism to block non-compliant workloads at admission time
4. **Tamper Risk**: Admission controllers deployed directly into clusters can be modified or disabled by cluster administrators or compromised workloads
5. **Inconsistent Policy Enforcement**: No standardized mechanism to ensure vulnerability gates, signature verification, and security best practices are enforced across all clusters in an organization

This fragmentation creates security gaps, operational overhead, and compliance risk, particularly for enterprises with strict supply chain security requirements (e.g., SLSA compliance, Executive Order 14028, CIS Kubernetes Benchmarks).

## Supported Attestation Types

Admission control will validate various attestation types attached to container images. The following attestation standards and formats are in scope:

| Attestation Type | Standard/Format | Purpose | Priority |
|------------------|-----------------|---------|----------|
| **Image Signatures** | [Notary Project](https://github.com/notaryproject) signatures (using Notation tooling), Cosign | Verify image authenticity and publisher identity | P0 |
| **Vulnerability Scan Reports** | SARIF, CycloneDX VEX, OpenVEX | Gate deployments based on CVE severity and exploitability | P0 |
| **SBOM (Software Bill of Materials)** | SPDX, CycloneDX | Validate presence of SBOM and check for prohibited components | P0 |
| **In-Toto Attestations** | in-toto Attestation Framework (ITE-6) | Verify software supply chain provenance and build steps | P0 |
| **SLSA Provenance** | SLSA Provenance (v0.2, v1.0) | Validate build integrity and SLSA level compliance | P0 |
| **Security Configuration Assessment** | MDC Assessment Results (proprietary format) | Validate compliance with CIS Benchmarks, Pod Security Standards | P0 |
| **Lifecycle Metadata** | Azure Container Registry Lifecycle Metadata (proprietary format) | Track image lifecycle state (EOL, deprecated, retired) for vulnerability management | P0 |

## Goals/Non-Goals

### Functional Goals

1. **Unified Admission Control Platform**: Provide Azure Portal as the primary experience and AKS API for enabling, configuring, and managing admission control policies
2. **First-Party Microsoft Service Integration**: 
   - **Azure Container Registry (ACR)**: Deep integration with ACR artifact signing ([Notary Project](https://github.com/notaryproject) signatures using Notation tooling) and Image Integrity for signature verification
   - **Microsoft Defender for Containers (MDC)**: Integrate vulnerability scanning results and security configuration assessments for admission gating
   - **Azure Policy**: Enable organization-wide governance through built-in policy definitions
3. **Comprehensive Security Validation**: 
   - Image signature verification and attestation validation
   - Vulnerability scanning gates (block images with critical/high CVEs)
   - Security misconfiguration detection (CIS Kubernetes Benchmark violations, pod security standards)
   - Security best practices enforcement (privilege escalation, host namespace access, etc.)
4. **Tamper-Proof Architecture**: Ensure admission control configuration and enforcement cannot be bypassed or modified except through the AKS control plane API
5. **Centralized Management**: Support Azure Policy integration for fleet-wide governance and compliance reporting via Azure Portal (Kubernetes Hub)
6. **Extensible API Design**: API architecture deliberately designed to accommodate future third-party scanner and certification provider integrations (out of scope for initial release)

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

1. **Third-Party Security Tool Integration**: Initial release will not include integrations with third-party scanners (Aqua, Prisma Cloud, Twistlock), certification providers, or policy engines (OPA/Gatekeeper, Kyverno). The API will be designed to support these integrations in future releases.
2. **Exception/Exemption Workflow**: Automated workflows for requesting and approving exceptions to vulnerability gates or security configuration policies are out of scope. Customers requiring exemptions must use alternative mechanisms (e.g., image allow-lists at the namespace level).
3. **Runtime Security**: This feature focuses on admission-time controls; runtime detection, response, and behavioral analysis remain in Microsoft Defender for Containers.
4. **Custom Admission Logic/Policy Engine**: Customers requiring fully custom admission logic beyond the provided first-party integrations should use Azure Policy guest configuration or wait for future third-party integrations.
5. **Image Scanning Service**: AKS will not provide its own vulnerability scanner; integration with Microsoft Defender for Containers scanning is in scope.
6. **Certificate and Key Management**: While the feature integrates with signing solutions, certificate lifecycle management (issuance, rotation, revocation) remains the responsibility of Azure Key Vault, Azure Trusted Signing, or customer PKI.
7. **Multi-Cluster Policy Distribution (Initial ReleaLese)**: Fleet-wide policy management via Azure Policy will be addressed in a future iteration; initial release focuses on per-cluster configuration via Portal and API.
8. **SBOM Generation**: Generation of Software Bill of Materials is out of scope; validation of existing SBOM attestations is in scope.

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Security Architect | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/write<br>Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Authorization/policyAssignments/write | As a security architect, I want to design and enforce organization-wide supply chain security policies across all AKS clusters. I should be able to define signing requirements, vulnerability thresholds, and compliance gates centrally using Azure Policy, and receive compliance dashboards showing policy adherence across my fleet. Success: 100% of production clusters enforce signing requirements, vulnerability gates, and compliance policies with zero bypass incidents. |
| Cluster Operator | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/write<br>Microsoft.ContainerService/managedClusters/admissionControl/write<br>Microsoft.ContainerService/managedClusters/admissionControl/read | As a cluster operator, I want to enable and configure admission control for my AKS cluster through the AKS API without deploying any in-cluster resources manually. I should be able to integrate with our existing ACR registries where signatures and attestations are stored (generated during CI/CD) in under 30 minutes. Success: Admission control is active and cannot be disabled by cluster admins; clear audit trail of all configurations. |
| Application Developer | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/listClusterUserCredentials/action | As a developer, I want clear, actionable feedback when my container images are rejected by admission policies. I should receive specific errors indicating whether the issue is missing signatures, failing vulnerability scans, or policy violations, with links to remediation documentation. Success: 90% of admission failures resolved without contacting support. |
| Compliance Officer | Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Authorization/policyAssignments/read<br>Microsoft.Security/assessments/read | As a compliance officer, I want to demonstrate that all production AKS clusters enforce supply chain security policies consistent with our security framework (SLSA L3, NIST 800-190). I should have access to audit reports showing admission decisions and policy compliance over time. Success: Generate compliance reports for auditors with minimal manual effort. |

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
  
4. **Microsoft Defender for Containers Gated Deployment (Preview)**:
  - Leverages MDC vulnerability scanning results to block deployments of vulnerable images
  - **Current Capabilities**: Integrates with CI/CD pipelines to gate deployments based on vulnerability scan results from MDC
  - **Gaps**: 
    - Limited to vulnerability gating only; no signature verification or misconfiguration validation
    - Requires separate configuration from other AKS security controls
    - No integration with Image Integrity for signature verification
    - Limited to MDC scan results; cannot incorporate other attestation types (SBOM, SLSA provenance)
    - Operates independently from AKS lifecycle management
  
5. **AKS Image Integrity (Preview)**: 
  - Validates [Notary Project](https://github.com/notaryproject) signatures for container images (using Notation tooling)
  - **Gaps**: Limited to signature verification only, no vulnerability or policy integration, separate configuration from other security controls, no support for third-party signing solutions
  
6. **Third-Party Solutions (Aqua, Prisma, Twistlock)**: 
  - Rich policy engines with integrated scanning and signing
  - **Gaps**: Require separate licensing, complex installation, no AKS lifecycle integration, can be disabled by cluster admins

**Key Challenge**: Today's solutions are fragmented—vulnerability scanning (MDC), signature verification (Image Integrity), gated deployment (Defender Gated Deployment), and policy enforcement (Azure Policy/Gatekeeper) operate independently with no unified orchestration or tamper-proof enforcement mechanism.

## Relationship to Existing Microsoft Solutions

This admission control feature is designed to **unify and supersede** the fragmented first-party solutions currently available:

### Integration with Defender Gated Deployment

**Current State (Defender Gated Deployment Preview)**:
- Defender for Containers offers a "Gated Deployment" capability that blocks vulnerable images in CI/CD pipelines
- Operates at the pipeline level, not at the Kubernetes admission control level
- Limited to vulnerability scanning; does not validate signatures or security configurations
- Configured separately from AKS cluster settings

**New Unified Approach (This PRD)**:
- **AKS Admission Control becomes the single enforcement point** for all supply chain security policies (signatures, vulnerabilities, misconfigurations)
- **Defender for Containers integration**: AKS Admission Control will consume MDC vulnerability scan results and security assessments via API, enforcing them at cluster admission time
- **Migration Path**: 
  - Customers using Defender Gated Deployment can migrate to AKS Admission Control for enforcement at the cluster boundary
  - Defender Gated Deployment will continue to be supported in CI/CD contexts where early-stage gating is desired
  - **Recommended Architecture**: Use both layers—Defender Gated Deployment for CI/CD shift-left + AKS Admission Control for runtime enforcement
- **Enhanced Capabilities**: Unlike standalone Defender Gated Deployment, the integrated admission control adds:
  - Signature verification from ACR/Image Integrity
  - Security misconfiguration validation (CIS Benchmarks, Pod Security Standards)
  - SBOM and SLSA provenance attestation validation
  - Tamper-proof enforcement (cannot be bypassed by cluster admins)

### Integration with AKS Image Integrity

**Current State (Image Integrity Preview)**:
- AKS Image Integrity validates [Notary Project](https://github.com/notaryproject) signatures on container images (using Notation tooling)
- Configured separately at the cluster level
- Limited to signature verification only

**New Unified Approach (This PRD)**:
- **AKS Admission Control subsumes Image Integrity functionality** as one policy type among many
- Image Integrity's signature verification engine becomes a **policy evaluator** within the admission control platform
- **Migration Path**: 
  - Customers using Image Integrity will migrate their signature policies to the new admission control API
  - Existing Image Integrity configurations will be automatically migrated or deprecated with a transition period
  - **Configuration Consolidation**: Single admission control configuration replaces separate Image Integrity and policy settings

### Integration with Azure Policy for Kubernetes

**Current State (Azure Policy for Kubernetes - GA)**:
- Uses OPA Gatekeeper to enforce deny/audit policies
- Limited to configuration validation; no supply chain security integration

**New Unified Approach (This PRD)**:
- **Azure Policy remains the fleet-wide governance layer**
- **AKS Admission Control becomes the enforcement engine** for supply chain security policies defined in Azure Policy
- **Complementary Relationship**: 
  - Azure Policy: Organization-wide policy definition and compliance reporting
  - AKS Admission Control: Cluster-level enforcement of those policies plus additional supply chain security validations
- **No Migration Required**: Existing Azure Policy assignments continue to work; new built-in policies leverage admission control

### Summary: Unified Platform Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Azure Policy (Fleet Governance)                   │
│              Define policies, compliance reporting, audit             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              AKS Admission Control (Unified Enforcement)             │
│                      (This PRD - New Platform)                        │
├─────────────────────────────────────────────────────────────────────┤
│  Policy Evaluators:                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ Image Integrity  │  │ Defender for     │  │ Configuration    │  │
│  │ (Signatures)     │  │ Containers       │  │ Validation       │  │
│  │                  │  │ (Vulnerabilities)│  │ (Misconfig/Best  │  │
│  │ - Notation       │  │                  │  │  Practices)      │  │
│  │ - Cosign         │  │ - CVE gating     │  │                  │  │
│  │ - SLSA           │  │ - SBOM checks    │  │ - CIS Benchmarks │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

Deprecated/Migrated:
  - Defender Gated Deployment → Migrated to Admission Control
  - Image Integrity (standalone) → Integrated as policy evaluator
  - Azure Policy Gatekeeper (for supply chain) → Remains for non-supply chain policies
```

