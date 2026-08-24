#!/usr/bin/env bash
# Syncs an extra Claude Code account with the main ~/.claude profile.
#
#   ~/.claude-accounts/sync-profile.sh <account>
#
# Symlinked to ~/.claude (shared): chats and auto-memory (projects/),
# prompt history, CLAUDE.md, settings.json, hooks.json, subagents, commands,
# skills, and plugins.
#
# Kept separate per account: .claude.json (login, project trust),
# sessions/, security/, cache/ -- these can't be shared, the login lives
# there. MCP servers live inside .claude.json, so they aren't symlinked --
# just the mcpServers key gets copied (rerun this script if you add a new
# server to your main profile).

set -euo pipefail

MAIN="$HOME/.claude"
ACCT="${1:-}"

if [ -z "$ACCT" ]; then
  echo "usage: $0 <account>"
  echo "accounts:"
  ls -1 "$HOME/.claude-accounts" 2>/dev/null | grep -v '\.sh$' | sed 's/^/  /'
  exit 1
fi

DIR="$HOME/.claude-accounts/$ACCT"
[ -d "$DIR" ] || { echo "no such account: $DIR"; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$DIR/pre-sync-backup-$STAMP"

link() {
  local name="$1" src="$MAIN/$1" dst="$DIR/$1"
  [ -e "$src" ] || { echo "  skip $name (not in main profile)"; return; }
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$BAK"
    mv "$dst" "$BAK/"
    echo "  $name -- previous copy moved to $(basename "$BAK")/"
  fi
  ln -s "$src" "$dst"
  echo "  $name -> ~/.claude/$name"
}

echo "Syncing $ACCT with ~/.claude"
for item in CLAUDE.md settings.json hooks.json statusline-command.sh \
            agents commands skills plugins projects history.jsonl; do
  link "$item"
done

# MCP servers: copy the mcpServers key from the main ~/.claude.json,
# without touching the account profile's own login/project trust.
python3 - "$HOME/.claude.json" "$DIR/.claude.json" <<'PY'
import json, sys, shutil, os

main_path, acct_path = sys.argv[1], sys.argv[2]
with open(main_path) as f:
    main = json.load(f)
servers = main.get("mcpServers", {})
if not servers:
    print("  MCP: no servers in the main profile")
    sys.exit(0)

acct = {}
if os.path.exists(acct_path):
    shutil.copy2(acct_path, acct_path + ".bak")
    with open(acct_path) as f:
        acct = json.load(f)

acct["mcpServers"] = servers
tmp = acct_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(acct, f, indent=2)
os.replace(tmp, acct_path)
print("  MCP: " + ", ".join(sorted(servers)))
PY

echo "Done."
