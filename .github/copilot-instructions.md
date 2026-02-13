# copilot-instructions.md

## 📄 Purpose

This repository stores Product Requirements Documents (PRDs) and high-level Design Docs for products and features. GitHub Copilot is used to generate initial drafts, update sections, and transform ideas into standardized documentation.

---

## 🧠 General Instructions for Copilot

- Use Markdown syntax.
- Always include the document metadata (title, status, authors, last updated).
- Structure content using H2 headers for major sections.
- Prefer clarity over verbosity.
- Assume the audience is a cross-functional team (PMs, engineers, designers).

---

## ✍️ Writing a New PRD

**Prompt:**

```
Generate a PRD for a feature based on the provided problem statement.
```

**Expected Output Format:**

Use `../prd/0000-prd-template.md` as a template.

---

## 🔌 Writing API Proposals

For API authoring, use the prompt files in `.github/prompts/`:

| Prompt File                     | Purpose                                                |
| ------------------------------- | ------------------------------------------------------ |
| `api-proposal.prompt.md`        | Generate a complete API proposal from requirements     |
| `api-review-feedback.prompt.md` | Review an API proposal and provide structured feedback |
| `api-prd-to-proposal.prompt.md` | Convert a PRD into an API proposal                     |
| `api-cli-generator.prompt.md`   | Generate Azure CLI commands for an API                 |

**API Specification Format:** TypeSpec (not Swagger/JSON)

API proposals now use [TypeSpec](https://typespec.io/) as the specification language, following the [Azure REST API development process](https://github.com/Azure/azure-rest-api-specs/blob/main/documentation/typespec-rest-api-dev-process.md).
**Expected Output Format:**

Use `../api/0000-api-template.md` as a template.

---

## 🤖 Automated API Code Review

This repository includes path-specific custom instructions for **GitHub Copilot code review** on PRs targeting the `api/` folder.

**Location:** `.github/instructions/api-review.instructions.md`

**What it does:**

- Automatically provides detailed API **design and proposal** review feedback when reviewing PRs that modify files in `api/`
- Uses severity indicators: ✅ DO, ✔️ YOU MAY, ⚠️ YOU SHOULD NOT, ⛔ DO NOT
- Checks for Azure API Guidelines compliance, TypeSpec quality, AKS patterns, and security issues
- Categorizes feedback as 🔴 Critical, 🟡 Recommendation, or ❓ Question

---

## 📚 Cross-Referencing

When referencing other documents:

- Link using relative paths if in-repo.
- Use the format `[Feature Name](../path/to/doc.md)`.

---

## ✅ Review Checklist (for AI)

Before finalizing:

- Did you include all mandatory sections (Overview, Goals, Requirements)?
- Is the tone professional and clear?
- Are all acronyms defined?
- Did you avoid speculative implementation details unless under a dedicated section?
