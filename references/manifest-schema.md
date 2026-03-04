# Multi-Repo Manifest Schema

The `.multi-repo-manifest.json` file is placed at the root of each repository in the project. It provides a machine-readable map of the project topology so agents can quickly determine where to route issues without parsing CLAUDE.md.

## Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["version", "project", "repos"],
  "properties": {
    "version": {
      "type": "string",
      "description": "Schema version. Currently '1.1'.",
      "enum": ["1.0", "1.1"]
    },
    "project": {
      "type": "string",
      "description": "Human-readable name for the overall multi-repo project."
    },
    "repos": {
      "type": "array",
      "description": "All repositories in this project.",
      "items": {
        "type": "object",
        "required": ["name", "url", "role", "owns", "depends_on"],
        "properties": {
          "name": {
            "type": "string",
            "description": "Repository name (e.g., 'auth-service')."
          },
          "url": {
            "type": "string",
            "format": "uri",
            "description": "GitHub URL of the repository."
          },
          "role": {
            "type": "string",
            "enum": ["owned", "third-party"],
            "default": "owned",
            "description": "Whether you own this repo ('owned') or it's a third-party dependency ('third-party'). Owned repos get full analysis and fix flows. Third-party repos get issue-only routing — the agent skips code analysis and files issues with available consumer-side info."
          },
          "owns": {
            "type": "array",
            "items": { "type": "string" },
            "description": "List of packages, services, or modules this repo is responsible for. Use package names as published (e.g., '@acme/auth-sdk', 'billing-api')."
          },
          "depends_on": {
            "type": "array",
            "description": "Dependencies that come from sibling repos in this project.",
            "items": {
              "type": "object",
              "required": ["package", "source_repo"],
              "properties": {
                "package": {
                  "type": "string",
                  "description": "The package or service name as consumed (e.g., '@acme/auth-sdk')."
                },
                "source_repo": {
                  "type": "string",
                  "description": "Name of the sibling repo that owns this dependency. Must match a 'name' in the repos array."
                },
                "version": {
                  "type": "string",
                  "description": "Currently used version or reference (e.g., '^2.1.0', 'main', 'v3.0.0-beta')."
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## Example

```json
{
  "version": "1.1",
  "project": "MyPlatform",
  "repos": [
    {
      "name": "auth-service",
      "url": "https://github.com/acme/auth-service",
      "role": "owned",
      "owns": ["@acme/auth-sdk", "auth-api"],
      "depends_on": []
    },
    {
      "name": "billing-api",
      "url": "https://github.com/acme/billing-api",
      "role": "owned",
      "owns": ["billing-api", "@acme/billing-client"],
      "depends_on": [
        {
          "package": "@acme/auth-sdk",
          "source_repo": "auth-service",
          "version": "^1.3.0"
        }
      ]
    },
    {
      "name": "web-app",
      "url": "https://github.com/acme/web-app",
      "role": "owned",
      "owns": ["web-app"],
      "depends_on": [
        {
          "package": "@acme/auth-sdk",
          "source_repo": "auth-service",
          "version": "^1.3.0"
        },
        {
          "package": "@acme/billing-client",
          "source_repo": "billing-api",
          "version": "^2.0.1"
        }
      ]
    },
    {
      "name": "redis",
      "url": "https://github.com/redis/redis",
      "role": "third-party",
      "owns": ["redis"],
      "depends_on": []
    }
  ]
}
```

## How agents use this file

When an agent encounters an error in a dependency:

1. Read `.multi-repo-manifest.json`
2. Find the failing package in the `owns` array of sibling repos
3. **Check the `role` of the source repo:**
   - `"owned"` → proceed with full analysis and fix routing (file issue, plan fix, etc.)
   - `"third-party"` → skip code analysis entirely. Draft an issue using only the consumer repo's context (error messages, stack traces, reproduction steps) and file it with `gh issue create -R <url>`
4. Look up the `url` of that source repo
5. Use that URL to file the GitHub issue with `gh issue create -R <url>`

If a dependency is **not in the manifest at all**, treat it as implicitly third-party.

This is faster and more reliable than parsing CLAUDE.md for routing decisions.

## Backward compatibility

- Schema version `"1.0"` manifests do not include the `role` field. Agents should treat repos without a `role` field as `"owned"` for backward compatibility.
- When running `update manifest`, upgrade v1.0 manifests to v1.1 by adding `"role": "owned"` to all existing repos and prompting the user to classify any that should be `"third-party"`.
