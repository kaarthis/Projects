---
title: AKS Upgrade Guardrails: SLO‑Gated, Metric‑Aware Upgrades
wiki: ""
pm-owners: [kaarthis]
feature-leads: []
authors: [kaarthis]
stakeholders: []
approved-by: []
status: Draft
last-updated: 2025-08-08
---

# Overview

Before this feature, AKS customers had to hand‑craft blue/green flows and stitch alerts to decide whether to proceed or stop upgrades. Now, AKS customers can declare application SLO guardrails (Azure Monitor alerts and Prometheus rules) that the upgrade process enforces with canary and soak checks to automatically pause or abort on anomalies.

## Problem Statement / Motivation

AKS upgrades validate readiness signals (PDBs, probes, API breaks) but miss nuanced, post‑upgrade degradations that do not flip pod readiness immediately: latency regressions, error‑rate spikes, delayed OOMs after node moves, and cascading issues that surface over time. Customers either run quasi‑manual blue/green orchestrations with custom gates or rely on AKS Blue/Green nodepool upgrades rolling out later this year, which simplify cutover but are nodepool‑only and do not evaluate application SLO signals. Many lack the platform automation and observability maturity to do this reliably. We need upgrade‑integrated mechanisms to detect these problems and stop the operation.

Examples observed:
- Added application latency after an upgrade
- Increased error rate after version/image change
- Pods crashing/oomkilling minutes or hours after moving to upgraded nodes
- Cascading issues that manifest progressively across components

## Goals/Non-Goals

### Functional Goals
- Declare SLO guardrails via existing monitoring investments:
  - Azure Monitor alert rules (resource IDs)
  - Prometheus (Managed Prometheus or external) via rule names or PromQL
- Support preflight (checks before upgrade), canary (limited early upgrade phase—upgrade a subset of nodes/pods to catch issues before full rollout), and post-upgrade soak windows (monitoring after upgrade to detect delayed problems)
- On breach: pause or abort; optionally trigger agent pool rollback when available
- Log gating decisions/breaches for audit and diagnostics
- Azure Policy enablement to require guardrails in production
- Scope: Applies to regular rolling upgrades and to Blue/Green agent pool upgrades when available
- Node pool coverage: Supported for VMSS and VM‑based node pools

### Non-Functional Goals
- Guard decision loop P95 ≤ 2 minutes
- Security: https endpoints only; domain allowlist for external Prom; MSI for Azure Monitor; secrets via Key Vault refs
- Reliability: guard evaluation availability ≥ 99.9% during upgrades
- Telemetry: adoption, latency, breach precision/false‑positive rate

