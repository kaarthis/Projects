---
description: "Review a single AKS documentation article through all four review perspectives (Doc, Eng, CSS, PM synthesis). Use when you want to review one specific article end-to-end."
agent: "agent"
---

# Review a Single Article

Run the full review pipeline on a single article.

## Input

- **Article URL or path:** ${input:article:Paste the learn.microsoft.com URL or the file path in MicrosoftDocs/azure-aks-docs}

## Procedure

1. Fetch the article source from `MicrosoftDocs/azure-aks-docs`
2. Invoke the **PM Reviewer** agent, which will:
   - Dispatch **Doc Reviewer**, **Eng Reviewer**, and **CSS Reviewer** in parallel
   - Synthesize findings
   - Apply changes and create a PR
3. Report the PR URL and a summary of findings
