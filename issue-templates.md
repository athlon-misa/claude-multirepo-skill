# GitHub Issue Templates for Cross-Repo Coordination

These templates are used by agents when filing issues on sibling repositories. They provide structured information that helps the receiving repo's agent (or human) understand and fix the problem quickly.

---

## Bug Report Template

Use when the agent encounters a bug in a dependency from a sibling repo.

```markdown
---
title: "[cross-repo] {{SHORT_DESCRIPTION}}"
labels: cross-repo, bug
---

**Filed by:** Agent working in [{{CONSUMER_REPO}}]({{CONSUMER_REPO_URL}})
**Dependency version:** {{PACKAGE_NAME}}@{{VERSION}}

## Bug description

{{WHAT_WENT_WRONG}}

## Steps to reproduce

From the context of `{{CONSUMER_REPO}}`:

1. {{STEP_1}}
2. {{STEP_2}}
3. {{STEP_3}}

## Expected behavior

{{EXPECTED}}

## Actual behavior

{{ACTUAL}}

## Error output

```
{{ERROR_LOGS_OR_STACK_TRACE}}
```

## Environment

- Consumer repo: {{CONSUMER_REPO}} ({{BRANCH_OR_COMMIT}})
- Dependency: {{PACKAGE_NAME}}@{{VERSION}}
- Runtime: {{NODE_VERSION_OR_PYTHON_VERSION_ETC}}

## Workaround

{{WORKAROUND_IF_ANY — or "None — consumer repo is blocked on this."}}
```

---

## Feature Request Template

Use when the agent needs a new feature or API change from a sibling repo's package/service.

```markdown
---
title: "[cross-repo] Feature request: {{SHORT_DESCRIPTION}}"
labels: cross-repo, enhancement
---

**Filed by:** Agent working in [{{CONSUMER_REPO}}]({{CONSUMER_REPO_URL}})
**Dependency version:** {{PACKAGE_NAME}}@{{VERSION}}

## What I need

{{DESCRIBE_THE_DESIRED_API_OR_BEHAVIOR}}

## Why I need it

{{USE_CASE_FROM_CONSUMER_PERSPECTIVE}}

## Current behavior

{{WHAT_THE_DEPENDENCY_DOES_NOW}}

## Desired behavior

{{WHAT_IT_SHOULD_DO_INSTEAD_OR_ADDITIONALLY}}

## Suggested API (optional)

```typescript
// Example of what the consumer repo would like to call:
{{CODE_EXAMPLE}}
```

## Impact

{{WHAT_IS_BLOCKED_OR_DEGRADED_WITHOUT_THIS}}
```

---

## Breaking Change Report Template

Use when a dependency update introduces a breaking change that affects the consumer repo.

```markdown
---
title: "[cross-repo] Breaking change after update to {{VERSION}}"
labels: cross-repo, breaking-change
---

**Filed by:** Agent working in [{{CONSUMER_REPO}}]({{CONSUMER_REPO_URL}})
**Updated from:** {{OLD_VERSION}} → {{NEW_VERSION}}

## What broke

{{DESCRIPTION}}

## Previous behavior ({{OLD_VERSION}})

{{HOW_IT_WORKED_BEFORE}}

## New behavior ({{NEW_VERSION}})

{{HOW_IT_WORKS_NOW}}

## Migration guidance needed

{{WHAT_THE_CONSUMER_NEEDS_TO_KNOW_TO_ADAPT}}
```

---

## Template usage notes

- The `[cross-repo]` prefix in titles makes these issues easy to filter and identify
- The `cross-repo` label is required — agents in the receiving repo watch for this label
- Always include the consumer repo name and URL so the receiving agent has full context
- Include dependency version pinned in the consumer repo, not just "latest"
- Error logs should be trimmed to the relevant portions — no full build outputs
- The "Workaround" field helps the receiving repo prioritize (blocked = urgent)