### Non-Goals
- No full blue/green traffic orchestration
- No control plane rollback (unsupported); agent pool rollback only when available
- No auto‑remediation of applications
- Does not replace AKS Blue/Green nodepool upgrades; complements them with SLO gating

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Developer / Cluster Owner | Microsoft.ContainerService/managedClusters/write; Microsoft.AlertsManagement/alerts/read | Reference existing alerts or Prom rules; upgrade pauses/aborts on breach. Success: No SLO breach escapes an upgrade. |
| Platform Operator | Microsoft.ContainerService/managedClusters/*; Microsoft.AlertsManagement/alerts/*; Microsoft.Insights/* | Define org defaults; enforce via policy; monitor compliance. Success: Safe upgrades at scale without bespoke pipelines. |

## Customers and Business Impact

Current Customer Impact (baseline):Mar - July 2025
| Issue Type                    | Number of Cases |
|-------------------------------|-----------------|
| Post-upgrade workload break   | 11              |
| Pods crashing or not ready    | 66              |
| Performance degradation       | 4               |
| Latency regressions           | 32              |
| Delayed memory spikes         | 12              |

In the last 4 months (March–July), there were 1,050 upgrade-related support cases. Of these, a significant portion were tied to workload breakage or post-upgrade latency/performance regressions, with issues often surfacing after upgrade completion rather than during the process.
- Heavy operator burden maintaining bespoke blue/green flows and manual canary gates; inconsistent coverage across teams.

Business Impact / OKR Alignment:
- Direct contribution to the internal “Workload SLO” OKR by preventing upgrade‑induced SLO breaches via automated gating.
- Upgrade CSAT baseline ≈ 160; targeted uplift through safer‑by‑default upgrades and fewer incidents.
- Expected outcomes: lower Sev2+ post‑upgrade volume, higher safe upgrade completion rate, reduced no‑fly time—tracked in Definition of Success.

## Existing Solutions or Expectations

- Customer‑built blue/green, manual canaries, ad‑hoc alert checks
- AKS Blue/Green Nodepool Upgrade (rolling out): native nodepool cutover; nodepool‑only; no app SLO gating; control plane unchanged
- 3P CD systems with health gates (not integrated into AKS upgrade engine)
- Gaps: fragmentation, high ops cost, no uniform governance, inconsistent quality

## What will the announcement look like?

Announcing SLO‑Gated, Metric‑Aware Upgrades for AKS

AKS upgrades can now honor your application SLOs. Reference Azure Monitor alert rules or Prometheus rules, configure canary/soak windows, and AKS will pause or abort upgrades on anomalies—no bespoke pipelines required. Public preview for agent pool upgrades this release; GA to follow after feedback.

**Addressing Key Challenges**
- Nuanced regressions (latency, error rate, delayed OOMs) missed by readiness checks
- High operational cost of bespoke blue/green pipelines; lack of governance
- Noise/false positives when alerts aren’t evaluated with warm‑up/debounce logic

**Functionality and Usage**
- Configure guardrails via API/CLI/Portal using existing Azure Monitor alerts and/or Prometheus rules
- Evaluate in preflight, canary, and post‑upgrade soak windows; on breach → pause/abort; optional agent pool rollback
- Works with AKS Blue/Green nodepool upgrades: guardrails gate canary and pre‑cutover phases

**Availability**
- Public Preview: agent pool upgrades (VMSS and VM node pools); control plane uses pause‑only (no rollback)
- GA target: adds built‑in policies and Managed Prometheus first‑class integration
- Blue/Green nodepool upgrades available later this year; guardrails complement, not replace

## Proposal

Options considered (concise):
1) Status quo (manual). No change; risk persists.  
2) Portal‑only checks. UI convenience, no IaC/policy.  
3) Native guardrails (Managed Prometheus only). Simplifies integration but excludes self‑hosted/external alert sources.  
4) Native guardrails (source‑agnostic, recommended). Supports Azure Managed Prometheus, self‑hosted Prometheus, and external providers.

**Options and Trade‑offs (concise)**
| Option | Pros | Cons | Decision |
|-------|------|------|----------|
| 1. Status quo | Zero engineering | Incidents persist; no governance | Rejected |
| 2. Portal‑only | Faster UX uplift | No IaC/policy; not automatable | Rejected |
| 3. Managed‑only guardrails | Simpler integration; tighter UX | Excludes ~14–15% self‑hosted Prom users; large enterprises depend on self‑hosted; Managed Prom adoption is low (≈2%) | Rejected |
| 4. Guardrails (source‑agnostic) | Meets customers where they are (Managed + self‑hosted + external); uses existing alerts; IaC + policy; composable | Broader integration surface | Recommended |

Rationale for 4: Adoption reality (self‑hosted Prom widely used by large enterprises; Managed Prom lukewarm). Source‑agnostic design minimizes friction, leverages existing alerts, integrates with the upgrade lifecycle, and scales with policy without forcing stack migration.

Breaking changes: None (opt‑in).  
Go‑to‑market: Preview (agent pools), iterate; GA with Azure Policy + Managed Prometheus first‑class.  

Pricing: Included; standard Azure Monitor/Prometheus costs apply.

False positives/noise mitigation: consecutive breaches, warm‑up suppression, debounce windows, cooldowns, and customer‑selected signals only.

Security posture: External endpoints require https + allowlisted domains; auth via Key Vault or workload identity; Azure Monitor via MSI.

## Observability & Troubleshooting Experience

### Failure Visibility & Diagnostics

- **Manual Upgrades:**
  - Failures due to guardrail breaches are shown in CLI/Portal with clear error messages: which SLO(s) breached, metric, threshold, observed value, and evaluation window.
  - Diagnostic logs and gating decision summaries are available via `az aks upgrade-guards show` and in the Portal diagnostics blade.
  - Users can review the decision timeline, including timestamps, signals, and breach rationale.
  - Retry: after fixing the root cause (e.g., alert resolved), users can re-initiate the upgrade from CLI/Portal.

- **Auto-Upgrades:**
  - Failures are logged in the cluster's activity log and surfaced in Azure Monitor, Comms manager (event details, breach context).
  - Notifications can be sent via Action Groups, comms manager if configured.
  - Retry: auto-upgrades do not auto-retry after a breach; customers must manually resume or re-trigger after review.

- **Level of Detail:**
  - Both manual and auto-upgrades provide: breached SLO name, metric, threshold, observed value, evaluation window, and recommended next steps.
  - Portal and CLI expose a diagnostics panel with evaluation history and links to alert rules.

## User Experience 

### API
Delta on Managed Cluster/Agent Pool upgrade policy (abbreviated):

```json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "enabled": true,
        "evaluation": {
          "preflightMinutes": 10,
          "canaryMinutes": 20,
          "soakMinutes": 60,
          "consecutiveBreachesRequired": 2
        },
        "actions": {
          "onBreach": "pause",
          "onBreachAgentPool": { "rollbackEnabled": true }
        },
        "azureMonitor": {
          "alertRuleIds": [
            "/subscriptions/.../resourceGroups/.../providers/microsoft.insights/metricAlerts/p95-latency-slo",
            "/subscriptions/.../resourceGroups/.../providers/microsoft.insights/metricAlerts/CPU Usage Percentage - AutoKaarerror-rate-slo"
          ]
          // scopeResourceId removed (implicit cluster scope inferred from upgrade context). Supply only in future if cross-scope evaluation is enabled.
        },
        "prometheus": {
          "mode": "managed",              // managed | external
          "ruleNames": ["HighErrorRate", "P95LatencySpike"]
        }
      }
    }
  }
}
```
**Contract: Customer vs AKS (with explicit inputs & references)**
- Azure Monitor (Customer provides): Existing alert rule resource IDs (metricAlerts, scheduledQueryRules, smartDetectorAlertRules) already firing on true SLO breaches. Docs: https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-types
- Managed Prometheus (Customer provides): Rule group(s) of Prometheus alerting rules (resource type `Microsoft.AlertsManagement/prometheusRuleGroups`) in the connected workspace; list the ruleNames to enforce. Docs: https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-rule-groups
- External / Self‑Hosted Prometheus (Customer provides):
  1. HTTPS endpoint exposing `/api/v1/alerts` (must be allow‑listed)
  2. Rule names to enforce (must appear in active alerts payload)
  3. Authentication secret reference (Key Vault secret / workload identity). Upstream alerting docs: https://prometheus.io/docs/alerting/latest/alerts/ ; KV secrets (CSI driver): https://learn.microsoft.com/azure/aks/csi-secrets-store-driver
  4. (Optional) CA bundle if using private PKI
- Security Inputs (Customer): domain allowlist entry (policy), secret reference, optional action groups for notifications.
- AKS Responsibilities: Poll sources during preflight/canary/soak, apply consecutive breach logic, decide pause/abort/rollback, emit diagnostics. Never mutates customer rules or thresholds.
- AKS Non‑Responsibilities: Creating/editing alert rules, changing thresholds, parsing raw PromQL for external endpoints beyond rule status, auto‑remediation.

**Property Explanations (concise)**
- (Required) healthGuards.enabled: Master switch.
- (Required) evaluation.preflightMinutes: Warm‑up/validation before any drain; avoids cold‑start noise. Upgrade pauses immediately if any required alert is already firing at preflight start.
- (Required) evaluation.canaryMinutes: Limited drain/traffic phase to catch early regressions.
- (Required) evaluation.soakMinutes: Post‑upgrade observation window to detect delayed/cascading issues.
- (Optional) evaluation.consecutiveBreachesRequired: Debounce against transient spikes (default 2 if omitted – to define in spec).
- (Required) actions.onBreach: pause | abort decision (default pause if omitted).
- (Optional) actions.onBreachAgentPool.rollbackEnabled: Blue/Green rollback mapping when supported.
- (Conditional Required) azureMonitor.alertRuleIds: ≥1 IDs if using Azure Monitor source.
- (Conditional Required) prometheus.mode: managed | external when Prometheus rules used.
- (Conditional Required) prometheus.ruleNames: ≥1 rule if prometheus.mode set.
- (Conditional Required) prometheus.endpoint: Required when mode=external.
- (Conditional Required) prometheus.auth.keyVaultSecretRef: If external endpoint requires auth.

### Defaults (P0) – concise
| Property | Type | Allowed / Range | Default (if omitted) | Required When | Mutable After Create? |
|----------|------|-----------------|----------------------|---------------|-----------------------|
| healthGuards.enabled | bool | true/false | false | Always (customer sets) | Yes |
| evaluation.preflightMinutes | int | 0–60 | 10 (if enabled & omitted) | enabled=true | Yes (not mid-phase) |
| evaluation.canaryMinutes | int | 5–180 | 20 (if omitted) | enabled=true | Yes (only before canary start) |
| evaluation.soakMinutes | int | 10–360 | 60 (if omitted) | enabled=true | Yes (only before soak start) |
| evaluation.consecutiveBreachesRequired | int | 1–5 | 2 | enabled=true | Yes |
| actions.onBreach | enum | pause | abort | pause | enabled=true | No (per-upgrade immutable) |
| actions.onBreachAgentPool.rollbackEnabled | bool | true/false | false | Blue/Green scenario | No (for running upgrade) |
| azureMonitor.alertRuleIds[] | array<string> | 1–32 IDs | – (no default) | Using Azure Monitor source | Yes |
| prometheus.mode | enum | managed | external | – (unset) | Using Prometheus source | Yes |
| prometheus.ruleNames[] | array<string> | 1–32 names | – (no default) | prometheus.mode set | Yes |
| prometheus.endpoint | string (URL) | https scheme, <=2083 chars | – | prometheus.mode=external | Yes |
| prometheus.auth.keyVaultSecretRef | string | Valid KV secret ID | – | External endpoint requires auth | Yes |
| rollbackEnabled (agent pool) | bool | true/false | false | Blue/Green scenario | No (per-upgrade) |

Notes:
- Mutation constraints: values cannot be changed for a phase already in progress (e.g., cannot reduce canaryMinutes after canary started). Service rejects with 409.
- Arrays max (32) sized to bound evaluation latency; larger sets require future quota increase.
- Omitted required fields result in 400 (ValidationError) before operation starts.
- Fail-closed: source unreachable > retry budget → pause (state reason=SourceUnreachable).

**Validation (musts)** (unchanged summary)
- If enabled: at least one source (azureMonitor.alertRuleIds OR prometheus.ruleNames) present.
- Control plane: onBreach → pause only.
- External Prom: https + allowlisted domain + valid auth secret.
- Rollback only when agent pool Blue/Green supported.

### Customer Contract (TL;DR)
| Source | Customer Provides (Required) | Optional | AKS Reads Only | Docs |
|--------|------------------------------|----------|----------------|------|
| Azure Monitor | alertRuleIds (metricAlerts / scheduledQueryRules / smartDetector) | Action Group IDs | Firing status | https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-types |
| Managed Prometheus | ruleNames (must exist in prometheusRuleGroups) | – | Rule firing state | https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-rule-groups |
| External Prometheus | HTTPS endpoint (/api/v1/alerts), ruleNames, auth secret ref, allowlisted domain | CA bundle (private PKI) | Active alerts JSON | https://prometheus.io/docs/alerting/latest/alerts/ |
| Common | evaluation windows, onBreach action | rollbackEnabled (agent pool) | Evaluation outcomes | (above) |

### Customer Pre‑Upgrade Checklist (Quick)
- Collected all alertRuleIds / ruleNames (stable names; no impending rename)
- All SLO alerts currently healthy (not firing)
- Auth secret stored in Key Vault; AKS MSI has get permission (scoped to secret)
- External endpoint (if used) returns 200 JSON for /api/v1/alerts within timeout (<5s)
- Domain on organization allowlist (policy)
- Policy exemptions (if any) approved

### Identity (Minimum Permissions)
- AKS Managed Identity / workload identity needs:
  - Key Vault: secrets/get on specific secret(s)
  - Azure Monitor: read on alert rule resources (Microsoft.Insights/* read, Microsoft.AlertsManagement/* read where applicable)
  - Prometheus rule groups: Microsoft.AlertsManagement/prometheusRuleGroups/read

### Networking (External Endpoint Minimums)
1. TLS 1.2+ valid cert (or provide CA bundle)
2. FQDN allowlisted by policy
3. Only /api/v1/alerts exposed (least surface)
4. 5s server-side timeout + rate limiting (AKS pauses on timeout)
5. Auth via Key Vault secret (no static inline tokens)

(Advanced hardening: mTLS, WAF, Private Link, rotation cadence – defer to Appendix if needed.)

### Use Case Scenarios

#### 1. Managed Alert Rules (Azure Monitor)
**Prerequisites (Customer provides):** Existing latency & error-rate Azure Monitor alert rules (IDs); optional action group.
**Steps:**
1. Locate alert rule IDs (Portal: Monitor > Alerts > Alert rules > select rule > JSON View / Resource ID).
2. Enable guardrails referencing IDs via CLI/Portal.
3. AKS evaluates status each window; pauses on consecutive breaches.
4. Customer remediates & resumes.
**Monitoring:** `az aks upgrade-guards show`, Portal Alerts blade.
**Docs:** Azure alert rule types https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-types

API Example (Request - PATCH cluster):
```http
PATCH https://management.azure.com/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "enabled": true,
        "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
        "actions": { "onBreach": "pause" },
        "azureMonitor": {
          "alertRuleIds": [
            "/subscriptions/{subId}/resourceGroups/{rg}/providers/microsoft.insights/metricAlerts/p95-latency-slo",
            "/subscriptions/{subId}/resourceGroups/{rg}/providers/microsoft.insights/scheduledQueryRules/error-rate-slo"
          ]
        }
      }
    }
  }
}
```
API Example (Response excerpt - GET cluster after configuration):
```json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "state": "Configured",
        "lastEvaluation": {
          "phase": "preflight",
          "windowStart": "2025-08-12T10:00:00Z",
            "alerts": [
              {"id": "/subscriptions/.../metricAlerts/p95-latency-slo", "firing": false},
              {"id": "/subscriptions/.../scheduledQueryRules/error-rate-slo", "firing": false}
            ]
        }
      }
    }
  }
}
```

#### 2. Managed Prometheus (Rule Groups)
**Prerequisites (Customer provides):**
- Managed Prometheus enabled (workspace connected to cluster)
- Prometheus rule group with alerting rules (e.g., HighErrorRate, P95LatencySpike)
- Rule names to enforce
**Where to find rule names:** Portal: Monitor > Metrics (Prometheus) > Rule groups > open group > list of alert rules (Name column). Alternatively ARM: GET rule group resource (names appear under `properties.rules.name`).
**Steps:**
1. Create / verify rule group (Docs: https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-rule-groups) with SLO rules.
2. Collect rule names to enforce (ensure severity & labels stable).
3. Enable guardrails with mode managed and ruleNames list:
   ```sh
   az aks upgrade -g myRG -n myCluster --kubernetes-version X --enable-upgrade-guards \
     --guards-prom-mode managed --guards-prom-rule-names HighErrorRate P95LatencySpike \
     --guards-preflight 10 --guards-canary 20 --guards-soak 60 --guards-consecutive 2
   ```
4. AKS polls Managed Prometheus alert status; pauses on breaches.
5. Customer inspects alert (Portal: Monitor > Alerts or Prometheus rule groups blade), resolves issue, resumes.
**Docs:** Rule groups creation https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-rule-groups

API Example (Request - PATCH cluster):
```http
PATCH https://management.azure.com/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "enabled": true,
        "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
        "actions": { "onBreach": "pause" },
        "prometheus": { "mode": "managed", "ruleNames": ["HighErrorRate", "P95LatencySpike"] }
      }
    }
  }
}
```
API Example (Response excerpt - evaluation snapshot):
```json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "lastEvaluation": {
          "phase": "canary",
          "ruleStatuses": [
            {"name": "HighErrorRate", "firing": true, "consecutiveCount": 1},
            {"name": "P95LatencySpike", "firing": false, "consecutiveCount": 0}
          ],
          "decision": "continue"
        }
      }
    }
  }
}
```

#### 3. External Prometheus (Self‑Hosted Endpoint)
**Required Inputs (Customer):**
- Networking:
    - HTTPS only (TLS 1.2+), dedicated DNS (e.g., https://prom.example.com); validate cert + hostname.
    - Expose only /api/v1/alerts; no other admin paths on same host.
    - Restrict inbound (Private Link / internal LB / firewall); if public, front with WAF; deny 0.0.0.0/0 except 443.
    - Outbound evaluator egress via controlled path (Firewall) with FQDN allowlist (prom.example.com).
    - Apply NSGs + network policies to block lateral movement.

- Identity & Secrets:
    - AKS evaluator uses managed (or workload) identity to pull secrets (Key Vault); no static creds in config.
    - Prefer short‑lived OIDC / scoped token; rotate ≤90 days; store/rotate in Key Vault (soft delete + purge protection).
    - Optional mTLS (client cert/key from Key Vault CSI); scope KV access to specific secret versions.

- External Endpoint Access & Hardening:
    - Enforce TLS 1.2+, certificate pin/chain validation; separate hostname if other APIs required.
    - Rate limit + timeout; return 429/503 for backoff; AKS fails closed (pause) on errors/timeouts.
    - Domain allowlisted via Azure Policy; block unapproved hosts.
    - Minimal alert payload (rule name, labels); exclude PII.
**Optional Inputs:** CA bundle secret if private CA.
**Steps:**
1. Ensure endpoint exposes `/api/v1/alerts` (curl https://prom.example.com/api/v1/alerts).
2. Confirm target alert rules exist (Prometheus UI > Alerts) and names match desired SLOs.
3. Store auth token in Key Vault (Docs: https://learn.microsoft.com/azure/key-vault/secrets/ ) and reference via secret provider (CSI: https://learn.microsoft.com/azure/aks/csi-secrets-store-driver ).
4. Enable guardrails:
   ```sh
   az aks upgrade -g myRG -n myCluster --kubernetes-version X --enable-upgrade-guards \
     --guards-prom-mode external --guards-prom-endpoint https://prom.example.com \
     --guards-prom-auth-keyvault <kvSecretRef> \
     --guards-prom-rule-names HighErrorRate P95LatencySpike \
     --guards-preflight 10 --guards-canary 20 --guards-soak 60 --guards-consecutive 2
   ```
5. AKS polls endpoint; pauses/aborts on consecutive breaches.
6. Customer reviews breach (CLI diagnostics), fixes issue, retries.
**Docs:** Upstream alerts https://prometheus.io/docs/alerting/latest/alerts/

API Example (Request - PATCH cluster):
```http
PATCH https://management.azure.com/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "enabled": true,
        "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
        "actions": { "onBreach": "abort" },
        "prometheus": {
          "mode": "external",
          "endpoint": "https://prom.example.com",
          "auth": { "keyVaultSecretRef": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kv}/secrets/prom-token" },
          "ruleNames": ["HighErrorRate", "P95LatencySpike"]
        }
      }
    }
  }
}
```
API Example (Response excerpt - breach causing pause):
```json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "state": "Paused",
        "pauseReason": {
          "phase": "soak",
          "breaches": [
            {"ruleName": "HighErrorRate", "firing": true, "observedValue": 0.12, "threshold": 0.05, "consecutiveCount": 2}
          ],
          "action": "abort"
        }
      }
    }
  }
}
```

**/api/v1/alerts Expected Shape (excerpt)**
```json
{
  "status": "success",
  "data": {
    "alerts": [
      { "labels": { "alertname": "HighErrorRate" }, "state": "firing" },
      { "labels": { "alertname": "P95LatencySpike" }, "state": "inactive" }
    ]
  }
}
```
AKS matches alertname to provided ruleNames; firing|inactive used for breach evaluation.

