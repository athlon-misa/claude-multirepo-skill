---
name: multi-repo-agent
description: "Coordinate Claude Code agents working across multiple repositories that depend on each other. Use this skill whenever a user mentions working on multiple repos, cross-project dependencies, SDK bugs originating from another project, multi-service architectures, or microservices that need to talk to each other. Also trigger when the user mentions 'monorepo alternative', 'cross-repo issues', 'agent coordination', 'multi-project setup', or wants Claude to file issues/PRs on a dependency repo instead of hacking around problems locally. This skill handles initialization (detecting repos and their relationships), generating per-repo CLAUDE.md ownership rules, and routing bugs/feature requests to the correct repo via GitHub issues — with user confirmation before any cross-repo action."
---

# Multi-Repo Agent Coordination

## What this skill does

When a developer works on multiple related repositories with Claude Code (e.g., an SDK + a game + a backend service), each repo's agent needs to know:

1. **What it owns** — what code it's responsible for fixing
2. **What it depends on** — which packages/services come from sibling repos
3. **Where to route problems** — when it hits a bug in a dependency, it should file an issue on the right repo rather than patching around it locally

This skill automates that setup and enforces the routing behavior during development.

---

## Initialization — run this once per project

When the user says something like "initialize multi-repo coordination", "set up my repos to work together", or provides a list of related repositories, follow these steps:

### Step 1: Discover the project topology

Ask the user to confirm:
- The list of repositories (names + GitHub URLs)
- Which repos depend on which (e.g., "game imports the login SDK from identity-platform")
- The GitHub org or owner for issue filing

If the user has a `package.json`, `requirements.txt`, `go.mod`, or similar in each repo, read those to auto-detect cross-repo dependencies. Present your findings and ask for confirmation.

**Example conversation:**
```
User: I have three repos — OpenFederation (identity + SDK), game-leaderboard, and mini-game. Set them up.

Agent: I found these relationships:
  • mini-game depends on @openfederation/login-sdk (from OpenFederation)
  • mini-game depends on game-leaderboard (API client)
  • game-leaderboard depends on @openfederation/login-sdk (from OpenFederation)

Does this look right? Any missing connections?
```

### Step 2: Generate CLAUDE.md files

For each repository, generate (or append to) a `CLAUDE.md` file at the repo root. This file is what Claude Code reads as project-level instructions.

Read the template from `references/claude-md-template.md` and fill it in for each repo using the topology from Step 1.

The generated CLAUDE.md must include:
- **Ownership boundary** — what this repo is responsible for
- **Dependency map** — which packages/services come from sibling repos, with their GitHub URLs
- **Routing rules** — explicit instructions telling the agent NOT to fix dependency bugs locally, and instead to propose filing a GitHub issue on the correct repo
- **Confirmation gate** — the agent must always ask the user before taking any cross-repo action

### Step 3: Generate a shared project manifest

Create a `.multi-repo-manifest.json` at each repo root (or a shared location if the user prefers). This machine-readable file lets agents quickly look up where to route issues.

Read the schema from `references/manifest-schema.md`.

### Step 4: Present the results

Show the user what was generated, repo by repo. Ask them to review and confirm before committing anything.

---

## Runtime behavior — how agents use this during development

Once initialized, the CLAUDE.md in each repo instructs the agent to follow these rules:

### When the agent encounters a bug in a dependency

1. **Identify the source** — check if the buggy package/service is listed in the dependency map
2. **Do NOT fix it locally** — no monkey-patching, no local forks, no "temporary workarounds" committed to this repo
3. **Draft a GitHub issue** for the upstream repo using the bug report template from `references/issue-templates.md`
4. **Show the draft to the user** and ask: "I've identified this as a bug in [repo-name]. Here's a draft issue. Should I file it?"
5. **Only after user confirms**, use the GitHub CLI (`gh issue create`) or the GitHub API to file the issue
6. **Optionally**, create a minimal local workaround clearly marked as temporary (with a `TODO` referencing the issue number)

### When the agent needs a new feature from a dependency

Same flow as bugs, but use the feature request template from `references/issue-templates.md`. Label with `enhancement` instead of `bug`.

### When the agent receives an issue filed by a sibling repo's agent

If the user opens an issue that was filed by another repo's agent (recognizable by the `cross-repo` label or a specific template), the agent should:
1. Read the issue carefully
2. Propose a fix within this repo's codebase
3. Reference the downstream repo's issue in the PR description

---

## Confirmation gates

Every cross-repo action requires explicit user confirmation. The agent must never:
- File issues silently
- Push to another repo without asking
- Modify dependencies without approval

The confirmation prompt should be clear and concise:
```
I found a bug in the login SDK (from OpenFederation) — token refresh 
returns 401 when the token is expired instead of triggering a refresh.

I've drafted a GitHub issue for the OpenFederation repo. Want me to file it?
[Shows issue title + body preview]
```

---

## Commands

Users can trigger specific actions:

- **"initialize repos"** or **"set up multi-repo"** — runs the full initialization flow
- **"show repo map"** — displays the current dependency topology
- **"route this bug"** — manually triggers the bug-routing flow for a specific issue the agent found
- **"update manifest"** — regenerates the manifest after repos change

---

## Prerequisites

The user needs the GitHub CLI (`gh`) installed and authenticated to file cross-repo issues. If `gh` is not available, draft the issue body and present it to the user to file manually.

Verify before filing:
```bash
gh auth status
```

## File reference

- `references/claude-md-template.md` — Template for generating per-repo CLAUDE.md content. Read this before generating any CLAUDE.md files.
- `references/manifest-schema.md` — Schema and example for `.multi-repo-manifest.json`. Read this before generating manifests.
- `references/issue-templates.md` — GitHub issue body templates for bugs, feature requests, and breaking changes. Read the appropriate template before drafting any cross-repo issue.
- `scripts/detect-deps.sh` — Run this against each repo path to auto-detect dependencies from package files. Output is JSON.
