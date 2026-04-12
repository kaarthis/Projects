---
name: ms-learn-style-guide
description: 'Microsoft Learn documentation style guide rules for AKS content reviews. Use for doc-a-thon Doc Reviewer checks, content quality validation, metadata compliance, Acrolinx-style rules.'
---

# MS Learn Style Guide for AKS

## When to Use
- Doc Reviewer agent performing content quality checks
- Validating article structure and metadata
- Checking writing quality against MS Learn standards

## Metadata Requirements

Every article must have these frontmatter fields:

| Field | Required | Format | Example |
|-------|----------|--------|---------|
| `title` | Yes | String, < 65 chars | `Configure network policies in AKS` |
| `description` | Yes | String, < 160 chars, includes "Azure Kubernetes Service" | `Learn how to configure network policies in Azure Kubernetes Service (AKS).` |
| `ms.date` | Yes | `mm/dd/yyyy` | `04/11/2026` |
| `ms.topic` | Yes | Enum: concept, how-to, reference, tutorial, overview, quickstart | `how-to` |
| `ms.service` | Yes | `azure-kubernetes-service` | `azure-kubernetes-service` |
| `author` | Yes | GitHub username | `kaarthis` |
| `ms.author` | Yes | Microsoft alias | `kaarthis` |
| `ms.custom` | No | Comma-separated tags | `devx-track-azurecli, build-2026` |

## Article Structure by Type

### How-to Articles
```
H1: Title (verb + noun)
  Introduction paragraph
  H2: Prerequisites
  H2: Step 1 — {action}
  H2: Step 2 — {action}
  ...
  H2: Verify / Validate
  H2: Clean up resources (if applicable)
  H2: Next steps
```

### Concept Articles
```
H1: Title
  Introduction paragraph
  H2: Overview / What is {concept}
  H2: Key concepts
  H2: How {concept} works
  H2: Benefits / Use cases
  H2: Limitations / Considerations
  H2: Next steps
```

## Writing Rules

### Voice & Tone
- **DO:** Use second person ("you", "your")
- **DO:** Use active voice ("Create a cluster" not "A cluster is created")
- **DO:** Use present tense for descriptions ("This command creates..." not "This command will create...")
- **DO:** Use imperative mood for instructions ("Run the following command")
- **DO NOT:** Use first person ("we", "our") except in official Microsoft announcements
- **DO NOT:** Use "please" in instructions
- **DO NOT:** Use marketing language ("best-in-class", "industry-leading", "seamlessly")

### Terminology (AKS-specific)
| Correct | Incorrect |
|---------|-----------|
| node pool | nodepool, agent pool |
| Azure Kubernetes Service (AKS) | Azure Container Service |
| managed identity | MSI, service principal (unless specifically about SP) |
| workload identity | pod identity (deprecated) |
| Azure CNI | azure-cni |
| Azure Linux | Mariner (use "Azure Linux" for customer-facing docs) |

### Code Blocks
- Always specify language: ` ```bash `, ` ```json `, ` ```yaml `
- Use `<placeholder>` for values customers must replace
- Include expected output for verification commands
- Use `az` CLI as primary, ARM/Bicep as secondary

### Notes & Alerts
```markdown
> [!NOTE]
> Supplementary information.

> [!TIP]
> Optional best practice.

> [!IMPORTANT]
> Essential information.

> [!CAUTION]
> Potential negative consequences.

> [!WARNING]
> Dangerous action that could cause data loss.
```

### Links
- Internal links: relative paths (`../concepts/networking.md`)
- External Microsoft: `aka.ms` short links where available
- External non-Microsoft: full URL with descriptive text
- Never use bare URLs
- Never use "click here" or "this link" as link text