### CLI Experience
- Failure output: summarizes breached guardrails (alert/rule name, observed vs threshold, phase, action) and points to diagnostics: az aks upgrade-guards show -g <rg> -n <cluster>
- Enable with Azure Monitor + Managed Prometheus example:
    az aks upgrade -g rg -n c --kubernetes-version X --enable-upgrade-guards \
        --guards-preflight 10 --guards-canary 20 --guards-soak 60 --guards-consecutive 2 \
        --guards-action pause \
        --guards-azmon-alert-ids /subscriptions/.../metricAlerts/p95-latency-slo /subscriptions/.../scheduledQueryRules/error-rate-slo \
        --guards-prom-mode managed --guards-prom-rule-names HighErrorRate P95LatencySpike \
        --guards-agentpool-rollback true
- External Prometheus example (abort on breach):
    az aks upgrade -g rg -n c --kubernetes-version X --enable-upgrade-guards \
        --guards-preflight 10 --guards-canary 20 --guards-soak 60 --guards-consecutive 2 \
        --guards-action abort \
        --guards-prom-mode external --guards-prom-endpoint https://prom.example.com \
        --guards-prom-auth-keyvault /subscriptions/.../vaults/myKv/secrets/prom-token \
        --guards-prom-rule-names HighErrorRate P95LatencySpike
