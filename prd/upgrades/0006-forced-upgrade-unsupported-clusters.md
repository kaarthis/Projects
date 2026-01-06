---
title: Reducing Unsupported Cluster Footprint - Forced Upgrade Strategy
wiki: ""
pm-owners: [kaarthis]
feature-leads: []
authors: [kaarthis]
stakeholders: []
approved-by: [] 
---

# Overview 

## Problem Statement / Motivation  

> Before forced upgrades, AKS customers could leave clusters on unsupported Kubernetes versions indefinitely, exposing themselves and Azure to security vulnerabilities and operational risk. 
> Now, AKS will ensure all clusters remain on supported versions through a structured transition and ongoing enforcement, eliminating the unsupported cluster footprint.

**Reference:** AKS uses the [AKS Kubernetes Release Calendar](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar) as the authoritative source for version support status and EOL dates.

**The Problem:**

Today, over **35% of daily average AKS clusters run on unsupported Kubernetes versions** (refer to the [Unsupported Clusters Dashboard](https://msit.powerbi.com/groups/c1b4652f-efe6-4031-8526-36cc9b27677c/reports/41a330a3-173e-4b6d-9e3d-6d083edaee0d/d596a4cb0a0c740aa68d?experience=power-bi)). This is a critical problem for multiple reasons:

1. **Microsoft SFI Commitment:** Microsoft's Secure Futures Initiative (SFI) requires all infrastructure to be on supported, patched versions. Unsupported clusters undermine this commitment and expose Microsoft and customers to increased risk.

2. **Security Risk:** Unsupported Kubernetes versions no longer receive security patches from the upstream community, leaving clusters exposed to known CVEs and cyber attacks.

3. **Operational Cost:** Maintaining infrastructure compatibility for a long tail of unsupported versions creates significant infrastructure and engineering costs for the AKS team.

4. **Customer Risk:** Customers on unsupported versions are running vulnerable infrastructure, often unknowingly, which puts their workloads and data at risk.

**The Solution:**

AKS will implement a **two-phase strategy** to eliminate the unsupported cluster footprint:

1. **Transition State (One-Time):** A defined cutoff date (e.g., August 2026) by which all existing unsupported clusters must be upgraded. If customers do not act, AKS will perform the upgrade automatically.

2. **Steady State (Ongoing):** A new policy where no cluster can ever become unsupported. Steady state is triggered by a new Kubernetes version GA (e.g., 1.35 GA in November 2026), which causes the oldest supported versions to reach EOL. At that point:
   - **Community clusters at EOL:** Automatically and silently convert to LTS (billing change only, no upgrade, no disruption). LTS pricing begins immediately. Customers will have already received notifications about the upcoming conversion.
   - **LTS clusters at EOL:** Enter a 60-day platform support grace period (see [Platform Support Policy](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#platform-support-policy)), then force-upgraded to the next LTS kubernetes version.
   - **Opting out of LTS:** Customers can opt out of LTS by upgrading to a supported community version (per the release calendar). Customers cannot opt out of LTS while remaining on the same version since that version is no longer supported in community. See [LTS documentation](https://learn.microsoft.com/en-us/azure/aks/long-term-support) for details.

---

## Goals/Non-Goals

### Functional Goals

1. **Eliminate Unsupported Footprint:** Reduce the percentage of unsupported clusters from 35% to <1% within 12 months of steady state enforcement.

2. **Transition State Execution:** Successfully migrate all existing unsupported clusters to a supported version by the defined cutoff date (e.g., August 2026).

3. **Steady State Enforcement:** Implement a system where clusters are automatically upgraded before falling out of support, making "unsupported" an impossible state.

4. **Customer Communication:** Deliver clear, multi-channel notifications to enable customers to self-upgrade before platform intervention.

5. **Minimize Disruption:** For the vast majority of clusters (community → LTS conversion), there is no upgrade or disruption—only a billing/support plan change. For LTS clusters at EOL, forced upgrades respect customer-configured maintenance windows; if no maintenance window is configured, platform uses system convenience timing (platform-determined, not a specific day like weekend).

### Non-Functional Goals

1. **Security & Compliance:** Ensure all clusters run versions eligible for upstream security patches, supporting Microsoft SFI requirements and customer compliance frameworks (FedRAMP, SOC 2).
3. **Telemetry:** Track and report on unsupported cluster footprint, upgrade success rates, and customer communication effectiveness.
4. **Supportability:** Provide clear documentation and portal UX for customers to understand their cluster's support status and upcoming actions.

### Non-Goals

1. **Skip Version Upgrades:** Enabling customers to skip multiple minor versions in a single upgrade is a separate feature and out of scope for this PRD.
2. **Rollback to Unsupported Versions:** The platform will not allow rollback to a version that is no longer supported.
3. **Exception Process Definition:** A small number of customers may require exceptions. The mechanism for handling exceptions is outside the scope of this PRD.

---

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| **Platform Engineer** | Microsoft.ContainerService/managedClusters/read/write | As a platform engineer, I want to receive clear, advance notice when my cluster is approaching end-of-support. I want to upgrade on my own schedule within the allowed window. If I miss the deadline, I expect the platform to upgrade my cluster safely during my configured maintenance window. **Success:** I am never surprised; I always know my cluster's support status. |
| **Security/Compliance Officer** | Microsoft.ContainerService/managedClusters/read | As a compliance officer, I need to verify that all clusters in my organization are on supported versions. I want a dashboard in the Portal showing compliance status. **Success:** I can generate a compliance report showing 100% of clusters are on supported versions. |
| **AKS Operations Team** | N/A (Internal) | As an AKS operator, I want to reduce the operational burden of supporting a long tail of old versions. **Success:** The unsupported cluster footprint is reduced to <1%, freeing up engineering resources. |

---

## Customers and Business Impact 

**Current State (Problem):**
- **35%+ of daily clusters** are on unsupported versions.
- These clusters are exposed to **unpatched CVEs**.
- AKS team spends significant resources maintaining compatibility for unsupported versions.
- Microsoft SFI compliance is at risk.

**Target State (Outcome):**
- **<1% of clusters** on unsupported versions (only exceptional cases with documented justification).
- All clusters receive security patches.
- Reduced operational cost for AKS team.
- Full compliance with SFI.

**Business Impact:**
- **Security Posture:** Aligns AKS with Microsoft SFI and industry best practices.
- **Operational Efficiency:** Reduces engineering burden and support ticket volume related to unsupported versions.
- **Customer Trust:** Customers can rely on AKS to keep their infrastructure secure by default.

---

## Existing Solutions or Expectations 

| Current Approach | How it Works | Why it Fails |
|------------------|--------------|--------------|
| **Auto-Upgrade Channels (patch, stable, rapid, node-image)** | Customers opt-in to automatic upgrades. | Adoption is optional. Many customers use `none` channel and never upgrade. **Note:** `patch` channel only upgrades within the same minor version (e.g., 1.30.1 → 1.30.2) and will NOT upgrade to a new minor version when EOL approaches. |
| **EOL Notifications** | Customers receive emails and portal banners when a version is approaching EOL. | Notifications are often ignored. No enforcement mechanism exists. |
| **Support Ticket Denial** | AKS support may decline to help with issues on unsupported versions. | Reactive, not proactive. Doesn't prevent the problem. |

**Gap:** There is no mechanism today to *force* an upgrade. Customers can ignore all warnings and remain on unsupported versions indefinitely. Even customers on `patch` channel are at risk because `patch` does not cross minor versions.

---

## What will the announcement look like?

**Announcing "Always Supported" Policy for Azure Kubernetes Service (AKS)**

We are announcing a new policy to ensure all AKS clusters remain on supported Kubernetes versions at all times. Starting **[Date]**, AKS will automatically upgrade clusters that have not been upgraded by customers before their version reaches end-of-support.

**Addressing Key Challenges**

Running Kubernetes clusters on unsupported versions exposes customers to unpatched security vulnerabilities and operational risk. Today, over 35% of AKS clusters run on unsupported versions. This new policy eliminates this risk by ensuring every cluster stays within the supported version window.

**How It Works**

1. **Transition Phase (Now - August 2026):** If your cluster is currently on an unsupported version, you will receive notifications to upgrade. If you do not upgrade by the cutoff date, AKS will upgrade your cluster to the next supported version.

2. **Steady State (November 2026 onward):** The `none` auto-upgrade channel will be deprecated. When a cluster's community version reaches end-of-support, AKS will automatically convert it to LTS (billing change only, no upgrade disruption). LTS pricing begins immediately upon conversion. Customers can opt out of LTS by upgrading to a supported community version. LTS clusters that reach end-of-support enter a 60-day [platform support](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#platform-support-policy) grace period, after which AKS will force upgrade to the next LTS version.

**Important for `patch` channel users:** The `patch` channel only upgrades within the same minor version. It will NOT upgrade you to a new minor version when your current version reaches EOL. You must switch to `stable`/`rapid` or upgrade manually before EOL, or AKS will upgrade your cluster automatically.

**Availability**

This policy applies to all AKS clusters. Customers will receive at least 6 months of advance notice via email, Azure Portal banners, and Azure Advisor recommendations.

For more information, review the detailed documentation on the new "Always Supported" policy.

---

## Proposal 

### Two-Phase Strategy

This feature is implemented in two distinct phases:

### Transition State (One-Time Cleanup)

**Scope:** All existing clusters currently running on unsupported Kubernetes versions.

**Goal:** Migrate 100% of legacy unsupported clusters to a supported version by the cutoff date.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TRANSITION STATE                                   │
│                        (One-Time Cleanup)                                    │
│                                                                              │
│  Target: All existing unsupported clusters                                   │
│  Cutoff: August 2026 (Illustrative)                                          │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Community Clusters              │ LTS Clusters                          ││
│  │ Running 1.33 or below           │ Running 1.30 LTS or below             ││
│  │         ↓                       │         ↓                             ││
│  │ Must upgrade to 1.34+           │ Must upgrade to 1.31 LTS+             ││
│  │ by Aug 2026                     │ by Aug 2026                           ││
│  │         ↓                       │         ↓                             ││
│  │ If not done → AKS upgrades      │ If not done → AKS upgrades            ││
│  │ automatically                   │ automatically                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

**Notification Timeline:** T-6, T-3, T-1 months before cutoff date.

---

### Steady State (Ongoing Enforcement)

**Scope:** All clusters going forward, triggered by each new Kubernetes version GA.

**Goal:** Ensure no cluster can ever become unsupported—"Always Supported" policy.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            STEADY STATE                                      │
│                       (Ongoing Enforcement)                                  │
│                                                                              │
│  Triggered by: New K8s version GA (e.g., 1.35 GA in Nov 2026)               │
│  This causes EOL of: 1.34 Community / 1.31 LTS                              │
│  Note: All timelines are illustrative and may vary based on execution.      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Community Clusters at EOL       │ LTS Clusters at EOL                   ││
│  │ (e.g., 1.34 reaches EOL)        │ (e.g., 1.31 LTS reaches EOL)          ││
│  │         ↓                       │         ↓                             ││
│  │ Automatic & silent conversion   │ 60-day platform support grace period  ││
│  │ to 1.34 LTS                     │ (see Platform Support Policy)         ││
│  │         ↓                       │         ↓                             ││
│  │ LTS pricing begins IMMEDIATELY  │ Force upgrade to 1.32 LTS             ││
│  │ (No upgrade, no disruption)     │ (Bypass PDB after drain timeout)      ││
│  │         ↓                       │ (3 retry attempts if failed)          ││
│  │ Opt-out: Upgrade to supported   │                                       ││
│  │ community version               │                                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  KEY STEADY STATE RULES:                                                     │
│  • No cluster can exit "Always Supported" policy                            │
│  • "None" channel deprecated (requires Breaking Change Board approval)      │
│  • "Patch" channel does NOT cross minor versions—platform takes over at EOL │
│  • upgradeDriver field flips to "PlatformDriven" at EOL                     │
│  • Platform Support = 60-day grace for LTS clusters at EOL                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### API Design Options

Three options were evaluated for implementing steady state enforcement:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **Option 1:** Change `none` channel behavior | Keep the `none` enum value but change its behavior to allow platform-driven upgrades at EOL. | No API breaking change. Simple to implement. | Confusing for customers. `none` no longer means "no upgrades." Documentation mismatch. |
| **Option 2:** Deprecate `none`, introduce `platform-forced` channel | Remove `none` and add a new channel value that explicitly signals platform-controlled upgrades. | Clear intent for customers. | Formal API breaking change process required. Customer migration effort. |
| **Option 3 (Recommended):** Deprecate `none`, add read-only `upgradeDriver` status field | Remove `none` channel. Add a new read-only property in the auto-upgrade profile: `upgradeDriver` with enum values `CustomerDriven` or `PlatformDriven`. | Clear separation: Channels are always customer intent. Platform behavior is explicit and read-only. Minimal API bloat. Best customer communication. | Requires deprecation process for `none`. |

**Recommendation: Option 3**

This option provides the clearest customer experience:
- **Auto-upgrade channels** (`patch`, `stable`, `rapid`) represent **customer intent**—they are forward-looking and customer-driven.
- **`upgradeDriver` property** (read-only) indicates whether the **customer** or **platform** will drive the next upgrade. This field is **computed dynamically** based on the cluster's current state—it is not a persistent setting.
- When a cluster reaches EOL and the customer has not scheduled an upgrade, `upgradeDriver` flips to `PlatformDriven`, signaling imminent forced upgrade.
- Once the cluster is upgraded (by customer or platform) to a supported version, `upgradeDriver` returns to `CustomerDriven`. See FAQ for detailed scenarios.
- Deprecating `none` makes auto-upgrade channels always forward-looking. Default platform behavior becomes explicit via the read-only `upgradeDriver` field with clear documentation and portal UX.

#### Special Case: `patch` Channel at EOL

**Important:** The `patch` channel only upgrades within the same minor version (e.g., 1.30.1 → 1.30.2). It does **NOT** perform minor version upgrades. When a minor version reaches EOL, a cluster on `patch` channel will NOT receive an automatic upgrade to the next minor version.

**Behavior at EOL:**
1. **Notification:** Customers on `patch` channel receive explicit warnings that their minor version is approaching EOL and `patch` channel will not save them.
2. **Customer Action Window:** Customer can switch to `stable` or `rapid` channel, or perform a manual upgrade to a supported version.
3. **Platform Takeover:** If the customer takes no action by EOL, `upgradeDriver` flips to `PlatformDriven` and the platform force-upgrades the cluster to the next LTS version (same as `none` channel behavior).
4. **Channel Preserved:** After the forced upgrade, the cluster's `upgradeChannel` remains `patch`. The platform only intervened for the EOL event; ongoing behavior reverts to customer-driven patch upgrades.

**Rationale:** Customers on `patch` explicitly chose patch-only behavior, meaning they accept responsibility for minor version upgrades. If they do not act, platform-driven upgrade to LTS is a safe fallback that keeps them supported.

---

### Communication Plan

**Target Recipients:** Subscription owners for clusters approaching EOL.

**Purpose:** Frequent and targeted outreach before transition of clusters (one-off migration phase).

| Timeline | Action | Channel |
|----------|--------|---------|
| **T-12 months** | Announce policy change (this PRD) | Blog, Email to Subscription Owners, Azure Updates |
| **T-6 months** | First warning to unsupported cluster owners | Email to Subscription Owners, Portal Banner, Azure Advisor |
| **T-6 months** | **Special warning to `patch` channel users:** "Your minor version is approaching EOL. The `patch` channel will not upgrade you to a new minor version. Switch to `stable`/`rapid` or upgrade manually." | Email to Subscription Owners, Portal Banner |
| **T-3 months** | Second warning with upgrade instructions | Email to Subscription Owners, Portal Banner, Service Health Alert |
| **T-1 month** | Final warning: "Upgrade now or AKS will upgrade for you" | Email to Subscription Owners, Portal Banner, Service Health Alert |
| **T-0** | Forced upgrade executed during maintenance window (or system convenience if none configured) | N/A (Automated) |
| **Post-upgrade** | Confirmation notification | Email to Subscription Owners, Activity Log |

---

### Breaking Changes

| Change | Impact | Mitigation |
|--------|--------|------------|
| **Deprecation of `none` auto-upgrade channel** | Customers using `none` will need to select a new channel or accept platform-driven upgrades. Requires Breaking Change Board approval. | 12-month deprecation notice. Clear migration guidance. Terraform/Bicep examples provided. |
| **Forced upgrades at EOL** | Customers who previously remained on unsupported versions will experience mandatory upgrades. Forced upgrades will push through PDB blocks (using [force upgrade with bypass PDB](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb) after drain timeout) and handle API deprecations. | Multi-month advance warning. Upgrades respect maintenance windows when configured. |

---

### Forced Upgrade Behavior

**Method:** Forced upgrades use the [Force Upgrade (Bypass PDB)](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb) option after the drain timeout expires. This ensures upgrades complete even when PDBs would otherwise block node eviction.

**Retry Strategy:** Based on competitor analysis:
- **GKE:** Retries upgrades with exponential backoff over several days.
- **EKS:** Attempts upgrade in maintenance windows, retries if failed.

**AKS Approach:** The platform will attempt forced upgrade **3 times** with appropriate backoff. If all retry attempts fail, the cluster enters an "out of support" state and the customer is alerted to take manual action.

**Post-Upgrade State:** If a forced upgrade fails after all retries:
1. Cluster remains in unsupported state.
2. Customer receives alert with failure details.
3. Support ticket is auto-created for high-severity cases.
4. Customer must manually resolve and upgrade.

---

### Pricing

- **No pricing change** for forced upgrades.
- **LTS pricing is immediate:** Community clusters that convert to LTS at EOL begin LTS billing immediately upon conversion. There is no opt-in required for the conversion; it is automatic and silent (customers will have received prior notifications).
- **Opting out of LTS:** Customers can opt out of LTS billing by upgrading to a supported community version per the [AKS Kubernetes Release Calendar](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar). Customers cannot opt out of LTS while remaining on the same version (since that version is out of community support). See [LTS documentation](https://learn.microsoft.com/en-us/azure/aks/long-term-support) for opt-out instructions.

---

## User Experience 

### Portal Experience

**Cluster Overview Blade:**
- New banner: "This cluster is on version X.XX which reaches end-of-support on [Date]. [Upgrade Now] or AKS will upgrade automatically."
- **Special banner for `patch` channel clusters:** "This cluster uses the `patch` channel, which only upgrades within the same minor version. Your minor version X.XX reaches end-of-support on [Date]. Switch to `stable`/`rapid` or upgrade manually, or AKS will upgrade automatically."
- New status indicator: `Support Status: Supported | Approaching EOL | Platform Upgrade Scheduled`
- Display `upgradeDriver` status when `PlatformDriven` to clearly indicate the platform will perform the upgrade.
- For LTS-converted clusters: Display LTS billing status and link to opt-out instructions.

**Kubernetes Hub (Fleet View):**
- Dashboard showing: "X clusters approaching EOL in next 30/60/90 days"
- Filter: "Show clusters requiring action"
- Indicator for clusters where `upgradeDriver = PlatformDriven`

### API

**New read-only property in `managedClusterProperties.autoUpgradeProfile`:**

```json
{
  "autoUpgradeProfile": {
    "upgradeChannel": "stable",
    "nodeOSUpgradeChannel": "NodeImage",
    "upgradeDriver": "CustomerDriven"  // Read-only. Enum: CustomerDriven | PlatformDriven
  }
}
```

When `upgradeDriver` is `PlatformDriven`, it indicates the platform will force an upgrade because:
- The cluster is on an unsupported version (Transition State), OR
- The cluster has reached EOL and entered the 60-day platform support grace period with no customer upgrade scheduled (Steady State).

**Note:** The `upgradeDriver` field flips to `PlatformDriven` **at EOL**, not before. This provides clear signal that platform-driven action is imminent.

**Deprecation of `none` channel:**
- `upgradeChannel: "none"` will return a deprecation warning in API responses starting [Date].
- `none` channel must be deprecated on or before steady state timelines. Exact timing is flexible but deprecation must be complete before steady state enforcement begins.
- This requires Breaking Change Board approval.
- Existing clusters with `none` will be migrated to the new behavior (platform-driven at EOL).

### CLI Experience

**New output in `az aks show`:**
```
Auto Upgrade Profile:
  Upgrade Channel: stable
  Node OS Upgrade Channel: NodeImage
  Upgrade Driver: CustomerDriven   <-- NEW
```


### Policy Experience

**New Built-in Azure Policy Definition:**

`[Preview] AKS clusters must not be on unsupported Kubernetes versions`

- **Effect:** Audit / Deny
- **Logic:** Flags clusters where the Kubernetes version has reached EOL.
- **Use Case:** Compliance officers can assign this policy to ensure visibility and enforcement.

---

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|----------|
| 1 | **Reduce unsupported footprint** | % of daily clusters on unsupported versions | <1% within 12 months of steady state | P0 |
| 2 | **Transition state completion** | % of legacy unsupported clusters upgraded by cutoff | 100% by Aug 2026 | P0 |
| 3 | **Forced upgrade success rate** | % of forced upgrades completing without failure | >99.5% | P0 |
| 4 | **Customer communication reach** | % of affected customers who received at least 3 notifications | 100% | P0 |
| 5 | **Support ticket volume** | Change in support tickets related to unsupported versions | -50% YoY | P1 |
| 6 | **SFI Compliance** | Audit pass rate for AKS against SFI requirements | 100% | P0 |

---

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | System must identify all clusters on unsupported versions and flag them for forced upgrade. | P0 |
| 2 | System must send notifications at T-6, T-3, and T-1 months before forced upgrade. | P0 |
| 3 | Forced upgrades must respect customer-configured maintenance windows. If no window is configured, platform uses system convenience timing (platform-determined, not a specific default like weekends). | P0 |
| 4 | Forced upgrades must use the [Force Upgrade (Bypass PDB)](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb) method after drain timeout. Platform will retry 3 times; if all attempts fail, cluster enters out-of-support state and customer is alerted. | P0 |
| 5 | API must expose `upgradeDriver` read-only property indicating `CustomerDriven` or `PlatformDriven`. The flip to `PlatformDriven` must occur at EOL, not before. | P0 |
| 6 | `none` auto-upgrade channel must be deprecated with Breaking Change Board approval. Deprecation must be complete on or before steady state enforcement begins. | P0 |
| 7 | Clusters on `patch` channel must receive specific notification that `patch` does not cross minor versions and they must take action before EOL or accept platform-driven upgrade. | P0 |
| 8 | Portal must display clear support status and forced upgrade schedule for each cluster. | P0 |
| 9 | Kubernetes Hub must provide fleet-wide view of clusters approaching EOL. | P1 |
| 10 | Azure Policy definition must be available for compliance enforcement. | P1 |
| 11 | Documentation must clearly explain the new "Always Supported" policy. | P0 |

## Test Requirements 

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | E2E test: Cluster on unsupported version receives forced upgrade at scheduled time. | P0 |
| 2 | E2E test: Forced upgrade respects maintenance window configuration. | P0 |
| 3 | E2E test: Notification pipeline delivers emails at T-6, T-3, T-1 months. | P0 |
| 4 | E2E test: `upgradeDriver` property correctly reflects platform vs. customer control. | P0 |
| 5 | E2E test: Forced upgrade succeeds without rollback in 99.5% of cases. After 3 retry attempts, failed clusters are flagged and customers alerted. | P0 |
| 6 | E2E test: Clusters with `none` channel receive deprecation warning in API response. | P1 |
| 7 | E2E test: Clusters on `patch` channel approaching EOL receive specific warning about minor version limitation. | P0 |
| 8 | E2E test: Clusters on `patch` channel at EOL have `upgradeDriver` flip to `PlatformDriven` and receive forced upgrade. | P0 |
| 9 | Load test: System can process forced upgrades for 10,000+ clusters in a single day. | P1 |

---

# Dependencies and Risks 

| No. | Dependency / Risk | Giver Team / Mitigation |
|-----|-------------------|-------------------------|
| 1 | **Notification pipeline integration** | Comms Manager team. Risk: Delivery failures. Mitigation: Multi-channel (email + portal + advisor). |
| 2 | **Maintenance window enforcement** | AKS RP team. Risk: Edge cases where no window is configured. Mitigation: Use system convenience timing (platform-determined) if no window set—not a specific default like weekends. |
| 3 | **Customer backlash** | Risk: Customers unhappy with forced upgrades or unexpected LTS billing. Mitigation: 12-month advance notice, clear communication, respect for maintenance windows, clear LTS opt-out documentation. |
| 4 | **API deprecation process** | ARM/API Review board / Breaking Change Board. Risk: Delays in approving `none` channel deprecation. Mitigation: Start process early (Q1 2026). This is a hard dependency. |
| 5 | **Upgrade reliability** | AKS Upgrade team. Risk: Forced upgrades fail at higher rate than voluntary. Mitigation: Use same safe upgrade infrastructure (surge, health gates). |
| 6 | **LTS pricing transition** | Finance/Billing team. Risk: Customer confusion about pricing change when community converts to LTS. Mitigation: Clear billing documentation, LTS pricing meter activates immediately, clear opt-out instructions in portal and docs. |

---

# Compete 

## GKE 

**Release Channels:**
- GKE has `Rapid`, `Regular`, `Stable`, and `Extended` channels.
- Clusters in a release channel are **automatically upgraded** by Google.
- There is **no opt-out**; customers must be in a release channel.
- GKE will force-upgrade clusters that fall out of support.

**AKS Comparison:** GKE is already in "steady state" mode. AKS is aligning with this approach.

## EKS 

**Extended Support:**
- EKS offers **Extended Support** for an additional 12 months beyond standard EOL, for an additional fee.
- After extended support ends, clusters are **force-upgraded** to the oldest supported version.

**Auto Mode:**
- EKS Auto Mode (new) automatically manages upgrades for customers.
- Customers can still opt-out by not using Auto Mode, but EKS will still force-upgrade at EOL.

**AKS Comparison:** EKS is moving toward forced upgrades. AKS LTS is analogous to EKS Extended Support. AKS is aligning with EKS's direction of enforcing supported versions.

---

# Appendix

## Version Calendar (Illustrative)

**Note:** All timelines and versions below are illustrative examples. Actual dates will be determined based on execution and will be published separately in the official [AKS Kubernetes Release Calendar](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar).

| Version | Type | Community EOL | LTS EOL | Steady State Action |
|---------|------|---------------|---------|---------------------|
| 1.30 | LTS | N/A | Aug 2026 | 60-day grace → Force upgrade to 1.31 LTS |
| 1.31 | LTS | N/A | Nov 2026 | 60-day grace → Force upgrade to 1.32 LTS |
| 1.32 | Community | May 2026 | Mar 2027 | At Community EOL: Auto-convert to 1.32 LTS (billing only) |
| 1.33 | Community | Aug 2026 | Jun 2027 | At Community EOL: Auto-convert to 1.33 LTS (billing only) |
| 1.34 | Community | Nov 2026 | Nov 2027 | At Community EOL: Auto-convert to 1.34 LTS (billing only) |

**Key Insight:** 
- **Community clusters at EOL:** No upgrade happens. Automatic and silent conversion to LTS (billing/support plan change). LTS pricing meter begins immediately. Customers can opt out by upgrading to a supported community version.
- **LTS clusters at EOL:** Actual version upgrade happens after 60-day [platform support](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#platform-support-policy) grace period using [Force Upgrade (Bypass PDB)](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb). This is the minority of clusters.

---

## Frequently Asked Questions

### Q: What happens to clusters on the `patch` auto-upgrade channel when their minor version reaches EOL?

**A:** The `patch` channel only upgrades within the same minor version (e.g., 1.30.1 → 1.30.2). It does **NOT** perform minor version upgrades.

When a minor version reaches EOL:
1. Customers on `patch` receive explicit warnings starting T-6 months that their minor version is approaching EOL and the `patch` channel will not upgrade them.
2. Customers can switch to `stable` or `rapid` channel, or perform a manual upgrade.
3. If no action is taken by EOL, the `upgradeDriver` flips to `PlatformDriven` and the platform force-upgrades the cluster to the next LTS version.
4. After the forced upgrade, the cluster's `upgradeChannel` remains `patch`. The platform only intervened for the EOL event.

**Key Point:** Choosing `patch` means the customer accepts responsibility for minor version upgrades. The platform only takes over at EOL as a safety net.

### Q: Will my `patch` channel setting be changed after a forced upgrade?

**A:** No. The `upgradeChannel` setting remains `patch` after a platform-driven forced upgrade. The platform only intervenes at EOL to ensure the cluster stays on a supported version. Ongoing patch upgrades within the new minor version continue to be customer-driven via the `patch` channel.

### Q: How is `patch` channel different from `none` channel after this change?

**A:** 
- **`none` (deprecated):** Customer explicitly opted out of all automatic upgrades. Platform takes over at EOL.
- **`patch`:** Customer opted in to automatic patch upgrades within the same minor version. Customer is responsible for minor version upgrades. Platform takes over at EOL only if customer does not act.

Both result in platform-driven upgrade at EOL, but `patch` provides automatic security patches within the minor version, while `none` provided no automatic upgrades at all.

### Q: What if I want automatic minor version upgrades but less frequently than `stable`?

**A:** Consider using the `stable` channel, which upgrades to new minor versions after they have been proven in the `rapid` channel. Alternatively, you can use `patch` and manually upgrade minor versions on your own schedule—but you must do so before EOL or the platform will upgrade for you.

### Q: The `upgradeDriver` field is read-only. When does it change from `PlatformDriven` back to `CustomerDriven`?

**A:** The `upgradeDriver` field is **computed dynamically** based on the cluster's current state. It is not a persistent setting—it reflects real-time status.

**Scenarios where `upgradeDriver` returns to `CustomerDriven`:**

| Scenario | What Happened | Result |
|----------|---------------|--------|
| **Customer upgrades before forced upgrade** | Customer manually upgrades or the auto-upgrade channel (`stable`/`rapid`) upgrades the cluster to a supported version before the platform acts. | `upgradeDriver` → `CustomerDriven` |
| **Platform completes forced upgrade** | Platform successfully force-upgrades the cluster to the next LTS version. Cluster is now on a supported version. | `upgradeDriver` → `CustomerDriven` |
| **Customer switches to minor-crossing channel** | Customer on `patch` or deprecated `none` switches to `stable` or `rapid` channel before EOL. The new channel will handle the upgrade. | `upgradeDriver` → `CustomerDriven` |
| **LTS cluster exits grace period via customer action** | During the 60-day platform support grace period, customer upgrades the LTS cluster to the next LTS version manually. | `upgradeDriver` → `CustomerDriven` |

**Key Insight:** Once a cluster is on a supported version and has a forward-looking upgrade path (via channel or customer intent), `upgradeDriver` is `CustomerDriven`. The field only shows `PlatformDriven` when the cluster is at or past EOL with no scheduled customer-driven upgrade.

### Q: Can a customer prevent `upgradeDriver` from ever becoming `PlatformDriven`?

**A:** Yes. A cluster's `upgradeDriver` will never become `PlatformDriven` if:
1. The cluster uses `stable` or `rapid` auto-upgrade channel (these channels automatically upgrade to new minor versions before EOL).
2. The customer proactively upgrades manually before EOL.
3. The customer configures a maintenance window and has scheduled an upgrade before the EOL date.

**Best Practice:** Use `stable` or `rapid` channel with a configured maintenance window to ensure upgrades happen on your schedule and `upgradeDriver` always remains `CustomerDriven`.
