---
description: "Run only the Finder agent to discover stale AKS documentation articles without creating issues. Article staleness scan, opportunity discovery, priority ranking."
agent: "agent"
---

# Find Stale Articles

Run the **Finder** agent to scan `MicrosoftDocs/azure-aks-docs` for stale and high-priority articles.

## Configuration

- **Target repo:** MicrosoftDocs/azure-aks-docs
- **Article path:** `articles/aks/`
- **Max results:** ${input:maxResults:Maximum articles to return (default: 50)}
- **Staleness threshold:** ${input:stalenessThreshold:Minimum days since ms.date to include (default: 365)}

## Instructions

1. Clone or update the docs repo locally
2. Scan all `.md` files under `articles/aks/`
3. Parse YAML frontmatter for `ms.date`, `title`, `ms.topic`
4. Check git history for last commit date per file
5. Query Kusto for support ticket volumes (if available)
6. Compute priority scores using the scoring algorithm
7. Return ranked list as JSON

Output the results as a ranked table AND as JSON for use by the Dispatcher.
