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

1. **Azure Portal as Primary Experience**: Position **Azure Portal's Kubernetes Hub** as the central, recommended interface for configuring and managing admission control, with unified visibility across all first-party security integrations (ACR, Defender, Image Integrity)
2. **API Support for Automation**: Provide AKS API support for customers who require Infrastructure-as-Code and automation workflows (ARM templates, Bicep, Terraform)
3. **First-Party Microsoft Service Integration**: 
   - **Azure Container Registry (ACR)**: Deep integration with ACR artifact signing ([Notary Project](https://github.com/notaryproject) signatures using Notation tooling) and Image Integrity for signature verification
   - **Microsoft Defender for Containers (MDC)**: Integrate vulnerability scanning results and security configuration assessments for admission gating
   - **Azure Policy**: Enable organization-wide governance through built-in policy definitions
3. **Comprehensive Security Validation**: 
   - Image signature verification and attestation validation
   - Vulnerability scanning gates (block images with critical/high CVEs)
   - Security misconfiguration detection (CIS Kubernetes Benchmark violations, pod security standards)
   - Security best practices enforcement (privilege escalation, host namespace access, etc.)
4. **Tamper-Proof Architecture**: Ensure admission control configuration and enforcement cannot be bypassed or modified except through the AKS control plane API
5. **Kubernetes Hub Integration**: Centralized visibility and management through Azure Portal's Kubernetes Hub, showing admission control status, policy compliance, and decision audit logs across all clusters
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
| Security Architect | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/write<br>Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Authorization/policyAssignments/write | As a security architect, I want to design and enforce organization-wide supply chain security policies across all AKS clusters **using Azure Portal's Kubernetes Hub**. I should be able to define signing requirements, vulnerability thresholds, and compliance gates through a visual interface, and receive compliance dashboards showing policy adherence across my fleet. Success: 100% of production clusters enforce signing requirements, vulnerability gates, and compliance policies with zero bypass incidents—all visible from a single Portal view. |
| Cluster Operator | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/write<br>Microsoft.ContainerService/managedClusters/admissionControl/write<br>Microsoft.ContainerService/admissionControl/read | As a cluster operator, I want to enable and configure admission control for my AKS cluster **through the Azure Portal** without deploying any in-cluster resources manually or writing YAML. I should navigate to my cluster in the Portal, enable admission control in the Security blade, select my ACR registries for signature verification and MDC for vulnerability scanning, all through dropdown menus and toggles. Success: Admission control fully configured in under 10 minutes using only the Portal; no CLI or kubectl required. |
| Application Developer | Microsoft.ContainerService/managedClusters/read<br>Microsoft.ContainerService/managedClusters/listClusterUserCredentials/action | As a developer, I want clear, actionable feedback when my container images are rejected by admission policies. When deployment fails, I should see admission decision details **in the Portal's activity log and Kubernetes Hub** with specific errors indicating whether the issue is missing signatures, failing vulnerability scans, or policy violations, with links to remediation documentation. Success: 90% of admission failures resolved without contacting support by using Portal diagnostics. |
| Compliance Officer | Microsoft.Authorization/policyDefinitions/read<br>Microsoft.Authorization/policyAssignments/read<br>Microsoft.Security/assessments/read | As a compliance officer, I want to demonstrate that all production AKS clusters enforce supply chain security policies consistent with our security framework (SLSA L3, NIST 800-190). **Using Azure Portal's Kubernetes Hub**, I should access pre-built compliance dashboards showing admission control coverage, policy compliance trends, and audit logs for all admission decisions. Success: Generate compliance reports for auditors in under 15 minutes entirely from the Portal. |

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

Integrated Admission Control is now available in **public preview** in all Azure regions for AKS clusters running Kubernetes 1.28+. The feature is accessible through Azure Portal's Kubernetes Hub, Azure CLI, and ARM templates. General availability is planned for Q2 2026.

For more information, review the detailed documentation on how to make the most of this exciting new feature!

## Proposal 

### Recommended Approach: Portal-Managed, Control Plane-Enforced Admission Control

**Description**: 
Deploy admission control infrastructure as a managed service running in the AKS control plane (RP-side), separate from tenant cluster workloads. **Azure Portal's Kubernetes Hub serves as the primary user interface**, providing a unified visual experience for configuring policies across all first-party Microsoft services (ACR, MDC, Image Integrity). The AKS control plane acts as a validating webhook endpoint for the cluster's API server, intercepting admission requests and applying policies configured via the Portal or API.

**Architecture**:
```
┌─────────────────────────────────────────────────────────────────────┐
│                   Azure Portal - Kubernetes Hub                     │
│            (Primary UX - Visual Policy Configuration)                │
│  - Enable/Disable Admission Control                                  │
│  - Select ACR Registries for Signature Verification                 │
│  - Configure MDC Vulnerability Thresholds                            │
│  - View Admission Decisions & Compliance Dashboards                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │ Portal configures via AKS API
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 AKS Control Plane (RP-side)                          │
│                Admission Control Service (Managed)                   │
├─────────────────────────────────────────────────────────────────────┤
│  Policy Evaluators (Microsoft First-Party):                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ ACR + Image      │  │ Defender for     │  │ Security Config  │  │
│  │ Integrity        │  │ Containers       │  │ Validator        │  │
│  │ (Signatures)     │  │ (Vulnerabilities)│  │ (CIS, PSS)       │  │
│  │                  │  │                  │  │                  │  │
│  │ - Notary sigs    │  │ - CVE gating     │  │ - CIS Benchmarks │  │
│  │ - SLSA provenance│  │ - SBOM checks    │  │ - Pod Security   │  │
│  │ - in-toto        │  │ - Scan freshness │  │ - Best practices │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└────────────────────────────┬────────────────────────────────────────┘
                             │ Webhook
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│            Customer AKS Cluster (Tenant Workloads)                   │
│                  Kubernetes API Server                               │
│         (Configured with AKS Control Plane webhook)                  │
└─────────────────────────────────────────────────────────────────────┘
```

**Policy Configuration Flow (Portal-First)**:
1. Cluster operator opens AKS cluster in Azure Portal → Kubernetes Hub
2. Navigates to **Security** → **Admission Control** blade
3. Clicks **"Enable Admission Control"** toggle
4. **Signature Verification** section:
   - Dropdown: Select ACR registries to trust
   - Table: View signing keys from Azure Key Vault / Azure Trusted Signing
   - Toggle: Enforce in production namespaces only
5. **Vulnerability Scanning** section:
   - Toggle: "Block images with critical/high vulnerabilities"
   - Dropdown: Select severity threshold (Critical, High, Medium)
   - Input: Maximum scan age (default: 7 days)
6. **Security Best Practices** section:
   - Checklist: Enable CIS Kubernetes Benchmark validation
   - Checklist: Enforce Pod Security Standards (baseline/restricted)
7. **Save** → Portal calls AKS API to configure control plane
8. Real-time status: "Admission control active - Enforcing 3 policies"

**Alternative Access (API/CLI for Automation)**:
- Customers requiring Infrastructure-as-Code can use ARM templates, Bicep, or Terraform
- CLI commands available for scripting and CI/CD integration
- **But Portal remains the recommended starting point** for discovery and initial setup

**Pros**:
- ✅ **Portal-First UX**: Non-technical users can configure complex policies without YAML expertise
- ✅ **Unified Integration**: Single interface shows how ACR, MDC, and Image Integrity work together
- ✅ **Tamper-Proof**: Admission logic runs outside cluster; cannot be modified by cluster users
- ✅ **Managed Lifecycle**: AKS handles upgrades, scaling, and availability of admission service
- ✅ **Consistent API**: Portal, CLI, and IaC tools all use the same AKS API surface
- ✅ **Audit Trail**: All decisions logged in Azure Monitor, visible in Portal
- ✅ **Performance Isolation**: Admission service scales independently of tenant workloads
- ✅ **Discoverability**: Security features visible in context within Kubernetes Hub

**Cons**:
- ⚠️ **Network Latency**: Additional hop to control plane (mitigated with regional deployment and <500ms SLA)
- ⚠️ **Infrastructure Investment**: Requires new control plane infrastructure (justified by customer demand and security value)
- ⚠️ **Failover Design**: Must handle control plane unavailability gracefully (configurable fail-open/fail-closed modes)

**Breaking Changes**: 
None. This is a new additive feature. Customers using Image Integrity (standalone) or Defender Gated Deployment will receive migration guidance to consolidate into the unified admission control platform.

**Go-to-Market**:
- **Positioning**: "Enterprise-grade supply chain security, built into AKS and managed through Azure Portal"
- **Target Segments**: Regulated industries (finance, healthcare, government), large enterprises with compliance requirements
- **Competitive Differentiation**: 
  - Only managed Kubernetes service with **Portal-first, control-plane enforced** admission control
  - Deepest first-party integration (ACR, MDC, Azure Policy) vs. GKE's Cloud-only approach or EKS's DIY model
- **Launch Vehicle**: Azure Portal Kubernetes Hub as the hero experience (not buried in CLI docs)

**Pricing**:
- **Preview**: Free during public preview
- **GA Pricing** (to be finalized in partnership with Finance):

## User Experience 

This section details the end-to-end user experience across all personas, with **Azure Portal as the primary interface**.

### Portal Experience (Primary UX)

#### Cluster Creation Flow - Quick Setup

When creating a new AKS cluster in Azure Portal:

**New Tab in Creation Wizard**: "Supply Chain Security"

**Step 1: Enable Admission Control**
- Toggle: **"Enable admission control"** (Off by default for preview; On by default at GA)
- Info icon: "Enforce image signing, vulnerability scanning, and security best practices at deployment time. Managed by AKS control plane - cannot be tampered with."

**Step 2: Choose Security Policies** (Conditional - shown if toggle is On)

Quick-start templates (radio buttons):
- ○ **Enforce signed images** - Require Notary Project signatures from ACR
- ○ **Block vulnerable images** - Prevent deployment of images with critical CVEs
- ○ **Comprehensive security** (Recommended) - Signatures + vulnerabilities + best practices
- ○ **Custom configuration** - Configure policies manually

**Step 3: Configure Selected Template** (Example: "Comprehensive security")

```
┌─────────────────────────────────────────────────────────────┐
│ Image Signature Verification                      [Enabled ✓]│
│ ─────────────────────────────────────────────────────────────│
│ Trusted Registries: [Select ACR registries ▼]                │
│ Selected: myacr.azurecr.io, prodacr.azurecr.io              │
│                                                               │
│ Signing Keys Source: [Azure Key Vault ▼]                     │
│ Key Vault: [Select vault ▼] mykv                             │
│                                                               │
│ Enforcement Scope: [Production namespaces only ▼]            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Vulnerability Scanning                             [Enabled ✓]│
│ ─────────────────────────────────────────────────────────────│
│ Provider: [Microsoft Defender for Containers]                │
│ (Requires Defender for Containers enabled on subscription)   │
│                                                               │
│ Block images with severity: [Critical and High ▼]            │
│ Maximum scan age: [7] days                                   │
│                                                               │
│ Enforcement Scope: [All namespaces except kube-system ▼]     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Security Best Practices                            [Enabled ✓]│
│ ─────────────────────────────────────────────────────────────│
│ ☑ CIS Kubernetes Benchmark validation                        │
│ ☑ Pod Security Standards - Baseline                          │
│ ☑ Block privilege escalation                                 │
│ ☑ Block host namespace access                                │
│                                                               │
│ Enforcement Mode: [Enforce (block violations) ▼]             │
│                   (Audit mode available for testing)          │
└─────────────────────────────────────────────────────────────┘

[< Previous]  [Review + Create]
```

---

#### Existing Cluster - Admission Control Blade

**Navigation**: Azure Portal → Kubernetes Service (myCluster) → **Security** → **Admission Control**

**Overview Tab**:
```
┌─────────────────────────────────────────────────────────────────────┐
│ Admission Control - myCluster (Production)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Status: ● Enabled - Enforcing                                      │
│  Mode: Enforce (Block policy violations)                            │
│  Active Policies: 3                                                  │
│  Last Updated: Nov 17, 2025 10:30 AM by admin@contoso.com          │
│                                                                      │
│  [Disable Admission Control]  [Switch to Audit Mode]  [Test Policy] │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│ Quick Stats (Last 24 hours)                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │
│  │   Allowed   │  │   Denied    │  │   Errors    │                │
│  │   12,456    │  │     342     │  │      2      │                │
│  └─────────────┘  └─────────────┘  └─────────────┘                │
│                                                                      │
│  Denial Breakdown:                                                   │
│    • Missing signatures: 198 (58%)                                   │
│    • Critical vulnerabilities: 120 (35%)                             │
│    • Security misconfiguration: 24 (7%)                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Policies Tab**:
```
Active Policies                                        [+ Add Policy]

┌─────────────────────────────────────────────────────────────────────┐
│ Image Signature Verification                   [Enabled ✓] [Edit] [⋮]│
├─────────────────────────────────────────────────────────────────────┤
│ Provider: ACR + Image Integrity (Notary Project)                     │
│ Trusted Registries: myacr.azurecr.io, prodacr.azurecr.io           │
│ Signing Keys: Azure Key Vault (mykv/prod-signing-key)              │
│ Scope: Namespaces (production, staging)                             │
│ Last Updated: Nov 15, 2025                                          │
│                                                                      │
│ Status: ✓ Policy active - Denied 198 deployments (last 24h)        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Vulnerability Scanning Gate                [Enabled ✓] [Edit] [⋮]   │
├─────────────────────────────────────────────────────────────────────┤
│ Provider: Microsoft Defender for Containers                          │
│ Severity Threshold: Critical + High                                  │
│ Maximum Scan Age: 7 days                                            │
│ Scope: All namespaces (except kube-system, kube-public)            │
│ Last Updated: Nov 15, 2025                                          │
│                                                                      │
│ Status: ✓ Policy active - Denied 120 deployments (last 24h)        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Security Best Practices                        [Enabled ✓] [Edit] [⋮]│
├─────────────────────────────────────────────────────────────────────┤
│ Provider: Microsoft Defender for Containers (Security Assessments)   │
│ Checks Enabled:                                                       │
│  ✓ CIS Kubernetes Benchmark                                          │
│  ✓ Pod Security Standards (Baseline)                                 │
│  ✓ Block privilege escalation                                        │
│  ✓ Block host namespace access                                       │
│ Scope: Namespaces (production)                                       │
│ Last Updated: Nov 15, 2025                                           │
│                                                                       │
│ Status: ✓ Policy active - Denied 24 deployments (last 24h)          │
└─────────────────────────────────────────────────────────────────────┘
```

**Admission Decisions Tab** (Real-time audit log):
```
Filter by: [All ▼]  [Last 24 hours ▼]  Decision: [All ▼]  🔍 Search

┌──────────────────────────────────────────────────────────────────────┐
│ Time        │ Image                    │ Namespace │ Decision │ Policy│
├──────────────────────────────────────────────────────────────────────┤
│ 10:45:23 AM │ myacr.io/app:v1.2.3     │ production│ ✗ DENIED │ Vuln  │
│             │ Reason: Image contains 2 critical CVEs (CVE-2024-1234, │
│             │ CVE-2024-5678). Scan age: 2 days.                      │
│             │ [View Scan Report] [Request Exception]                 │
├──────────────────────────────────────────────────────────────────────┤
│ 10:42:10 AM │ myacr.io/web:latest     │ staging   │ ✗ DENIED │ Sig   │
│             │ Reason: No valid Notary signature found. Expected      │
│             │ signature from key 'prod-signing-key'.                 │
│             │ [Learn How to Sign] [View Trusted Keys]                │
├──────────────────────────────────────────────────────────────────────┤
│ 10:40:55 AM │ myacr.io/api:v2.0.1     │ production│ ✓ ALLOWED│ All   │
│             │ Passed: Signature valid ✓, No critical CVEs ✓, CIS ✓  │
├──────────────────────────────────────────────────────────────────────┤
│ 10:38:12 AM │ myacr.io/worker:v1.5    │ production│ ✗ DENIED │ Config│
│             │ Reason: Security misconfiguration - Privileged         │
│             │ container with hostNetwork=true violates CIS 5.2.1     │
│             │ [View CIS Benchmark] [Remediation Guide]               │
└──────────────────────────────────────────────────────────────────────┘

[Export to CSV]  [View in Log Analytics]
```

**Kubernetes Hub Integration** (Fleet-wide view):
```
Azure Portal → Kubernetes Hub → Security → Admission Control Coverage

┌──────────────────────────────────────────────────────────────────────┐
│ Admission Control Coverage (Subscription: Production)                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Clusters with Admission Control: 45 / 50 (90%)                     │
│  [View Non-Compliant Clusters]                                       │
│                                                                       │
│  Policy Adoption:                                                     │
│    • Signature Verification: 42 clusters (84%)                        │
│    • Vulnerability Scanning: 45 clusters (90%)                        │
│    • Security Best Practices: 38 clusters (76%)                       │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ Compliance Trend (Last 30 days)           [Line chart showing  ││
│  │                                             increasing adoption] ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                       │
│  Top Denied Images (Fleet-wide):                                     │
│  1. contoso.azurecr.io/legacy-app:v1.0 - 450 denials (no signature) │
│  2. public.ecr.aws/nginx:latest - 320 denials (critical CVEs)       │
│  3. gcr.io/myproject/api:dev - 180 denials (unsigned)                │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

### API Experience (Automation Layer)

**New ARM Resource**: `Microsoft.ContainerService/managedClusters/admissionControl`

**API Version**: `2024-11-01` (preview), `2026-05-01` (GA target)

```json
{
  "type": "Microsoft.ContainerService/managedClusters/admissionControl",
  "apiVersion": "2024-11-01-preview",
  "name": "default",
  "properties": {
    "enabled": true,
    "mode": "Enforcing", // or "Audit"
    "policies": {
      "imageSignatureVerification": {
        "enabled": true,
        "provider": "AzureContainerRegistry",
        "trustedRegistries": [
          {
            "registryResourceId": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerRegistry/registries/myacr",
            "signingKeySource": {
              "type": "AzureKeyVault",
              "keyVaultUri": "https://mykv.vault.azure.net/keys/prod-signing-key"
            }
          }
        ],
        "enforcementScope": {
          "namespaces": ["production", "staging"],
          "excludeNamespaces": ["kube-system", "kube-public"]
        }
      },
      "vulnerabilityScanning": {
        "enabled": true,
        "provider": "DefenderForContainers",
        "severityThreshold": "Critical", // Critical, High, Medium, Low
        "maxScanAge": "P7D", // ISO 8601 duration
        "enforcementScope": {
          "allNamespaces": true,
          "excludeNamespaces": ["kube-system"]
        }
      },
      "securityBestPractices": {
        "enabled": true,
        "provider": "DefenderForContainers",
        "checks": [
          "CISKubernetesBenchmark",
          "PodSecurityStandardsBaseline",
          "BlockPrivilegeEscalation",
          "BlockHostNamespace"
        ],
        "enforcementScope": {
          "namespaces": ["production"]
        }
      }
    },
    "failurePolicy": "Fail", // or "Ignore" (fail-closed vs fail-open)
    "diagnostics": {
      "logAnalyticsWorkspaceId": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/myworkspace",
      "enableMetrics": true,
      "retentionDays": 90
    }
  }
}
```

**API Operations**:
- `PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl/default` - Create/update
- `GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl/default` - Get config
- `DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl/default` - Disable
- `POST /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl/default/testPolicy` - Dry-run test
- `GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl/default/decisions` - Query admission logs

---

### CLI Experience (Automation Layer)

**Note**: CLI commands support automation scenarios. **Portal remains the recommended interface for discovery and initial setup.**

**Enable Admission Control with Signature Verification**:
```bash
az aks admission-control create \
  --resource-group myRG \
  --cluster-name myCluster \
  --mode enforce \
  --signature-verification \
    --acr-resource-id /subscriptions/.../registries/myacr \
    --signing-key-vault-uri https://mykv.vault.azure.net/keys/prod-key \
    --namespaces production staging
```

**Add Vulnerability Scanning Policy**:
```bash
az aks admission-control policy add \
  --resource-group myRG \
  --cluster-name myCluster \
  --policy-type vulnerability-scanning \
  --provider defender \
  --severity-threshold critical-and-high \
  --max-scan-age 7d \
  --all-namespaces \
  --exclude-namespaces kube-system kube-public
```

**Enable Security Best Practices**:
```bash
az aks admission-control policy add \
  --resource-group myRG \
  --cluster-name myCluster \
  --policy-type security-best-practices \
  --provider defender \
  --checks CISBenchmark PodSecurityBaseline \
  --namespaces production
```

**Test Policy (Dry-Run)**:
```bash
az aks admission-control test \
  --resource-group myRG \
  --cluster-name myCluster \
  --image myacr.azurecr.io/app:v1.2.3 \
  --namespace production
```

**Output**:
```yaml
admissionDecision: Deny
evaluationResults:
  - policyType: ImageSignatureVerification
    result: Pass
    message: "Valid Notary signature found from key 'prod-signing-key'"
  
  - policyType: VulnerabilityScanning
    result: Deny
    message: "Image contains 2 critical vulnerabilities"
    details:
      - cve: CVE-2024-1234
        severity: Critical
        exploitability: High
      - cve: CVE-2024-5678
        severity: Critical
        exploitability: Medium
    remediationLinks:
      - "https://learn.microsoft.com/azure/defender-for-cloud/remediate-vulnerability-findings"
  
  - policyType: SecurityBestPractices
    result: Pass
    message: "No CIS Benchmark violations detected"

finalDecision: Deny
reason: "Image failed VulnerabilityScanning policy due to 2 critical CVEs"
```

**View Admission Decisions**:
```bash
az aks admission-control decisions list \
  --resource-group myRG \
  --cluster-name myCluster \
  --since 24h \
  --decision denied \
  --output table
```

**Get Admission Control Status**:
```bash
az aks admission-control show \
  --resource-group myRG \
  --cluster-name myCluster
```

---

### Policy Experience

**Built-in Azure Policy Definition 1: Require Signed Images**

```json
{
  "policyDefinitionId": "aks-require-signed-images",
  "displayName": "[Preview] AKS clusters should enforce image signature verification",
  "description": "Enforce that all container images deployed to AKS clusters have valid signatures from trusted signers using Notary Project or Cosign. This policy ensures supply chain integrity and prevents deployment of untrusted images.",
  "mode": "Indexed",
  "metadata": {
    "category": "Kubernetes",
    "preview": true
  },
  "parameters": {
    "effect": {
      "type": "String",
      "allowedValues": ["DeployIfNotExists", "Audit", "Disabled"],
      "defaultValue": "DeployIfNotExists"
    },
    "trustedRegistries": {
      "type": "Array",
      "metadata": {
        "description": "List of Azure Container Registry resource IDs that are trusted for signed images"
      }
    },
    "enforcementNamespaces": {
      "type": "Array",
      "defaultValue": ["production", "staging"],
      "metadata": {
        "description": "Namespaces where signature verification should be enforced"
      }
    }
  },
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.ContainerService/managedClusters"
        },
        {
          "field": "Microsoft.ContainerService/managedClusters/admissionControl.enabled",
          "notEquals": true
        }
      ]
    },
    "then": {
      "effect": "[parameters('effect')]",
      "details": {
        "type": "Microsoft.ContainerService/managedClusters/admissionControl",
        "deploymentScope": "ResourceGroup",
        "existenceCondition": {
          "field": "Microsoft.ContainerService/managedClusters/admissionControl.policies.imageSignatureVerification.enabled",
          "equals": true
        },
        "deployment": {
          "properties": {
            "mode": "incremental",
            "template": {
              "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
              "resources": [
                {
                  "type": "Microsoft.ContainerService/managedClusters/admissionControl",
                  "apiVersion": "2024-11-01-preview",
                  "name": "[concat(parameters('clusterName'), '/default')]",
                  "properties": {
                    "enabled": true,
                    "mode": "Enforcing",
                    "policies": {
                      "imageSignatureVerification": {
                        "enabled": true,
                        "provider": "AzureContainerRegistry",
                        "trustedRegistries": "[parameters('trustedRegistries')]",
                        "enforcementScope": {
                          "namespaces": "[parameters('enforcementNamespaces')]"
                        }
                      }
                    }
                  }
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

**Built-in Azure Policy Definition 2: Block Critical Vulnerabilities**

Similar structure with `vulnerabilityScanning` policy configuration.

**Built-in Azure Policy Initiative: "AKS Supply Chain Security Baseline"**

```json
{
  "policySetDefinitionId": "aks-supply-chain-security-baseline",
  "displayName": "[Preview] AKS Supply Chain Security Baseline",
  "description": "This initiative bundles policies to establish a baseline for supply chain security on AKS clusters, including image signature verification, vulnerability scanning, and security best practices validation.",
  "metadata": {
    "category": "Kubernetes",
    "preview": true
  },
  "policyDefinitions": [
    {
      "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/aks-require-signed-images",
      "parameters": { "effect": { "value": "DeployIfNotExists" } }
    },
    {
      "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/aks-block-critical-vulnerabilities",
      "parameters": { 
        "effect": { "value": "DeployIfNotExists" },
        "severityThreshold": { "value": "Critical" }
      }
    },
    {
      "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/aks-enforce-security-best-practices",
      "parameters": { "effect": { "value": "DeployIfNotExists" } }
    }
  ]
}
```

**Usage in Portal**:
1. Navigate to **Azure Policy** → **Definitions** → Search "AKS Supply Chain"
2. Select **"AKS Supply Chain Security Baseline"** initiative
3. Click **"Assign"**
4. Scope: Select subscription or resource group
5. Parameters: Specify trusted ACR registries, namespaces
6. **Assign** → Policy engine automatically configures admission control on all AKS clusters

---

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Increase supply chain security adoption | % of AKS clusters with admission control enabled | 45% of production clusters by GA+6mo | P0 |
| 2   | Portal-first adoption | % of admission control configurations created via Portal vs CLI/API | >70% via Portal | P0 |
| 3   | Reduce security incidents | # of production incidents from unverified/vulnerable images | 50% reduction in affected customers YoY | P0 |
| 4   | Improve user experience satisfaction | CSAT score for admission control feature | ≥4.5/5.0 | P0 |
| 5   | Drive ACR Premium adoption | # of ACR Premium registries with signing enabled | 30% increase QoQ | P1 |
| 6   | Drive Defender for Containers adoption | # of subscriptions with Defender enabled for vulnerability scanning | 25% increase QoQ | P1 |
| 7   | Reduce support burden | # of support tickets related to admission control configuration | 40% reduction vs. self-managed OPA/Gatekeeper baseline | P1 |
| 8   | Meet performance SLA | p95 admission decision latency | <500ms | P0 |
| 9   | Achieve reliability SLA | Admission control service availability | 99.9% | P0 |
| 10  | Enable compliance | # of customers achieving SLSA L3 / FedRAMP compliance using this feature | 50 customers by GA+12mo | P1 |

**Experiments**:
- **A/B Test (Preview)**: Default admission control ON for new clusters created via Portal (50% of regions) vs. OFF (control) → measure adoption rate and feedback sentiment
- **Usability Study**: Observe 10 customers (mixed personas) configuring admission control using Portal with think-aloud protocol → iterate on UX based on friction points
- **Performance Canary**: Deploy to 5% of clusters with telemetry to validate <500ms latency SLA before broader rollout

---

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   | Azure Portal Kubernetes Hub must provide visual interface for enabling/disabling admission control without CLI | P0 |
| 2   | Portal must display real-time admission decision logs with filtering and search capabilities | P0 |
| 3   | Portal must show policy effectiveness dashboards (allowed/denied trends, top denied images) | P0 |
| 4   | AKS API must support enabling/disabling admission control via ARM/CLI for automation scenarios | P0 |
| 5   | Support ACR Notary Project signature verification with integration to Azure Key Vault / Azure Trusted Signing | P0 |
| 6   | Support Microsoft Defender for Containers vulnerability scan results as admission gate | P0 |
| 7   | Support Microsoft Defender for Containers security assessment results (CIS, PSS) as admission gate | P0 |
| 8   | Admission control configuration must be tamper-proof (not modifiable from within cluster) | P0 |
| 9   | Support namespace-scoped policy enforcement (include/exclude namespaces) | P0 |
| 10  | Provide "Audit" mode for testing policies without blocking deployments | P0 |
| 11  | Emit admission decision logs to Azure Monitor / Log Analytics | P0 |
| 12  | Support dry-run/test policy API and Portal feature for validating images before deployment | P0 |
| 13  | Integrate with Azure Policy for fleet-wide governance (built-in policy definitions) | P0 |
| 14  | Portal must provide guided wizards for common scenarios (e.g., "Enable signature verification") | P1 |
| 15  | Support configurable failure policy (fail-open or fail-closed when admission service unavailable) | P0 |
| 16  | Portal must show integration status with ACR, Defender, Image Integrity (connected/disconnected) | P1 |
| 17  | Support SBOM attestation verification (SPDX, CycloneDX formats) | P0 |
| 18  | Support SLSA provenance attestation verification | P0 |
| 19  | Support in-toto attestation verification | P0 |
| 20  | Portal must provide remediation guidance for common denial reasons (missing signature, CVE, etc.) | P1 |

## Test Requirements 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   | Unit tests for all policy evaluator modules (signature, vulnerability, security config) | P0 |
| 2   | Integration tests for AKS API → admission service → cluster API server flow | P0 |
| 3   | End-to-end Portal tests for all user journeys (enable, configure, view decisions) | P0 |
| 4   | Performance tests: 10,000 admission decisions/sec with <500ms p95 latency | P0 |
| 5   | Chaos testing: Admission service failure, network partition, control plane unavailability | P0 |
| 6   | Security testing: Attempt to bypass policies from within cluster (should fail) | P0 |
| 7   | Compatibility testing: All supported Kubernetes versions (1.28, 1.29, 1.30+) | P0 |
| 8   | ACR integration tests: Notary Project signatures, signing key rotation | P0 |
| 9   | Defender integration tests: Mock vulnerability scan results, assessment results | P0 |
| 10  | Scalability tests: 1000+ clusters with admission control enabled in single region | P1 |
| 11  | Disaster recovery tests: Admission service failover between regions | P1 |
| 12  | Upgrade tests: In-place upgrade of admission service without cluster disruption | P0 |
| 13  | Audit mode tests: Verify policies log violations without blocking | P0 |
| 14  | Azure Policy tests: Policy assignment, compliance reporting, auto-remediation | P0 |
| 15  | Accessibility tests: Portal UI meets WCAG 2.1 AA standards | P1 |
| 16  | Usability tests: 10 customers complete admission control setup via Portal in <10 minutes | P0 |

---

# Dependencies and Risks 

| No. | Requirement or Deliverable | Giver Team / Contact | Risk / Mitigation |
|-----|---------|---------|---------|
| 1   | ACR Notary Project signature verification API | ACR Team | **Risk**: API changes or latency issues; **Mitigation**: Joint API design review, contract tests, caching layer for signature metadata |
| 2   | Defender for Containers vulnerability scan results API | Defender Team | **Risk**: Latency in scan result retrieval (>500ms); **Mitigation**: Async pre-fetching, cache scan results with TTL, graceful degradation |
| 3   | Defender for Containers security assessment API (CIS, PSS) | Defender Team | **Risk**: Assessment data format changes; **Mitigation**: Versioned API contract, backward compatibility tests |
| 4   | Azure Policy engine integration for fleet governance | Azure Policy Team | **Risk**: Policy evaluation latency; **Mitigation**: Pre-compiled policies, regional caching |
| 5   | Kubernetes Hub Portal UI development | Azure Portal Team | **Risk**: Portal UX delivery slips behind API GA; **Mitigation**: API-first development, Portal in parallel track, preview with CLI-only if needed |
| 6   | Azure Key Vault integration for signing key retrieval | Key Vault Team | **Risk**: Key Vault throttling at scale; **Mitigation**: Key metadata caching (30min TTL), rate limit handling, customer guidance on key vault SKU |
| 7   | Azure Trusted Signing integration | Trusted Signing Team | **Risk**: Service availability in all regions; **Mitigation**: Fallback to Azure Key Vault, clear regional availability documentation |
| 8   | Log Analytics workspace for admission logs | Azure Monitor Team | **Risk**: Log ingestion limits for high-volume clusters; **Mitigation**: Sampling for high-volume customers, customer-configurable log verbosity |
| 9   | AKS control plane infrastructure for admission service | AKS RP Team | **Risk**: Control plane capacity for admission service workload; **Mitigation**: Dedicated admission control pod pools, auto-scaling, regional deployment |
| 10  | Kubernetes API server webhook latency tolerance | Upstream Kubernetes | **Risk**: API server timeout if admission service slow (default 30s); **Mitigation**: <500ms SLA, configurable timeout, fail-open option |
| 11  | FedRAMP compliance certification | Compliance Team | **Risk**: Certification delays GA for government customers; **Mitigation**: Early engagement, parallel compliance workstreams, audit trail design upfront |
| 12  | Image Integrity migration plan | AKS PM Team | **Risk**: Customer confusion migrating from standalone Image Integrity; **Mitigation**: Auto-migration tool, documentation, deprecation timeline (12mo) |
| 13  | Defender Gated Deployment deprecation communication | Defender PM Team | **Risk**: Customer backlash if forced migration; **Mitigation**: Side-by-side operation for 12mo, clear migration benefits, assisted migration |

---

# Compete 

## GKE (Google Kubernetes Engine)

**Binary Authorization**:
- **Capabilities**: Built-in admission control enforcing image signature verification using Cloud KMS or asymmetric keys; integrates with Container Analysis API for vulnerability scanning; supports SLSA attestations
- **UX**: Configured through Google Cloud Console (similar Portal-first approach) or gcloud CLI
- **Pros**: Mature feature (GA since 2019), tight integration with Google Cloud services (Artifact Registry, Container Analysis)
- **Gaps**: 
  - Limited to Google Cloud-native tools; no extensibility for third-party scanners
  - Requires deep GCP knowledge (Cloud KMS, Container Analysis)
  - No unified security best practices validation (CIS Benchmarks)

**GKE Policy Controller**:
- **Capabilities**: Managed Open Policy Agent (OPA) with pre-built policy library; supports custom Rego policies
- **Pros**: Flexible policy engine for custom use cases
- **Gaps**: 
  - Requires Rego expertise for custom policies (steep learning curve)
  - Separate from Binary Authorization (fragmented experience)

**AKS Advantage**: 
- **Deeper first-party integration**: ACR + Defender + Image Integrity unified vs. GKE's Cloud-only approach
- **Portal-first UX**: Kubernetes Hub provides more accessible, visual experience vs. gcloud CLI-heavy approach
- **Security best practices validation**: CIS Benchmarks, Pod Security Standards built-in vs. manual Rego policies in GKE

---

## EKS (Amazon Elastic Kubernetes Service)

**Amazon ECR Image Scanning**:
- **Capabilities**: Integrated vulnerability scanning with ECR (basic and enhanced scanning); can block deployments via admission controller (customer-deployed)
- **Gaps**: 
  - **Not control-plane enforced**: Customer must manually deploy and manage admission webhook
  - **Tamper risk**: Admission controller runs in-cluster, can be disabled by cluster admins
  - **No managed service**: Customer responsible for lifecycle, upgrades, availability

**AWS Signer + EKS Integration**:
- **Capabilities**: Sign container images with AWS Signer; verify signatures in EKS via admission controller
- **Gaps**:
  - **DIY approach**: Requires deploying own admission webhook (no managed service)
  - **Complex setup**: Manual configuration of Signer, ECR, admission controller, IAM roles

**EKS Security Best Practices**:
- **Approach**: AWS provides guidance and blog posts on deploying OPA, Kyverno, or third-party solutions (Aqua, Prisma)
- **Gaps**:
  - **No managed admission control service** (unlike AKS)
  - **No unified UX**: Each tool (ECR scanning, AWS Signer, OPA) configured separately

**AKS Advantage**:
- **Fully managed service**: AKS owns admission control infrastructure vs. EKS DIY
- **Tamper-proof**: Control-plane enforcement vs. EKS in-cluster approach
- **Portal-first UX**: Kubernetes Hub visual interface vs. EKS CLI/YAML-heavy approach
- **Unified platform**: Single admission control API for signatures + vulnerabilities + best practices vs. EKS fragmented tools

---

## Competitive Positioning Summary

| Capability | AKS (This PRD) | GKE | EKS |
|------------|----------------|-----|-----|
| **Managed Admission Control Service** | ✅ Control plane | ✅ Control plane (Binary Auth) | ❌ DIY (customer-deployed) |
| **Portal-First UX** | ✅ Kubernetes Hub | ⚠️ Cloud Console (less integrated) | ❌ CLI/YAML-heavy |
| **Tamper-Proof Enforcement** | ✅ | ✅ | ❌ (in-cluster) |
| **First-Party Signature Verification** | ✅ (ACR/Notation) | ✅ (Artifact Registry/Cloud KMS) | ✅ (AWS Signer) but manual setup |
| **First-Party Vulnerability Scanning** | ✅ (Defender for Containers) | ✅ (Container Analysis) | ✅ (ECR Scanning) but manual integration |
| **Security Best Practices Validation** | ✅ (CIS, PSS via Defender) | ⚠️ (Requires custom Rego) | ⚠️ (Requires manual OPA/Kyverno) |
| **Unified Configuration** | ✅ Single admission control API | ⚠️ (Binary Auth + Policy Controller separate) | ❌ (Fragmented tools) |
| **Extensibility for 3P Tools** | ✅ (Designed for future) | ⚠️ (Limited) | ⚠️ (DIY integration) |
| **Azure Policy Integration** | ✅ | ❌ | ❌ |
| **Kubernetes Hub Fleet View** | ✅ | ⚠️ (GKE Fleet Management) | ⚠️ (EKS Connector) |

**Key Differentiators**:
1. **AKS is the only managed Kubernetes service with Portal-first, control-plane enforced admission control** that unifies signatures, vulnerabilities, and security best practices
2. **Deepest Microsoft ecosystem integration**: ACR, Defender, Azure Policy, Azure Trusted Signing, Azure Key Vault
3. **Accessibility**: Kubernetes Hub makes supply chain security accessible to non-CLI users (security architects, compliance officers)
