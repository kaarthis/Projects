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
To define a flexible, extensible, and vendor-neutral mechanism for upgrade gating in AKS and non-AKS Kubernetes clusters. The goal is to enable pre-, during-, and post-upgrade validation through declarative gate definitions and evaluations, supporting both managed and self-managed observability stacks.


### **Design Principles**
- **Extensibility**: Support a wide range of upgrade gate definitions and evaluation strategies.
- **Vendor Agnosticism**: Avoid tight coupling with Azure-specific APIs or tooling.
- **Cluster Independence**: Enable consistent behavior across AKS and non-AKS clusters.
- **Declarative Configuration**: Use Kubernetes-native constructs (CRDs) to define and manage gates.


### **Architecture Overview**

#### **1. Gate Definition (Custom Resource)**
- A Kubernetes Custom Resource (CR) defines the upgrade gate.
- This CR includes:
  - **Gate name and description**
  - **Health criteria** (e.g., Prometheus query, webhook endpoint)
  - **Scope** (cluster-wide, node pool, namespace)
  - **Evaluation mode**: `Managed`, `Self-managed`, or `None`

#### **2. Gate Evaluation (Custom Resource)**
- A separate CR type captures the evaluation result of each gate.
- This CR includes:
  - **Gate reference**
  - **Evaluation timestamp**
  - **Status**: `Pass`, `Fail`, `Pending`
  - **Diagnostics**: Optional logs or metrics

#### **3. Integration Model**
- **Custom Resource (CR)**:
  - Provides a generic, Kubernetes-native model applicable to both AKS and non-AKS clusters.
  - Enables community-driven contributions and extensibility.
- **ARM API**:
  - Used solely for **mode enablement**—to toggle gating behavior via a boolean switch.
  - Does **not** define or manage gates directly.
  - Example: `enableUpgradeGates: true` in ARM signals the RP to look for CRs in the cluster.

#### **4. Endpoint and Authentication**
- Each Gate CR may specify an **evaluation endpoint** and **authentication method** (e.g., webhook with token).
- The RP (Resource Provider) pulls from a **well-defined, discoverable endpoint list** to evaluate gates post-upgrade action.


#### ✅ **Pros**
- **Kubernetes-Native**: CR-based design aligns with Kubernetes extensibility patterns.
- **Cross-Cluster Compatibility**: Works across AKS and non-AKS clusters.
- **Community-Friendly**: Encourages open-source contributions and vendor-neutral adoption.
- **Flexible Evaluation**: Supports both managed (e.g., Azure Monitor/Prometheus) and self-managed setups.
- **Separation of Concerns**: ARM API is used only for enablement, keeping gate logic within the cluster.

#### ❌ **Cons**
- **Operational Complexity**: Self-managed mode requires users to deploy and maintain gate controllers.
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

- CR-first surface: two CRDs — UpgradeGate (spec: name, scope, criteria, evaluationMode, version) and GateEvaluation (sessionId, gateRef, phase, status, observedValue, window, metadata).
- CRUD via Kubernetes API (kubectl / REST): controllers and adapters create/observe UpgradeGate and write idempotent GateEvaluation objects under the cluster namespace.
- Adapters publish structured evaluation records (gateRef, phase, sourceId, status, value, thresholdContext, ts, runId) either by creating GateEvaluation CRs or invoking a local controller webhook.
- Discovery & versioning: Each evaluation session snapshots the gate spec using specVersion and specHash to ensure reproducibility and traceability.
- Security & Validation:
  - Standard K8s authN/authZ — serviceaccounts + Role/ClusterRole bindings for publishers/controllers
  - Optional signed webhook payloads for external adapters
  - Admission validation for schema and auth

### CLI Experience

- Primary UX via kubectl and small helper tooling:
  - kubectl apply -f upgrade-gate.yaml (create/modify gates)
  - kubectl get upgradegates, kubectl describe upgradegate <name>, kubectl get gateevaluations --selector=session=<id>
    - Example output:
      ```
      NAME         SESSION         PHASE      STATUS   VALUE   THRESHOLD   TS
      latency-gate upgrade-2025-01 canary     Fail     210ms   <200ms      2025-08-13T09:14:33Z
      error-gate   upgrade-2025-01 post       Pass     0.1%    <1%         2025-08-13T09:16:10Z
      ```
  - kubectl logs -l app=gate-controller -n kube-system
- Az/installer convenience:
  - az aks update --name <cluster> --resource-group <rg> --set properties.enableUpgradeGates=true (enablement toggle)
  - az aks extensions install aks-gate-controller (one‑click controller install)
- Developer ergonomics: provide `aks-gate` kubectl plugin (supports dry-run/simulation modes for safer experimentation; create/validate/simulate) and templates (latency, errors, OOM) to reduce JSON authoring.
- Debugging: GateEvaluation objects include correlation IDs and timestamps to support traceable upgrade workflows. Builtin status fields and easy export of evaluation snapshots for post‑mortem.

### Portal Experience

- Portal shows enablement and high‑level inventory (which clusters have gating controller deployed and which gates are attached).
- For CR-first fidelity: Portal links to the cluster explorer or GitOps repo for editing gate CRs; displays recent evaluation summaries (pass/fail rates, latest breach, session timeline with phase transitions, breach events, and final decisions) by ingesting controller metrics/logs.
- Read-only gate details and one‑click links to drill into GateEvaluation sessions and diagnostic artifacts; authoritative gate definitions remain in-cluster; Portal supports visibility and onboarding but defers authoring to GitOps or CLI workflows.
- Limitations: authoritative gate definitions remain in‑cluster; Portal augments visibility and onboarding (templates, creation wizards that emit CRs into repo/cluster).

### Policy Experience

- Governance via cluster-scoped policy + admission:
  - Use Azure Policy to require the gate controller to be installed (audit/enforce).
  - Use OPA/Gatekeeper constraints or Kubernetes admission policies to enforce allowed gate templates, scope restrictions, and required labels/annotations.
    - Example: block UpgradeGate CRs with unmanaged endpoints or missing required labels.
- Enforcement patterns:
  - Audit mode to surface policy drift (no change to in‑cluster CRs).
  - Enforce mode via Gatekeeper to block noncompliant UpgradeGate CRs (e.g., disallowed external endpoints, disallowed evaluation modes).
- RBAC model:
  - Gate authors: define UpgradeGate specs
  - Publishers: adapters that emit GateEvaluations
  - Operators: trigger upgrades and inspect sessions
- Recommended ops: combine Azure Policy (controller presence + cluster config) with in‑cluster OPA constraints for fine‑grained, centralized governance while keeping gate definitions cluster-native.
- This layered model enables centralized governance without sacrificing cluster-native flexibility.

# Definition of Success

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