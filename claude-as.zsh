# >>> use-codex-in-claude-code >>>
# Claude Code: multiple accounts through isolated CLAUDE_CONFIG_DIR, plus
# "codex" -- ChatGPT subscription as the model, via claude-code-proxy;
# "openrouter" -- any model by API key, via OpenRouter;
# "openai" -- OpenAI models by your own API key (not a subscription).
# https://github.com/draiqw/claude-code-bring-your-model
claude-as() {
  local acct="$1"
  if [ -z "$acct" ]; then
    echo "usage: claude-as <account> [claude args...]"
    echo "accounts:"
    ls -1 "$HOME/.claude-accounts" 2>/dev/null | grep -v '\.sh$\|\.env$\|\.cjs$\|\.example$' | sed 's/^/  /'
    echo "  codex        (ChatGPT subscription, via claude-code-proxy)"
    echo "  openrouter   (OpenRouter API key, any model in its catalog)"
    echo "  openai       (plain OpenAI API key, gpt-5.x models)"
    echo "  default      (your main ~/.claude)"
    return 1
  fi
  shift
  if [ "$acct" = "default" ]; then
    command claude "$@"
  elif [ "$acct" = "openai" ]; then
    # A plain OpenAI API key (sk-proj-...), not a ChatGPT subscription --
    # that case is the "codex" branch below. A local server (claude-adapter,
    # https://github.com/shantoislamdev/claude-adapter) is started for the
    # session and stopped on exit, same as claude-code-proxy for codex.
    local keyfile="$HOME/.claude-accounts/openai.env"
    local serve_script="$HOME/.claude-accounts/openai-proxy-serve.cjs"
    if [ ! -f "$keyfile" ] || [ ! -f "$serve_script" ]; then
      echo "missing key or $serve_script: see README, \"OpenAI (your own API key)\""
      return 1
    fi
    local OPENAI_API_KEY="" OPENAI_ADAPTER_TOKEN=""
    source "$keyfile"
    if [ -z "$OPENAI_API_KEY" ] || [ -z "$OPENAI_ADAPTER_TOKEN" ]; then
      echo "$keyfile exists, but OPENAI_API_KEY or OPENAI_ADAPTER_TOKEN is empty"
      return 1
    fi
    local proxy_log="/tmp/openai-adapter.log"
    local started_proxy=0
    local proxy_pid=""
    if ! curl -s -o /dev/null -m 2 -H "x-api-key: $OPENAI_ADAPTER_TOKEN" "http://127.0.0.1:18766/v1/models" 2>/dev/null; then
      OPENAI_API_KEY="$OPENAI_API_KEY" OPENAI_ADAPTER_TOKEN="$OPENAI_ADAPTER_TOKEN" \
        node "$serve_script" >"$proxy_log" 2>&1 &
      proxy_pid=$!
      disown
      started_proxy=1
      local i=0
      while ! grep -q "listening" "$proxy_log" 2>/dev/null; do
        i=$((i + 1))
        if [ "$i" -ge 30 ] || ! kill -0 "$proxy_pid" 2>/dev/null; then
          echo "openai-adapter didn't come up within 15s, check $proxy_log"
          kill "$proxy_pid" 2>/dev/null
          return 1
        fi
        sleep 0.5
      done
    fi

    CLAUDE_CONFIG_DIR="$HOME/.claude-accounts/openai" \
    ANTHROPIC_BASE_URL="http://127.0.0.1:18766" \
    ANTHROPIC_AUTH_TOKEN="$OPENAI_ADAPTER_TOKEN" \
      command claude --model 'gpt-5.4-mini' "$@"

    if [ "$started_proxy" = 1 ] && [ -n "$proxy_pid" ]; then
      kill "$proxy_pid" 2>/dev/null
    fi
  elif [ "$acct" = "openrouter" ]; then
    # Any model in the OpenRouter catalog, by your own API key -- billed
    # from your OpenRouter balance, not a subscription. OpenRouter's own
    # official Anthropic-compatible endpoint, no proxy needed.
    local keyfile="$HOME/.claude-accounts/openrouter.env"
    if [ ! -f "$keyfile" ]; then
      echo "missing key: create $keyfile with a line OPENROUTER_API_KEY=sk-or-..."
      echo "see README, OpenRouter section"
      return 1
    fi
    local OPENROUTER_API_KEY=""
    source "$keyfile"
    if [ -z "$OPENROUTER_API_KEY" ]; then
      echo "$keyfile exists, but OPENROUTER_API_KEY is empty"
      return 1
    fi
    CLAUDE_CONFIG_DIR="$HOME/.claude-accounts/openrouter" \
    ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
    ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY" \
    ANTHROPIC_API_KEY="" \
      command claude --model 'deepseek/deepseek-v4-pro-0813' "$@"
  elif [ "$acct" = "codex" ]; then
    # ChatGPT subscription (Codex) as the model, via a local claude-code-proxy.
    # The proxy is started for the session and stopped on exit from claude,
    # but only if we're the one who started it (an already-running proxy
    # from elsewhere is left alone).
    local proxy_log="/tmp/claude-code-proxy.log"
    local started_proxy=0
    local proxy_pid=""
    if ! curl -s -o /dev/null -m 2 "http://127.0.0.1:18765/v1/models"; then
      command claude-code-proxy serve --no-monitor >"$proxy_log" 2>&1 &
      proxy_pid=$!
      disown
      started_proxy=1
      local i=0
      while ! curl -s -o /dev/null -m 1 "http://127.0.0.1:18765/v1/models"; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
          echo "claude-code-proxy didn't come up within 15s, check $proxy_log"
          kill "$proxy_pid" 2>/dev/null
          return 1
        fi
        sleep 0.5
      done
    fi

    CLAUDE_CONFIG_DIR="$HOME/.claude-accounts/codex" \
    ANTHROPIC_BASE_URL="http://127.0.0.1:18765" \
    ANTHROPIC_AUTH_TOKEN="unused" \
    ANTHROPIC_SMALL_FAST_MODEL="gpt-5.6-luna[1m]" \
    CLAUDE_CODE_AUTO_COMPACT_WINDOW="900000" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1 \
      command claude --model 'gpt-5.6-luna[1m]' "$@"

    if [ "$started_proxy" = 1 ] && [ -n "$proxy_pid" ]; then
      kill "$proxy_pid" 2>/dev/null
    fi
  else
    CLAUDE_CONFIG_DIR="$HOME/.claude-accounts/$acct" command claude "$@"
  fi
}
# <<< use-codex-in-claude-code <<<
