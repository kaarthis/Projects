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
- Managed Azure Monitor metrics/alerts (first‑class managed option)
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
- Support Azure Monitor (managed) plus BYO endpoints (Prometheus, OTEL, webhook, CRD aggregator) from the start through a uniform Gate Signal contract
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

The user stories below are implementation‑agnostic and ensure support pre/during/post gates, prefer an extensible signal model (Prometheus first, CRD/webhook extensibility later), and cover key personas (cluster operator, app developer, platform operator, integrator).

| Persona | Story ID | User Story (As a...) | Acceptance Criteria (high level) |
|--------:|---------:|---------------------|---------------------------------|
| Cluster Operator | CO-1 | As a Cluster Operator, I want to attach one or more named gates to a planned upgrade so that AKS evaluates cluster health before, during (per-batch/canary), and after the upgrade and can automatically stop or roll back when thresholds are breached. | Gate can be bound to an upgrade; evaluations occur at pre/during/post points; upgrade aborts or triggers agent-pool rollback when configured; decision is auditable. |
| Cluster Operator | CO-2 | As a Cluster Operator, I want to reuse a centrally managed gate (defined once, referenced by many clusters) so I can enforce org policies consistently. | Gate resource can be referenced by multiple clusters; policy can target gate resources; status and breaches are queryable per cluster. |
| Application Developer | AD-1 | As an App Developer, I want to express my service's health contract (SLOs) using the simplest supported signal format so upgrades are prevented when my app is degraded. | A gate can reference a Managed Prometheus rule group (Phase 1) or an equivalent aggregated health signal; breach details include rule name, observed value, and timestamp. |
| Platform Operator | PO-1 | As a Platform Operator, I want a default, low-friction integration (managed Prometheus) out-of-the-box and an extensible path (CR/webhook) for advanced users so we balance adoption and extensibility. | Default Prometheus integration works with minimal configuration; PRD documents extension paths (CRD, webhook, adapters) and owners. |
| Gate Integrator / 3P Provider | GI-1 | As an Integrator, I want a clear integration contract (event/decision or health endpoint) so I can implement a gate adapter or external gate system that interoperates with AKS upgrade orchestration. | Event/decision webhook schema or health-aggregation contract is published; adapter can map external signals to the gate contract; idempotency and auth semantics are documented. |
| Third‑party Monitoring Provider | TM-1 | As a Monitoring Provider, I want to integrate my signal into gates without forcing customers to migrate their tooling so my customers can use existing monitoring with AKS guardrails. | PRD documents adapter patterns (PromRuleGroup → CR / webhook); example integration flow exists. |
| Fleet / Program Manager | FM-1 | As a Fleet Manager, I want gates to be targetable via ARM/Policy so I can enforce organizational constraints and audit compliance across clusters. | Gates are ARM resources or ARM-referenced constructs; Azure Policy can audit/enforce gate bindings. |

Acceptance criteria common to all stories:
- Gate evaluations produce durable, queryable events (evaluations & breaches) with timestamps, correlation IDs, and diagnostic context.
- Gate decisions (proceed/abort/hold/rollback) are exposed to CLI/Portal/API and are auditable in activity logs.
- Default behavior in Phase 1 supports Managed Prometheus rule groups; extension points for CR/webhook adapters are documented.
- Security model and RBAC principals for gate management and signal publishing are defined at a high level (detailed RBAC design is a follow-up task).


## Proposal (Alternative + Comparative Decision)

### Option A : Dedicated Upgrade Gate Resource (Versioned, Reusable)

#### Proposal
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


### Option B (Alternative): Inline Alert-Binding (Ephemeral Gate Spec)

Instead of a standalone Upgrade Gate ARM child resource, embed a gating block directly inside each upgrade request (and optionally as a reusable profile on the managed cluster spec). The block lists:
- Rule group (or alert rule) resource IDs (Azure Managed Prometheus first; later Azure Monitor / custom endpoints via URLs + auth refs)
- Phase directives (preflight / canary / post) with per-phase evaluation windows
- Breach actions (abort | rollback* where supported) and optional debounce/consecutive settings
- Optional inline threshold overrides or simple expression filters (label selectors) to scope which rules apply

Each upgrade run materializes an immutable “Gate Session” object (diagnostic record only) capturing:
- Resolved rule set snapshot (IDs + digests)
- Evaluations and breach events
- Final decision (proceed / abort / rollback)

