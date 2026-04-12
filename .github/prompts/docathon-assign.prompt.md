---
description: "Assign a pre-curated list of articles for doc-a-thon review. Use when articles are already selected (e.g., from a .loop file or spreadsheet) rather than auto-discovered."
agent: "agent"
---

# Assign Articles for Review

Take a provided list of articles and create the doc-a-thon Kanban board.

## Input

Paste the article list below. Accepted formats:
- Markdown table with columns: URL, Title, Priority
- CSV with columns: url, title, priority
- Simple list of URLs (one per line — priority will be set to "medium")

**Article list:**
${input:articleList:Paste article URLs or a markdown/CSV table of articles to review}

## Configuration

- **Month:** ${input:month:Month name (e.g., April 2026)}
- **Kanban repo:** ${input:kanbanRepo:Repo for GitHub Issues and Project board (default: current repo)}

## Instructions

1. Parse the article list from the input
2. For each article, fetch the source file from the docs repo to extract metadata (`ms.date`, `title`)
3. If priority is not provided, run a quick staleness check on each article
4. Pass the article list to the **Dispatcher** agent to create the Kanban board
5. Report back with the board URL and issue count
