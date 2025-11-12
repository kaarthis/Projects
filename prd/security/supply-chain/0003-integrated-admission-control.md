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

## What will the announcement look like?

**Announcing Integrated Admission Control for Azure Kubernetes Service (AKS)**

We are thrilled to introduce **Integrated Admission Control**, a new platform capability designed to bring comprehensive, tamper-proof supply chain security enforcement to AKS clusters. With Integrated Admission Control, you can now enforce image signing verification, vulnerability scanning gates, and custom compliance policies through a single, unified AKS API that seamlessly integrates with both Azure-native and third-party security solutions.

**Addressing Key Challenges**

Today, implementing robust supply chain security on Kubernetes requires stitching together multiple tools, manually deploying in-cluster components, and accepting the risk that policies can be tampered with or bypassed. Organizations struggle to:

- **Ensure all container images are signed and verified** before deployment
- **Block vulnerable images** from running in production environments
- **Enforce consistent policies** across multiple clusters and teams
- **Integrate third-party security tools** without complex custom development
- **Prevent policy tampering** by privileged cluster users

Integrated Admission Control solves these challenges by moving policy enforcement to the AKS control plane, where it is managed, monitored, and protected by Azure.

**Functionality and Usage**

With this release, you can:

1. **Enable Admission Control via AKS API**: Configure all admission policies through `az aks` commands or ARM templates—no in-cluster YAML required
2. **Enforce Image Signatures**: Integrate with Azure Container Registry Notation signing to ensure only signed images run in your clusters
3. **Block Vulnerable Images**: Connect to Azure Defender for Containers or third-party scanners (Aqua, Prisma, Twistlock) to prevent deployment of images with critical vulnerabilities
4. **Leverage Third-Party Solutions**: Seamlessly enable partner admission controllers through the AKS Marketplace with zero manual installation
5. **Tamper-Proof Enforcement**: Admission policies are enforced in the control plane and cannot be disabled or modified by cluster administrators
6. **Centralized Governance**: Use Azure Policy to apply admission control requirements across all clusters in your organization
7. **Audit and Compliance**: Access detailed logs of all admission decisions for security reviews and compliance reporting

**Availability**

Integrated Admission Control is now available in **public preview** in all Azure regions for AKS clusters running Kubernetes 1.36+. The feature requires AKS API version 2026-11-01 or later. General availability is planned for Q2 2027.

For more information, review the detailed documentation on how to make the most of this exciting new feature!

## Proposal 

### Option 1: Control Plane Admission Webhook (Recommended)

**Description**: 
Deploy admission control infrastructure as a managed service running in the AKS control plane (RP-side), separate from tenant cluster workloads. The AKS control plane acts as a webhook endpoint for the cluster's API server, intercepting admission requests and applying policies configured via the AKS API.

**Architecture**:
```
Customer Cluster (Tenant) → API Server → Webhook → AKS Control Plane Admission Service
                                                    ↓
                                                    Policy Evaluators:
                                                    - ACR Signature Validator
                                                    - Defender Vulnerability Gate
                                                    - Third-Party Plugin (Aqua/Prisma)
                                                    - OPA/Rego Engine
```

**Pros**:
- ✅ Tamper-proof: Admission logic runs outside cluster; cannot be modified by cluster users
- ✅ Managed lifecycle: AKS handles upgrades, scaling, and availability
- ✅ Consistent API: All configuration through AKS ARM/CLI
- ✅ Audit trail: All decisions logged in Azure Monitor
- ✅ Performance isolation: Admission service scales independently of tenant workloads

**Cons**:
- ⚠️ Network latency: Additional hop to control plane (mitigated with regional deployment)
- ⚠️ Complexity: Requires new control plane infrastructure
- ⚠️ Failover design: Must handle control plane unavailability gracefully

**Breaking Changes**: None. This is a new additive feature.

---

### Option 2: Enhanced In-Cluster Gatekeeper (Not Recommended)

**Description**: 
Enhance the existing Azure Policy for Kubernetes (Gatekeeper-based) with signing/scanning integrations and protect it with a controller that prevents modification.

**Pros**:
- ✅ Builds on existing Azure Policy investment
- ✅ Lower latency (in-cluster)