- Inspect last decision / breach timeline:
    az aks upgrade-guards show -g rg -n c

### Portal Experience
- Upgrade wizard: SLO guardrails toggle (disabled by default unless organizational policy enforces)
- Select alert sources: Azure Monitor alert rules (multi-select) and/or Prometheus rule names (managed or external endpoint config)
- Configure: preflight, canary, soak minutes; consecutive breaches; action (pause | abort), optional agent pool rollback
- Preview panel: enumerates selected signals, evaluation windows, and resulting stop conditions
- On breach: banner details phase, rule(s), counts, chosen action; Resume / Abort buttons gated by RBAC
- Diagnostics blade: chronological evaluation events (timestamp, phase, rule statuses, decision) + export
- Blue/Green agent pool: guardrails wrap canary slice and pre‑cutover; rollback option visible only if supported

### Policy Experience
Built‑in (planned) policies:
- Require healthGuards.enabled = true for production (alias: Microsoft.ContainerService/managedClusters/upgradePolicy.healthGuards.enabled)
- Audit required Azure Monitor alert IDs present (alias: .../healthGuards.azureMonitor.alertRuleIds[*])
- Audit required Prometheus rule names present (alias: .../healthGuards.prometheus.ruleNames[*])
- Deny external prometheus.endpoint domains not on allowlist
- DeployIfNotExists: stamp org defaults (enabled, evaluation windows, prometheus.mode) via aliases: 
    - .../healthGuards.enabled
    - .../healthGuards.evaluation.preflightMinutes
    - .../healthGuards.evaluation.canaryMinutes
    - .../healthGuards.evaluation.soakMinutes
    - .../healthGuards.evaluation.consecutiveBreachesRequired
    - .../healthGuards.prometheus.mode
