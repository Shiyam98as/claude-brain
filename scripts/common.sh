#!/usr/bin/env bash
# common.sh — Shared utilities for claude-brain
set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
CLAUDE_DIR="${HOME}/.claude"
CLAUDE_JSON="${HOME}/.claude.json"
BRAIN_CONFIG="${CLAUDE_DIR}/brain-config.json"
BRAIN_REPO="${CLAUDE_DIR}/brain-repo"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEFAULTS_FILE="${PLUGIN_ROOT}/config/defaults.json"

# ── OS Detection ───────────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}

OS="$(detect_os)"

# ── JSON Query ─────────────────────────────────────────────────────────────────
# Uses jq if available, falls back to python3
_has_jq=false
_has_python3=false

if command -v jq &>/dev/null; then
  _has_jq=true
elif command -v python3 &>/dev/null; then
  _has_python3=true
fi

json_query() {
  # Usage: json_query '.field.subfield' < input.json
  #    or: echo '{}' | json_query '.field'
  local filter="$1"
  if $_has_jq; then
    jq -r "$filter"
  elif $_has_python3; then
    python3 -c "
import sys, json
data = json.load(sys.stdin)
parts = '''${filter}'''.strip('.').split('.')
result = data
for p in parts:
    if p and isinstance(result, dict):
        result = result.get(p)
    elif p and isinstance(result, list):
        result = result[int(p)] if p.isdigit() else None
    if result is None:
        break
if result is None:
    print('null')
elif isinstance(result, (dict, list)):
    print(json.dumps(result))
else:
    print(result)
"
  else
    echo "ERROR: Neither jq nor python3 found. Install one of them." >&2
    return 1
  fi
}

json_build() {
  # Build JSON from arguments using jq or python3
  # Usage: json_build --arg key value --arg key2 value2 'template'
  if $_has_jq; then
    jq "$@"
  elif $_has_python3; then
    # Fallback: only supports simple --arg key val patterns
    python3 -c "
import sys, json
args = sys.argv[1:]
data = {}
i = 0
while i < len(args) - 1:
    if args[i] == '--arg' and i + 2 < len(args):
        data[args[i+1]] = args[i+2]
        i += 3
    else:
        i += 1
print(json.dumps(data, indent=2))
" "$@"
  else
    echo "ERROR: Neither jq nor python3 found." >&2
    return 1
  fi
}

json_set() {
  # Set a key in a JSON file
  # Usage: json_set file.json '.key' 'value'
  local file="$1" path="$2" value="$3"
  if $_has_jq; then
    local tmp
    tmp=$(mktemp)
    jq "${path} = ${value}" "$file" > "$tmp" && mv "$tmp" "$file"
  elif $_has_python3; then
    python3 -c "
import json, sys
with open('${file}') as f:
    data = json.load(f)
keys = '${path}'.strip('.').split('.')
obj = data
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
obj[keys[-1]] = json.loads('${value}')
with open('${file}', 'w') as f:
    json.dump(data, f, indent=2)
"
  fi
}

# ── Hashing ────────────────────────────────────────────────────────────────────
compute_hash() {
  # Compute SHA256 hash of stdin
  if command -v sha256sum &>/dev/null; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum &>/dev/null; then
    shasum -a 256 | cut -d' ' -f1
  elif $_has_python3; then
    python3 -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())"
  else
    echo "ERROR: No hash utility found." >&2
    return 1
  fi
}

file_hash() {
  # Compute SHA256 hash of a file
  local file="$1"
  if [ -f "$file" ]; then
    compute_hash < "$file"
  else
    echo "null"
  fi
}

# ── Machine ID ─────────────────────────────────────────────────────────────────
generate_machine_id() {
  # Generate an 8-char hex ID
  if [ -f /dev/urandom ]; then
    head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n'
  elif $_has_python3; then
    python3 -c "import secrets; print(secrets.token_hex(4))"
  else
    date +%s | compute_hash | head -c 8
  fi
}

get_machine_id() {
  if [ -f "$BRAIN_CONFIG" ]; then
    json_query '.machine_id' < "$BRAIN_CONFIG"
  else
    echo ""
  fi
}

