# Doc-a-thon Agent Registry

This file registers all agents in the doc-a-thon automation framework.

## Agent Roster

| Agent | File | Role | Tools | Invocable |
|-------|------|------|-------|-----------|
| Finder | `.github/agents/docathon-finder.agent.md` | Staleness scanner — discovers and scores articles for review | read, search, execute, web | Yes |
| Dispatcher | `.github/agents/docathon-dispatcher.agent.md` | Kanban manager — creates issues, assigns reviewers, manages board | execute, web | Yes |
| Doc Reviewer | `.github/agents/docathon-doc-reviewer.agent.md` | Content developer review — style, structure, metadata, links | read, search, web | Sub-agent only |
| Eng Reviewer | `.github/agents/docathon-eng-reviewer.agent.md` | Engineering review — CLI, API, code samples, feature status | read, search, execute, web | Sub-agent only |
| CSS Reviewer | `.github/agents/docathon-css-reviewer.agent.md` | Support review — troubleshooting gaps, customer errors | read, search, web | Sub-agent only |
| PM Reviewer | `.github/agents/docathon-pm-reviewer.agent.md` | SME final gate — synthesizes reviews, creates PR | read, search, edit, execute, web, agent | Yes |

## Workflow

```
User triggers /docathon-kickoff
    └─► Finder (scans docs repo, scores articles)
         └─► Dispatcher (creates Kanban issues)
              └─► PM Reviewer orchestrates:
                   ├─► Doc Reviewer (parallel)
                   ├─► Eng Reviewer (parallel)
                   └─► CSS Reviewer (parallel)
                   └─► PM Reviewer synthesizes → PR
```

## Agent Communication

- **Finder → Dispatcher**: Ranked article list (JSON) with priority scores
- **Dispatcher → Reviewers**: GitHub Issue with article metadata and review checklist
- **Reviewers → PM Reviewer**: Structured review findings per checklist section
- **PM Reviewer → Human**: Pull Request with synthesized changes and review summary
