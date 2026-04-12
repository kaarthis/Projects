---
name: stale-article-detection
description: 'Detect stale AKS documentation articles by parsing ms.date metadata, git history, and computing priority scores. Use for doc-a-thon article discovery, staleness scanning, freshness analysis.'
---

# Stale Article Detection

## When to Use
- Scanning `MicrosoftDocs/azure-aks-docs` for articles needing review
- Computing priority scores for doc-a-thon article ranking
- Analyzing content freshness across a documentation set

## Staleness Sources

### 1. `ms.date` Metadata
Every MS Learn article has YAML frontmatter with `ms.date` in `mm/dd/yyyy` format:
```yaml
---
title: Configure an AKS cluster
ms.date: 01/15/2025
ms.topic: how-to
ms.service: azure-kubernetes-service
---
```

Parse with: `grep -E "^ms\.date:" {file} | head -1 | awk '{print $2}'`

### 2. Git Commit History
Last meaningful commit (excluding bot/automated commits):
```bash
git log -1 --format="%ai" --diff-filter=M -- {file}
```

Filter out automated commits:
```bash
git log --format="%H %an %s" -- {file} | grep -v "learn-build-service" | grep -v "prmerger-automator" | head -1
```

### 3. Redirect Check
Exclude redirected articles by checking `.openpublishing.redirection.json`:
```bash
cat .openpublishing.redirection.json | jq '.redirections[].source_path' | grep {relative_path}
```

## Priority Score Algorithm

```
priority_score = (0.5 × staleness_score) + (0.4 × support_score) + (activity_bonus)
```

### Staleness Score (0–100)
```python
days = (today - ms_date).days
staleness_score = min(100, (days / 730) * 100)
# 365 days = 50, 730+ days = 100, 180 days = 25
```

### Support Score (0–100)
Normalized by percentile rank across all scanned topics:
```python
support_score = (rank_position / total_topics) * 100
# Top support topic = 100, bottom = 0
```

### Activity Bonus (-10 to +10)
```python
days_since_last_commit = (today - last_git_commit).days
if days_since_last_commit > 180:
    activity_bonus = 10   # Dormant — penalize
elif days_since_last_commit < 90:
    activity_bonus = -10  # Active — reward
else:
    activity_bonus = 0
```

## File Filtering

Include: `articles/aks/**/*.md`

Exclude:
- `includes/**` (shared snippets)
- `media/**` (images)
- `zone-pivots/**`
- Files in `.openpublishing.redirection.json`
- Files with `ms.topic: include`
