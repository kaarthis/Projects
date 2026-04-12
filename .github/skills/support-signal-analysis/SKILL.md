---
name: support-signal-analysis
description: 'Analyze AKS support ticket data from Kusto to identify high-impact documentation gaps. Use for doc-a-thon CSS Reviewer analysis, support topic mapping, ticket volume scoring, customer pain point discovery.'
---

# Support Signal Analysis

## When to Use
- Finder agent computing support scores for article prioritization
- CSS Reviewer agent analyzing support patterns for a specific article topic
- Mapping support ticket themes to documentation gaps

## Kusto Connection

| Property | Value |
|----------|-------|
| **Cluster** | `https://supportrptwus3prod.westus3.kusto.windows.net` |
| **Database** | `Product360Jit` |
| **Table** | `AllCloudsSupportIncidentWithReferenceModelJitVNext` |
| **AKS Product ID** | `16450` |

## Key Queries

### Top Support Topics (Last 90 Days)
```kql
AllCloudsSupportIncidentWithReferenceModelJitVNext
| where ProductId == "16450"
| where CreatedTime > ago(90d)
| summarize TicketCount = count() by SupportTopicL2, SupportTopicL3
| order by TicketCount desc
| take 50
```

### Topic Trend (Monthly)
```kql
AllCloudsSupportIncidentWithReferenceModelJitVNext
| where ProductId == "16450"
| where CreatedTime > ago(180d)
| summarize TicketCount = count() by SupportTopicL3, Month = startofmonth(CreatedTime)
| order by Month desc, TicketCount desc
```

### Severity Distribution for a Topic
```kql
AllCloudsSupportIncidentWithReferenceModelJitVNext
| where ProductId == "16450"
| where CreatedTime > ago(90d)
| where SupportTopicL2 has "{topic}"
| summarize TicketCount = count() by Severity
| order by Severity asc
```

### High-Severity Tickets by Topic
```kql
AllCloudsSupportIncidentWithReferenceModelJitVNext
| where ProductId == "16450"
| where CreatedTime > ago(90d)
| where Severity in ("A", "B")
| summarize SevAB_Count = count() by SupportTopicL2, SupportTopicL3
| order by SevAB_Count desc
| take 20
```

## Topic-to-Article Mapping

Map support topic hierarchy to documentation articles:

| Support Topic L2 | Likely Article Areas |
|---|---|
| Cluster Create and Upgrade | create-cluster, upgrade, kubernetes-versions |
| Connectivity | networking, load-balancer, ingress, private-cluster |
| Node Pools | node-pool, scale, auto-scaler |
| Identity and Security | managed-identity, workload-identity, rbac, aad |
| Monitoring | monitoring, diagnostics, logs |
| Storage | storage, persistent-volumes, csi-drivers |
| Networking | cni, network-policy, service-mesh |

### Mapping Algorithm
1. Normalize support topic text (lowercase, remove special chars)
2. Match against article `title` and `ms.topic` metadata
3. Match against article H2 headings
4. Fuzzy match with Levenshtein distance ≤ 3
5. If no match, flag as "unmapped support topic — potential doc gap"

## Support Score Computation

For the Finder's priority scoring:

```python
# Get all topic ticket counts
all_counts = [query results ordered by TicketCount]

# For each article's matched topics, sum ticket counts
article_ticket_count = sum(matched_topic_counts)

# Normalize to 0-100 by percentile
percentile = rank(article_ticket_count, all_article_counts)
support_score = percentile * 100
```

## Fallback (No Kusto Access)

If Kusto is unavailable, use these proxy signals:
1. **GitHub Issues** on `Azure/AKS` repo — count issues mentioning the topic
2. **Stack Overflow** — count questions tagged `azure-aks` + topic keywords
3. **MS Q&A** — search for topic-related questions
4. Set `support_score = 0` and note "Support signal unavailable" in output
