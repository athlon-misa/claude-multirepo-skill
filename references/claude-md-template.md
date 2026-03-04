# CLAUDE.md Template for Multi-Repo Coordination

Use this template to generate a CLAUDE.md for each repository in the project. Replace all `{{placeholders}}` with actual values from the project topology.

---

## Template

```markdown
# {{REPO_NAME}} — Agent Instructions

## Ownership

This repository owns **{{OWNERSHIP_DESCRIPTION}}**.
Any bugs, features, or refactors related to the above are this agent's responsibility to fix directly.

## Dependencies from owned sibling repositories

These come from repos your team maintains. Bugs here get full analysis and fix routing:

{{#each OWNED_DEPENDENCIES}}
- **{{DEP_NAME}}** — from [{{SOURCE_REPO_NAME}}]({{SOURCE_REPO_URL}}) `[owned]`
  - Used for: {{USAGE_DESCRIPTION}}
  - Current version: {{VERSION_OR_REF}}
{{/each}}

## Dependencies from third-party repositories

These come from external projects you don't control. Do NOT analyze their source code — file issues with consumer-side context only:

{{#each THIRD_PARTY_DEPENDENCIES}}
- **{{DEP_NAME}}** — from [{{SOURCE_REPO_NAME}}]({{SOURCE_REPO_URL}}) `[third-party]`
  - Used for: {{USAGE_DESCRIPTION}}
  - Current version: {{VERSION_OR_REF}}
{{/each}}

## Cross-repo routing rules

When you encounter a bug or need a feature change in any dependency listed above:

1. **Do NOT attempt to fix it in this repository.** No monkey-patching, no local overrides, no "temporary" forks of the dependency code.
2. **Check the dependency's role:**
   - **Owned** → Draft a GitHub issue targeting the source repository. Use the appropriate issue template (bug report, feature request, or breaking change). Proceed with the full routing flow.
   - **Third-party** → Do NOT analyze the third-party repo's source code. Draft a GitHub issue using only information available from this repo: error messages, stack traces, reproduction steps, and expected vs actual behavior. Keep it concise and actionable.
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
- To see all open cross-repo issues, invoke `/multi-repo-agent` then say `check issues`
- To analyze an issue and get a fix plan, invoke `/multi-repo-agent` then say `plan fix` or `plan fix #<number>`
- Fix analysis uses **progressive-depth**: it starts with a targeted scan of 1-3 files and only widens if needed, saving tokens on simple issues

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
- The `OWNERSHIP_DESCRIPTION` should be a plain-English summary of what the repo contains (e.g., "the authentication service, OAuth flows, and the auth SDK published as @acme/auth-sdk")
- The `USAGE_DESCRIPTION` should explain how this repo uses the dependency (e.g., "authenticating users at login" or "processing payments via the billing API")
- Split dependencies into `OWNED_DEPENDENCIES` and `THIRD_PARTY_DEPENDENCIES` based on the `role` field in `.multi-repo-manifest.json`. If a dependency's source repo has no `role` field (v1.0 manifest), treat it as owned.
- If a CLAUDE.md already exists, append this content under a `## Multi-Repo Coordination` section rather than overwriting
