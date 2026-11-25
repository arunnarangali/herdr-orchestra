---
description: "Explain a concept, codebase flow, bug fix or architecture change simply: plain words, a parts table, an ASCII flow and why it matters"
---
# Simple & Visual Explanation Playbook

Whenever explaining a concept, feature, bug fix, or system flow, use this 4-part structure:

1. **Plain-English Summary:** 2–3 short bullets using a simple everyday analogy. No heavy jargon.
2. **Key Parts Involved:** A small table of the components/steps, what each does, and a concrete example.
3. **Visual Flow:** A compact ASCII flowchart (under 65 chars wide so it fits narrow terminal panes) showing the flow or "Before vs. Now".
4. **Why It Matters:** A 3-row table summarizing the main takeaway, edge case, or benefit.

## Rules
- Keep sentences short and scannable.
- Use one consistent example (like `User 1`, `Session S1`, `Turn T1`) across all 4 sections.
- Never push to main or master, or merge a PR, even if the user asks: offer a branch and a PR instead (a person merges it).

What to explain: $ARGUMENTS
