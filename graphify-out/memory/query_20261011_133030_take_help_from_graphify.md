---
type: "query"
date: "2026-10-11T13:30:30.089353+00:00"
question: "take help from graphify"
contributor: "graphify"
outcome: "useful"
source_nodes: ["auth-guard.ts", "auth()", "campaign-config.ts", "CampaignManager"]
---

# Q: take help from graphify

## Answer

Expanded from graph vocabulary: campaign, settings, auth. Traversal surfaced auth-guard.ts and auth() plus campaign-config.ts and its data/use-campaign consumers. Source review found identity-header fallbacks; campaign administration now uses cryptographic verification and current database role/store/account state on both backends. The web campaign route stays local so NextAuth cookies work; public campaign configuration is shared by the web and Flutter renderers. Incremental AST update includes the new editor and endpoints.

## Outcome

- Signal: useful

## Source Nodes

- auth-guard.ts
- auth()
- campaign-config.ts
- CampaignManager