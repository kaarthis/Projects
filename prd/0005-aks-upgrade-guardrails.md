---
title: AKS Upgrade Guardrails: SLO‑Gated, Metric‑Aware Upgrades
wiki: ""
pm-owners: [kaarthis, Shashank]
feature-leads: []
authors: [kaarthis]
stakeholders: [Simon Stephane Wenjun Yi Liqian Jorge]
approved-by: []
status: Draft
last-updated: 2025-08-13
---

# Overview

Before this feature, AKS customers hand‑crafted blue/green or rolling flows and manually watched dashboards/alerts to decide whether to continue or stop an upgrade. Now, customers declare application and platform SLO guardrails through a simple, source‑agnostic Gate Signal API. The API supports:
- Managed Azure Monitor metrics/alerts (first‑class managed option, including Node Problem Detector and Managed Prometheus)
- Bring‑your‑own (BYO) endpoints: self‑hosted Prometheus, OpenTelemetry collectors,  webhooks, or CRD‑aggregated health inside the cluster

The upgrade engine evaluates these signals during preflight, canary, and post‑upgrade windows and will automatically abort—or roll back agent pools—on sustained anomalies. Gate lifecycle (attach, evaluate, decide) is cleanly separated from signal providers, so adding or swapping a monitoring backend does not require reauthoring gates.

## Problem Statement / Motivation

Built‑in AKS readiness checks (API, scheduling, quota, PDB) miss nuanced or delayed degradations (latency creep, error spikes, memory leaks) that emerge minutes or hours after node replacement or control plane changes. Operators today must babysit metrics and manually time an abort, increasing toil and risk. Blue/Green mechanics (drain batches, soak, cutover) improve safety but still lack integrated, metrics‑based intervention.

We need first‑class, SLO‑aware guardrails:
- Preflight: block starting when baseline health is already poor
- Canary / per‑batch: catch early regressions before broad exposure
- Post‑upgrade: detect delayed failures (e.g., OOM, latency growth)
- Control plane: pre and post abort‑only gates to prevent risky control plane actions when SLOs are failing

Extensibility (day one, not deferred):
- A minimal, versioned Gate Signal schema normalizes inputs (status, value, threshold context, timestamps)
- Any signal source can integrate via:
  - Direct Azure Monitor lookup (managed path)
  - Signed webhook adapter that posts normalized evaluations
  - In‑cluster CRD (e.g., ClusterHealthEntry) aggregated into a composite status
  - Polling or push adapters for self‑hosted Prometheus / OTEL pipelines

Example upgrade pain points:
- Latency regressions after partial rollout
- Error‑rate spikes tied to version/image change
- OOM / crashloop patterns appearing after canary window
- Cascading dependency failures unfolding over time

## Goals / Non-Goals

### Functional Goals
- Provide SLO‑gated upgrades for agent pools with preflight, canary, and post phases; on breach → abort or rollback (when rollback supported)
- Provide control plane pre and post gates (abort‑only)
- Support Azure Monitor (managed) including Node Problem Detector and Managed Prometheus, plus BYO endpoints (Prometheus, OTEL, webhook, CRD aggregator) from the start through a uniform Gate Signal contract
- Allow multiple reusable gate resources bound to clusters via RBAC + Azure Policy
- Support managed service mesh scenarios (L7 latency, error rate, retry/circuit breaker metrics, mTLS status) without app changes
- Produce auditable, durable evaluation and breach events with clear timelines
- Operate independently of pacing/soak mechanics and respect maintenance windows
- Offer a documented adapter contract (schema + auth + idempotency) for any external or in‑cluster publisher to emit normalized health evaluations

### Non-Goals
- No fleet‑level multi‑cluster orchestration or ordering logic
- No automated traffic shifting or full blue/green traffic management (upgrade engine only)
- No application auto‑remediation (we stop / rollback only)
- No policy‑driven alert authoring (policy governs gate attachment, not signal definition)
- No guarantee of rollback for control plane (abort‑only by design)
- No custom business workflow engine (decisions limited to proceed / hold / abort / rollback)


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

