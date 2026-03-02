# CLAUDE.md Template for Multi-Repo Coordination

Use this template to generate a CLAUDE.md for each repository in the project. Replace all `{{placeholders}}` with actual values from the project topology.

---

## Template

```markdown
# {{REPO_NAME}} — Agent Instructions

## Ownership

This repository owns **{{OWNERSHIP_DESCRIPTION}}**.
Any bugs, features, or refactors related to the above are this agent's responsibility to fix directly.

## Dependencies from sibling repositories

The following packages or services are **NOT owned by this repo**. They come from sibling projects in this multi-repo setup:

{{#each DEPENDENCIES}}
- **{{DEP_NAME}}** — from [{{SOURCE_REPO_NAME}}]({{SOURCE_REPO_URL}})
  - Used for: {{USAGE_DESCRIPTION}}
  - Current version: {{VERSION_OR_REF}}
{{/each}}

## Cross-repo routing rules

When you encounter a bug or need a feature change in any dependency listed above:

1. **Do NOT attempt to fix it in this repository.** No monkey-patching, no local overrides, no "temporary" forks of the dependency code.
2. **Draft a GitHub issue** targeting the source repository. Use the appropriate issue template (bug report, feature request, or breaking change).
3. **Always ask the user for confirmation** before filing the issue. Show them the full issue preview.
4. After filing, you may create a minimal marked workaround in this repo if needed to unblock work. Always include a `TODO({{ISSUE_URL}})` comment referencing the upstream issue.

## Issue filing

Use `gh issue create` with these defaults:
- **Repo:** `{{SOURCE_REPO_OWNER}}/{{SOURCE_REPO_NAME}}`
- **Labels:** `cross-repo`, plus `bug`, `enhancement`, or `breaking-change` as appropriate
- **Body:** Always include: consumer repo name + URL, dependency version, reproduction steps, expected vs actual behavior

## Receiving cross-repo issues

If you see issues labeled `cross-repo` filed against this repository:
- These were created by agents working in sibling repos that hit a problem with your code
- Treat them as high-priority bug reports or feature requests
- When creating a PR to fix them, reference the original issue number
- After fixing, notify the user so the downstream repo can update its dependency

## Project topology

This repo is part of a multi-repo project:
{{#each ALL_REPOS}}
- [{{REPO_NAME}}]({{REPO_URL}}) — {{SHORT_DESCRIPTION}}
{{/each}}

Manifest file: `.multi-repo-manifest.json` (machine-readable topology)
```

---

## Generation notes

When filling in this template:
- Read `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, or equivalent to auto-detect dependency versions
- The `OWNERSHIP_DESCRIPTION` should be a plain-English summary of what the repo contains (e.g., "the identity platform, OAuth flows, and the login SDK published as @openfederation/login-sdk")
- The `USAGE_DESCRIPTION` should explain how this repo uses the dependency (e.g., "authenticating users at game launch" or "posting scores to the leaderboard API")
- If a CLAUDE.md already exists, append this content under a `## Multi-Repo Coordination` section rather than overwriting
