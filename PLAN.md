# Implementation Plan: claude-brain v0

## Phase 1: Foundation (Scripts + Config)

### 1.1 common.sh — Shared utilities
- Define paths: BRAIN_CONFIG, BRAIN_REPO, CLAUDE_DIR, etc.
- Load brain-config.json helper
- Machine ID generation (uuid-like from /dev/urandom)
- Hash function wrapper (sha256sum or shasum depending on OS)
- JSON helpers using jq
- Git wrapper (handles brain-repo operations)
- Logging (to merge-log.json)
- OS detection (Linux, macOS, WSL)

### 1.2 config/defaults.json
- Default configuration values
- Merge confidence threshold (0.8)
- Auto-sync enabled by default
- Max memory lines (200)

### 1.3 export.sh — Serialize brain to snapshot
- Scan ~/.claude/ for all brain artifacts
- Read CLAUDE.md, rules/, skills/, agents/, output-styles/
- Read auto memory from ~/.claude/projects/*/memory/
- Read agent memory from ~/.claude/agent-memory/*/
- Read settings.json (strip env vars)
- Read keybindings.json
- Read MCP servers from ~/.claude.json (rewrite paths to ${HOME})
- Compute sha256 hash for each file
- Assemble into brain-snapshot.json format
- Write to stdout or specified output path