**Cons**:
- ❌ Tamper risk: Still vulnerable to cluster admin bypass (e.g., deleting ValidatingWebhookConfiguration)
- ❌ Limited extensibility: Hard to integrate third-party solutions
- ❌ Shared fate: Admission controller availability tied to cluster health

---

### Option 3: Hybrid Model

**Description**: 
Control plane API for configuration + in-cluster enforcement with RP-side monitoring that detects and remediates tampering.

**Pros**:
- ✅ Lower latency
- ✅ Tamper detection

**Cons**:
- ❌ Complexity: Two systems to maintain
- ❌ Race conditions: Window where policies could be bypassed before remediation

---

### Recommended Approach: Option 1 (Control Plane Admission Webhook)

This approach best addresses the core requirements: tamper-proof enforcement, unified API, and ecosystem extensibility. The latency concerns can be mitigated through regional deployment and caching optimizations.

**Go-to-Market**:
- **Positioning**: "Enterprise-grade supply chain security, built into AKS"
- **Target Segments**: Regulated industries (finance, healthcare, government), large enterprises with compliance requirements
- **Competitive Differentiation**: Only managed Kubernetes service with control-plane enforced, tamper-proof admission control

**Pricing**:
- **Preview**: Free during public preview
- **GA Pricing** (to be finalized):
  - Base fee: $0.10/cluster/hour for admission control service
  - Transaction pricing: $0.50/million admission decisions (beyond free tier of 10M/month)
  - Third-party integrations: Partner pricing (e.g., Aqua license) + AKS integration fee TBD

## User Experience 

### Persona 1: Cluster Operator Enabling Signature Verification

**Journey**: Enable ACR signature verification on a new AKS cluster

**Steps**:
1. Cluster operator creates cluster with admission control enabled
2. Configures signature verification policy pointing to ACR signing keys
3. Deploys test workload with unsigned image → admission denied
4. Signs image using Notation CLI and ACR
5. Deploys signed image → admission approved

**Experience**:
- Clear error messages: "Image 'myapp:v1' rejected: No valid signature found. Expected signature from key 'prod-signing-key' in Azure Key Vault."
- Azure Portal shows admission control status and recent decisions
- Audit logs in Log Analytics capture all decisions with image metadata

---

### Persona 2: Security Architect Enforcing Vulnerability Gates via Azure Policy

**Journey**: Require all production clusters to block images with critical vulnerabilities

**Steps**:
1. Security architect creates Azure Policy definition: "AKS clusters must block images with critical CVEs"
2. Assigns policy to production subscription
3. AKS automatically configures admission control on all production clusters
4. Developer attempts to deploy image with CVE-2024-1234 (critical) → admission denied
5. Compliance dashboard shows 100% policy adherence across fleet

**Experience**:
- Azure Policy portal shows compliance state across all clusters
- Non-compliant clusters automatically remediated
- Policy effects audited and reported

---

### Persona 3: Cluster Operator Integrating Prisma Cloud

**Journey**: Enable Prisma Cloud admission control on existing cluster

**Steps**:
1. Cluster operator navigates to AKS cluster → Admission Control blade
2. Selects "Enable Third-Party Integration" → chooses Prisma Cloud from marketplace
3. Provides Prisma Cloud API credentials (or uses managed identity)
4. AKS configures webhook to Prisma Cloud policy engine
5. Prisma Cloud policies (vulnerability, compliance, runtime) now enforced at admission time

**Experience**:
- No YAML editing or Helm chart deployment required
- Prisma Cloud dashboard shows AKS integration status
- AKS portal displays admission decisions from Prisma Cloud

### API

**New Resource**: `Microsoft.ContainerService/managedClusters/admissionControl`

