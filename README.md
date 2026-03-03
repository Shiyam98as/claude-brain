# claude-brain

Sync and evolve your Claude Code brain across machines.

## What It Does

Claude Code accumulates knowledge over time: auto-memory, custom agents, skills, rules, settings, and CLAUDE.md instructions. This plugin makes that knowledge portable across all your machines.

- **Export** your brain state to a portable format
- **Sync** brains across machines via Git (no central server)
- **Merge** intelligently: deterministic for structured data, LLM-powered for unstructured knowledge
- **Evolve** by promoting stable patterns from memory to durable configuration
- **Auto-sync** on every Claude Code session start/end via hooks

## Quick Start

### First machine (initialize)

```
/brain-init git@github.com:you/my-brain.git
```

### Other machines (join)

```
/brain-join git@github.com:you/my-brain.git
```

### That's it

Hooks auto-sync on every session start/end. Your brain follows you.

## Commands

| Command | Description |
|---------|-------------|
| `/brain-init <remote>` | Initialize brain network with a Git remote |
| `/brain-join <remote>` | Join an existing brain network |
| `/brain-status` | Show brain inventory and sync status |
| `/brain-sync` | Manually trigger full sync cycle |
| `/brain-evolve` | Promote stable patterns from memory |
| `/brain-conflicts` | Review and resolve merge conflicts |
| `/brain-log` | Show sync history |

## How It Works

### Sync Model

Each machine pushes brain snapshots to a shared Git repo. When a machine pulls, it merges all snapshots:

- **Structured data** (settings, keybindings, MCP servers): Deterministic JSON deep-merge
- **Unstructured data** (memory, CLAUDE.md): LLM-powered semantic merge via `claude -p`

### What Gets Synced

| Component | Synced? | Strategy |
|-----------|---------|----------|
| CLAUDE.md | Yes | Semantic merge |
| Rules | Yes | Union by filename |
| Skills | Yes | Union by name |
| Agents | Yes | Union by name |
| Auto memory | Yes | Semantic merge |
| Agent memory | Yes | Semantic merge |
| Settings (hooks, permissions) | Yes | Deep merge |
| Keybindings | Yes | Union |
| MCP servers | Yes | Union, paths rewritten |
| OAuth tokens | Never | Security |
| Env vars | Never | Machine-specific |

### What Never Leaves Your Machine

- OAuth tokens and API keys
- `~/.claude.json` (internal state)
- Environment variables from settings
- `.local` config files

## Dependencies

- `git` (for sync transport)
- `jq` or `python3` (for JSON processing)
- `claude` CLI (for semantic merge — already installed if you have Claude Code)

## Architecture

```
Machine A              Machine B              Machine C
┌──────────┐          ┌──────────┐          ┌──────────┐
│ claude-   │          │ claude-   │          │ claude-   │
│ brain     │          │ brain     │          │ brain     │
│ plugin    │          │ plugin    │          │ plugin    │
└─────┬─────┘          └─────┬─────┘          └─────┬─────┘
      │                      │                      │
      └──────────┬───────────┴──────────┬───────────┘
                 │     Git Remote       │
                 │  (user's private     │
                 │       repo)          │
                 └──────────────────────┘
```

No central server. Each machine merges on pull. Git handles transport.

## Installation

### From marketplace (when available)

```
/plugin marketplace add toroleapinc/claude-brain
/plugin install claude-brain
```

### Local development

```
claude --plugin-dir ./claude-brain
```

## License

MIT
