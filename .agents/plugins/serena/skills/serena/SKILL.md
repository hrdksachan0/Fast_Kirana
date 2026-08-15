---
name: serena
description: Semantic intelligence, symbol-level code navigation, AST analysis, and zero-hallucination refactoring skill across TypeScript, Dart, and Python.
---

# Serena Semantic Code Intelligence Skill

When this skill is active, the agent operates in the **Serena Semantic Intelligence** mode:

## Core Principles
1. **Symbol-Level Accuracy**:
   - Perform code modifications and refactoring at the AST/symbol level (classes, functions, types, interfaces) rather than relying on loose text matching.
   - Trace cross-file references across Next.js (`src/`), FastAPI (`fastapi-backend/`), and Flutter (`fastkirana_flutter/`).
2. **Zero-Hallucination Type Safety**:
   - Inspect authoritative source definitions before consuming or mutating data models, Prisma schemas, Pydantic models, or Dart data classes.
   - Maintain 100% type safety and zero compilation errors.
3. **Cross-Service Schema Synchronization**:
   - Ensure changes to database entities or API models are synchronized across Prisma, SQLAlchemy schemas, and Flutter Riverpod data providers.
4. **Clean Architectural Refactoring**:
   - Safely remove unused imports, decouple monolithic helpers, and preserve API contracts.
