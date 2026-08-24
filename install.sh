#!/usr/bin/env bash
# One-command install:
#
#   curl -fsSL https://raw.githubusercontent.com/draiqw/claude-code-bring-your-model/main/install.sh | bash
#
# Installs claude-code-proxy (brew) and claude-adapter (npm), drops
# sync-profile.sh and openai-proxy-serve.cjs into ~/.claude-accounts,
# appends the claude-as function to ~/.zshrc (idempotently), creates and
# syncs the codex/openrouter/openai profiles, and stages a .env for each
# API-key-based profile from its .env.example template. Logging into
# ChatGPT and pasting your API keys are separate manual steps -- this
# script can't do either (one needs a browser, the other needs your key).

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/draiqw/claude-code-bring-your-model/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
ACCOUNTS_DIR="$HOME/.claude-accounts"
ZSHRC="$HOME/.zshrc"

fetch() {
  # $1 = filename. Uses the local copy next to this script if present
  # (running from a git clone), otherwise pulls it from GitHub (running
  # via curl | bash).
  local name="$1"
  if [ -f "$SCRIPT_DIR/$name" ]; then
    cat "$SCRIPT_DIR/$name"
  else
    curl -fsSL "$REPO_RAW/$name"
  fi
}

random_token() {
  if command -v node >/dev/null 2>&1; then
    node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
  elif command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    date +%s%N | shasum | cut -c1-48
  fi
}

# Stages a real, private (chmod 600) env file for a profile from its
# .env.example template -- but only if that file doesn't already exist, so
# rerunning install.sh never clobbers a key you've already pasted in.
# $2 (optional): sed expression to pre-fill a placeholder, e.g. a
# freshly generated local secret.
stage_env() {
  # One var per `local` line -- macOS ships bash 3.2, which mishandles
  # `local a="$1" b="${2:-}"` (multiple positional-param assignments on one
  # `local` statement) under `set -u`, raising a spurious unbound-variable
  # error even though $1 is bound.
  local name="$1"
  local fill="${2:-}"
  local dst="$ACCOUNTS_DIR/$name.env"
  fetch "$name.env.example" > "$ACCOUNTS_DIR/$name.env.example"
  if [ -f "$dst" ]; then
    echo "  $name.env already exists, left untouched"
    return
  fi
  if [ -n "$fill" ]; then
    sed "$fill" "$ACCOUNTS_DIR/$name.env.example" > "$dst"
  else
    cp "$ACCOUNTS_DIR/$name.env.example" "$dst"
  fi
  chmod 600 "$dst"
  echo "  $name.env created from the template -- edit it and paste your key"
}

echo "== 1/5: claude-code-proxy (for codex/kimi/grok/cursor) =="
if command -v claude-code-proxy >/dev/null 2>&1; then
  echo "  already installed: $(claude-code-proxy --version 2>&1 | head -1)"
elif command -v brew >/dev/null 2>&1; then
  brew install raine/claude-code-proxy/claude-code-proxy
else
  echo "  Homebrew not found. Install manually:"
  echo "  https://github.com/raine/claude-code-proxy#installation"
  echo "  then rerun this script."
  exit 1
fi

echo "== 2/5: claude-adapter (for openai) =="
if command -v npm >/dev/null 2>&1; then
  npm install -g claude-adapter
else
  echo "  npm not found. The openai profile (your own OpenAI key) won't work;"
  echo "  codex and openrouter don't need npm. Install Node.js and rerun"
  echo "  this script if you want the openai profile."
fi

echo "== 3/5: ~/.claude-accounts =="
mkdir -p "$ACCOUNTS_DIR"
fetch "sync-profile.sh" > "$ACCOUNTS_DIR/sync-profile.sh"
chmod +x "$ACCOUNTS_DIR/sync-profile.sh"
fetch "openai-proxy-serve.cjs" > "$ACCOUNTS_DIR/openai-proxy-serve.cjs"
echo "  sync-profile.sh, openai-proxy-serve.cjs in place"

echo "== 4/5: claude-as function in ~/.zshrc =="
BLOCK="$(fetch "claude-as.zsh")"
touch "$ZSHRC"
if grep -q "# >>> use-codex-in-claude-code >>>" "$ZSHRC"; then
  # Reinstall: replace the old block between the markers with the fresh one
  TMP="$(mktemp)"
  awk '
    /# >>> use-codex-in-claude-code >>>/ { skip = 1 }
    !skip { print }
    /# <<< use-codex-in-claude-code <<</ { skip = 0 }
  ' "$ZSHRC" > "$TMP"
  cat "$TMP" > "$ZSHRC"
  rm -f "$TMP"
  echo "" >> "$ZSHRC"
  echo "$BLOCK" >> "$ZSHRC"
  echo "  block updated"
else
  {
    echo ""
    echo "$BLOCK"
  } >> "$ZSHRC"
  echo "  block added"
fi

echo "== 5/5: codex, openrouter, openai profiles =="
mkdir -p "$ACCOUNTS_DIR/codex" "$ACCOUNTS_DIR/openrouter" "$ACCOUNTS_DIR/openai"
"$ACCOUNTS_DIR/sync-profile.sh" codex
"$ACCOUNTS_DIR/sync-profile.sh" openrouter
"$ACCOUNTS_DIR/sync-profile.sh" openai
echo
stage_env "openrouter"
stage_env "openai" "s/replace-with-a-random-local-secret/$(random_token)/"

cat <<'EOF'

Done. Next steps:

  source ~/.zshrc                    # or open a new terminal window

Codex -- needs a browser, sign in with ChatGPT Plus/Pro:
  claude-code-proxy codex auth login
  claude-as codex

OpenRouter -- open ~/.claude-accounts/openrouter.env in an editor, paste
your key in place of the placeholder, then:
  claude-as openrouter

OpenAI -- open ~/.claude-accounts/openai.env in an editor, paste your key
(the local adapter secret is already filled in), then:
  claude-as openai

claude-as codex/openai each start and stop their own local server for the
session. Details, model lists, and troubleshooting are in README.md.
EOF