```json
{
  "properties": {
    "admissionControl": {
      "enabled": true,
      "mode": "Enforcing", // or "Audit"
      "policies": [
        {
          "policyType": "ImageSignatureVerification",
          "enabled": true,
          "config": {
            "trustedSigners": [
              {
                "provider": "AzureContainerRegistry",
                "registryResourceId": "/subscriptions/.../registries/myacr",
                "signingKeyVaultUri": "https://mykv.vault.azure.net/keys/signing-key"
              }
            ],
            "enforcementScope": {
              "namespaces": ["production", "staging"],
              "excludeNamespaces": ["kube-system"]
            }
          }
        },
        {
          "policyType": "VulnerabilityGate",
          "enabled": true,
          "config": {
            "provider": "DefenderForContainers", // or "Aqua", "Prisma", "Twistlock"
            "severity": "Critical", // Block images with critical+ vulns
            "maxAge": "7d", // Scan results must be < 7 days old
            "enforcementScope": {
              "namespaces": ["production"]
            }
          }
        },
        {
          "policyType": "ThirdPartyAdmissionController",
          "enabled": true,
          "config": {
            "provider": "PrismaCloud",
            "connectionDetails": {
              "apiEndpoint": "https://api.prismacloud.io",
              "credentialSecretRef": "/subscriptions/.../secrets/prisma-creds"
            }
          }
        }
      ],
      "diagnostics": {
        "logAnalyticsWorkspaceId": "/subscriptions/.../workspaces/myworkspace",
        "enableMetrics": true
      }
    }
  }
}
```

**API Operations**:
- `PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl` - Create/update admission control config
- `GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl` - Get current config
- `DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl` - Disable admission control
- `POST /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/admissionControl/testPolicy` - Test policy against sample image (dry-run)

### CLI Experience

**Enable Admission Control with Signature Verification**:
```bash
az aks admission-control enable \
  --resource-group myRG \
  --name myCluster \
  --policy signature-verification \
  --acr-resource-id /subscriptions/.../registries/myacr \
  --signing-key-vault-uri https://mykv.vault.azure.net/keys/prod-key
```

**Add Vulnerability Gate**:
```bash
az aks admission-control policy add \
  --resource-group myRG \
  --name myCluster \
  --policy-type vulnerability-gate \
  --provider defender \
  --severity critical \
  --max-scan-age 7d \
  --namespaces production staging
```

**Enable Third-Party Integration**:
```bash
az aks admission-control integration add \
  --resource-group myRG \
  --name myCluster \
  --provider prisma-cloud \
  --api-endpoint https://api.prismacloud.io \
  --credential-secret /subscriptions/.../secrets/prisma-creds
```

**Test Policy (Dry-Run)**:
```bash
az aks admission-control test-policy \
  --resource-group myRG \
  --name myCluster \
  --image myacr.azurecr.io/myapp:v1.2.3 \
  --namespace production
```
Output:
```
Policy Evaluation Results:
✓ ImageSignatureVerification: PASS - Valid signature found
✗ VulnerabilityGate: DENY - Image contains 2 critical vulnerabilities (CVE-2024-1234, CVE-2024-5678)

Admission Decision: DENY
Reason: Image failed VulnerabilityGate policy
```

**View Admission Logs**:
```bash
az aks admission-control logs \
  --resource-group myRG \
  --name myCluster \
  --since 1h \
  --decision denied
```

### Portal Experience

**Cluster Creation Flow**:
1. New "Supply Chain Security" tab in AKS creation wizard
2. Toggle: "Enable admission control" (off by default)
3. Quick-start templates:
   - "Enforce signed images (ACR)"
   - "Block vulnerable images (Defender)"
   - "Custom policies"
4. Advanced configuration: Add policies, configure namespaces, set audit vs. enforce mode

**Existing Cluster - Admission Control Blade**:
- **Overview**: Status (enabled/disabled), mode (audit/enforce), active policies count
- **Policies Tab**: List of configured policies with enable/disable toggles
  - Each policy shows: Type, provider, scope (namespaces), last updated
  - "Add Policy" button → wizard for signature verification, vulnerability gate, or third-party
- **Decisions Tab**: Recent admission decisions (allowed/denied) with filters
  - Table: Timestamp, Image, Namespace, Decision, Policy, Reason
  - Click row → detailed view with full pod spec, policy evaluation breakdown
- **Integrations Tab**: Marketplace of supported third-party solutions
  - Cards for Aqua, Prisma, Twistlock, Kyverno with "Enable" buttons
- **Diagnostics Tab**: Metrics dashboard
  - Admission rate (req/s), deny rate, latency p50/p95/p99
  - Top denied images, top denied namespaces

**Figma Design**: [Link to design mocks - TBD]

### Policy Experience

**Built-in Policy Definition 1: Require Signed Images**