Automatic upgrade defaults (policy-driven POV):
- Prod: baseline (10/20/60 minutes; consecutive=2; action=pause; latency + error alerts required). Opt‑out via exemption.
- Non‑prod: disabled unless opted in.
- Fleet/subscription policy can override windows, required rule sets.

Example (conceptual) deny policy snippet (external endpoint domain allowlist):
```
Deny if: healthGuards.prometheus.mode == "external" AND
  domain(extract(healthGuards.prometheus.endpoint)) NOT IN ["prom.example.com","prom.corp.local"]
```
(Implemented via policy rule conditions + alias for endpoint when exposed.)

# Definition of Success

## Expected Impact: Business, Customer, Technology

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|---------|
| 1 | Fewer upgrade-induced incidents | Post-upgrade Sev2+ tied to upgrades | -50% in 6 months | High |
| 2 | Safer, faster upgrades | % upgrades with zero manual pause (customer initiated) | +30% in 2 quarters | High |
| 3 | Adoption | % prod clusters with guardrails enabled | 70% in 2 quarters | High |
| 4 | Detection quality | Breach precision TP/(TP+FP) | ≥80% | High |
| 5 | Latency | Decision loop P95 | ≤2 min | Medium |

# Requirements

## Functional Requirements
| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Configure healthGuards via API/CLI/Portal | High |
| 2 | Azure Monitor alert rule integration (IDs) | High |
| 3 | Prometheus integration (managed + external with auth) | High |
| 4 | Evaluation windows: preflight, canary, soak + consecutive breach logic | High |
| 5 | Actions: pause | abort; agent pool rollback toggle (where supported) | High |
| 6 | Structured decision & breach logging (phase, rule, value) | High |
| 7 | Policy: require / audit / deny / DeployIfNotExists | Medium |
| 8 | Noise controls: warm-up suppression, debounce, cooldown | Medium |
| 9 | External endpoint security: TLS, allowlist, Key Vault / MI auth | High |
| 10 | Safe default on evaluator errors (fail closed → pause) | High |

