---
description: "Review guidelines for doc-a-thon documentation reviews. Applies to all doc-a-thon review agents. Content quality standards, review severity levels, output format requirements."
applyTo: "docathon/**"
---

# Doc-a-thon Review Guidelines

These instructions apply to all doc-a-thon review agents operating on AKS documentation.

## Severity Levels

Use these severity levels consistently across all review types:

| Severity | Meaning | Action Required |
|----------|---------|----------------|
| **Critical** | Incorrect information that could cause customer outages, data loss, or security issues | Must fix before merge |
| **High** | Outdated commands/versions, broken links, missing prerequisites that cause customer confusion | Should fix before merge |
| **Medium** | Style violations, structural improvements, minor inaccuracies | Fix if time permits |
| **Low** | Cosmetic issues, minor wording suggestions, nice-to-have improvements | Optional |

## Review Principles

1. **Customer-first** — every finding should tie back to customer impact
2. **Evidence-based** — cite the specific line, command, or section
3. **Actionable** — provide the fix, not just the problem
4. **Non-destructive** — preserve existing content unless it's wrong; improve, don't rewrite
5. **Scope-aware** — each reviewer stays in their lane (Doc=style, Eng=technical, CSS=support)

## Output Format Requirements

All reviewers MUST use the structured output format defined in their agent charter. This enables the PM Reviewer to parse and synthesize findings consistently.

Required fields in every review:
- `Article` — title
- `File` — file path
- `Status` — Pass | Needs Changes | Needs Major Revision
- `Reviewer` — agent role name
- At least one findings section with severity per finding
- `Summary` — 2-3 sentence overall assessment

## MS Learn Documentation Standards

- **ms.date** — update to today when content is verified or changed (format: `mm/dd/yyyy`)
- **Metadata** — all required fields present: `title`, `description`, `ms.topic`, `ms.service`, `author`, `ms.author`
- **Structure** — H1 matches title, logical heading hierarchy, prerequisites for how-to articles, next-steps at the end
- **Voice** — second person ("you"), active voice, present tense for descriptions, imperative for instructions
- **Code blocks** — language specified, commands are runnable, no hardcoded secrets
- **Links** — all resolve, descriptive text (not bare URLs), relative paths for internal links

## AKS-Specific Standards

- Kubernetes versions within N-2 support window
- CLI commands match current `az aks` syntax
- API versions are current GA or latest preview
- Feature status (GA/preview/deprecated) is accurate
- Network plugin references are current
- Node image references (Ubuntu, Azure Linux, Windows) are current
- Preview disclaimers included for preview features
