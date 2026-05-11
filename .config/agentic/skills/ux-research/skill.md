---
name: ux-research
description: "UX Research workflow for interview guides, transcript cleaning, and synthesis. Use for: interview, user research, usability, transcript, synthesis, insights, personas, user testing, survey, feedback, thematic analysis, research report, discovery, validation"
---

# UX Research Assistant

Supports three core UX research workflows. Auto-detects mode from context.

## Mode Detection

**1. Guide Creator** - When user mentions: interview guide, research plan, questions, hypothesis, research goals, prep, discovery research, validation research

**2. Transcript Cleaner** - When user mentions: transcript, clean, audio, recording, anonymize, raw interview, structure

**3. Synthesis Assistant** - When user mentions: synthesis, analyze, insights, themes, patterns, report, findings, thematic analysis

## Workflow

### Step 1: Detect Mode & Confirm
Ask: "I'll help with [detected mode]. Is that correct, or did you have a different research task in mind?"

### Step 2: Gather Context

**For Guide Creator:**
- What product/feature is being researched?
- What decisions will this inform?
- Who are target users?
- Exploratory or validation research?

**For Transcript Cleaner:**
- Request the raw transcript
- Ask about anonymization requirements
- Confirm output format preferences

**For Synthesis:**
- Request clean transcripts (offer to clean first if raw)
- How many participants?
- What were the research questions?

### Step 3: Execute

Invoke the `ux-researcher` droid via Task tool with the appropriate prompt based on detected mode and gathered context.

### Step 4: Iterate

- Present output in sections for validation
- Ask: "Does this capture it accurately? What should I adjust?"
- Refine based on feedback

## Quality Checks

**Guide Creator:**
- Are questions open-ended (not leading)?
- Do probes dig into the "why"?
- Is timing realistic?

**Transcript Cleaner:**
- Is all PII anonymized?
- Are emotional cues preserved?
- Is speaker attribution clear?

**Synthesis:**
- Are insights grounded in quotes?
- Are contradicting views noted?
- Is confidence level stated?

## Output Locations

Save deliverables to project or requested location:
- Interview guides: `research/guides/YYYY-MM-DD-<topic>.md`
- Clean transcripts: `research/transcripts/P<N>-<date>.md`
- Synthesis reports: `research/reports/YYYY-MM-DD-<topic>-synthesis.md`
