# Doc-a-thon Review Checklist

**Article:** {title}
**File:** {filePath}
**URL:** {url}
**Priority Score:** {priorityScore}/100
**ms.date:** {msDate} ({daysSinceMsDate} days ago)

---

## Doc Review (Content Developer)

### Metadata & Freshness
- [ ] `ms.date` accurate
- [ ] `title` clear, follows pattern
- [ ] `description` < 160 chars, includes "Azure Kubernetes Service"
- [ ] `ms.topic` correct (concept/how-to/reference/tutorial/overview/quickstart)
- [ ] `author` and `ms.author` valid

### Structure
- [ ] H1 matches title
- [ ] Logical heading hierarchy
- [ ] Prerequisites section (for how-to/tutorial)
- [ ] Next steps section
- [ ] Appropriate length

### Writing Quality
- [ ] Active voice, second person
- [ ] No jargon without explanation
- [ ] Consistent terminology
- [ ] No marketing language

### Links
- [ ] All links resolve
- [ ] Descriptive link text (no bare URLs)
- [ ] Internal links use relative paths

**Status:** ☐ Pass ☐ Needs Changes ☐ Needs Major Revision
**Findings:** (list below)

---

## Eng Review (Engineering SME)

### CLI Commands
- [ ] All `az aks` commands use current syntax
- [ ] Parameters are current (not deprecated)
- [ ] Example commands are runnable

### API & Versions
- [ ] REST API versions are current
- [ ] Kubernetes versions within N-2 support window
- [ ] ARM/Bicep examples use current providers

### Code Samples
- [ ] YAML manifests are valid
- [ ] Language specified on code blocks
- [ ] No hardcoded secrets

### Feature Status
- [ ] GA features correctly marked
- [ ] Preview features have disclaimer
- [ ] No references to deprecated features without notice

**Status:** ☐ Pass ☐ Needs Changes ☐ Needs Major Revision
**Findings:** (list below)

---

## CSS Review (Support Engineer)

### Prerequisites
- [ ] All prerequisites explicitly listed
- [ ] Required permissions documented
- [ ] Required tools and versions specified

### Troubleshooting
- [ ] Common error messages documented with solutions
- [ ] Troubleshooting section exists (for how-to/tutorial)
- [ ] Known issues/limitations documented

### Customer Confusion
- [ ] Steps in correct order
- [ ] Instructions unambiguous
- [ ] Feature names match Portal

### Support Coverage
- [ ] Article covers related top support topics
- [ ] Missing topics flagged

**Status:** ☐ Pass ☐ Needs Changes ☐ Needs Major Revision
**Findings:** (list below)

---

## PM Review (SME Final Gate)

### Synthesis
- [ ] All reviewer findings addressed
- [ ] Conflicts resolved
- [ ] Changes applied to article
- [ ] `ms.date` updated

### PR Created
- [ ] Branch: `docathon/{month}-{year}/{slug}`
- [ ] PR body includes review summary
- [ ] Items for human review flagged

**PR URL:** {url}
