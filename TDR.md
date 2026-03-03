# Technical Design Review: claude-brain

**Project**: claude-brain — Sync and evolve your Claude Code brain across machines
**Author**: Eddie Liang
**Date**: 2026-03-03
**Status**: Draft

---

## 1. Problem Statement

Claude Code accumulates valuable knowledge over time: auto-memory, custom agents, skills, rules, settings, and CLAUDE.md instructions. This "brain" is trapped on the machine where it was created. There is no built-in mechanism to:

1. **Migrate** a brain to a new machine
2. **Sync** brains across multiple machines used by the same person
3. **Merge** brains when multiple machines have independently accumulated knowledge
4. **Evolve** brains by promoting stable patterns from ephemeral memory to durable configuration

Users who work across multiple machines (laptop, desktop, cloud VMs) lose the compounding benefit of Claude Code's learning.

## 2. Proposed Solution

A **Claude Code plugin** distributed via the marketplace that:

- Runs on every machine where the user has Claude Code
- Exports local brain state to a portable format
- Syncs brain snapshots via a Git remote (no central server)
- Merges brains using deterministic strategies for structured data and LLM-powered semantic merge for unstructured data
- Auto-syncs on session boundaries via hooks (zero daily effort)
- Periodically evolves the brain by promoting stable patterns

## 3. Architecture

### 3.1 High-Level Architecture

```
Machine A              Machine B              Machine C
┌──────────┐          ┌──────────┐          ┌──────────┐
│ claude-   │          │ claude-   │          │ claude-   │
│ brain     │          │ brain     │          │ brain     │
│ plugin    │          │ plugin    │          │ plugin    │
│           │          │           │          │           │
│ hooks:    │          │ hooks:    │          │ hooks:    │
│ auto-push │          │ auto-push │          │ auto-push │
│ auto-pull │          │ auto-pull │          │ auto-pull │
└─────┬─────┘          └─────┬─────┘          └─────┬─────┘
      │                      │                      │
      └──────────┬───────────┴──────────┬───────────┘
                 │                      │
                 ▼                      ▼
          Git Remote (user's repo)
          ┌────────────────────────────────┐
          │ machines/                      │
          │   machine-a/brain-snapshot.json│
          │   machine-b/brain-snapshot.json│
          │   machine-c/brain-snapshot.json│
          │ consolidated/                  │
          │   brain.json                   │
          │ meta/                          │
          │   machines.json                │
          │   merge-log.json               │
          └────────────────────────────────┘
```

### 3.2 Sync Model: Merge on Pull (No Central Server)

When a machine pulls, it:
1. Fetches all other machines' snapshots
2. Runs deterministic merge on structured data (settings, keybindings, MCP)
3. Runs LLM-powered semantic merge on unstructured data (memory, CLAUDE.md)
4. Writes the merged result to `consolidated/`
5. Applies the consolidated brain locally
6. Pushes the updated consolidated state

The last machine to pull becomes the latest consolidator. All machines converge because they all merge against the same set of snapshots.

### 3.3 Merge Strategies

| Data Type | Strategy | LLM Required? |
|-----------|----------|---------------|
| settings.json | Deep JSON merge: arrays union, objects recursive merge | No |
| keybindings.json | Union bindings, latest wins on key conflict | No |
| MCP servers | Union servers, rewrite paths with ${HOME} vars | No |
| Skills | Union by name, if same name + both modified → LLM merge | Sometimes |
| Agents | Union by name, same conflict handling as skills | Sometimes |
| Rules | Union by filename | No |
| Output styles | Union by filename | No |
| CLAUDE.md | LLM semantic merge: dedup, reconcile, preserve unique | Yes |
| Auto memory | LLM semantic merge: dedup, tag machine-specific | Yes |
| Agent memory | LLM semantic merge per agent | Yes |

### 3.4 What Gets Synced vs What Stays Local

| Component | Sync? | Reason |
|-----------|-------|--------|
| CLAUDE.md | Merge | Universal preferences |
| rules/ | Union | All rules apply anywhere |
| skills/ | Union | Workflows are portable |
| agents/ (definitions) | Union | Agent prompts are portable |
| agent memory | Merge | Agent learnings transfer |
| keybindings | Merge | Muscle memory is global |
| output styles | Union | Preferences are portable |
| Auto memory (project learnings) | Merge | "Use pnpm" applies everywhere |
| Auto memory (path-specific) | Skip | "/home/alice/..." not useful elsewhere |
| settings.json (hooks, permissions) | Merge | Automation is portable |
| settings.json (env vars) | Skip | Machine-specific |
| MCP servers (remote/HTTP) | Sync | URLs are universal |
| MCP servers (local/stdio) | Rewrite | Commands need path variables |
| OAuth tokens | Never | Security |
| ~/.claude.json | Never | Machine-local secrets |
| Session transcripts | Never | Ephemeral |

