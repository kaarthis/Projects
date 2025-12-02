---
title: Integrated Admission Control for AKS Supply Chain Security
wiki: ""
pm-owners: [kaarthis, shashank]
feature-leads: []
authors: [kaarthis]
stakeholders: [Toddy, Yi, Maya, Weinong]
approved-by: [] 
---

# Overview 

## Problem Statement / Motivation  

Before integrated admission control, AKS customers had to cobble together fragmented solutions across multiple tools and platforms to enforce image signing, verification, vulnerability management, and security configuration policies/best practices, with no consistent way to manage or protect these controls. Now, AKS customers can enable comprehensive, tamper-proof admission control **directly from the Azure Portal's Kubernetes Hub experience**, seamlessly integrating Microsoft-owned security services (ACR, Defender for Containers, Image Integrity) to enforce supply chain security and best practices at the cluster boundary—all through a unified, visual interface with no YAML or CLI required.

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

1. **Portal-First with API-Flexible Architecture**: 
   - **Primary Experience**: Azure Portal's Kubernetes Hub is the central, recommended interface for configuring and managing admission control with unified visibility across all first-party security integrations (ACR, Defender, Image Integrity)
   - **API for Automation**: AKS API support for Infrastructure-as-Code and automation workflows (ARM templates, Bicep, Terraform) for customers requiring declarative infrastructure
   - **Centralized Visibility**: Real-time admission control status, policy compliance dashboards, and decision audit logs across all clusters in Kubernetes Hub