No persistent gate configuration resource exists beyond historical session artifacts.

#### Pros
- Minimal conceptual surface (no extra ARM resource type)
- Faster initial implementation; relies on existing rule group IDs only
- Per-upgrade flexibility (teams can experiment without touching shared objects)
- Avoids early versioning / migration logic (schema co-evolves with upgrade API)
- Lower RBAC friction (uses existing cluster write permission)
- Eliminates indirection when mapping a breach to a rule (1:1 listing)

#### Cons
- Configuration duplication across clusters and repeated upgrade requests (drift risk)
- Harder centralized governance (Azure Policy must parse nested spec; no targetable child resource)
- RBAC granularity limited (cannot delegate gate authoring separately from general cluster updates)
- Retrofitting new signal providers forces cluster/upgrade API churn rather than adding adapter resources
- Difficult to share vetted gate bundles (copy/paste or templates only)
- Auditing requires mining historic session objects; no “current intended gate” to inspect
- Inline threshold overrides can diverge from canonical rule definitions (silently forked SLO logic)

### Recommendation / Vote

Preferred: Option A (Dedicated Upgrade Gate Resource)

Rationale:
- Governance, reuse, and auditability are strategic for large estates; those concerns compound over time and outweigh the initial speed of the inline model.
- A versioned gate contract future‑proofs multi-provider extensibility (Prometheus → adapters) without forcing upgrade API churn.
- Separation of “desired guardrails” (gate resource) from “execution timeline” (evaluations, breaches) produces cleaner UX and compliance stories.
- Policy and RBAC alignment are materially simpler with a targetable resource type.
- Early indirection cost (one extra resource) is minor relative to long‑term operational efficiency and reduced drift.

Mitigations for Option A complexities:
- Provide quick-start CLI/Portal wizards to scaffold a gate from selected rule groups.
- Offer dry-run validation and template library to lower authoring friction.
- Supply adapter SDK to accelerate third-party signal integration.

Conclusion: Adopt Option A; do not pursue Option B beyond a lightweight “ephemeral override” extension (future) for rare one-off experimental upgrades.

### Final Decision

Vote: Option A (Dedicated Upgrade Gate Resource) – Accepted.
Option B – Rejected (retain as documented alternative for historical rationale).


## Announcement: SLO‑Gated, Metric‑Aware Upgrades for AKS (Public Preview)

We are introducing reusable, SLO‑aware upgrade guardrails that continuously evaluate application and platform health before, during, and after AKS upgrades. These guardrails turn your existing operational signals into automated “proceed / pause / abort / rollback (agent pools)” decisions—reducing manual dashboard watching and lowering post‑upgrade incident risk.

### What It Delivers
- Safer upgrades: Early detection of latency, error rate, and stability regressions.
- Reusable guardrails: Define once, apply consistently across clusters for predictable governance.
- Phased protection: Preflight validation, canary confidence building, and post‑upgrade drift detection.
- Automatic intervention: Abort or (for agent pools) optional rollback when sustained anomalies are detected.
- Clear auditability: Each decision backed by timestamped evaluation history and breach events.

### Why It Matters
Traditional readiness checks miss slow‑burn or phase‑specific issues. Teams today script ad‑hoc blue/green flows and manually chase alerts. Guardrails reduce toil, standardize safety practices, and help prevent avoidable customer impact.

### Customer Value
- Higher upgrade confidence and velocity.
- Fewer late‑detected regressions.
- Consistent enforcement of operational standards without bespoke pipelines.
- Extensible model designed to add more signal sources over time.

### Availability
- Public Preview: Agent pool upgrades (rollback supported where configuration allows). Control plane uses abort-only safety.
- Roadmap: Broader governance integrations, expanded signal sources, and general availability after feedback.

### Get Started
Enable guardrails on a target cluster, reference your existing health signals, run an upgrade, and review the decision timeline. Share feedback to shape the GA release.

Guardrails complement (not replace) your existing rollout strategies—making safe the default, not an afterthought.


## User Experience 


### Operator Journeys (Scenarios)

#### Examples with timelines (mock)


### API


### CLI Experience


### Portal Experience


### Policy Experience


# Definition of Success

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures



# Requirements

## Functional Requirements



## Test Requirements



# Appendix: FAQ