get_machine_name() {
  hostname 2>/dev/null || echo "unknown"
}

# ── Brain Config ───────────────────────────────────────────────────────────────
is_initialized() {
  [ -f "$BRAIN_CONFIG" ] && [ -d "$BRAIN_REPO/.git" ]
}

load_config() {
  if [ ! -f "$BRAIN_CONFIG" ]; then
    echo "ERROR: Brain not initialized. Run /brain-init first." >&2
    return 1
  fi
}

get_config() {
  local key="$1"
  json_query ".$key" < "$BRAIN_CONFIG"
}

# ── Git Operations ─────────────────────────────────────────────────────────────
brain_git() {
  git -C "$BRAIN_REPO" "$@"
}

brain_push_with_retry() {
  local max_attempts="${1:-3}"
  local delay="${2:-2}"
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    if brain_git push origin main 2>/dev/null; then
      return 0
    fi
    # Pull rebase and retry
    brain_git pull --rebase origin main 2>/dev/null || true
    attempt=$((attempt + 1))
    if [ "$attempt" -le "$max_attempts" ]; then
      sleep "$delay"
    fi
  done

  echo "WARNING: Push failed after $max_attempts attempts." >&2
  return 1
}

# ── Logging ────────────────────────────────────────────────────────────────────
brain_log() {
  local level="$1"
  shift
  if [ "${BRAIN_QUIET:-false}" != "true" ]; then
    echo "[claude-brain] $level: $*" >&2
  fi
}

log_info() { brain_log "INFO" "$@"; }
log_warn() { brain_log "WARN" "$@"; }
log_error() { brain_log "ERROR" "$@"; }

append_merge_log() {
  local action="$1" summary="$2"
  local log_file="${BRAIN_REPO}/meta/merge-log.json"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local machine_id
  machine_id=$(get_machine_id)
  local machine_name
  machine_name=$(get_machine_name)

  if [ ! -f "$log_file" ]; then
    echo '{"entries":[]}' > "$log_file"
  fi

  if $_has_jq; then
    local tmp
    tmp=$(mktemp)
    jq --arg ts "$timestamp" \
       --arg mid "$machine_id" \
       --arg mn "$machine_name" \
       --arg act "$action" \
       --arg sum "$summary" \
       '.entries = [{"timestamp":$ts,"machine_id":$mid,"machine_name":$mn,"action":$act,"summary":$sum}] + .entries | .entries = .entries[:200]' \
       "$log_file" > "$tmp" && mv "$tmp" "$log_file"
  elif $_has_python3; then
    python3 -c "
import json
with open('${log_file}') as f:
    data = json.load(f)
entry = {'timestamp':'${timestamp}','machine_id':'${machine_id}','machine_name':'${machine_name}','action':'${action}','summary':$(printf '%s' "$summary" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}
data['entries'] = [entry] + data.get('entries', [])
data['entries'] = data['entries'][:200]
with open('${log_file}', 'w') as f:
    json.dump(data, f, indent=2)
"
  fi
}

# ── Timestamp ──────────────────────────────────────────────────────────────────
now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ── Dependency Check ───────────────────────────────────────────────────────────
check_dependencies() {
  local missing=()

  if ! command -v git &>/dev/null; then
    missing+=("git")
  fi

  if ! $_has_jq && ! $_has_python3; then
    missing+=("jq or python3")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Missing dependencies: ${missing[*]}" >&2
    echo "Install them before using claude-brain." >&2
    return 1
  fi
}

# ── Path Encoding/Decoding ─────────────────────────────────────────────────────
# Claude Code encodes project paths: /home/user/project → -home-user-project
decode_project_path() {
  local encoded="$1"
  echo "$encoded" | sed 's/^-/\//' | sed 's/-/\//g'
}

encode_project_path() {
  local path="$1"
  echo "$path" | sed 's/\//-/g'
}

# Extract a human-friendly project name from encoded path
project_name_from_encoded() {
  local encoded="$1"
  # Take the last segment of the decoded path
  local decoded
  decoded=$(decode_project_path "$encoded")
  basename "$decoded"
}
