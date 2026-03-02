# multi-repo-agent

A Claude Code skill that coordinates AI agents working across multiple repositories. When an agent hits a bug in a dependency from another repo, it knows to file a GitHub issue upstream instead of hacking around it locally — and always asks you before taking action.

## The problem

You're working on multiple repos that depend on each other. Maybe an identity platform with a login SDK, a game that imports that SDK, and a leaderboard service. You have Claude Code open in each project.

The game agent hits a bug in the login SDK. Without coordination, it tries to fix the SDK bug inside the game repo — monkey-patching, forking, or working around it. The fix belongs in the SDK repo, not the game.

**multi-repo-agent** teaches each agent where its ownership boundaries are and how to route problems to the right place.

## What it does

- **Auto-detects cross-repo dependencies** from `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, or `Cargo.toml`
- **Generates `CLAUDE.md` files** per repo with ownership rules, dependency maps, and routing instructions
- **Creates a `.multi-repo-manifest.json`** so agents can programmatically look up where to send issues
- **Routes bugs and feature requests** to the correct upstream repo via GitHub issues
- **Always asks for confirmation** before filing anything cross-repo

## Install

### Claude Code (CLI)

**Personal install** — available across all your projects:

```bash
git clone https://github.com/YOUR_USERNAME/multi-repo-agent.git
cp -r multi-repo-agent ~/.claude/skills/multi-repo-agent
```

**Project install** — scoped to one project:

```bash
cd your-project
mkdir -p .claude/skills
cp -r /path/to/multi-repo-agent .claude/skills/multi-repo-agent
```

### Quick one-liner (Claude Code)

```bash
git clone https://github.com/YOUR_USERNAME/multi-repo-agent.git ~/.claude/skills/multi-repo-agent
```

## Usage

### Initialize your repos

Open Claude Code in any of your project repos and say:

```
Initialize multi-repo coordination for my projects
```

Or be specific:

```
Set up multi-repo for these repos:
- OpenFederation (https://github.com/myorg/OpenFederation) — identity platform + login SDK
- game-leaderboard (https://github.com/myorg/game-leaderboard) — score tracking service
- mini-game (https://github.com/myorg/mini-game) — the game client
```

The skill will:

1. Scan each repo's package files to detect cross-repo dependencies
2. Show you the dependency graph and ask you to confirm
3. Generate a `CLAUDE.md` (or append to your existing one) in each repo
4. Create a `.multi-repo-manifest.json` in each repo

After that, every Claude Code session in those repos will know the rules automatically.

### During development

You don't need to do anything special. The generated `CLAUDE.md` handles it. When the agent encounters a dependency bug, it will:

1. Identify that the bug belongs to a sibling repo
2. Draft a GitHub issue with reproduction steps
3. Show you the draft and ask: *"Should I file this?"*
4. Only file it after you confirm
5. Optionally leave a `TODO` workaround referencing the issue

### Commands

| Say this | What happens |
|---|---|
| `initialize repos` or `set up multi-repo` | Full initialization flow |
| `show repo map` | Displays current dependency topology |
| `route this bug` | Manually trigger bug-routing for something the agent found |
| `update manifest` | Regenerate the manifest after adding/removing repos |

## Example workflow

```
You (in mini-game repo): "The login flow crashes when the token expires"

Agent: I've identified this as a bug in @openfederation/login-sdk
       (owned by the OpenFederation repo). The SDK returns a 401
       instead of triggering a token refresh.

       Here's a draft GitHub issue for OpenFederation:

       Title: [cross-repo] Token refresh returns 401 on expired tokens
       Body: [full reproduction steps from mini-game's perspective]

       Should I file this on the OpenFederation repo?

You: "Yes, file it"

Agent: Filed as OpenFederation#47. I've added a temporary workaround
       with a TODO(OpenFederation#47) comment so we can keep working.
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
No. Install the skill once (in `~/.claude/skills/` for personal, or per-project). The skill generates `CLAUDE.md` and `.multi-repo-manifest.json` files in each repo — those are what the agents read day-to-day.

## Contributing

Issues and PRs welcome. Some areas that could use help:

- GitLab / Jira issue-filing support
- Dependency detection for more ecosystems (Maven, Gradle, Swift, Dart, etc.)
- A `--dry-run` mode that shows what would be generated without writing files
- MCP server integration for real-time agent-to-agent messaging
