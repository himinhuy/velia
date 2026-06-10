---
name: coding
description: End-to-end coding workflow for the TCM learning app — plan, implement, test, and verify a feature or fix. Use when asked to build a feature, fix a bug, scaffold a module, or wire up an integration (database, AI, auth).
---

You are executing a focused coding task for the TCM learning app. Follow these steps in order.

## Step 1 — Understand before touching anything

Read the relevant files first. Never edit based on assumptions. If the task involves:
- A database model: read `prisma/schema.prisma`
- A route or page: read the file under `app/`
- An API route: read `app/api/...`
- An AI feature: read existing prompt construction to stay consistent

Ask one clarifying question if the scope is genuinely ambiguous. Otherwise proceed.

## Step 2 — Plan (state it briefly)

Write 2–4 bullet points covering:
- What files will be created or changed
- Any schema migration needed
- Any non-obvious tradeoff or risk

Do not implement yet — confirm the plan is right before writing code.

## Step 3 — Implement

Follow these non-negotiable rules:

**TypeScript**
- Strict mode, no `any`, no `@ts-ignore`
- Export types alongside implementations; never inline `as unknown as X` casts

**Next.js**
- Server Components by default; add `"use client"` only when the component needs browser APIs or React state
- Route handlers live in `app/api/[resource]/route.ts`
- Use `next/navigation` (not `next/router`) for App Router

**Prisma**
- Every schema change gets a migration: `npx prisma migrate dev --name <descriptive-name>`
- Use `prisma.$transaction` for multi-step writes
- Never expose raw Prisma errors to the client

**Tailwind**
- Utility classes only — no custom CSS unless Tailwind cannot express it
- TCM content layout: always show Chinese characters + Pinyin + English together, never English-only

**Claude API (AI features)**
- Model: `claude-sonnet-4-6`
- Always add `cache_control: { type: "ephemeral" }` to the system prompt message when it contains a TCM knowledge base (>500 tokens)
- Parse and validate model output before using it — never trust raw strings from the model in database writes

**Safety-critical content**
- Herb toxicity flags, pregnancy contraindications, and drug interaction warnings must render with a visually distinct style (e.g., red border, warning icon) and must never be conditionally hidden
- Treat missing safety data as "unknown risk" and display a warning, not silence

**General**
- No comments unless the WHY is non-obvious
- No premature abstractions — solve the task, not hypothetical future tasks
- Prefer editing existing files over creating new ones
- Validate at system boundaries (user input, external APIs); trust internal code

## Step 4 — Write tests alongside the code

- Unit/component: Vitest + React Testing Library
- e2e: Playwright (for full user flows)
- Safety-critical rendering (herb flags, Chinese display): always has a test
- SRS interval math: always has a unit test
- Mock the Anthropic SDK in unit tests; never hit the real API in CI

## Step 5 — Verify

After implementing:
1. Run `npm run typecheck` — zero errors required
2. Run `npm test` — all tests pass
3. If a UI component was changed, start the dev server and visually confirm the golden path works
4. Check that no existing tests regressed

Report the outcome of each step. If something fails, fix it before declaring done.
