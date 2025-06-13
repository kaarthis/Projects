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

