---
name: multi-repo-agent
disable-model-invocation: true
description: "Coordinate Claude Code agents working across multiple repositories that depend on each other. Invoke manually with /multi-repo-agent when you want to initialize multi-repo coordination, update repo manifests, or route bugs/feature requests to upstream repos. After initialization, the generated CLAUDE.md files in each repo handle day-to-day routing automatically — you only need to invoke this skill again for setup changes."
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

This skill uses `disable-model-invocation: true`, so it is **never loaded automatically**. Invoke it manually with `/multi-repo-agent` and then use one of these commands:

- **"initialize repos"** or **"set up multi-repo"** — runs the full initialization flow
- **"show repo map"** — displays the current dependency topology
- **"route this bug"** — manually triggers the bug-routing flow for a specific issue the agent found
- **"update manifest"** — regenerates the manifest after repos change
- **"check issues"** — queries GitHub for open `cross-repo`-labeled issues (both incoming and outgoing)
- **"plan fix"** or **"plan fix #47"** — reads a cross-repo issue, analyzes the codebase, and proposes a fix plan

After initialization, the generated `CLAUDE.md` files handle all cross-repo routing automatically. You only need to invoke `/multi-repo-agent` again when changing the repo topology, for manual routing, or to check/fix incoming issues.

---

## Checking and fixing cross-repo issues

### `check issues`

This command queries GitHub for open issues labeled `cross-repo`, showing both issues filed against this repo and issues this repo filed on siblings.

**Steps:**

1. **Read `.multi-repo-manifest.json`** from the current repo root. If missing, tell the user: "No manifest found — run `initialize repos` first."
2. **Identify the current repo** by running `git remote get-url origin` and matching it against the manifest's repo list.
3. **Query incoming issues** (filed against this repo):
   ```bash
   gh issue list -R <this-repo> --label "cross-repo" --state open --json number,title,body,labels,createdAt,url
   ```
4. **Query outgoing issues** (filed by this repo on siblings): for each sibling repo in the manifest, run:
   ```bash
   gh issue list -R <sibling-repo> --label "cross-repo" --state open --search "in:body <this-repo-name>"
   ```
5. **Display a structured summary** with two sections:
   - **Incoming** — issues other repos filed against this one (these need fixes here)
   - **Outgoing** — issues this repo filed on siblings (waiting on upstream fixes)

   For each issue show: `#number — title (age)`

**Edge cases:**
- No manifest → error with setup instructions
- No issues found → "All clear — no open cross-repo issues."
- `gh` not authenticated → show manual GitHub URLs for each repo's issue page

### `plan fix`

This command reads a cross-repo issue, analyzes the local codebase, and proposes a fix plan.

**Steps:**

1. **Manifest guard** — same as `check issues`. Error if `.multi-repo-manifest.json` is missing.
2. **Select an issue:**
   - If the user provides an issue number (e.g., `plan fix #47`) → fetch it directly:
     ```bash
     gh issue view 47 -R <this-repo> --json number,title,body,labels,url
     ```
   - If no number → list incoming `cross-repo` issues. If exactly one, auto-select it. If multiple, prompt the user to pick one.
3. **Parse the issue body** for context: consumer repo, affected package/module, reproduction steps, expected vs actual behavior.
4. **Analyze the local codebase** to locate the relevant code and identify the root cause. Use the reproduction steps and affected module from the issue to guide the search.
5. **Present a fix plan** to the user:
   - **Root cause** — what's wrong and where
   - **Proposed changes** — files to modify and what the fix looks like
   - **PR plan** — suggested branch name (e.g., `fix/cross-repo-47`), commit message, and issue reference (`Fixes #47`)
6. **If the user confirms** → implement the fix, create a branch, commit, and open a PR referencing the original issue.

**Edge cases:**
- No incoming issues → "Nothing to plan — no open cross-repo issues filed against this repo."
- Issue from an unknown repo → proceed anyway (the issue body contains enough context)
- Issue lacks detail → ask the user for clarification before proposing a plan

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