## Observability & Troubleshooting Requirements
| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Detailed breach diagnostics (CLI/Portal) | High |
| 2 | Log every decision (continue, pause, abort, rollback) with metadata | High |
| 3 | Manual resume after remediation | High |
| 4 | Auto-upgrade failures surfaced in Activity Log, Alerts, Comms manager | High |
| 5 | Actionable messages with next steps + direct rule links | High |

## Test Requirements
| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | E2E across sources (Azure Monitor / managed / external Prom) | High |
| 2 | Scale: concurrent guarded upgrades (≥1000 pools) | High |
| 3 | False-positive resilience (debounce, consecutive counts) | High |
| 4 | Security: endpoint validation, secret access (KV/MI), TLS enforcement | High |
| 5 | Control plane vs agent pool variance (pause-only vs rollback) | Medium |
| 6 | Rollback correctness on agent pool breach | High |
| 7 | Fail-closed paths (timeouts, auth errors) cause pause not silent pass | High |

# Dependencies and Risks

| No. | Deliverable | Giver Team |
|-----|------------|------------|
| 1 | Alerts API stability / permissions | Azure Monitor |
| 2 | Managed Prometheus rule status APIs | Azure Monitor |
| 3 | ARM schema + SDK updates | ARM / SDK |
| 4 | CLI & Portal feature surfaces | Azure CLI / Portal |
| 5 | Agent pool rollback hooks | AKS Runtime |

