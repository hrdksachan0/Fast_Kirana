---
name: ralph
description: Autonomous iterative execution loop skill (Ralph Wiggum methodology) for continuous goal-driven coding, self-testing, and automated task completion until 100% verified.
---

# Ralph Wiggum Autonomous Execution Skill

When this skill is active, the agent operates in the **Ralph Autonomous Loop** mode:

## Core Principles
1. **Iterative Autonomous Execution**:
   - Continuously pick up tasks from the implementation plan or PRD without requiring manual human prompting between micro-steps.
   - Execute, inspect, test, and verify until the entire task goal is met.
2. **Self-Verification & Auto-Debugging**:
   - After writing or editing code, automatically execute verification commands (`npx tsc --noEmit`, test suites, build checks).
   - If a build check or test fails, automatically inspect log tracebacks, diagnose root causes, and apply fixes immediately.
3. **Task Completion Tracking**:
   - Update tracking plans and walkthroughs (`walkthrough.md` / `implementation_plan.md`) as tasks complete.
   - Never declare a goal complete until concrete, empirical verification demonstrates 100% clean execution.
4. **Resilient Self-Healing Loop**:
   - Persevere through errors by switching diagnostic tools (reading un-truncated logs, checking types, running syntax checks) instead of guessing or abandoning log analysis.