## 4. Plugin Structure

```
claude-brain/
├── .claude-plugin/
│   └── plugin.json                 ← Plugin manifest
├── skills/
│   ├── brain-init/SKILL.md         ← /brain-init: first machine setup
│   ├── brain-join/SKILL.md         ← /brain-join: other machines join
│   ├── brain-status/SKILL.md       ← /brain-status: overview
│   ├── brain-sync/SKILL.md         ← /brain-sync: manual sync
│   ├── brain-evolve/SKILL.md       ← /brain-evolve: promote patterns
│   ├── brain-conflicts/SKILL.md    ← /brain-conflicts: resolve conflicts
│   └── brain-log/SKILL.md          ← /brain-log: sync history
├── agents/
│   └── brain-merge.md              ← Merge agent with persistent memory
├── hooks/
│   └── hooks.json                  ← SessionStart/SessionEnd auto-sync
├── scripts/
│   ├── common.sh                   ← Shared utilities (paths, config loading)
│   ├── export.sh                   ← Serialize brain to JSON snapshot
│   ├── import.sh                   ← Apply consolidated brain locally
│   ├── push.sh                     ← Push snapshot to Git remote
│   ├── pull.sh                     ← Pull + trigger merge
│   ├── merge-structured.sh         ← Deterministic JSON merge
│   ├── merge-semantic.sh           ← LLM merge via claude -p
│   ├── status.sh                   ← Inventory local brain state
│   ├── register-machine.sh         ← Machine identity management
│   └── evolve.sh                   ← Analyze and promote patterns
├── templates/
│   ├── merge-prompt.md             ← Prompt for semantic merge
│   ├── evolve-prompt.md            ← Prompt for evolution analysis
│   └── conflict-prompt.md          ← Prompt for conflict resolution
└── config/
    └── defaults.json               ← Default configuration values
```

## 5. Data Formats

### 5.1 Brain Snapshot (per machine)

```json
{
  "version": "1.0.0",
  "exported_at": "2026-03-03T12:00:00Z",
  "machine": {
    "id": "a1b2c3d4",
    "name": "work-laptop",
    "os": "linux",
    "hostname": "dev-01"
  },
  "declarative": {
    "claude_md": {
      "content": "...",
      "hash": "sha256:abc..."
    },
    "rules": {
      "security.md": { "content": "...", "hash": "sha256:..." },
      "testing.md": { "content": "...", "hash": "..." }
    }
  },
  "procedural": {
    "skills": {
      "review/SKILL.md": { "content": "...", "hash": "..." }
    },
    "agents": {
      "debugger.md": { "content": "...", "hash": "..." }
    },
    "output_styles": {
      "my-style.md": { "content": "...", "hash": "..." }
    }
  },
  "experiential": {
    "auto_memory": {
      "project-a": {
        "MEMORY.md": { "content": "...", "hash": "..." },
        "patterns.md": { "content": "...", "hash": "..." }
      }
    },
    "agent_memory": {
      "debugger": {
        "MEMORY.md": { "content": "...", "hash": "..." }
      }
    }
  },
  "environmental": {
    "settings": {
      "content": {},
      "hash": "..."
    },
    "keybindings": {
      "content": {},
      "hash": "..."
    },
    "mcp_servers": {
      "servers": {},
      "original_paths": {}
    }
  }
}
```

### 5.2 Machine Registry (meta/machines.json)

```json
{
  "machines": {
    "a1b2c3d4": {
      "name": "work-laptop",
      "os": "linux",
      "registered_at": "2026-01-15T10:00:00Z",
      "last_sync": "2026-03-03T12:00:00Z",
      "projects": ["project-a", "project-b"]
    }
  }
}
```

### 5.3 Merge Log (meta/merge-log.json)

```json
{
  "entries": [
    {
      "timestamp": "2026-03-03T12:05:00Z",
      "machine": "work-laptop",
      "action": "merge",
      "sources": ["work-laptop", "home-desktop"],
      "summary": {
        "memory_entries_merged": 5,
        "memory_duplicates_removed": 2,
        "skills_added": 1,
        "conflicts_found": 0,
        "conflicts_auto_resolved": 0
      }
    }
  ]
}
```

### 5.4 Conflict File (~/.claude/brain-conflicts.json)

```json
{
  "conflicts": [
    {
      "id": "c001",
      "created_at": "2026-03-03T12:05:00Z",
      "type": "memory",
      "file": "MEMORY.md",
      "project": "project-a",
      "machine_a": { "machine": "work-laptop", "content": "Use vitest for testing" },
      "machine_b": { "machine": "home-desktop", "content": "Use jest for testing" },
      "ai_suggestion": "Use vitest (more recent)",
      "ai_confidence": 0.7,
      "resolved": false
    }
  ]
}
```

### 5.5 Local Brain Config (~/.claude/brain-config.json)

