#!/bin/bash
# detect-deps.sh — Auto-detect cross-repo dependencies from package files
#
# Usage: ./detect-deps.sh /path/to/repo
#
# Scans a repository for dependency declarations and prints them as JSON.
# Supports: package.json (npm), requirements.txt (pip), pyproject.toml (Python),
#           go.mod (Go), Cargo.toml (Rust)
#
# The output is a flat list of dependency names. The agent then matches
# these against the `owns` list in sibling repos to detect cross-repo deps.

set -euo pipefail

REPO_PATH="${1:-.}"

echo "{"
echo "  \"repo_path\": \"$REPO_PATH\","
echo "  \"detected_dependencies\": {"

found_any=false

# --- Node.js / npm ---
if [ -f "$REPO_PATH/package.json" ]; then
    found_any=true
    echo "    \"npm\": {"
    echo "      \"file\": \"package.json\","
    echo "      \"dependencies\": $(python3 -c "
import json, sys
try:
    with open('$REPO_PATH/package.json') as f:
        pkg = json.load(f)
    deps = {}
    for key in ['dependencies', 'devDependencies', 'peerDependencies']:
        if key in pkg:
            deps.update(pkg[key])
    print(json.dumps(deps, indent=6))
except Exception as e:
    print('{}')
    sys.exit(0)
")"
    echo "    },"
fi

# --- Python / pip ---
if [ -f "$REPO_PATH/requirements.txt" ]; then
    found_any=true
    echo "    \"pip\": {"
    echo "      \"file\": \"requirements.txt\","
    echo "      \"dependencies\": $(python3 -c "
import json, re
deps = {}
try:
    with open('$REPO_PATH/requirements.txt') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                match = re.match(r'^([a-zA-Z0-9_-]+[a-zA-Z0-9._-]*)\s*([>=<~!]*.*)?$', line)
                if match:
                    deps[match.group(1)] = (match.group(2) or '').strip()
except: pass
print(json.dumps(deps, indent=6))
")"
    echo "    },"
fi

# --- Python / pyproject.toml ---
if [ -f "$REPO_PATH/pyproject.toml" ]; then
    found_any=true
    echo "    \"pyproject\": {"
    echo "      \"file\": \"pyproject.toml\","
    echo "      \"dependencies\": $(python3 -c "
import json, re
deps = {}
try:
    with open('$REPO_PATH/pyproject.toml') as f:
        content = f.read()
    # Simple extraction of dependencies array
    in_deps = False
    for line in content.split('\n'):
        if 'dependencies' in line and '=' in line and '[' in line:
            in_deps = True
            continue
        if in_deps:
            if ']' in line:
                in_deps = False
                continue
            line = line.strip().strip(',').strip('\"').strip(\"'\")
            if line:
                match = re.match(r'^([a-zA-Z0-9_-]+)', line)
                if match:
                    deps[match.group(1)] = line
except: pass
print(json.dumps(deps, indent=6))
")"
    echo "    },"
fi

# --- Go ---
if [ -f "$REPO_PATH/go.mod" ]; then
    found_any=true
    echo "    \"go\": {"
    echo "      \"file\": \"go.mod\","
    echo "      \"dependencies\": $(python3 -c "
import json, re
deps = {}
try:
    with open('$REPO_PATH/go.mod') as f:
        in_require = False
        for line in f:
            line = line.strip()
            if line == 'require (':
                in_require = True
                continue
            if line == ')':
                in_require = False
                continue
            if in_require and line:
                parts = line.split()
                if len(parts) >= 2:
                    deps[parts[0]] = parts[1]
except: pass
print(json.dumps(deps, indent=6))
")"
    echo "    },"
fi

# --- Rust / Cargo ---
if [ -f "$REPO_PATH/Cargo.toml" ]; then
    found_any=true
    echo "    \"cargo\": {"
    echo "      \"file\": \"Cargo.toml\","
    echo "      \"dependencies\": $(python3 -c "
import json, re
deps = {}
try:
    with open('$REPO_PATH/Cargo.toml') as f:
        in_deps = False
        for line in f:
            line = line.strip()
            if re.match(r'^\[.*dependencies\]', line):
                in_deps = True
                continue
            if line.startswith('[') and 'dependencies' not in line:
                in_deps = False
                continue
            if in_deps and '=' in line:
                key, val = line.split('=', 1)
                deps[key.strip()] = val.strip().strip('\"')
except: pass
print(json.dumps(deps, indent=6))
")"
    echo "    },"
fi

if [ "$found_any" = false ]; then
    echo "    \"_note\": \"No recognized package files found\""
fi

echo "  }"
echo "}"
