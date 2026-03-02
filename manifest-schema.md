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
      "description": "Schema version. Currently '1.0'.",
      "const": "1.0"
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
        "required": ["name", "url", "owns", "depends_on"],
        "properties": {
          "name": {
            "type": "string",
            "description": "Repository name (e.g., 'OpenFederation')."
          },
          "url": {
            "type": "string",
            "format": "uri",
            "description": "GitHub URL of the repository."
          },
          "owns": {
            "type": "array",
            "items": { "type": "string" },
            "description": "List of packages, services, or modules this repo is responsible for. Use package names as published (e.g., '@openfederation/login-sdk', 'leaderboard-api')."
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
                  "description": "The package or service name as consumed (e.g., '@openfederation/login-sdk')."
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
  "version": "1.0",
  "project": "GamePlatform",
  "repos": [
    {
      "name": "OpenFederation",
      "url": "https://github.com/yourorg/OpenFederation",
      "owns": ["@openfederation/login-sdk", "identity-api"],
      "depends_on": []
    },
    {
      "name": "game-leaderboard",
      "url": "https://github.com/yourorg/game-leaderboard",
      "owns": ["leaderboard-api", "@yourorg/leaderboard-client"],
      "depends_on": [
        {
          "package": "@openfederation/login-sdk",
          "source_repo": "OpenFederation",
          "version": "^1.3.0"
        }
      ]
    },
    {
      "name": "mini-game",
      "url": "https://github.com/yourorg/mini-game",
      "owns": ["mini-game-client"],
      "depends_on": [
        {
          "package": "@openfederation/login-sdk",
          "source_repo": "OpenFederation",
          "version": "^1.3.0"
        },
        {
          "package": "@yourorg/leaderboard-client",
          "source_repo": "game-leaderboard",
          "version": "^2.0.1"
        }
      ]
    }
  ]
}
```

## How agents use this file

When an agent encounters an error in a dependency:

1. Read `.multi-repo-manifest.json`
2. Find the failing package in the `owns` array of sibling repos
3. Look up the `url` of that source repo
4. Use that URL to file the GitHub issue with `gh issue create -R <url>`

This is faster and more reliable than parsing CLAUDE.md for routing decisions.