Managed Prometheus Adoption (Feb 16–Aug 13, 2025)
- Internal clusters:
  - Start: 12,695
  - End: 16,797
  - Growth: +4,102
- External clusters:
  - Start: 23,858
  - End: 31,536
  - Growth: +7,678

This strong and consistent growth across internal and external environments underscores increasing reliance on Managed Prometheus for observability at scale—making a compelling case for continued investment.

Business Impact / OKR Alignment:
- Direct contribution to the internal “Workload SLO” OKR by preventing upgrade‑induced SLO breaches via automated gating.
- Upgrade CSAT baseline ≈ 160; targeted uplift through safer‑by‑default upgrades and fewer incidents.
- Expected outcomes: lower Sev2+ post‑upgrade volume, higher safe upgrade completion rate, reduced no‑fly time—tracked in Definition of Success.

## Existing Solutions or Expectations

- Customer‑built blue/green, manual canaries, ad‑hoc alert checks
- AKS Blue/Green Nodepool Upgrade (rolling out): native nodepool cutover; nodepool‑only; no app SLO gating; control plane unchanged
- 3P CD systems with health gates (not integrated into AKS upgrade engine)
- Gaps: fragmentation, high ops cost, no uniform governance, inconsistent quality

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Developer / Cluster Owner | Microsoft.ContainerService/managedClusters/write; Microsoft.AlertsManagement/prometheusRuleGroups/read | Reference existing Managed Prometheus alert rules; upgrade aborts or rolls back (agent pools) on breach. Success: No SLO breach escapes an upgrade. |
| Platform Operator | Microsoft.ContainerService/managedClusters/*; Microsoft.AlertsManagement/prometheusRuleGroups/* | Define org defaults; enforce via policy; monitor compliance. Success: Safe upgrades at scale without bespoke pipelines. |

## User Stories

The user stories below are implementation‑agnostic and ensure support pre/during/post gates, prefer an extensible signal model (Prometheus first, CRD/webhook extensibility later), and cover key personas (cluster operator, app developer).

| Persona | Story ID | User Story | Acceptance Criteria |
|---------|---------:|-----------|---------------------|
| Cluster Operator | CO-1 | As a Cluster Operator, I want to attach one or more named gates to a planned upgrade and reuse centrally managed gates so AKS evaluates health pre/during/post upgrade and org policies are enforced consistently. | Gates can be bound to an upgrade; evaluations occur at pre/during/post phases; a gate resource can be referenced by multiple clusters; gate references are enforceable via Azure Policy/RBAC; per-run evaluation sessions are materialized and queryable. |
| Cluster Operator | CO-2 | As a Cluster Operator, I want automated rollback and auditable diagnostics when an upgrade fails so I can restore health quickly and investigate root cause. | Configured agent‑pool rollback triggers on sustained breach; decisions (proceed/abort/rollback), timestamps, correlation IDs, evaluation snapshots and breach context are recorded and queryable for post‑mortem. |
| Application Developer | AD-1 | As an App Developer, I want to express my service SLOs with a simple signal format and avoid noisy aborts so upgrades are blocked only on meaningful degradations. | Gates can reference Managed Prometheus rule groups or equivalent aggregated signals; support aggregation windows, debounce/consecutive thresholds, and sampling hints; breach events include rule name, observed value, window, and sample density; defaults favor conservative, low‑cardinality rules. |

Acceptance criteria common to all stories:
- Gate evaluations produce durable, queryable events (evaluations & breaches) with timestamps, correlation IDs, and diagnostic context.
- Gate decisions (proceed/abort/hold/rollback) are exposed to CLI/Portal/API and are auditable in activity logs.
- Gate modes: either Fully Managed (Managed Prometheus / Azure Monitor rule groups) or Bring‑Your‑Own (self‑hosted Prometheus, OpenTelemetry, signed webhooks, in‑cluster CRDs). The Gate Signal adapter contract (schema, auth, idempotency, sample/window hints) and the normalized evaluation tuple ensure durable, auditable events and identical decision semantics regardless of provider. Tenants select managed or BYO via policy/CLI without changing gate behavior.
- Security model and RBAC principals for gate management and signal publishing are defined at a high level (detailed RBAC design is a follow-up task).


## **Proposals

### OPTION A : Extensible and Vendor-Agnostic Upgrade Gates via Custom Resources**

### **Objective**
To define a flexible, extensible, and vendor-neutral mechanism for upgrade gating in AKS and non-AKS Kubernetes clusters—including service mesh scenarios. The goal is to enable pre-, during-, and post-upgrade validation through declarative gate definitions and evaluations, supporting both managed and self-managed observability stacks, and mesh-specific health signals.

### **Design Principles**
- **Extensibility**: Support a wide range of upgrade gate definitions and evaluation strategies, including mesh control plane and data plane health.
- **Vendor Agnosticism**: Avoid tight coupling with Azure-specific APIs or tooling; support external sources (Prometheus, Datadog, etc.) via adapters.
- **Cluster and Mesh Independence**: Enable consistent behavior across AKS, non-AKS clusters, and mesh deployments.
- **Declarative Configuration**: Use Kubernetes-native constructs (CRDs) to define and manage gates, with a normalized evaluation contract for all sources.

### **Architecture Overview**

#### **1. Gate Definition (Custom Resource)**
- A Kubernetes Custom Resource (CR) defines the upgrade gate.
- This CR includes:
  - **Gate name and description**
  - **Health criteria** (e.g., Prometheus query, webhook endpoint, mesh-specific metrics)
  - **Scope** (cluster-wide, node pool, namespace, mesh control/data plane)
  - **Evaluation mode**: `Managed`, `Self-managed`, or `None`
  - **Adapters**: Managed, webhook, or external (e.g., Datadog, mesh telemetry)

#### **2. Gate Evaluation (Custom Resource)**
- A separate CR type captures the evaluation result of each gate.
- This CR includes:
  - **Gate reference**
  - **Evaluation timestamp**
  - **Status**: `Pass`, `Fail`, `Pending`
  - **Diagnostics**: Optional logs or metrics
  - **Health summary**: Node, cluster, and mesh health as applicable

#### **3. Integration Model**
- **Custom Resource (CR)**:
  - Provides a generic, Kubernetes-native model applicable to both AKS and non-AKS clusters, and mesh deployments.
  - Enables community-driven contributions and extensibility, including mesh-specific adapters.
- **ARM API**:
  - Used solely for **mode enablement**—to toggle gating behavior via an enum (disabled, managed, byo, hybrid).
  - Does **not** define or manage gates directly.
  - Example: `operationGateConfig.mode: "hybrid"` in ARM signals the RP to look for CRs in the cluster, including mesh gates.

#### **4. Endpoint and Authentication**
- Each Gate CR may specify an **evaluation endpoint** and **authentication method** (e.g., webhook with token, mesh telemetry adapter).
- The RP (Resource Provider) pulls from a **well-defined, discoverable endpoint list** to evaluate gates post-upgrade action.

#### **Mesh Applicability**
- Gates can be defined for mesh control plane upgrades, mesh data plane health, and mesh-specific SLOs (latency, mTLS, error rate, etc.).
- The same CRD contract applies: mesh adapters publish normalized evaluation results, enabling mesh upgrades to be gated by custom or managed health signals.
- Customers can use managed mesh metrics, custom mesh telemetry, or external mesh observability platforms (e.g., Datadog, New Relic) via adapters.

#### ✅ **Pros**
- **Kubernetes-Native**: CR-based design aligns with Kubernetes extensibility patterns and mesh architectures.
- **Mesh and Cluster Compatibility**: Works across AKS, non-AKS clusters, and mesh deployments.
- **Community-Friendly**: Encourages open-source contributions and vendor-neutral adoption, including mesh adapters.
- **Flexible Evaluation**: Supports managed, self-managed, and mesh-specific setups.
- **Separation of Concerns**: ARM API is used only for enablement, keeping gate logic within the cluster and mesh.

#### ❌ **Cons**
- **Operational Complexity**: Self-managed mode requires users to deploy and maintain gate controllers and mesh adapters.
- **Learning Curve**: CRD-based configuration may be unfamiliar to some users.
- **Debugging Overhead**: Failures in gate evaluation may be harder to trace without centralized tooling.
- **Limited ARM Visibility**: ARM API does not expose gate definitions or evaluations, which may limit portal integration.

### Option B : Dedicated Upgrade Gate Resource (Versioned, Reusable)

#### Summary
Introduce a first-class ARM child resource: `Microsoft.ContainerService/upgradeGates/{gateName}`.  
A gate holds a versioned, declarative contract describing:
- Which signal sources (initially Azure Managed Prometheus rule groups; later additional providers/adapters) are authoritative
- Phase bindings (preflight, canary, post) and per-phase evaluation windows, debounce/consecutive breach criteria, and permitted actions (proceed / hold / abort / rollback where supported)
- Optional global behaviors (fail‑closed policy, evaluation cadence hints, max decision latency)

Clusters (or specific upgrade operations) attach one or more existing gates via lightweight references. Each upgrade run materializes ephemeral “evaluation sessions” that:
- Snapshot the referenced gate spec (with a spec hash/version)
- Produce periodic Evaluation records (status per rule group / phase)
- Emit Breach events when gating conditions are met (including synthetic fail‑closed breaches)
- Record a final Decision object (proceed / abort / rollback) with traceability (correlation IDs, timestamps)

Adapters or future providers (e.g., webhook publisher, CRD aggregator, self‑hosted Prometheus bridge) normalize their raw signals into a stable internal tuple: (gateId, phase, ruleGroupId | sourceId, status, observedValue, thresholdContext, timestamp, metadata). This preserves a consistent engine path independent of signal origin.

#### Key Characteristics
- Reusable: One authored gate can be bound by many clusters (governed via RBAC + Policy)
- Versioned: Spec changes create a new revision; sessions reference the exact revision used
- Auditable Separation of Intent vs Execution: Gate spec = intent; evaluations/breaches/decision = execution artifacts
- Extensible: New providers integrate by publishing normalized evaluations—no upgrade API churn
- Governable: Policy targets gate resources directly (enforce required gates, disallow unapproved ones)
- Minimal Runtime Coupling: Pacing/soak strategies remain outside the gate; gate only answers “is it still safe?”

#### Pros
- Strong governance & compliance: Distinct resource enables Policy, RBAC granularity, inventory, drift detection
- Reuse & DRY: Central SLO guardrails referenced by many clusters without copy/paste
- Clean extensibility: Adding providers/adapters does not mutate upgrade request schema
- Clear audit trail: Spec hash + session records simplify retrospectives and incident forensics
- Safer evolution: Versioned contract lets us introduce new fields without breaking in-flight or historical sessions
- Operational clarity: Operators inspect current intended gates separately from historical runs
- Lower long-term maintenance: Avoids proliferation of slightly divergent inline specs

#### Cons
- Slightly higher initial cognitive load (must create and reference a gate resource)
- Additional ARM surface area (new resource type + lifecycle operations)
- Indirection when debugging (must pivot gate → session to see live evaluation history)
- Requires tooling (CLI/Portal) scaffolds to avoid manual JSON authoring early on

#### Mitigations
- Provide CLI/Portal wizards to generate a gate from selected rule groups
- Offer gate templates (baseline latency/error SLO, platform health) to accelerate adoption
- Supply adapter SDK + auth examples to reduce effort for third-party signal publishers

## 🔍 **Comparison Summary**

| Feature | **Option A: Custom Resource (CR) Model** | **Option B: Dedicated ARM Resource Model** |
|--------|------------------------------------------|---------------------------------------------|
| **Extensibility** | High – CRs allow flexible, Kubernetes-native definitions | High – adapters normalize signals, extensible via providers |
| **Vendor Agnosticism** | Strong – CRs work across AKS and non-AKS clusters | Moderate – ARM-centric, but adapters can support non-Azure signals |
| **Governance & Policy** | Limited – CRs are cluster-scoped, harder to enforce centrally | Strong – ARM gates are versioned, reusable, and policy-targetable |
| **Operational Clarity** | Mixed – CRs are flexible but debugging is decentralized | Strong – clear separation of intent vs execution, audit trail |
| **Reusability** | Low – CRs are per-cluster, not easily shared | High – gates are reusable across clusters via references |
| **Tooling Requirements** | Lower – uses existing Kubernetes patterns | Higher – needs CLI/Portal scaffolding for authoring and referencing |
| **ARM API Role** | Minimal – only used to enable/disable gating mode | Central – defines gate resources and governs upgrade behavior |



## ✅ **Recommendation: Option A – Custom Resource (CR) Model**

## Why was Option A chosen?

- Aligns with Kubernetes-native patterns and community expectations.
- Supports both AKS and non-AKS clusters without Azure dependency.
- Enables rapid iteration and experimentation via GitOps and CLI.
- Keeps gate logic flexible and extensible inside the cluster.
- Minimizes ARM surface area and avoids premature centralization.

## Announcement: SLO‑Gated, Metric‑Aware Upgrades for AKS (Public Preview)

We are shipping extensible, vendor‑agnostic upgrade guardrails built around Kubernetes Custom Resources (CRs). Gate definitions and evaluation results live in the cluster as CRs, enabling declarative, Kubernetes‑native SLO contracts that the upgrade engine discovers and evaluates before, during, and after upgrades. This CR‑first design makes it simple to integrate both managed and self‑managed observability backends while keeping gate intent and execution close to the workloads they protect.

### What It Delivers
- Safer upgrades: Early detection of latency, error‑rate, and stability regressions via CR‑defined health criteria.
- Cross‑cluster compatibility: Works consistently across AKS and non‑AKS clusters using the same CR model.
- Declarative configuration: Define gates with familiar Kubernetes CRs and manage them with standard tooling (kubectl, GitOps).
- Flexible evaluation: Support for managed (Azure Monitor / Managed Prometheus) and self‑managed stacks via adapter patterns that publish normalized evaluations into the CR ecosystem.
- Automatic intervention: Abort or (for agent pools) optional rollback when sustained anomalies are detected.
- Community-friendly extensibility: Open CR model enables third‑party adapters, controller contributions, and ecosystem integrations.

### Why It Matters
Builtin readiness checks miss nuanced, phase‑specific degradations. CR‑based gates provide a native, extensible way to encode SLOs and automate upgrade decisions without vendor lock‑in. By keeping gate definitions and evaluations in‑cluster, teams gain reproducible, auditable safety checks that align with existing Kubernetes workflows.

### Customer Value
- True cluster portability with consistent upgrade safety patterns.
- Leverage existing Kubernetes skills and GitOps practices.
- Easier third‑party integration and community contributions.
- Simplified paths for connecting existing observability platforms via adapters.
- Vendor‑neutral approach preserving infrastructure and toolchain flexibility.

### Availability
- Public Preview: CR‑based gating for agent pool upgrades (rollback supported where configured). Control plane gates are abort‑only.
- ARM Role: ARM may be used only to toggle gating behavior at the RP level (enableUpgradeGates) — gate definitions and evaluations remain cluster‑native CRs.
- Roadmap: Additional adapter patterns (webhook, CRD aggregators), managed adapter improvements, and GA after public preview feedback.

### Get Started
Deploy the gate CRDs and controllers to your cluster, author gate CRs to express health criteria, and run an upgrade. The upgrade engine will discover and evaluate gates automatically. Provide feedback to help prioritize adapter work, UX improvements, and GA readiness.

Guardrails complement existing rollout strategies—making safe the default while preserving your monitoring and orchestration choices.

## User Experience

### API

#### ARM API Surface (Enablement Only)

```json
// Managed Cluster (MC) resource
{
  "type": "Microsoft.ContainerService/managedClusters", // ARM resource type for AKS cluster
  "properties": {
    "operationGateConfig": {
      "mode": "disabled" // enum: disabled | managed | byo | hybrid
      // disabled: No upgrade gating
      // managed: Only managed (Azure Monitor/Prometheus) gates
      // byo: Only bring-your-own (webhook/CRD/external) gates
      // hybrid: Both managed and BYO gates enabled
    }
    // "addon": { // optional future extension
    //   "monitoring": true // enables managed monitoring integration
    // }
  }
}

// Fleet resource (for update runs)
{
  "type": "Microsoft.ContainerService/fleets", // ARM resource type for AKS fleet
  "properties": {
    "updateRunGateConfig": {
      "mode": "disabled" // enum: disabled | managed | byo | hybrid
      // Same semantics as above
    }
  }
}
```

- The 'mode' enum allows customers to select which upgrade gating sources are enabled for their cluster or fleet.
- This enables flexibility for managed, BYO, or hybrid gating strategies.

#### Kubernetes CRD Surface (Two-CRD Model)

> The upgrade gating contract uses only two CRDs:
> - `UpgradeGate`: Defines the gate, criteria, phases, and adapters (spec/definition).
> - `GateEvaluation`: Reports the result of evaluating a gate for a specific upgrade session and phase (reporting/evaluation).

**Field Options Reference**

| Field           | Options                                 | Description                                                                 |
|-----------------|-----------------------------------------|-----------------------------------------------------------------------------|
| scope           | cluster, nodepool, namespace            | Where the gate applies: cluster-wide, node pool, or namespace               |
| evaluationMode  | Managed, Self-managed, None             | How evaluation is performed: managed (platform), self-managed (custom), none|
| phaseBindings   | preflight, canary, post, post-drain, ...| Upgrade phases when the gate is evaluated                                   |
| adapters.type   | AzureMonitor, Webhook, External         | Integration type: managed, webhook, or external provider                    |

- **scope**: `cluster` (default, applies to the whole cluster), `nodepool` (applies to a specific node pool), `namespace` (applies to a namespace).
- **evaluationMode**:
  - `Managed`: Evaluation is performed by managed platform sources (e.g., Azure Monitor, Managed Prometheus).
  - `Self-managed`: Evaluation is performed by custom/user sources (e.g., webhook, external provider).
  - `None`: No evaluation (gate is disabled).
- **phaseBindings**: List of upgrade phases to evaluate the gate. Common values: `preflight`, `canary`, `post`. You may add custom phases as needed (e.g., `post-drain`).
- **adapters.type**:
  - `AzureMonitor`: Managed adapter for Azure Monitor/Prometheus.
  - `Webhook`: User-defined webhook endpoint.
  - `External`: Third-party provider (Datadog, New Relic, etc.).

```yaml
# UpgradeGate CRD (Spec/Definition)
apiVersion: upgrade.guardrails.aks.io/v1
kind: UpgradeGate
metadata:
  name: custom-external-gate
  namespace: default
spec:
  description: "Block upgrade if external system signals unhealthy"
  # Scope can be cluster, nodepool, or namespace for fine-grained gating
  scope: cluster # cluster | nodepool | namespace
  # scope: nodepool # Uncomment for node pool-specific gating
  # scope: namespace # Uncomment for namespace-specific gating
  # Evaluation mode options: Managed | Self-managed | None
  evaluationMode: Self-managed # Managed | Self-managed | None
  criteria:
    # This can be any custom criteria relevant to your external system
    externalSignal: true # Example placeholder
    threshold: 1 # Example threshold
    window: 10m
  phaseBindings:
    - preflight
    - canary
    - post
    # - post-drain # Uncomment to add custom phase
  adapters:
    # Example: User-defined webhook adapter for any external endpoint
    - type: Webhook
      endpoint: "https://your-external-health-endpoint/api/evaluate"
      auth:
        method: token
        tokenRef: your-external-token
    # Example: External provider integration (Datadog, New Relic, etc.)
    - type: External
      provider: "CustomObservabilityPlatform"
      config:
        apiKeyRef: custom-api-key
        query: "custom_query_expression"
    # - type: AzureMonitor # Uncomment to add managed adapter
    #   ruleGroup: "prod-latency"
```

# All options for scope, evaluationMode, phaseBindings, and adapters are shown above. Use comments to select the desired configuration.

```yaml
# GateEvaluation CRD (Reporting/Evaluation)
apiVersion: upgrade.guardrails.aks.io/v1
kind: GateEvaluation
metadata:
  name: custom-external-gate-eval-20250909
  namespace: default
spec:
  gateRef: custom-external-gate
  sessionId: upgrade-20250909-001
  phase: canary
  status: Fail
  observedValue: 0 # Example value from external system
  thresholdContext: "external system signaled unhealthy"
  timestamp: "2025-09-09T09:14:33Z"
  diagnostics:
    - message: "External system reported unhealthy status"
    - logs: "See external endpoint logs"
```

# This makes it obvious how to define custom CRs for external endpoints and providers.

# Only these two CRDs are required for upgrade gating. Health fields are optional and only included if relevant to the gate's criteria.

### CLI Experience

- Primary UX via kubectl and helper tooling, operating on CRs:
  - `kubectl apply -f upgrade-gate.yaml` (create/modify UpgradeGate CRs)
  - `kubectl get upgradegates`, `kubectl describe upgradegate <name>`, `kubectl get gateevaluations --selector=session=<id>`
    - Example output:
      ```
      NAME         SESSION         PHASE      STATUS   VALUE   THRESHOLD   TS
      latency-gate upgrade-2025-01 canary     Fail     210ms   <200ms      2025-08-13T09:14:33Z
      error-gate   upgrade-2025-01 post       Pass     0.1%    <1%         2025-08-13T09:16:10Z
      ```
  - `kubectl logs -l app=gate-controller -n kube-system` for controller diagnostics
- Az/installer convenience:
  - `az aks update --name <cluster> --resource-group <rg> --set properties.enableUpgradeGates=true` (toggle ARM enablement)
  - `az aks extensions install aks-gate-controller` (controller install)
- Developer ergonomics:
  - `aks-gate` kubectl plugin supports dry-run/simulation, create/validate/simulate gates, and templates for latency, errors, OOM
  - All CLI tooling supports managed, BYO, and external adapters (e.g., Datadog, mesh telemetry) via the adapters array in UpgradeGate CRs
- Debugging:
  - GateEvaluation CRs include correlation IDs, timestamps, and adapter source info (managed, webhook, external)
  - Evaluation snapshots and breach events are easily exported for post-mortem

### Portal Experience

- Portal shows enablement status and high-level inventory:
  - Which clusters have the gate controller deployed
  - Which UpgradeGate CRs are attached (read-only view)
- Evaluation summaries:
  - Portal displays pass/fail rates, latest breach, session timeline, phase transitions, breach events, and final decisions by ingesting controller metrics/logs and GateEvaluation CRs
  - Evaluation results from managed, BYO, and external adapters (including mesh and Datadog) are surfaced in the Portal
- Authoritative gate definitions remain in-cluster as CRs:
  - Portal links to cluster explorer or GitOps repo for editing gate CRs
  - Creation wizards emit CRs into repo/cluster; onboarding is supported but authoring is deferred to CLI/GitOps
- Limitations:
  - Portal is read-only for gate definitions; all authoring and modification is done via CRs and CLI
  - Adapter source (managed, webhook, external) is shown in evaluation details for transparency

## Definition of Success

| Description                                 | Metric                                  | Target                |
|---------------------------------------------|-----------------------------------------|-----------------------|
| Reduce post-upgrade incidents               | Number of Sev2+ incidents post-upgrade  | < 5 per month         |
| Lower operator burden                       | Manual intervention rate                | < 10% of upgrades     |
| Durable, auditable evaluation and breach events | Evaluation/breach event retention      | 100% for 90 days      |
| High safe upgrade completion rate           | Successful upgrade rate                  | > 98%                 |
| Improved upgrade CSAT                       | Customer satisfaction score              | +20 uplift from baseline |

# Requirements

## Functional Requirements
- SLO-gated upgrades for agent pools (preflight, canary, post phases; abort/rollback on breach).
- Control plane gates (abort-only).
- Support for Azure Monitor, Prometheus, OTEL, webhook, CRD aggregator via uniform Gate Signal contract.
- Multiple reusable gate resources bound via RBAC + Azure Policy.
- Auditable evaluation and breach events; documented adapter contract for external/in-cluster publishers.

## Test Requirements
- Validate SLO-gated upgrade flows, breach detection, rollback, and audit event generation.
- Ensure compatibility with managed and BYO signal sources.
- Confirm policy enforcement and RBAC separation.

## Compete (GKE, EKS)

- GKE: Basic automatic upgrades and release channels; limited built‑in SLO gating and less centralized governance compared with AKS Upgrade Guardrails. See Google Cloud docs: https://cloud.google.com/kubernetes-engine/docs/concepts/automatic-upgrades
- EKS: Cluster upgrades are typically manual or driven by external pipelines; no integrated SLO‑gating primitives or unified audit/policy surface. See AWS EKS docs: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html

A short note on positioning: while GKE and EKS provide solid upgrade primitives, AKS Upgrade Guardrails focus on preventing SLO regressions during upgrades through auditable, reusable gate resources and a consistent signal contract—reducing operator toil and post‑upgrade incidents.

# Appendix: FAQ

## What are the two design options?

**Option A: CR-first (Custom Resource) Model**
- Uses two Kubernetes CRDs: `UpgradeGate` and `GateEvaluation`.
- Gate logic lives inside the cluster.
- Evaluation is published via CRs or controller webhooks.
- ARM API is used only to toggle enablement (`enableUpgradeGates: true`).

**Option B: Dedicated ARM Resource Model**
- Introduces a new ARM resource: `upgradeGates/{gateName}`.
- Gates are versioned, reusable, and centrally governed.
- Evaluation sessions and breach events are tracked in ARM.
- Strong policy and audit capabilities.

---

## Why was Option A chosen?

- Aligns with Kubernetes-native patterns and community expectations.
- Supports both AKS and non-AKS clusters without Azure dependency.
- Enables rapid iteration and experimentation via GitOps and CLI.
- Keeps gate logic flexible and extensible inside the cluster.
- Minimizes ARM surface area and avoids premature centralization.

*While Option B offers strong governance and auditability, Option A provides a lighter-weight, developer-friendly path that’s easier to adopt and evolve—especially for early-stage rollout and community engagement.*


### 🔄 Upgrade Gates: Complexity Comparison

| Dimension    | Option A: CR-first Model                | Option B: Dedicated ARM Resource Model           |
|-------------|-----------------------------------------|-------------------------------------------------|
| Authoring   | YAML-based, GitOps-friendly             | Requires ARM resource creation and referencing   |
| Tooling     | kubectl + optional plugin               | Needs CLI/Portal scaffolding for authoring       |
| Governance  | Cluster-native RBAC, policy via OPA     | Centralized ARM policy, RBAC, and audit          |
| Auditability| In-cluster events, GitOps history       | ARM event stream, resource-level audit           |
| Extensibility| Easy to extend via CRDs and adapters   | Extensible via ARM adapters, but more formal     |
| Adoption    | Lower barrier, fast iteration           | Higher initial setup, strong enterprise controls |