Key risks & mitigations:
- False positives → warm-up + consecutive breach + cooldown
- External endpoint instability → timeout/backoff + fail-closed (pause) + metrics
- Security (exfiltration / weak auth) → TLS + allowlist + Key Vault + scoped MI
- Control plane no rollback → enforced pause-only with guidance
- Poor alert quality → baseline SLO templates + docs on tuning precision
- Scale contention (polling overhead) → adaptive polling cadence, batching, per-source jitter

# Compete

## GKE
- Offers upgrade strategies (surge, blue/green under maintenance) but no native integration of customer SLO alert gating.
## EKS
- Relies on external tooling / custom pipelines for SLO gating; no first-class customer alert integration in managed upgrade flow.
Competitive advantage: Integrated, policy-governable SLO guardrails (Azure Monitor + Prometheus) embedded in managed upgrade lifecycle with rollback hooks and diagnostics.

## Appendix: FAQ (Concise)

Q: Why support self-hosted Prometheus now?
A: Enterprise reality: significant subset (≈15%) relies on self-hosted for control, regulatory, air-gapped, or existing taxonomy reasons. Source-agnostic lowers friction and accelerates adoption.

Q: Is this intended to drive Managed Prometheus adoption?
A: Primary goal is safer upgrades. Managed Prom ease-of-use may yield modest uplift, but design remains source-agnostic to avoid vendor lock friction.

