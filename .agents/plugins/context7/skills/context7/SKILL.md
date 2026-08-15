---
name: context7
description: 7-Layer Deep Context & Memory Engine for multi-file codebase indexing, architecture tracking, and active conversation state retention.
---

# Context7 Deep Context & Memory Engine

When active, the agent maintains the **7-Layer Context Architecture**:

## The 7 Context Layers

1. **Layer 1: Identity & Core Capabilities**: System persona, tool capabilities, pair-programming standards.
2. **Layer 2: Architectural & Service Graph**: Tech stack mapping across Next.js (`src/`), FastAPI (`fastapi-backend/`), Prisma (`prisma/`), and Flutter (`fastkirana_flutter/`).
3. **Layer 3: Task & Implementation Execution State**: Active implementation plan, open tasks, verification status.
4. **Layer 4: AST & Symbol Intelligence**: Type declarations, data models, API endpoints, schema definitions.
5. **Layer 5: Empirical Log & Diagnostic Context**: Un-truncated terminal outputs, build logs, stack trace analysis.
6. **Layer 6: User Rules & Style Constraints**: Design guidelines, UX rules, project constraints in `AGENTS.md`.
7. **Layer 7: Change Graph & Memory Delta**: Tracking modified files, diff history, and incremental workspace changes across session turns.

## Operational Directives
- **Zero Context Loss**: Always maintain task context across multi-step changes.
- **Incremental Diff Tracking**: Log modified files and verify dependency impact across Next.js, FastAPI, and Flutter.
- **Deep File Graph Resolution**: Trace imported components, route definitions, and model dependencies before applying edits.
