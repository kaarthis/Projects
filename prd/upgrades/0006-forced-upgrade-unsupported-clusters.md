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

2. **Steady State (Ongoing):** A new policy where no cluster can ever become unsupported. Steady state is triggered by a new Kubernetes version GA (e.g., 1.38 GA in November 2026), which causes the oldest supported versions to reach EOL. At that point:
   - **Community clusters at EOL:** Enter a 60-day platform support grace period (see [Platform Support Policy](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#platform-support-policy)), then force-upgraded to the next supported community version.
   - **LTS clusters at EOL:** Enter a 60-day platform support grace period, then force-upgraded to the next LTS version.
   - **No tier transitions:** The platform will never automatically convert a community cluster to LTS or vice versa. Customers must explicitly choose their tier. This ensures no surprise billing changes.

---

## Goals/Non-Goals

### Functional Goals

1. **Eliminate Unsupported Footprint:** Reduce the percentage of unsupported clusters from 35% to <1% within 12 months of steady state enforcement.

2. **Transition State Execution:** Successfully migrate all existing unsupported clusters to a supported version by the defined cutoff date (e.g., August 2026).

3. **Steady State Enforcement:** Implement a system where clusters are automatically upgraded before falling out of support, making "unsupported" an impossible state.

4. **Customer Communication:** Deliver clear, multi-channel notifications to enable customers to self-upgrade before platform intervention.

5. **Minimize Disruption:** Forced upgrades respect customer-configured maintenance windows; if no maintenance window is configured, platform uses system convenience timing (platform-determined, not a specific day like weekend). Clusters stay within their tier (community or LTS) to avoid surprise billing changes.

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



## What will the announcement look like?

**Announcing "Always Supported" Policy for Azure Kubernetes Service (AKS)**

We are announcing a new policy to ensure all AKS clusters remain on supported Kubernetes versions at all times. Starting **[Date]**, AKS will automatically upgrade clusters that have not been upgraded by customers before their version reaches end-of-support.

**Addressing Key Challenges**

Running Kubernetes clusters on unsupported versions exposes customers to unpatched security vulnerabilities and operational risk. Today, over 35% of AKS clusters run on unsupported versions. This new policy eliminates this risk by ensuring every cluster stays within the supported version window.

**How It Works**

1. **Transition Phase (Now - August 2026):** If your cluster is currently on an unsupported version, you will receive notifications to upgrade. If you do not upgrade by the cutoff date, AKS will upgrade your cluster to the next supported version.

2. **Steady State (November 2026 onward):** When a cluster's version reaches end-of-support, it enters a 60-day [platform support](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#platform-support-policy) grace period. After the grace period, AKS will force upgrade community clusters to the next supported community version, and LTS clusters to the next LTS version. **No tier transitions occur**—community stays community, LTS stays LTS, ensuring no surprise billing changes.

**Important for `none` and `patch` channel users:** The `none` channel is retained for customers who want manual control over upgrades. However, both `none` and `patch` channels are subject to platform-enforced upgrades at EOL. The `patch` channel only upgrades within the same minor version—it will NOT upgrade you to a new minor version when your current version reaches EOL. If you are on either `none` or `patch` channel, you must upgrade manually (or switch to `stable`/`rapid`) before EOL, or AKS will upgrade your cluster automatically.

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
│  Triggered by: New K8s version GA (e.g., 1.38 GA in Nov 2026)               │
│  This causes EOL of: 1.34 Community / 1.31 LTS                              │
│  Note: All timelines are illustrative and may vary based on execution.      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Community Clusters at EOL       │ LTS Clusters at EOL                   ││
│  │ (e.g., 1.34 reaches EOL)        │ (e.g., 1.31 LTS reaches EOL)          ││
│  │         ↓                       │         ↓                             ││
│  │ 60-day platform support         │ 60-day platform support               ││
│  │ grace period                    │ grace period                          ││
│  │         ↓                       │         ↓                             ││
│  │ Force upgrade to 1.35           │ Force upgrade to 1.32 LTS             ││
│  │ (next supported community)      │ (next supported LTS)                  ││
│  │ (Bypass PDB after drain timeout)│ (Bypass PDB after drain timeout)      ││
│  │ (Exponential backoff retry)     │ (Exponential backoff retry)           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  KEY STEADY STATE RULES:                                                     │
│  • No cluster can exit "Always Supported" policy                            │
│  • No tier transitions: Community → Community, LTS → LTS (no surprise billing)│
│  • "None" channel retained—customers get manual control until EOL           │
│  • "Patch" channel does NOT cross minor versions—platform takes over at EOL │
│  • lastUpgradeSource field shows "System" after forced upgrade              │
│  • Platform Support = 60-day grace period before forced upgrade             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### API Design Options

Three options were evaluated for implementing steady state enforcement:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **Option 1:** Change `none` channel behavior | Keep the `none` enum value but change its behavior to allow platform-driven upgrades at EOL. | No API breaking change. Simple to implement. | Confusing for customers. `none` no longer means "no upgrades." Documentation mismatch. |
| **Option 2:** Deprecate `none`, introduce `platform-forced` channel | Remove `none` and add a new channel value that explicitly signals platform-controlled upgrades. | Clear intent for customers. | Formal API breaking change process required. Customer migration effort. |
| **Option 3 (Recommended):** Retain `none`, add read-only `lastUpgradeSource` field next to `kubernetesVersion` | Keep `none` channel for customers who want manual control (e.g., those falling back from `stable`). Add a new read-only property in `managedClusterProperties` (outside `autoUpgradeProfile`, next to `kubernetesVersion`): `lastUpgradeSource` with enum values `User` or `System`. | Clear separation: Channels represent customer intent (including explicit opt-out via `none`). Platform behavior is explicit and read-only. No breaking change for `none` users. Property location makes it clear this describes cluster state, not upgrade configuration. Re-uses terminology already established in AKS. | Requires clear documentation that `none` still results in system-driven upgrade at EOL. |


**Recommendation: Option 3 — Retain `none`, add read-only `lastUpgradeSource` field next to `kubernetesVersion`**

This option provides the clearest customer experience:
- **Auto-upgrade channels** (`none`, `patch`, `stable`, `rapid`) represent **customer intent**—they indicate the customer's preference for how upgrades should be handled under normal circumstances.
- **`none` channel is retained:** Customers who want full manual control can continue to use `none`. This is valuable for customers who fall back from `stable` or `rapid` to manage upgrades themselves.
- **Clusters without an `autoUpgradeProfile` or with `upgradeChannel: none`:** These clusters are subject to platform-driven upgrades at EOL. The platform will force-upgrade community clusters to the next supported community version, and LTS clusters to the next LTS version.
- **`lastUpgradeSource` property** (read-only, located next to `kubernetesVersion` in `managedClusterProperties`) indicates **how the cluster reached its current version**. This field is **computed dynamically** based on cluster history—it is not a persistent setting and not part of `autoUpgradeProfile`.
- Values: `User` (customer performed the upgrade) or `System` (platform forced the upgrade).
- When the platform forces an upgrade at EOL, `lastUpgradeSource` becomes `System`, giving customers visibility into the platform action taken.
- Clear documentation and portal UX communicate that clusters without an `autoUpgradeProfile`, or with `upgradeChannel` set to `none` or `patch`, will receive platform-driven upgrades at EOL. The `lastUpgradeSource` field makes this behavior explicit and observable.

#### Special Case: `patch` Channel at EOL

**Important:** The `patch` channel only upgrades within the same minor version (e.g., 1.30.1 → 1.30.2). It does **NOT** perform minor version upgrades. When a minor version reaches EOL, a cluster on `patch` channel will NOT receive an automatic upgrade to the next minor version.

**Behavior at EOL:**
1. **Notification:** Customers on `patch` channel receive explicit warnings that their minor version is approaching EOL and `patch` channel will not save them.
2. **Customer Action Window:** Customer can switch to `stable` or `rapid` channel, or perform a manual upgrade to a supported version.
3. **Platform Takeover:** If the customer takes no action by EOL, the cluster enters a 60-day platform support grace period, then the platform force-upgrades the cluster to the next supported version within the same tier (community → next community, LTS → next LTS). After the upgrade completes, `lastUpgradeSource` will show `System`.
4. **Channel Preserved:** After the forced upgrade, the cluster's `upgradeChannel` remains `patch`. The platform only intervened for the EOL event; ongoing behavior reverts to customer-driven patch upgrades.

**Rationale:** Customers on `patch` explicitly chose patch-only behavior, meaning they accept responsibility for minor version upgrades. If they do not act, platform-driven upgrade to the next supported version within their tier is a safe fallback that keeps them supported without surprise billing changes.

---


### Communication Plan

**Target Recipients:** Subscription owners for clusters approaching EOL.

**Purpose:** Frequent and targeted outreach before transition of clusters (one-off migration phase).

| Timeline | Action | Channel |
|----------|--------|---------|
| **T-12 months** | Announce policy change (this PRD) | Blog, Email to Subscription Owners, Azure Updates |
| **T-6 months** | First warning to unsupported cluster owners | Email to Subscription Owners, Portal Banner, Azure Advisor |
| **T-6 months** | **Special warning to `patch` channel users:** "Your minor version is approaching EOL. The `patch` channel will not upgrade you to a new minor version. Switch to `stable`/`rapid` or upgrade manually." | Email to Subscription Owners, Portal Banner |
| **T-3 months** | Second warning with upgrade instructions | Email to Subscription Owners, Portal Banner, Azure Advisor |
| **T-1 month** | Final warning: "Upgrade now or AKS will upgrade for you" | Email to Subscription Owners, Portal Banner, Azure Advisor |
| **T-0** | Forced upgrade executed during maintenance window (or system convenience if none configured) | N/A (Automated) |
| **Post-upgrade** | Confirmation notification | Email to Subscription Owners, Activity Log |
---

### Breaking Changes

| Change | Impact | Mitigation |
|--------|--------|------------|
| **Retain `none` channel, add read-only `lastUpgradeSource` field** | Customers using `none` can continue to use it for manual control. Platform behavior at EOL is now explicit via the `lastUpgradeSource` field (located next to `kubernetesVersion`). Customers must understand that `none` still results in platform-driven upgrade at EOL. | Clear documentation that `none` channel clusters will receive platform-driven upgrades at EOL. `lastUpgradeSource` field makes this behavior explicit and observable in API/Portal. |
| **Forced upgrades at EOL** | Customers who previously remained on unsupported versions will experience mandatory upgrades. Forced upgrades will push through PDB blocks (using [force upgrade with bypass PDB](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb) after drain timeout) and handle API deprecations. | Multi-month advance warning. Upgrades respect maintenance windows when configured. |

---

### Alternatives Considered

#### Alternative: Automatic LTS Conversion at Community EOL (Rejected)

**Description:** When a community version reaches EOL, automatically and silently convert the cluster to LTS (billing/support plan change only, no upgrade). LTS pricing would begin immediately. Customers could opt out by upgrading to a supported community version.

**Why Considered:**
- Minimizes disruption for the majority of clusters (no upgrade, just a billing change).
- Keeps customers on a supported version without requiring any action.
- Simpler for customers who don't want to manage upgrades.

**Why Rejected:**
1. **Surprise billing changes:** Automatic LTS conversion would result in unexpected LTS billing for customers who did not explicitly opt in. This violates the principle of no surprise billing.
2. **Tier transitions should be explicit:** Customers should always make an active choice to move between community and LTS tiers. Automatic tier transitions blur the line between these offerings.
3. **Customer trust:** Implicit pricing changes erode customer trust, even with advance notification.

**Chosen Approach:** Community clusters at EOL receive a 60-day platform support grace period, then are force-upgraded to the next supported community version. LTS clusters at EOL are force-upgraded to the next LTS version. No tier transitions occur, ensuring no surprise billing.

---

### Forced Upgrade Behavior

**Method:** Forced upgrades use the [Force Upgrade (Bypass PDB)](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb) option after the drain timeout expires. This ensures upgrades complete even when PDBs would otherwise block node eviction.

**Retry Strategy:** Based on competitor analysis:
- **GKE:** Retries upgrades with exponential backoff over several days.
- **EKS:** Attempts upgrade in maintenance windows, retries if failed.

**AKS Approach:** The platform will continue attempting forced upgrades with appropriate backoff until successful. There is no cap on retry attempts—the platform will persist until the cluster is upgraded to a supported version.

**Post-Upgrade State:** If a forced upgrade fails after all retries:
1. Cluster remains in unsupported state.
2. Customer receives alert with failure details.
3. Support ticket is auto-created for high-severity cases.
4. Customer must manually resolve and upgrade.

---

### Pricing

- **No pricing change** for forced upgrades.
- **No automatic tier transitions:** The platform will never automatically convert a community cluster to LTS or vice versa. This ensures customers are never surprised by LTS billing changes.
- **LTS pricing:** Customers must explicitly opt in to LTS. See [LTS documentation](https://learn.microsoft.com/en-us/azure/aks/long-term-support) for details on LTS pricing and enrollment.

---

## User Experience 

### Portal Experience

**Cluster Overview Blade:**
- **EOL Warning Banner:** "This cluster is on version X.XX which reaches end-of-support on [Date]. [Upgrade Now] or AKS will upgrade automatically."
- **`patch` Channel Warning:** "This cluster uses the `patch` channel, which only upgrades within the same minor version. Your minor version X.XX reaches end-of-support on [Date]. Switch to `stable`/`rapid` or upgrade manually, or AKS will upgrade automatically."
- **Post-Action Banner:** "This cluster was upgraded to X.XX by AKS on [Date]. View details in the [Activity Log]."
- **Status Indicator:** `Support Status: Supported | Approaching EOL | Platform Upgrade Scheduled`
- Display `lastUpgradeSource` status when `System`.

**Activity Log Integration:**
- All platform-driven upgrades are logged as ARM activity log events.
- Event includes: action type, previous/new version, timestamp, and initiator (`System`).
- Customers can query via Azure Portal Activity Log or `az monitor activity-log list`.

**Azure Advisor Recommendations:**
- **Recommendation:** "Upgrade AKS cluster to a supported Kubernetes version"
- **Impact:** High
- **Category:** Security
- **Trigger:** Cluster version is within 90 days of EOL or already unsupported.
- **Action:** Direct link to upgrade blade with recommended target version.

**Event Grid Integration:**
- **Upcoming Platform Upgrade Event:** Published when a cluster is scheduled for platform-driven upgrade (at EOL, 60 days before forced upgrade). Event type: `Microsoft.ContainerService.ClusterUpgradeScheduled`. Payload includes cluster ID, current version, target version, and scheduled date.
- **Post-Upgrade Event:** Published after a platform-driven upgrade completes. Event type: `Microsoft.ContainerService.ClusterUpgradeCompleted`. Payload includes cluster ID, previous version, new version, upgrade source (`System`), and timestamp.
- Customers can subscribe to these events and route them to Azure Functions, Logic Apps, webhooks, or other Event Grid destinations for custom automation and alerting workflows.

**AKS Communication Manager (Opt-In):**
- Customers who have opted into AKS Communication Manager receive automated email notifications:
    - **At EOL:** "Action Required: Your cluster [cluster-name] has reached end-of-support. You have 60 days to upgrade before automatic platform upgrade."
    - **On EOL:** "Notice: Your cluster [cluster-name] is now on an unsupported version. AKS will upgrade this cluster automatically."
    - **Post-EOL (after platform action):** "Completed: AKS has [upgraded / converted to LTS] your cluster [cluster-name]. Review details in the Activity Log."
- Emails include direct links to upgrade blade, documentation, and support resources.

**Kubernetes Hub (Fleet View):**
- Dashboard: "X clusters approaching EOL in next 30/60/90 days"
- Filter: "Show clusters requiring action"
- Indicator for clusters where `lastUpgradeSource = System`
- Column: "Last Platform Action" showing recent auto-upgrades/conversions

### API

**New read-only property in `managedClusterProperties` (next to `kubernetesVersion`):**

```json
{
    "properties": {
        "kubernetesVersion": "1.30.0",
        "lastUpgradeSource": "User",  // Read-only. Enum: User | System
        "autoUpgradeProfile": {
            "upgradeChannel": "none",
            "nodeOSUpgradeChannel": "NodeImage"
        }
    }
}
```

**`lastUpgradeSource` field:**
- **Location:** `managedClusterProperties` (outside `autoUpgradeProfile`, next to `kubernetesVersion`)
- **Type:** Read-only enum (`User` | `System`)
- **Purpose:** Indicates how the cluster reached its current `kubernetesVersion`.
- `User`: The last upgrade was initiated by the customer (via API, CLI, Portal, or auto-upgrade channel).
- `System`: The last upgrade was forced by the platform due to EOL policy enforcement.

**Note:** This field reflects **historical state** (how the cluster reached its current version), not **future intent**. It provides audit trail and visibility into platform actions.

**`none` channel behavior:**
- `none` channel is retained for customers who want manual control (e.g., those falling back from `stable`).
- Clear documentation and portal UX communicate that even `none` channel clusters will receive platform-driven upgrades at EOL.
- The `lastUpgradeSource` field makes platform actions explicit and observable.

### CLI Experience

**New output in `az aks show`:**
```
Kubernetes Version: 1.30.0
Last Upgrade Source: User   <-- NEW (next to kubernetesVersion)

Auto Upgrade Profile:
    Upgrade Channel: none
    Node OS Upgrade Channel: NodeImage
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
| 4 | Forced upgrades must use the [Force Upgrade (Bypass PDB)](https://learn.microsoft.com/en-us/azure/aks/upgrade-options#option-1-force-upgrade-bypass-pdb) method after drain timeout. Platform will use exponential backoff retry strategy (GKE-style, no fixed cap) until the cluster is upgraded; if consistently failing, cluster is flagged and customers alerted. | P0 |
| 5 | API must expose `lastUpgradeSource` read-only property in `managedClusterProperties` (next to `kubernetesVersion`) indicating `User` or `System`. This field reflects how the cluster reached its current version. | P0 |
| 6 | `none` auto-upgrade channel must be retained. Documentation must clearly explain that `none` channel clusters will receive platform-driven upgrades at EOL, made explicit via the `lastUpgradeSource` field after the upgrade. | P0 |
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
| 4 | E2E test: `lastUpgradeSource` property correctly reflects platform vs. customer-driven upgrades. | P0 |
| 5 | E2E test: Forced upgrade succeeds without rollback in 99.5% of cases. Platform uses exponential backoff retry; persistently failing clusters are flagged and customers alerted. | P0 |
| 6 | E2E test: Clusters with `none` channel at EOL receive forced upgrade and `lastUpgradeSource` shows `System` afterward. | P0 |
| 7 | E2E test: Clusters on `patch` channel approaching EOL receive specific warning about minor version limitation. | P0 |
| 8 | E2E test: Clusters on `patch` channel at EOL receive forced upgrade and `lastUpgradeSource` shows `System` afterward. | P0 |
| 9 | Load test: System can process forced upgrades for 10,000+ clusters in a single day. | P1 |

---

# Dependencies and Risks 

| No. | Dependency / Risk | Giver Team / Mitigation |
|-----|-------------------|-------------------------|
| 1 | **Notification pipeline integration** | Comms Manager team. Risk: Delivery failures. Mitigation: Multi-channel (email + portal + advisor). |
| 2 | **Maintenance window enforcement** | AKS RP team. Risk: Edge cases where no window is configured. Mitigation: Use system convenience timing (platform-determined) if no window set—not a specific default like weekends. |
| 3 | **Customer backlash** | Risk: Customers unhappy with forced upgrades. Mitigation: 12-month advance notice, clear communication, respect for maintenance windows. |
| 4 | **Documentation clarity for `none` channel** | AKS Docs team. Risk: Customers on `none` may not understand platform will still upgrade at EOL. Mitigation: Clear documentation, portal UX, and `lastUpgradeSource` field visibility after platform action. |
| 5 | **Upgrade reliability** | AKS Upgrade team. Risk: Forced upgrades fail at higher rate than voluntary. Mitigation: Use same safe upgrade infrastructure (surge, health gates). |

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

| Version | Type | EOL Date | Steady State Action |
|---------|------|----------|---------------------|
| 1.30 | LTS | Aug 2026 | 60-day grace → Force upgrade to 1.32 LTS |
| 1.32 | LTS | Nov 2027 | 60-day grace → Force upgrade to 1.34 LTS |
| 1.33 | Community | May 2026 | 60-day grace → Force upgrade to 1.34 (community) |
| 1.34 | Community | Aug 2026 | 60-day grace → Force upgrade to 1.35 (community) |
| 1.35 | Community | Nov 2026 | 60-day grace → Force upgrade to 1.36 (community) |

**Key Insight:** 
- **Community clusters at EOL:** 60-day platform support grace period, then forced upgrade to next supported community version. No tier change.
- **LTS clusters at EOL:** 60-day platform support grace period, then forced upgrade to next LTS version. No tier change.
- **No automatic tier transitions:** Customers are never surprised by billing changes. LTS enrollment is always explicit.

---

## Frequently Asked Questions

### Q: What happens to clusters on the `patch` auto-upgrade channel when their minor version reaches EOL?

**A:** The `patch` channel only upgrades within the same minor version (e.g., 1.30.1 → 1.30.2). It does **NOT** perform minor version upgrades.

When a minor version reaches EOL:
1. Customers on `patch` receive explicit warnings starting T-6 months that their minor version is approaching EOL and the `patch` channel will not upgrade them.
2. Customers can switch to `stable` or `rapid` channel, or perform a manual upgrade.
3. If no action is taken by EOL, the cluster enters a 60-day platform support grace period, then the platform force-upgrades the cluster to the next supported version within the same tier (community → next community, LTS → next LTS). After the upgrade, `lastUpgradeSource` will show `System`.
4. After the forced upgrade, the cluster's `upgradeChannel` remains `patch`. The platform only intervened for the EOL event.

**Key Point:** Choosing `patch` means the customer accepts responsibility for minor version upgrades. The platform only takes over at EOL as a safety net.

### Q: Will my `patch` channel setting be changed after a forced upgrade?

**A:** No. The `upgradeChannel` setting remains `patch` after a platform-driven forced upgrade. The platform only intervenes at EOL to ensure the cluster stays on a supported version. Ongoing patch upgrades within the new minor version continue to be customer-driven via the `patch` channel.

### Q: How is `patch` channel different from `none` channel after this change?

**A:** 
- **`none`:** Customer explicitly opted out of all automatic upgrades. Customer retains full manual control. Platform takes over at EOL only if customer does not act.
- **`patch`:** Customer opted in to automatic patch upgrades within the same minor version. Customer is responsible for minor version upgrades. Platform takes over at EOL only if customer does not act.

Both result in platform-driven upgrade at EOL, but `patch` provides automatic security patches within the minor version, while `none` provides no automatic upgrades at all. The `none` channel is retained for customers who want full manual control (e.g., those falling back from `stable` or `rapid`).

### Q: What if I want automatic minor version upgrades but less frequently than `stable`?

**A:** Consider using the `stable` channel, which upgrades to new minor versions after they have been proven in the `rapid` channel. Alternatively, you can use `patch` and manually upgrade minor versions on your own schedule—but you must do so before EOL or the platform will upgrade for you.

### Q: The `lastUpgradeSource` field is read-only. What does it indicate?

**A:** The `lastUpgradeSource` field is **computed dynamically** and indicates **how the cluster reached its current `kubernetesVersion`**. It is not a forward-looking indicator but a historical record.

- `User`: The last upgrade was initiated by the customer (via API, CLI, Portal, or auto-upgrade channel such as `stable`/`rapid`).
- `System`: The last upgrade was forced by the platform due to EOL policy enforcement.

**Example scenarios:**

| Scenario | What Happened | `lastUpgradeSource` Value |
|----------|---------------|---------------------------|
| **Customer manually upgrades** | Customer upgrades from 1.29 to 1.30 via CLI or Portal. | `User` |
| **Auto-upgrade channel upgrades** | Cluster on `stable` channel automatically upgrades to 1.30. | `User` |
| **Platform forces upgrade at EOL (Community)** | Customer took no action; platform force-upgraded community cluster from 1.34 to 1.35. | `System` |
| **Platform forces upgrade at EOL (LTS)** | Customer took no action; platform force-upgraded LTS cluster from 1.30 LTS to 1.32 LTS. | `System` |
| **Customer upgrades after platform action** | After platform forced upgrade to 1.35, customer later upgrades to 1.36. | `User` |

**Key Insight:** The `lastUpgradeSource` field provides audit trail visibility. After any customer-initiated upgrade (manual or via auto-upgrade channel), the field returns to `User`. It only shows `System` immediately after a platform-forced upgrade.

### Q: Can a customer avoid the platform ever forcing an upgrade (and thus `lastUpgradeSource` being `System`)?

**A:** Yes. A cluster will never experience a platform-driven upgrade if:
1. The cluster uses `stable` or `rapid` auto-upgrade channel (these channels automatically upgrade to new minor versions before EOL).
2. The customer proactively upgrades manually before EOL.
3. The customer configures a maintenance window and upgrades before the EOL date.

**Best Practice:** Use `stable` or `rapid` channel with a configured maintenance window to ensure upgrades happen on your schedule and `lastUpgradeSource` always shows `User`.

### Q: Is the `none` channel being deprecated?

**A:** No. The `none` channel is **retained** for customers who want full manual control over upgrades. This is valuable for customers who fall back from `stable` or `rapid` to manage upgrades themselves. However, clear documentation and portal UX communicate that even `none` channel clusters will receive platform-driven upgrades at EOL. After a platform-driven upgrade, the `lastUpgradeSource` field will show `System`, providing visibility into the platform action taken.
