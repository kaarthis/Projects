## Article Details
- **File:** {filePath}
- **URL:** {url}
- **ms.date:** {msDate} ({daysSinceMsDate} days ago)
- **Last git commit:** {lastGitCommit}
- **Priority score:** {priorityScore}/100

## Priority Breakdown
| Signal | Score | Weight | Weighted |
|--------|-------|--------|----------|
| Staleness | {stalenessScore} | 50% | {weighted_staleness} |
| Support | {supportScore} | 40% | {weighted_support} |
| Activity | {activityBonus} | 10% | {weighted_activity} |
| **Total** | | | **{priorityScore}** |

## Support Topics
- {topic1}: {ticket_count} tickets (90d)
- {topic2}: {ticket_count} tickets (90d)

## Review Checklist
- [ ] **Doc Review** — Structure, metadata, style, links
- [ ] **Eng Review** — CLI commands, API versions, code samples
- [ ] **CSS Review** — Support gaps, troubleshooting, customer errors
- [ ] **PM Review** — Feature accuracy, synthesis, PR creation

## Instructions
Each reviewer: check the boxes above when your review is complete. Add your findings as a comment using the structured format from your agent charter.