2. **First-Party Microsoft Service Integration**: 
   - **Azure Container Registry (ACR)**: Deep integration with ACR artifact signing ([Notary Project](https://github.com/notaryproject) signatures using Notation tooling) and Image Integrity for signature verification
   - **Microsoft Defender for Containers (MDC)**: Integrate vulnerability scanning results and security configuration assessments for admission gating
   - **Azure Policy**: Enable organization-wide governance through built-in policy definitions

3. **Comprehensive Security Validation**: 
   - Image signature verification and attestation validation (Notary, SLSA, in-toto)
   - Vulnerability scanning gates (block images with critical/high CVEs)
   - Security misconfiguration detection (CIS Kubernetes Benchmark violations, Pod Security Standards)
   - Security best practices enforcement (privilege escalation, host namespace access, etc.)

4. **Tamper-Proof Architecture**: Ensure admission control configuration and enforcement cannot be bypassed or modified except through the AKS control plane API

5. **Extensible API Design**: API architecture deliberately designed to accommodate future third-party scanner and certification provider integrations (out of scope for initial release)

### Non-Functional Goals

1. **Performance**: Admission control decisions must complete within 500ms for p95 to avoid impacting pod startup times
2. **Reliability**: 99.9% availability SLA for admission control service with graceful degradation
3. **Security**: 
   - Admission control infrastructure isolated from tenant workloads
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

1. **Third-Party Integrations** (v1): Integrations with third-party scanners (Aqua, Prisma, Twistlock), policy engines (OPA, Kyverno), or certification providers are future roadmap items; API designed for extensibility.
2. **Exception Workflows**: Automated approval workflows for policy exemptions are out of scope; 
3. **Custom Admission Logic**: Fully custom policies beyond provided first-party rules require Azure Policy guest configuration or future third-party integrations.
4. **Infrastructure Responsibilities**: Certificate lifecycle (issuance, rotation, revocation), image scanning service (uses MDC), and SBOM generation are out of scope.
5. **Runtime Security**: Runtime threat detection and behavioral analysis remain in Microsoft Defender for Containers; this feature controls admission only.

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Security Architect | Microsoft.ContainerService/managedClusters/read/write<br>Microsoft.Authorization/policyDefinitions/read/write | Design organization-wide supply chain policies in **Azure Portal's Kubernetes Hub**. Select signing requirements, vulnerability thresholds, and compliance gates via visual interface; apply across fleet via Azure Policy. **Success**: 100% production clusters with enforced policies, zero bypass incidents, compliance dashboards visible in Portal. |
| Cluster Operator | Microsoft.ContainerService/managedClusters/read/write<br>Microsoft.ContainerService/admissionControl/read/write | Enable and configure admission control via **Azure Portal** (no YAML/kubectl). Select ACR registries for signature verification and MDC for vulnerability scanning through dropdowns. **Success**: Full configuration <15 minutes; enforcement active and tamper-proof. |
| Application Developer | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/listClusterUserCredentials/action | Receive clear admission failure feedback with specific errors in **Portal's activity log**. View missing signatures, CVE details, or policy violations with remediation links. **Success**: Resolve 90% of rejections without support. |
| Compliance Officer | Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Security/assessments/read | Access pre-built compliance dashboards in **Kubernetes Hub** showing admission control coverage, policy compliance trends, and audit logs. **Success**: Generate auditor reports in <15 minutes entirely from Portal. |

## Customers and Business Impact 

**Target Customers & Value Delivered**:

- **Regulated Industries** (Finance, Healthcare, Government): Achieve SLSA/FedRAMP compliance faster with tamper-proof, Portal-managed admission control
- **Large Enterprises** (50+ AKS clusters): Eliminate admission control complexity; centralized policy enforcement via Kubernetes Hub replaces fragmented tools
- **Security-Conscious ISVs**: Demonstrate supply chain security to end customers via unified first-party integration

**Business Outcomes**:
- **Revenue Protection**: Prevent churn of enterprise customers struggling with fragmented solutions
- **Revenue Growth**: Enable net-new sales in regulated industries where supply chain security is a gating requirement
- **Azure Consumption**: Drive ACR Premium (signing), Defender for Containers, and Azure Policy adoption
- **OKR Alignment**: 
  - **FY25 Q3 Security OKR**: Increase AKS clusters with supply chain security controls to 45%
  - **FY25 Q4 Compliance OKR**: Support FedRAMP High authorization for AKS

## Existing Solutions or Expectations 

| Approach | Capabilities | Limitations |
|----------|--------------|-------------|
| **OPA/Gatekeeper** (Self-Managed) | Flexible custom policies written in Rego language; supports resource validation and mutation | Requires Rego expertise; runs in-cluster (can be modified/disabled by admins); customer manages installation, upgrades, and availability; no built-in integration with ACR signing or Defender scanning |
| **Azure Policy for Kubernetes** | Enforce compliance policies across clusters; deny non-compliant resources; centralized governance via Azure Portal | Policy-based validation only; does not verify image signatures or check vulnerability scan results; limited to configuration/compliance enforcement |
| **Defender for Containers** | Continuous vulnerability scanning of registry images; runtime threat detection; security posture management with CIS Benchmarks | Provides security insights and alerts but does not block deployments; requires separate tooling to enforce gates; no image signature verification |
| **Defender Gated Deployment** | Block CI/CD deployments based on vulnerability scan results; integrates with Azure DevOps and GitHub Actions | Works only at CI/CD pipeline stage, not cluster admission; vulnerability scanning only (no signature verification, no attestation validation); separate configuration from cluster security policies |
| **Image Integrity** | Verify Notary Project signatures on container images at deployment time; integrates with ACR artifact signing | Signature verification only; does not check vulnerability scan results or validate security configurations; no support for SBOM, SLSA, or other attestation types |
| **Third-Party Solutions** (Aqua, Prisma Cloud, Twistlock) | Comprehensive scanning, policy engines, and runtime protection with custom policy rules | Additional licensing costs; deployed in-cluster (can be tampered with); requires separate management and integration work; not managed by Azure |

**Ideal Customer Experience or Northstar UX**: 

A single, visual interface in Azure Portal where I can enable tamper-proof supply chain security gating (signatures + vulnerabilities + best practices) with simple toggles, receive instant clarity on why deployments fail with remediation guidance, and gain fleet-wide visibility into policy enforcement—without writing YAML or learning CLI commands.


## What will the announcement look like?

**Announcing Integrated Admission Control for Azure Kubernetes Service (AKS)**

We are thrilled to introduce **Integrated Admission Control**, a comprehensive supply chain security solution designed to protect your Kubernetes workloads at deployment time. With Integrated Admission Control in **Azure Portal's Kubernetes Hub**, you can now enforce image signing verification, vulnerability scanning gates, and security best practices—all through a unified, visual interface with no YAML or CLI required.

**Addressing Key Challenges**

Today, implementing robust supply chain security on Kubernetes requires stitching together multiple tools: separate configurations for image signature verification (Image Integrity), vulnerability scanning (Defender for Containers), and policy enforcement (Azure Policy). This fragmentation creates:

- **Security gaps**: Policies can be bypassed or tampered with by cluster administrators
- **Operational overhead**: Each tool requires separate configuration and management
- **Compliance risk**: No unified view of policy enforcement across clusters
- **Steep learning curve**: Teams need expertise in YAML, OPA/Rego, and Kubernetes admission webhooks

Integrated Admission Control solves these challenges by bringing all supply chain security controls into a single, Portal-first experience managed by the AKS control plane.

**Functionality and Usage**

With this release, you can:

1. **Enable Admission Control from Azure Portal**: Navigate to any AKS cluster in Kubernetes Hub, go to the Security blade, and enable admission control with a simple toggle—no YAML or kubectl required

2. **Enforce Image Signatures**: Integrate with your Azure Container Registry signing infrastructure (Notary Project/Notation) to ensure only signed images run in your clusters. Select trusted registries and signing keys through dropdown menus.

3. **Block Vulnerable Images**: Connect to Microsoft Defender for Containers to automatically block deployment of images with critical or high-severity vulnerabilities. Set severity thresholds and scan age requirements through the Portal.

4. **Validate Security Best Practices**: Enforce CIS Kubernetes Benchmarks and Pod Security Standards using MDC security assessments. Block workloads that violate security best practices (privilege escalation, host namespace access, etc.)

5. **Verify Supply Chain Attestations**: Validate SBOM, SLSA provenance, and in-toto attestations to meet supply chain compliance requirements (Executive Order 14028, SLSA L3)

6. **Tamper-Proof Enforcement**: All policies are enforced in the AKS control plane and cannot be disabled or modified by cluster administrators

7. **Centralized Visibility**: View admission control status, policy compliance, and admission decision audit logs across all clusters in Kubernetes Hub

8. **Azure Policy Integration**: Enforce admission control requirements organization-wide using built-in Azure Policy definitions

**Availability**

Integrated Admission Control is now available in **public preview** in all Azure regions for AKS clusters running Kubernetes 1.37+. The feature is accessible through Azure Portal's Kubernetes Hub, Azure CLI, and ARM templates. General availability is planned for Q2 2026.

For more information, review the detailed documentation on how to make the most of this exciting new feature!

## Proposal 

### Recommended Approach: Portal-Managed, Control Plane-Enforced Admission Control

**Description**: 
Deploy admission control infrastructure as a managed service running in the AKS control plane (RP-side), separate from tenant cluster workloads. **Azure Portal's Kubernetes Hub serves as the primary user interface**, providing a unified visual experience for configuring policies across all first-party Microsoft services (ACR, MDC, Image Integrity). The AKS control plane acts as a validating webhook endpoint for the cluster's API server, intercepting admission requests and applying policies configured via the Portal or API.
