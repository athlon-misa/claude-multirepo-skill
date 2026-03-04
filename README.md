# multi-repo-agent

A Claude Code skill that coordinates AI agents working across multiple repositories. When an agent hits a bug in a dependency from another repo, it knows to file a GitHub issue upstream instead of hacking around it locally — and always asks you before taking action.

## The problem

You're working on multiple repos that depend on each other. Maybe an auth service with an SDK, a web app that imports that SDK, and a billing API. You have Claude Code open in each project.

The web app agent hits a bug in the auth SDK. Without coordination, it tries to fix the SDK bug inside the web app repo — monkey-patching, forking, or working around it. The fix belongs in the auth service repo, not the web app.

**multi-repo-agent** teaches each agent where its ownership boundaries are and how to route problems to the right place.

## What it does

- **Auto-detects cross-repo dependencies** from `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, or `Cargo.toml`
- **Generates `CLAUDE.md` files** per repo with ownership rules, dependency maps, and routing instructions
- **Creates a `.multi-repo-manifest.json`** so agents can programmatically look up where to send issues
- **Routes bugs and feature requests** to the correct upstream repo via GitHub issues
- **Classifies repos as owned or third-party** — skips expensive analysis on deps you can't change, files issues with consumer-side context only
- **Progressive-depth analysis** — starts with a targeted scan of 1-3 files and only widens when needed, saving tokens on simple issues
- **Always asks for confirmation** before filing anything cross-repo

## Install

This skill uses `disable-model-invocation: true`, so it adds **zero token overhead** to projects where you don't use it. It's only loaded when you manually invoke `/multi-repo-agent`.

### Global install (recommended)

```bash
git clone https://github.com/YOUR_USERNAME/multi-repo-agent.git
cp -r multi-repo-agent ~/.claude/skills/multi-repo-agent
```

Or from a local copy:

```bash
tar xzf multi-repo-agent.skill -C ~/.claude/skills/
```

This makes the skill available in every project via `/multi-repo-agent`, with no context cost until you invoke it.

### Project install

If you only want it in a specific project:

```bash
cd your-project
mkdir -p .claude/skills
cp -r /path/to/multi-repo-agent .claude/skills/multi-repo-agent
```

## Usage

### Initialize your repos

Open Claude Code in any of your project repos and invoke the skill:

```
/multi-repo-agent
```

Then say:

```
Initialize multi-repo coordination for my projects
```

Or be specific:

```
Set up multi-repo for these repos:
- auth-service (https://github.com/acme/auth-service) — authentication + auth SDK
- billing-api (https://github.com/acme/billing-api) — billing and payments service
- web-app (https://github.com/acme/web-app) — the frontend application
```

The skill will:

1. Scan each repo's package files to detect cross-repo dependencies
2. Show you the dependency graph and ask you to confirm
3. Generate a `CLAUDE.md` (or append to your existing one) in each repo
4. Create a `.multi-repo-manifest.json` in each repo

After that, every Claude Code session in those repos will know the rules automatically — **no need to invoke the skill again** for day-to-day work.

### During development

You don't need to do anything special. The generated `CLAUDE.md` handles it. When the agent encounters a dependency bug, it will:

1. Identify that the bug belongs to a sibling repo
2. Draft a GitHub issue with reproduction steps
3. Show you the draft and ask: *"Should I file this?"*
4. Only file it after you confirm
5. Optionally leave a `TODO` workaround referencing the issue

### Commands

Invoke `/multi-repo-agent` first, then use these commands:

| Say this | What happens |
|---|---|
| `initialize repos` or `set up multi-repo` | Full initialization flow |
| `show repo map` | Displays current dependency topology |
| `route this bug` | Manually trigger bug-routing for something the agent found |
| `update manifest` | Regenerate the manifest after adding/removing repos |
| `check issues` | Show open `cross-repo` issues — incoming (need fixing here) and outgoing (waiting on siblings) |
| `plan fix` or `plan fix #47` | Read a cross-repo issue, analyze the codebase, and propose a fix plan |

## Example workflow

```
You (in web-app repo): "The login flow crashes when the token expires"

Agent: I've identified this as a bug in @acme/auth-sdk
       (owned by the auth-service repo). The SDK returns a 401
       instead of triggering a token refresh.

       Here's a draft GitHub issue for auth-service:

       Title: [cross-repo] Token refresh returns 401 on expired tokens
       Body: [full reproduction steps from web-app's perspective]

       Should I file this on the auth-service repo?

You: "Yes, file it"

Agent: Filed as auth-service#47. I've added a temporary workaround
       with a TODO(auth-service#47) comment so we can keep working.
```

### Third-party dependency bug

```
You (in web-app repo): "Redis connections are dropping under load"

Agent: redis is a third-party dependency — I won't analyze its source code.
       Based on the error logs in this repo, here's a draft issue:

       Title: [cross-repo] Connection drops under sustained load (>100 concurrent)
       Body: [error messages, connection config, reproduction steps from web-app]

       Should I file this on the redis repo?
```

The agent skips code analysis entirely for third-party repos, saving tokens and filing issues with only the information available from your codebase.

### Checking and fixing incoming issues

```
You (in auth-service repo): /multi-repo-agent
You: check issues

Agent: Cross-repo issue summary for auth-service:

       Incoming (1):
         #47 — Token refresh returns 401 on expired tokens (2 days ago)

       Outgoing (0):
         All clear.

You: plan fix #47

Agent: I've analyzed issue #47. Here's my fix plan:

       Root cause: TokenManager.refresh() checks expiry AFTER sending
       the request, so expired tokens hit the API and get a 401.

       Proposed changes:
         • src/auth/token-manager.ts — move expiry check before the
           API call; if expired, refresh first then retry
         • tests/auth/token-manager.test.ts — add test for expired
           token refresh flow

       PR plan:
         Branch: fix/cross-repo-47
         Message: "Fix token refresh on expired tokens (Fixes #47)"

       Want me to implement this?

You: yes

Agent: Done. PR #52 opened on auth-service referencing issue #47.
```

## What gets generated

### CLAUDE.md (per repo)

Each repo gets ownership boundaries and routing rules appended to its `CLAUDE.md`. See `references/claude-md-template.md` for the full template.

### .multi-repo-manifest.json (per repo)

A machine-readable topology file. See `references/manifest-schema.md` for the schema and an example.

## Project structure

```
multi-repo-agent/
├── SKILL.md                          # Skill instructions (what Claude reads)
├── README.md                         # This file
├── multi-repo-agent.skill            # Bundled skill file
├── references/
│   ├── claude-md-template.md         # Template for generating per-repo CLAUDE.md
│   ├── manifest-schema.md            # JSON schema for .multi-repo-manifest.json
│   └── issue-templates.md            # GitHub issue body templates (bug, feature, breaking change)
└── scripts/
    └── detect-deps.sh               # Auto-detect dependencies from package files
```

## Supported ecosystems

| File | Ecosystem |
|---|---|
| `package.json` | Node.js / npm / yarn |
| `requirements.txt` | Python / pip |
| `pyproject.toml` | Python (modern) |
| `go.mod` | Go |
| `Cargo.toml` | Rust |

Other ecosystems work too — provide the dependency list manually during initialization and the skill handles the rest.

## Requirements

- **Claude Code** with a paid plan (Pro, Max, Team, or Enterprise)
- **GitHub CLI (`gh`)** installed and authenticated — used to file cross-repo issues
- If `gh` is not available, the agent drafts issue bodies for you to file manually

## FAQ

**Does the agent ever file issues without asking me?**
No. Every cross-repo action goes through a confirmation prompt. You always see the full draft before anything is filed.

**What if I don't use GitHub?**
The routing logic and CLAUDE.md generation work regardless. The agent can draft the issue body and you can file it manually on GitLab, Jira, or wherever.

**Can I use this with a monorepo?**
It's designed for multi-repo setups. In a monorepo you'd typically use workspace-level boundaries instead. That said, you could use it to define ownership between packages within a monorepo if they have separate maintainers.

**What if my repos are private?**
Works fine. The GitHub CLI (`gh`) handles authentication. Just make sure it's authenticated with access to all the repos in your project.

**Do I need to install the skill in every repo?**
No. Install the skill once globally (in `~/.claude/skills/`). Run `/multi-repo-agent` to initialize your repos — this generates `CLAUDE.md` and `.multi-repo-manifest.json` files in each repo. Those files are what agents read day-to-day, with zero token overhead from the skill itself.

**Does this skill add to my token usage?**
No. It uses `disable-model-invocation: true`, so it's never loaded into context unless you explicitly invoke `/multi-repo-agent`. The generated `CLAUDE.md` files handle ongoing behavior — those are loaded as normal project instructions.

**How does repo role classification work?**
During initialization, the skill checks each repo's GitHub org ownership via `gh api` and suggests `owned` (your org) or `third-party` (external). You confirm or override. Third-party repos get lightweight issue-only routing — the agent never analyzes their source code, saving tokens. Repos not in the manifest at all are implicitly third-party.

**How does progressive-depth analysis save tokens?**
When fixing an issue on an owned repo, the agent starts with a Tier 1 targeted scan (1-3 files). If the root cause is clear — which it often is for issues with stack traces or specific function references — it stops there. It only escalates to Tier 2 (call graph + recent changes) or Tier 3 (full codebase search) when needed. You can also force a specific tier with `plan fix #47 --tier 3`.

**What if I have an old v1.0 manifest?**
Manifests without a `role` field still work — all repos default to `owned`. Run `update manifest` to upgrade to v1.1 and classify your repos.

## Contributing

Issues and PRs welcome. Some areas that could use help:

- GitLab / Jira issue-filing support
- Dependency detection for more ecosystems (Maven, Gradle, Swift, Dart, etc.)
- A `--dry-run` mode that shows what would be generated without writing files
- MCP server integration for real-time agent-to-agent messaging