```json
{
  "policyDefinitionId": "aks-require-signed-images",
  "displayName": "AKS clusters should only allow signed container images",
  "description": "Enforce that all container images deployed to AKS clusters have valid signatures from trusted signers.",
  "mode": "Indexed",
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
      "effect": "deployIfNotExists",
      "details": {
        "type": "Microsoft.ContainerService/managedClusters/admissionControl",
        "deployment": {
          "properties": {
            "template": {
              "resources": [
                {
                  "type": "Microsoft.ContainerService/managedClusters/admissionControl",
                  "properties": {
                    "policies": [
                      {
                        "policyType": "ImageSignatureVerification",
                        "enabled": true,
                        "config": {
                          "trustedSigners": "[parameters('trustedSigners')]"
                        }
                      }
                    ]
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

**Built-in Policy Definition 2: Block Critical Vulnerabilities**

Similar structure with `VulnerabilityGate` policy type.

**Policy Initiative: "AKS Supply Chain Security Baseline"**

Bundles:
- Require signed images
- Block critical vulnerabilities
- Require SBOM attestation (future)
- Enforce network policies (existing)

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Increase supply chain security adoption | % of AKS clusters with admission control enabled | 45% of production clusters by GA+6mo | P0 |
| 2   | Reduce security incidents | # of incidents from unverified/vulnerable images | 50% reduction in affected customers | P0 |
| 3   | Improve customer satisfaction | CSAT score for admission control feature | 4.5/5.0 | P0 |
| 4   | Drive ACR Premium adoption | # of ACR Premium registries with signing enabled | 30% increase QoQ | P1 |
| 5   | Enable third-party ecosystem | # of ISV integrations live | 5 partners (Aqua, Prisma, Twistlock, Kyverno, Falco) by GA | P1 |
| 6   | Reduce support burden | # of support tickets related to admission control | 40% reduction from baseline | P1 |
| 7   | Meet performance SLA | p95 admission latency | < 500ms | P0 |
| 8   | Achieve reliability SLA | Admission control service availability | 99.9% | P0 |

**Experiments**:
- **A/B Test**: Default admission control ON for new clusters (50% of regions) vs. OFF (control) → measure adoption and feedback
- **Canary**: Roll out to 10 early-adopter customers for feedback before public preview
- **Usability Study**: Observe 5 customers configuring admission control with think-aloud protocol → iterate on UX

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   | AKS API must support enabling/disabling admission control without direct cluster access | P0 |
| 2   | Support ACR image signature verification using Notation/Notary v2 | P0 |
| 3   | Support Azure Defender for Containers vulnerability scanning integration | P0 |
| 4   | Support third-party admission controller integrations (Aqua, Prisma, Twistlock) via partner API | P0 |
| 5   | Admission control configuration must be tamper-proof (not modifiable from within cluster) | P0 |
| 6   | Support namespace-scoped policy enforcement (include/exclude namespaces) | P0 |
| 7   | Provide "Audit" mode for testing policies without blocking deployments | P0 |
| 8   | Emit admission decision logs to Azure Monitor / Log Analytics | P0 |
| 9   | Support dry-run/test policy API for validating images before deployment | P1 |
| 10  | Integrate with Azure Policy for fleet-wide governance | P0 |
| 11  | Support image exemptions (allow-list) for specific images or registries | P1 |
| 12  | Provide CLI commands for all admission control operations | P0 |
| 13  | Provide Azure Portal UI for admission control configuration and monitoring | P0 |
| 14  | Support multiple concurrent policies (e.g., signature + vulnerability + custom) | P0 |
| 15  | Graceful degradation: If admission service unavailable, use fail-open or fail-closed mode (customer configurable) | P0 |
| 16  | Support SBOM attestation verification (future: P2) | P2 |
| 17  | Support custom OPA/Rego policy upload (future: P2) | P2 |

## Test Requirements 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   | Unit tests for all policy evaluator modules (signature, vulnerability, third-party) | P0 |
| 2   | Integration tests for AKS API → admission service → cluster API server flow | P0 |
| 3   | End-to-end tests for each supported policy type (signature, vulnerability, third-party) | P0 |
| 4   | Performance tests: 10,000 admission decisions/sec with <500ms p95 latency | P0 |
| 5   | Chaos testing: Admission service failure, network partition, control plane unavailability | P0 |
| 6   | Security testing: Attempt to bypass policies from within cluster (should fail) | P0 |
| 7   | Compatibility testing: All supported Kubernetes versions (1.28, 1.29, 1.30) | P0 |
| 8   | Third-party integration tests with Aqua, Prisma, Twistlock sandboxes | P0 |
| 9   | Scalability tests: 1000+ clusters with admission control enabled in single region | P1 |
| 10  | Disaster recovery tests: Admission service failover between regions | P1 |
| 11  | Upgrade tests: In-place upgrade of admission service without cluster disruption | P0 |
| 12  | Audit mode tests: Verify policies log violations without blocking | P0 |

# Dependencies and risks 

| No. | Requirement or Deliverable | Giver Team / Contact | Risk / Mitigation |
|-----|---------|---------|---------|
| 1   | ACR Notation signing API integration | ACR Team | **Risk**: ACR signing API changes; **Mitigation**: Joint API review, contract tests |
| 2   | Defender for Containers vulnerability scan results API | Defender Team | **Risk**: Latency in scan result retrieval; **Mitigation**: Caching layer, async pre-fetch |
| 3   | Azure Policy engine integration for fleet governance | Azure Policy Team | **Risk**: Policy evaluation latency; **Mitigation**: Pre-compiled policies, caching |
| 4   | Partner API contracts for Aqua, Prisma, Twistlock | ISV Partners | **Risk**: Partner delivery slips; **Mitigation**: Phased rollout, start with 2 partners for preview |
| 5   | AKS control plane infrastructure for admission service | AKS RP Team | **Risk**: Control plane capacity; **Mitigation**: Dedicated admission control pods, auto-scaling |
| 6   | Key Vault integration for signing key retrieval | Key Vault Team | **Risk**: Key Vault throttling; **Mitigation**: Key caching, rate limit handling |
| 7   | Log Analytics workspace for admission logs | Azure Monitor Team | **Risk**: Log ingestion limits; **Mitigation**: Sampling, customer-configurable verbosity |
| 8   | Kubernetes API server webhook latency tolerance | Upstream Kubernetes | **Risk**: Timeout if admission service slow; **Mitigation**: <500ms SLA, fail-open option |
| 9   | FedRAMP compliance certification | Compliance Team | **Risk**: Certification delays GA; **Mitigation**: Early engagement, parallel compliance work |
| 10  | CLI and Portal UX delivery | CLI/Portal Teams | **Risk**: UX slips behind API GA; **Mitigation**: API-first development, UX in parallel |

# Compete 

## GKE 

**Binary Authorization**:
- Built-in signing verification using asymmetric key pairs or Cloud KMS
- Integrates with Container Analysis API for vulnerability scanning
- Supports attestations (SLSA provenance, vulnerability scans)
- Control plane enforced, tamper-proof
- **Gaps**: Limited third-party integration, requires GCP-native tools

**GKE Policy Controller**:
- Managed OPA/Gatekeeper with pre-built policy library
- Integrated with GKE dashboard for compliance reporting
- **Gaps**: Requires Rego knowledge for custom policies

**Advantage AKS**: Better third-party ecosystem support, Azure-native integrations (ACR, Defender, Key Vault)

## EKS

**Amazon ECR Image Scanning**:
- Integrated vulnerability scanning with ECR
- Can block deployments via admission controller (customer-deployed)
- **Gaps**: Not control-plane enforced, requires manual setup

**AWS Signer + EKS Integration**:
- Sign images with AWS Signer, verify in EKS via admission controller
- **Gaps**: Requires deploying own admission webhook, not tamper-proof

**EKS Security Best Practices**:
- Guidance on deploying OPA, Kyverno, or third-party solutions
- **Gaps**: No managed admission control service

**Advantage AKS**: Fully managed, control-plane enforced solution vs. EKS DIY approach

---

**Differentiation Summary**:

| Capability | AKS (This PRD) | GKE | EKS |
|------------|----------------|-----|-----|
| Control-plane enforced | ✅ | ✅ | ❌ |
| First-party signing | ✅ (ACR Notation) | ✅ (Binary Auth) | ✅ (AWS Signer) |
| First-party vulnerability | ✅ (Defender) | ✅ (Container Analysis) | ✅ (ECR Scanning) |
| Third-party integration | ✅ (Aqua, Prisma, Twistlock) | ⚠️ (Limited) | ⚠️ (DIY) |
| Azure Policy integration | ✅ | ❌ | ❌ |
| Tamper-proof config | ✅ | ✅ | ❌ |
| Managed lifecycle | ✅ | ✅ | ❌ |