Q: What if no accessible Prometheus endpoint exists?
A: Use existing Azure Monitor metric/log alerts, or expose a secured endpoint (Private Link / allowlist). Without a reachable source, Prom-based signals cannot participate.

Q: Why not rely solely on readiness/liveness probes?
A: Probes detect binary pod health, not latency/error regressions, delayed OOM, or cascading failures. Aggregated SLO alerts provide earlier, actionable degradation signals.

Q: Can other vendors (e.g., Datadog) integrate?
A: Yes, if they expose an HTTPS endpoint mapping defined rule names to firing state. Future connectors can optimize discovery.

Q: How is authentication handled for private endpoints?
A: HTTPS + domain allowlist + Key Vault secret or managed identity. Private Link or in-cluster evaluator (future phase) for truly private networks.

Q: How are false positives minimized?
A: Warm-up suppression, consecutive breach threshold, debounce/cooldown, and (recommended) correlation with upgrade phase metrics (e.g., node upgrade progress) to filter ambient noise.

Q: What happens on evaluator or source errors?
A: Fail-closed: upgrade pauses (never silently passes), surfaced with error context for remediation.

Q: How does rollback differ from pause?
A: Pause halts progress; rollback (agent pool Blue/Green only) reverts traffic/primary designation to previous pool; control plane only supports pause.

