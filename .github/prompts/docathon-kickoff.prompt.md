---
description: "Start a new monthly doc-a-thon — scan for stale articles, create Kanban board, and prepare for review. Full automated pipeline from discovery to board creation."
agent: "agent"
---

# Doc-a-thon Kickoff

Run a full doc-a-thon kickoff for **${input:month:Month name (e.g., April 2026)}**.

## What this does

1. **Discover** — Invoke the `docathon-finder` agent to scan `MicrosoftDocs/azure-aks-docs` for stale and high-priority articles
2. **Create board** — Invoke the `docathon-dispatcher` agent to create a GitHub Projects Kanban board with one issue per article
3. **Ready for review** — Issues are in Backlog, ready for review agents to pick up

## Configuration

- **Target repo:** MicrosoftDocs/azure-aks-docs
- **Article path:** `articles/aks/`
- **Max articles:** ${input:maxArticles:Maximum articles to include (default: 30)}
- **Minimum priority score:** ${input:minScore:Minimum priority score threshold (default: 40)}
- **Kanban repo:** ${input:kanbanRepo:Repo for GitHub Issues and Project board (default: current repo)}

## Kusto Support Signal

Query support ticket volumes from:
- Cluster: `https://supportrptwus3prod.westus3.kusto.windows.net`
- Database: `Product360Jit`
- Table: `AllCloudsSupportIncidentWithReferenceModelJitVNext`
- Product ID: `16450`
- Time window: last 90 days

## Procedure

1. Run the **Finder** agent with the configuration above
2. Take the Finder's ranked output and pass it to the **Dispatcher** agent
3. The Dispatcher creates the Kanban board and issues
4. Report back with:
   - Number of articles discovered
   - Top 5 articles by priority score
   - Kanban board URL
   - Next steps for reviewers