### 1.4 import.sh — Apply consolidated brain locally
- Read consolidated brain.json
- Write CLAUDE.md (if changed)
- Write rules/ files (union — don't delete existing)
- Write skills/ (union)
- Write agents/ (union)
- Write output-styles/ (union)
- Merge settings.json (deep merge, don't overwrite local env)
- Merge keybindings.json (union bindings)
- Update auto memory (write merged content)
- Update agent memory (write merged content)
- Skip any file where local hash matches consolidated hash (no-op)

### 1.5 register-machine.sh — Machine identity
- Generate machine ID if not exists
- Detect machine name (hostname)
- Detect OS
- Create/update entry in meta/machines.json
- Save machine ID to brain-config.json

### 1.6 status.sh — Brain inventory
- Count lines in CLAUDE.md
- Count files in rules/, skills/, agents/, output-styles/
- Count memory entries across all projects
- Count agent memory entries
- Read brain-config.json for sync status
- Read meta/machines.json for network info
- Output formatted summary

## Phase 2: Git Operations (Push/Pull)

### 2.1 push.sh — Push snapshot to remote
- Check brain-config.json exists (initialized?)
- Run export.sh to create fresh snapshot
- Compare hash with last pushed hash (skip if identical)
- Copy snapshot to brain-repo/machines/<machine-id>/
- Update meta/machines.json (last_sync timestamp)
- Git add, commit, push
- Update brain-config.json (last_push timestamp)
- Flags: --quiet (suppress output), --force (push even if unchanged)

### 2.2 pull.sh — Pull + merge
- Check brain-config.json exists
- Git fetch + pull in brain-repo
- Read all machine snapshots from machines/*/brain-snapshot.json
- Read current consolidated/brain.json
- Compare hashes — if nothing changed, exit early
- Run merge-structured.sh for JSON data
- Run merge-semantic.sh for unstructured data (only if changed)
- Write merged result to consolidated/brain.json
- Run import.sh to apply locally
- Git add, commit, push consolidated/
- Update brain-config.json (last_pull timestamp)
- Append to meta/merge-log.json
- Flags: --quiet, --auto-merge (resolve high-confidence conflicts)

## Phase 3: Merge Engine

### 3.1 merge-structured.sh — Deterministic JSON merge
- Deep merge settings.json from all machines:
  - permissions.allow: union of all arrays
  - permissions.deny: union of all arrays
  - hooks: union by event type, dedup identical hooks
  - env: skip (machine-specific)
- Merge keybindings.json:
  - Union all bindings by context
  - If same key mapped differently, keep most recent (by snapshot timestamp)
- Merge MCP servers:
  - Union by server name
  - Remote (HTTP) servers: take as-is
  - Local (stdio) servers: rewrite command paths with ${HOME}
- Output: merged JSON files written to consolidated/

### 3.2 merge-semantic.sh — LLM-powered merge
- Accept two content files as arguments
- Read merge-prompt.md template
- Substitute content into template
- Call: claude -p "$PROMPT" --output-format json --json-schema "$SCHEMA" --model sonnet --max-turns 1
- Parse structured output:
  - merged_content → write to output file
  - conflicts → append to ~/.claude/brain-conflicts.json
  - deduped → log for audit
- Handle errors: if claude -p fails, keep both contents concatenated with markers
- Flags: --confidence-threshold (default 0.8)

### 3.3 templates/merge-prompt.md
- Clear instructions for semantic merge
- Rules: dedup, resolve contradictions, preserve unique, tag machine-specific
- 200-line limit enforcement for MEMORY.md
- Output format specification matching JSON schema

### 3.4 templates/evolve-prompt.md
- Instructions for analyzing accumulated memory
- Pattern detection across projects/machines
- Promotion criteria (frequency, consistency, universality)
- Output: promotions, new skills suggestions, stale entry identification

### 3.5 templates/conflict-prompt.md
- Context for resolving specific conflicts
- Input: the two conflicting entries + metadata
- Output: resolution with confidence score

## Phase 4: Skills (User Interface)

### 4.1 brain-init/SKILL.md
- Accepts git remote URL as argument
- Runs status.sh to show inventory
- Asks user to confirm
- Creates brain-repo, runs register-machine.sh, export.sh
- Initializes Git structure, pushes
- Saves brain-config.json

### 4.2 brain-join/SKILL.md
- Accepts git remote URL as argument
- Clones brain-repo
- Shows comparison (local vs consolidated)
- Asks user: merge, overwrite, or keep both
- Runs merge if needed
- Registers machine, applies brain, saves config

### 4.3 brain-status/SKILL.md
- Runs status.sh
- Shows formatted inventory
- Shows sync status, machine network, conflicts count

### 4.4 brain-sync/SKILL.md
- Manual trigger for push + pull cycle
- Shows summary of changes

### 4.5 brain-evolve/SKILL.md
- Runs evolve analysis
- Presents recommendations interactively
- Applies accepted changes
- Pushes evolved brain

### 4.6 brain-conflicts/SKILL.md
- Reads brain-conflicts.json
- Shows each conflict with AI suggestion
- Asks user to resolve
- Applies resolutions, removes from conflict file

### 4.7 brain-log/SKILL.md
- Reads meta/merge-log.json
- Shows recent sync/merge/evolve history

## Phase 5: Hooks + Agent

### 5.1 hooks/hooks.json
- SessionStart (startup|resume): pull.sh --quiet --auto-merge (async)
- SessionEnd (prompt_input_exit|logout): export.sh + push.sh --quiet (async)
- PreCompact (auto): export.sh --memory-only --quiet (async)

### 5.2 agents/brain-merge.md
- Merge specialist agent with persistent memory (user scope)
- Tools: Read, Write, Bash, Grep
- Tracks merge patterns and user preferences
- Gets smarter over time at auto-resolving conflicts

## Phase 6: Plugin Manifest + Marketplace

### 6.1 .claude-plugin/plugin.json
- Name, version, description, author, repository, license

### 6.2 Marketplace structure
- marketplace.json pointing to the plugin

## V0 Scope

For v0, we implement ALL phases but with these simplifications:

1. **merge-semantic.sh** handles exactly 2 brain merge (not N-way). Multi-machine handled by sequential pairwise merge.
2. **evolve.sh** is functional but basic — promotes memory entries that appear in 2+ machine snapshots.
3. **Conflicts** stored in JSON file, resolved via /brain-conflicts skill.
4. **No encryption** — relies on private Git repo.
5. **No Windows native** — Linux and macOS only (WSL works).

## File Count Estimate

| Category | Files | Complexity |
|----------|-------|-----------|
| Scripts | 10 | Medium-High |
| Skills | 7 | Medium |
| Agent | 1 | Medium |
| Templates | 3 | Low |
| Config | 2 | Low |
| Plugin manifest | 1 | Low |
| **Total** | **24** | |

## Acceptance Criteria (v0)

1. `/brain-init` creates brain repo, exports initial snapshot, pushes
2. `/brain-join` on a second machine pulls and applies the brain
3. SessionEnd hook exports and pushes snapshot silently
4. SessionStart hook pulls and merges changes silently
5. `/brain-status` shows accurate inventory and sync status
6. `/brain-sync` manually triggers full push+pull cycle
7. `/brain-evolve` analyzes memory and proposes promotions
8. `/brain-conflicts` shows and resolves merge conflicts
9. `/brain-log` shows sync history
10. Structured merge correctly unions settings, keybindings, MCP servers
11. Semantic merge correctly deduplicates and reconciles memory content
12. No secrets are ever exported in brain snapshots
