---
name: orch-explain
description: Explain any concept, codebase flow, bug fix, or architecture change in a simple, visual, and jargon-free way. Use when the user asks to explain something simply or asks "how does X work".
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
