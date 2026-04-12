# AKS Doc-a-thon Automation

A multi-agent automation framework for monthly documentation review events ("doc-a-thons") where AI agents handle discovery, triage, multi-perspective review, and PR creation — humans only trigger the event and review final PRs.

## What is a Doc-a-thon?

A month-long content improvement event where content, product/eng, and support teams collaborate to review, test, and refresh high-priority AKS documentation. Previously a manual process requiring coordination across PM, Eng, CSS, and Doc Writers — this project automates the entire pipeline with specialized AI agents.

## Architecture

```
Monthly Trigger ──► Finder scores articles by staleness + support volume
                         │
                         ▼
                 Dispatcher creates Issues on Kanban board
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
       Doc Review   Eng Review   CSS Review    (parallel sub-agents)
            │            │            │
            └────────────┴────────────┘
                         │
                         ▼
                 PM Reviewer synthesizes → creates PR
                         │
                         ▼
                 Human SME reviews PR → merge
```

## The 6 Agents

| Agent | Role | What it checks |
|-------|------|----------------|
| **Finder** | Staleness Scanner | `ms.date` age, git commit history, support ticket volumes, page view signals |
| **Dispatcher** | Kanban Manager | Creates GitHub Issues, assigns reviewers, manages project board columns |
| **Doc Reviewer** | Content Developer | Structure, metadata, MS Learn style guide, links, accessibility, Acrolinx-style quality |
| **Eng Reviewer** | Engineering SME | CLI commands, API versions, code samples, feature GA/preview status, K8s version accuracy |
| **CSS Reviewer** | Support Engineer | Top support topics, troubleshooting gaps, customer error patterns, missing prerequisites |
| **PM Reviewer** | SME Final Gate | Synthesizes all reviews, resolves conflicts between reviewers, creates the final PR |

## Priority Scoring Algorithm

Articles are ranked by a composite score:

```
priority_score = (0.5 × staleness_score) + (0.4 × support_score) + (activity_bonus)
```

| Factor | Weight | Source | Scoring |
|--------|--------|--------|---------|
| **Staleness** | 50% | Days since `ms.date` — normalized 0–100 | 365 days = 50, 730+ days = 100 |
| **Support signal** | 40% | CSS ticket volume for the article's topic — from Kusto | Top 10% = 100, bottom 50% = 0 |
| **Activity bonus** | 10% | Git commit recency penalty/reward | No commits in 180+ days = +10, recent activity = -10 |

## Workflow Modes

### Mode A: Opportunity Finder (automated discovery)
```bash
# Trigger the Finder agent to scan MicrosoftDocs/azure-aks-docs
# Uses /docathon-kickoff prompt
```
The Finder clones the docs repo, scans `ms.date` metadata in YAML frontmatter, cross-references with support signal data, scores articles, and hands the ranked list to the Dispatcher.

### Mode B: Article List Input (manual list)
```bash
# Provide a CSV/markdown list of articles to review
# Uses /docathon-assign prompt
```
Skip the Finder — provide a pre-curated list (e.g., from the .loop file shared by the Docs team). The Dispatcher takes the list directly and creates issues.

## Kanban Board

GitHub Projects board with 5 columns:

| Column | State | Who moves cards here |
|--------|-------|---------------------|
| **Backlog** | Scored, not started | Dispatcher |
| **Ready** | Assigned to reviewers | Dispatcher |
| **In Progress** | Reviews underway | Doc/Eng/CSS Reviewers |
| **In Review** | PR created, awaiting human | PM Reviewer |
| **Done** | PR merged | Human SME |

## Quick Start

### Prerequisites
- Node.js 18+
- GitHub CLI (`gh`) authenticated
- Squad CLI: `npm install -g @bradygaster/squad-cli`

### Initialize
```bash
cd docathon/
squad init
```

### Run a Doc-a-thon
1. **Trigger**: Use the `/docathon-kickoff` prompt in VS Code Copilot Chat
2. **Monitor**: Watch the GitHub Projects Kanban board
3. **Review**: Human SME reviews PRs created by the PM Reviewer agent
4. **Merge**: Approve and merge PRs on `MicrosoftDocs/azure-aks-docs`

### Autonomous Mode (Squad Watch)
```bash
# Ralph polls for issues and dispatches review agents automatically
squad watch --execute --interval 10
```

## Project Structure

```
# Copilot files live at the repo root for auto-discovery:
.github/
├── agents/                                # Agent definitions
│   ├── docathon-finder.agent.md
│   ├── docathon-dispatcher.agent.md
│   ├── docathon-doc-reviewer.agent.md
│   ├── docathon-eng-reviewer.agent.md
│   ├── docathon-css-reviewer.agent.md
│   └── docathon-pm-reviewer.agent.md
├── prompts/                               # Slash commands
│   ├── docathon-kickoff.prompt.md
│   ├── docathon-find-stale.prompt.md
│   ├── docathon-assign.prompt.md
│   └── docathon-review-article.prompt.md
├── instructions/
│   └── docathon-review.instructions.md
└── skills/
    ├── stale-article-detection/
    ├── ms-learn-style-guide/
    ├── aks-technical-review/
    └── support-signal-analysis/

# Project docs, templates, and config:
docathon/
├── README.md                              # This file
├── AGENTS.md                              # Agent registry
├── templates/
│   ├── review-checklist.md
│   ├── article-issue.md
│   └── pr-template.md
└── config/
    ├── docathon.config.yml
    └── article-list-template.csv
```

## Integration Points

| System | Purpose | How |
|--------|---------|-----|
| **MicrosoftDocs/azure-aks-docs** | Source repo for articles | Clone, scan, create PRs |
| **GitHub Projects** | Kanban board | `gh project` API |
| **GitHub Issues** | Per-article work items | `gh issue create` |
| **Squad CLI** | Agent orchestration | Watch mode + dispatch |
| **Kusto / Support Data** | CSS ticket volumes | Query for support signal scoring |

## Monthly Cadence

| Week | Activity | Agent |
|------|----------|-------|
| Week 1 | Finder scans, Dispatcher creates board + issues | Finder → Dispatcher |
| Week 2-3 | Parallel reviews by Doc/Eng/CSS agents | Doc, Eng, CSS Reviewers |
| Week 4 | PM Reviewer synthesizes, creates PRs | PM Reviewer |
| Week 4+ | Human SME reviews and merges | Human |