```json
{
  "version": "1.0.0",
  "remote": "git@github.com:user/my-brain.git",
  "machine_id": "a1b2c3d4",
  "machine_name": "work-laptop",
  "brain_repo_path": "~/.claude/brain-repo",
  "auto_sync": true,
  "last_push": "2026-03-03T12:00:00Z",
  "last_pull": "2026-03-03T11:55:00Z",
  "evolve_schedule": "weekly"
}
```

## 6. Key Workflows

### 6.1 Init (First Machine)

```
User: /brain-init git@github.com:user/my-brain.git
  1. Scan ~/.claude/ for brain artifacts
  2. Generate machine ID (random UUID short)
  3. Create brain-config.json locally
  4. Run export.sh → brain-snapshot.json
  5. Clone/init the remote repo
  6. Create directory structure (machines/, consolidated/, meta/)
  7. Copy snapshot to machines/<machine-id>/
  8. Copy snapshot to consolidated/ (first machine = initial consolidated)
  9. Create meta/machines.json
  10. Git commit + push
  11. Install hooks (write hooks.json)
```

### 6.2 Join (Additional Machines)

```
User: /brain-join git@github.com:user/my-brain.git
  1. Clone the brain remote to ~/.claude/brain-repo
  2. Scan local brain
  3. Export local brain snapshot
  4. Compare local vs consolidated
  5. If local has unique data → merge into consolidated
  6. Register machine in meta/machines.json
  7. Push snapshot to machines/<machine-id>/
  8. Apply consolidated brain locally
  9. Save brain-config.json
  10. Install hooks
```

### 6.3 Auto-Sync (Session Boundaries)

```
SessionStart:
  1. pull.sh: git fetch in brain-repo
  2. Compare local snapshot hash vs latest consolidated hash
  3. If different: run merge, apply changes
  4. Log sync event

SessionEnd:
  1. export.sh: create fresh brain snapshot
  2. Compare with last pushed snapshot (hash check)
  3. If changed: push.sh → commit + push new snapshot
  4. Log sync event
```

### 6.4 Semantic Merge

```
merge-semantic.sh receives two content strings:
  1. Builds prompt from merge-prompt.md template
  2. Calls: claude -p "$PROMPT" --output-format json --json-schema "$SCHEMA" --model sonnet
  3. Parses structured output:
     - merged_content → write to consolidated
     - conflicts (confidence < 0.8) → append to brain-conflicts.json
     - conflicts (confidence >= 0.8) → auto-resolve, log resolution
     - deduped → log what was removed
```

### 6.5 Evolve

```
User: /brain-evolve
  1. Read all memory files from consolidated brain
  2. Read current CLAUDE.md, rules/, skills/
  3. Build evolve prompt with all context
  4. Call claude -p with structured output schema:
     - promotions: [{from, to, content, reason}]
     - new_skills: [{name, content, reason}]
     - stale: [{file, entry, reason}]
  5. Present each recommendation to user
  6. Apply accepted changes
  7. Push evolved brain
```

## 7. Dependencies

| Dependency | Required? | Notes |
|-----------|-----------|-------|
| `claude` CLI | Yes | For `claude -p` semantic merge. Already installed. |
| `git` | Yes | Transport layer. Already on dev machines. |
| `jq` | Yes | JSON parsing in shell scripts. Widely available. |
| `sha256sum` / `shasum` | Yes | Content hashing. Standard on Linux/macOS. |
| `ssh` or HTTPS auth | Yes | For Git remote access. User configures once. |

No Python, Node, or package manager dependencies beyond what developers already have.

## 8. Security Considerations

- **No secrets in brain snapshots**: OAuth tokens, API keys, and ~/.claude.json are never exported
- **MCP paths rewritten**: Absolute paths converted to ${HOME} variables
- **Git remote is private**: User creates their own private repo
- **env vars in settings skipped**: Machine-specific env vars not synced
- **.local files excluded**: settings.local.json and CLAUDE.local.md never exported
- **Merge prompts don't leak secrets**: Templates only reference brain content, not credentials

## 9. Limitations (v0)

- No encryption at rest for brain snapshots (relies on Git repo access controls)
- No team/shared brain support (personal only)
- No selective sync (all-or-nothing per knowledge type)
- No automatic evolve scheduling (manual `/brain-evolve` only)
- Merge conflicts require manual resolution via `/brain-conflicts`
- jq must be installed separately on machines that don't have it
- No Windows native support (WSL works, Git Bash may not)

## 10. Future Enhancements (Post-v0)

- Team brain: selective sharing of skills/agents with teammates
- Encrypted brain snapshots (age/gpg encryption)
- Selective sync: choose which knowledge types to sync
- Automated evolve via cron/systemd integration
- Brain analytics: track knowledge growth over time
- Import from third-party plugins: extract useful patterns from other plugins
- Conflict resolution UI in Claude Code
- Brain backup/restore to cloud storage
