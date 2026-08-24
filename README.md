# claude-code-bring-your-model

Run Claude Code -- the real TUI, no cut corners -- on top of someone else's
model, paid for with a subscription or your own API key, not necessarily an
Anthropic model. Three ready-made paths:

- **Codex/GPT via a ChatGPT Plus/Pro subscription** -- through a local
  proxy (`claude-as codex`). The same proxy also does Kimi, Grok, Cursor
  Agent, OpenCode Go (see "Other providers").
- **Any model in the [OpenRouter](https://openrouter.ai/models) catalog by
  your own API key** -- billed from your OpenRouter balance, OpenRouter's
  own official Anthropic-compatible endpoint, no proxy needed
  (`claude-as openrouter`).
- **OpenAI models directly, by your own API key** (not a ChatGPT
  subscription) -- through a local protocol translator, `claude-adapter`
  (`claude-as openai`).

Plus multiple Claude Code accounts on one machine without login conflicts.
macOS/Linux, zsh only.

The mechanism, in short:

- Claude Code can talk to any URL that speaks its protocol, not just
  `api.anthropic.com` (`ANTHROPIC_BASE_URL`). That's how Bedrock, Vertex,
  etc. work -- but those still serve Claude models.
- [`claude-code-proxy`](https://github.com/raine/claude-code-proxy) runs
  such a server locally and signs in to ChatGPT itself (the same OAuth flow
  the official Codex CLI uses), translating requests from Claude Code into
  Codex calls and back.
- `CLAUDE_CONFIG_DIR` isolates Claude Code's login, so one machine can hold
  several independent accounts without anything leaking between them.

## Quick install

```sh
curl -fsSL https://raw.githubusercontent.com/draiqw/claude-code-bring-your-model/main/install.sh | bash
```

The script is idempotent -- safe to rerun. What it does:

1. Installs `claude-code-proxy` via Homebrew (if Homebrew is missing, it
   tells you what to install by hand).
2. Installs `claude-adapter` via npm (needed for the `openai` profile; if
   npm is missing, it says so and continues -- everything else still works).
3. Drops `sync-profile.sh` and `openai-proxy-serve.cjs` into
   `~/.claude-accounts/`.
4. Appends the `claude-as` function to `~/.zshrc`, between markers
   `# >>> use-codex-in-claude-code >>>` / `# <<< ... <<<` (reinstalling
   replaces the block instead of duplicating it).
5. Creates the `codex`, `openrouter`, and `openai` profiles and syncs each
   one with your main `~/.claude` right away (see "Shared history" below)
   -- **skills, plugins, subagents, commands, and MCP servers become the
   same ones you already have**, nothing to reinstall by hand.
6. Stages a real `.env` file for each API-key profile from its
   `.env.example` template, but only if one doesn't already exist yet --
   rerunning `install.sh` never overwrites a key you've already pasted in.
   For `openai`, the local adapter secret (`OPENAI_ADAPTER_TOKEN`) is
   generated automatically; you only paste the OpenAI key.

Next steps, by hand:

```sh
source ~/.zshrc                    # or open a new terminal window
```

Codex -- needs a browser, sign in with ChatGPT Plus/Pro (not an API key):

```sh
claude-code-proxy codex auth login
claude-as codex                    # regular Claude Code, answers via Codex
```

`claude-as codex` starts `claude-code-proxy` itself before launching (waits
up to 15 seconds) and stops it on exit from Claude Code -- but only if it's
the one that started it. An already-running proxy (say, in another window)
is left alone.

OpenRouter -- needs an API key from [openrouter.ai/keys](https://openrouter.ai/keys):

```sh
# open ~/.claude-accounts/openrouter.env in an editor, paste your key
claude-as openrouter               # regular Claude Code, model from OpenRouter
```

OpenAI -- needs your own API key, not a ChatGPT login:

```sh
# open ~/.claude-accounts/openai.env in an editor, paste your key
# (the local adapter secret is already filled in by install.sh)
claude-as openai                   # regular Claude Code, answers via GPT-5.x
```

### Manual install, without install.sh

```sh
git clone git@github.com:draiqw/claude-code-bring-your-model.git
cd claude-code-bring-your-model
./install.sh
```

or entirely by hand: copy `sync-profile.sh` and `openai-proxy-serve.cjs`
into `~/.claude-accounts/`, the contents of `claude-as.zsh` to the end of
`~/.zshrc`, `brew install raine/claude-code-proxy/claude-code-proxy`, `npm
install -g claude-adapter`, and copy the `.env.example` files into
`~/.claude-accounts/<name>.env` with your own keys.

## Multiple Claude Code accounts (no third-party model)

The same `claude-as` also just switches between claude.ai accounts, no
proxy or third-party model involved:

```sh
claude-as work auth login   # first time -- regular claude.ai login
claude-as work               # from then on -- a normal session as that account
claude-as                    # list what's set up
```

Each account lives in its own `~/.claude-accounts/<name>` -- a fully
separate `CLAUDE_CONFIG_DIR`: its own login, its own MCP servers, its own
history, its own memory, nothing shared by default.

## Shared chat history, memory, and CLAUDE.md across accounts

For accounts (`goga`, `codex`, `openrouter`, `openai`, ...) to see the same
chats, auto-memory, and settings as your main `~/.claude`, sync the profile:

```sh
~/.claude-accounts/sync-profile.sh <name>
```

Symlinked to `~/.claude/...`:

| Shared | Stays separate |
|---|---|
| `projects/` -- chats and auto-memory | `.claude.json` -- login, project trust |
| `history.jsonl` | `sessions/` |
| `CLAUDE.md` | `security/` |
| `settings.json`, `hooks.json`, `statusline-command.sh` | `cache/` |
| `agents/`, `commands/`, `skills/`, `plugins/` | |

MCP servers aren't symlinked (they live inside `.claude.json`, which stays
separate per account) -- the script copies the `mcpServers` key from your
main `~/.claude.json`. So: **add a new MCP server to your main profile, and
rerun `sync-profile.sh <name>` for every account you want it to show up
in**.

Check the login survived the sync:

```sh
CLAUDE_CONFIG_DIR=~/.claude-accounts/<name> claude auth status
```

## Choosing a Codex model

```sh
claude-code-proxy models
```

lists the catalog (`gpt-5.x`, including `-codex`/`-fast` variants, plus
Kimi, Grok, Cursor Agent if you also sign in to those with `claude-code-proxy
kimi auth login` etc). By default `claude-as codex` uses `gpt-5.6-luna[1m]`
-- change `--model 'gpt-5.6-luna[1m]'` in `claude-as.zsh` and reinstall, or
just add your own `--model` at the end of the command; the last flag wins
over the default:

```sh
claude-as codex --model 'gpt-5.3-codex[1m]'
```

## Other providers (Kimi, Grok, Cursor Agent, OpenCode Go)

`claude-code-proxy` is a general protocol translator -- Codex isn't the
only option. Same idea: your own subscription, your own `claude-code-proxy
<provider> auth login`, your own model names.

| Provider | Account | Login |
|---|---|---|
| Codex | ChatGPT Plus/Pro | `claude-code-proxy codex auth login` |
| Kimi | kimi.com (Kimi Code) | `claude-code-proxy kimi auth login` |
| Grok | grok.com | `claude-code-proxy grok auth login` |
| Cursor Agent | Cursor account | `claude-code-proxy cursor auth login` |
| OpenCode Go | OpenCode Go subscription | its own setup, see `claude-code-proxy help` |

There's no ready-made `claude-as <provider>` for these in this repo --
only `codex`. Easiest path: copy the `codex` block in `claude-as.zsh` (in
your own `~/.zshrc`), rename it to `kimi`/`grok`/`cursor`, and swap
`ANTHROPIC_MODEL`/`--model` for that provider's model -- the rest (start
the proxy, wait for it, stop it on exit) doesn't need to change. Current
model list: `claude-code-proxy models`.

## OpenRouter: any model, by your own API key

Unlike Codex/Kimi/Grok/Cursor (subscription, browser sign-in, a local proxy
translator), OpenRouter uses your own API key and bills your OpenRouter
balance per token, no subscription involved. And the Anthropic-compatible
endpoint is official, from OpenRouter itself (verified: `POST
https://openrouter.ai/api/v1/messages` without a key returns a real
Anthropic-shaped `authentication_error`, not a 404) -- no proxy needed,
`ANTHROPIC_BASE_URL` points straight at OpenRouter.

Set up a key:

1. Sign up and create a key at
   [openrouter.ai/keys](https://openrouter.ai/keys) (format `sk-or-v1-...`).
2. Add balance -- without it, paid models return a billing error.
3. Fill in the env file `install.sh` already staged for you (or create it
   from the template if you're doing this by hand):

   ```sh
   cp openrouter.env.example ~/.claude-accounts/openrouter.env
   chmod 600 ~/.claude-accounts/openrouter.env
   # then edit the file and paste your key
   ```

   The file lives outside the repo, in `~/.claude-accounts/`, is never
   committed to git, and is chmod 600 -- readable only by you.

Then:

```sh
claude-as openrouter
```

Defaults to `deepseek/deepseek-v4-pro-0813` (verified with a live request).
Change the model with your own `--model` at the end of the command
(overrides the default):

```sh
claude-as openrouter --model 'x-ai/grok-4.6'
claude-as openrouter --model 'z-ai/glm-5.3'
claude-as openrouter --model 'qwen/qwen3.8-max'
claude-as openrouter --model 'google/gemini-3.7-flash'
```

Current catalog (400+ models, changes over time):
[openrouter.ai/models](https://openrouter.ai/models), or
`curl -s https://openrouter.ai/api/v1/models | jq '.data[].id'`.

## OpenAI: your own API key directly, no subscription

Separate from `claude-as codex` (ChatGPT subscription via
`claude-code-proxy`) -- this is for a regular paid OpenAI API key
(`sk-proj-...`, billed from your API project balance, unrelated to a
ChatGPT Plus/Pro subscription). OpenAI has no Anthropic-compatible endpoint
of its own (verified: `POST https://api.openai.com/v1/messages` -> `404`),
so a local protocol translator is needed --
[`claude-adapter`](https://github.com/shantoislamdev/claude-adapter) (MIT),
run as a library by our own `openai-proxy-serve.cjs`, skipping its
interactive setup wizard and never touching `~/.claude/settings.json`.

Set up a key:

1. Create a key at
   [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
   and fund the project balance -- without it you'll get `429`/a billing
   error.
2. Fill in the env file `install.sh` already staged for you (the local
   adapter token is pre-filled; you only paste the API key). By hand:

   ```sh
   TOKEN=$(node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")
   cp openai.env.example ~/.claude-accounts/openai.env
   sed -i '' "s/replace-with-a-random-local-secret/$TOKEN/" ~/.claude-accounts/openai.env
   chmod 600 ~/.claude-accounts/openai.env
   # then edit the file and paste your OPENAI_API_KEY
   ```

   Same principle as `openrouter.env`: outside the repo, chmod 600, never
   committed. `OPENAI_ADAPTER_TOKEN` isn't an OpenAI credential -- it's the
   local secret `claude-as` uses to authenticate to its own local server.

Then:

```sh
claude-as openai
```

Defaults to `gpt-5.4-mini` (verified with a live request). Change it with
your own `--model`:

```sh
claude-as openai --model 'gpt-5.4'
claude-as openai --model 'gpt-5.4-nano'
claude-as openai --model 'gpt-4o-mini'
```

**A known protocol mismatch, already patched in `openai-proxy-serve.cjs`:**
`claude-adapter` 2.2.1 always sends `max_tokens` to OpenAI Chat Completions.
`gpt-5.x` models reject that with `400 Unsupported parameter: 'max_tokens'
... Use 'max_completion_tokens' instead` -- verified manually.
`max_completion_tokens` is accepted by older models too (`gpt-4o-mini`
etc., also verified) -- our launcher patches that field in outgoing
requests before the `openai` SDK sends them. If a future `claude-adapter`
release fixes this upstream, the patch just becomes redundant, not
harmful (it only rewrites the field if it's present).

## Things to know

About Codex/Kimi/Grok/Cursor (`claude-code-proxy`):

- **This isn't an official Anthropic or OpenAI feature.** `claude-code-proxy`
  is a third-party open-source project emulating the Anthropic protocol on
  top of someone else's model. All your Claude Code session traffic goes
  through a local process you're trusting with your code.
- **Terms of service.** OpenAI allows a personal OAuth sign-in to a
  third-party client under your own account (what this proxy does), but
  forbids sharing a single subscription as an API for many users
  ("sub2api") -- that gets caught by fraud detection. This is only about
  one person using their own subscription personally.
- **Your account can get flagged** -- the proxy's own README admits it:
  `Unofficial clients may carry account risk`. Treat this as an
  experiment, not a production setup.
- The proxy listens on `127.0.0.1:18765` with no request auth. Fine by
  default (loopback only), but don't expose the port without a firewall or
  extra auth in front of it.

About OpenRouter -- no proxy or OAuth risk (an official endpoint from
OpenRouter itself, a regular paid API), but:

- Billed per token from your balance, not a subscription -- pricing
  depends on the model, and expensive models can add up. Check the
  model's pricing page on openrouter.ai before running anything heavy.
- The `sk-or-...` key gives access to your whole account balance -- lives
  in `~/.claude-accounts/openrouter.env` at `600`, never commit it
  anywhere.

About OpenAI -- also an official API, but:

- `claude-adapter` is a third-party open-source protocol translator (not
  Anthropic, not OpenAI), even though it only runs locally with no OAuth.
  Session traffic passes through it the same way it does through
  `claude-code-proxy`.
- `OPENAI_ADAPTER_TOKEN` in `~/.claude-accounts/openai.env` isn't an OpenAI
  key -- it's a local secret between `claude-as` and the local server;
  still `600` and outside git, same as `OPENAI_API_KEY`.
- Billed from your OpenAI API project balance, separate from a ChatGPT
  subscription.

General:

- `--model` on the Claude Code CLI overrides `"model"` from the synced
  `settings.json` -- otherwise your shared `settings.json` (which has a
  regular Claude model in it) would pull the `codex`/`openrouter`/`openai`
  profile onto that model instead.

## Troubleshooting

- `claude-code-proxy didn't come up within 15s` -- check
  `/tmp/claude-code-proxy.log`.
- `Connection refused` from Claude Code (`codex` profile) -- the proxy
  isn't running and didn't start itself; check
  `curl http://127.0.0.1:18765/v1/models` by hand.
- `claude-as openrouter` says "missing key" -- `~/.claude-accounts/openrouter.env`
  doesn't exist, or `OPENROUTER_API_KEY` inside it is empty.
- **`claude-as openrouter` hangs for minutes with no response** -- verified
  in practice: with a bad key, Claude Code can silently hang for 5+ minutes
  instead of failing fast (OpenRouter itself answers the same request with
  a `401` in under a second -- it's not the network or OpenRouter, it's
  internal retries on the auth error). Don't wait it out -- check the key
  directly first, it's fast:

  ```sh
  curl -s -X POST https://openrouter.ai/api/v1/messages \
    -H 'content-type: application/json' \
    -H 'anthropic-version: 2023-06-01' \
    -H "x-api-key: $(grep -o 'sk-or-.*' ~/.claude-accounts/openrouter.env)" \
    -d '{"model":"deepseek/deepseek-v4-pro-0813","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}'
  ```

  If that answers quickly with no error, the key isn't the problem --
  rerun `claude-as openrouter` or give it more time. If curl returns `401`
  right away, fix the key in `~/.claude-accounts/openrouter.env` instead of
  waiting on a hung `claude-as`.
- `401`/`authentication_error` from OpenRouter -- the key is wrong,
  revoked, or has a stray space/newline pasted in; check
  `cat ~/.claude-accounts/openrouter.env`.
- Billing error/`402`/`insufficient credits` from OpenRouter -- add
  balance at openrouter.ai.
- Model not found -- check the exact `id` at
  [openrouter.ai/models](https://openrouter.ai/models), or via
  `curl -s https://openrouter.ai/api/v1/models | jq '.data[].id'`; the
  catalog changes, old slugs disappear.
- An account's login broke after `sync-profile.sh` -- shouldn't happen
  (`.claude.json` is never overwritten, only the `mcpServers` key inside it
  is patched, with a `.claude.json.bak` backup) -- but if it does, restore
  from that backup.
- `claude-as openai` says "missing key or openai-proxy-serve.cjs" --
  `~/.claude-accounts/openai.env` doesn't exist, `OPENAI_API_KEY`/
  `OPENAI_ADAPTER_TOKEN` inside it is empty, or `openai-proxy-serve.cjs`
  wasn't copied (rerun `install.sh`, or copy the file by hand).
- `openai-adapter didn't come up within 15s` -- check
  `/tmp/openai-adapter.log`; the usual cause is `claude-adapter` not
  installed (`npm install -g claude-adapter`) or `node` not found.
- `400 Unsupported parameter: 'max_tokens'` from OpenAI -- means the raw
  `claude-adapter` CLI/wizard is running instead of our
  `openai-proxy-serve.cjs`; either run it through `claude-as openai`, or
  apply the same patch from `openai-proxy-serve.cjs` by hand.
- `401` from OpenAI -- `OPENAI_API_KEY` is wrong/revoked, check
  [platform.openai.com/api-keys](https://platform.openai.com/api-keys).
- `429`/billing error from OpenAI -- fund the project balance at
  platform.openai.com (API limits are separate from a ChatGPT subscription).
- **`400 Invalid 'tools': array too long. Expected an array with maximum
  length 128, but got an array with length N instead`** from OpenAI --
  verified in practice: a synced (`sync-profile.sh`) profile can easily
  pull in 128+ tools from MCP servers and skills combined, and Chat
  Completions has a hard ceiling of 128, no exceptions. `codex`/`openrouter`
  don't hit this (different protocol/provider) -- only the raw OpenAI API
  does. `claude-as.zsh` doesn't auto-trim the tool set for `openai` yet;
  workarounds:
  - `claude-as openai --strict-mcp-config --mcp-config '{"mcpServers":{}}'`
    -- no MCP tools at all, only the built-in ones (a quick check that the
    limit is the actual problem, not something else in the chain);
  - disable some MCP servers just for the `openai` profile -- edit
    `mcpServers` in `~/.claude-accounts/openai/.claude.json` directly (it's
    a real file, not a symlink, so edits won't leak into your main
    profile) and don't rerun `sync-profile.sh openai` afterward, or it'll
    overwrite your edit.
