#!/usr/bin/env node
// Local Anthropic-compatible proxy on top of a plain OpenAI API key (not a
// ChatGPT subscription -- that case is already covered by `claude-as codex`).
// Uses the claude-adapter engine (https://github.com/shantoislamdev/claude-adapter)
// directly as a library, without its interactive setup wizard and without
// touching ~/.claude/settings.json -- same principle as every other profile
// in this repo: everything through explicit env vars, scoped to one session.
//
// Required env vars:
//   OPENAI_API_KEY        -- a key like sk-proj-... or sk-...
//   OPENAI_ADAPTER_TOKEN   -- the token claude-as uses to authenticate
//                             itself to the local proxy (not an OpenAI key)
// Optional:
//   OPENAI_ADAPTER_PORT     -- port (default 18766)
//   OPENAI_ADAPTER_BASE_URL -- upstream (default api.openai.com/v1)

const path = require("node:path");

function globalNodeModules() {
  // Standard npm layout: <node>/bin/node -> <node>/lib/node_modules --
  // resolved without shelling out, so no arbitrary command execution.
  return path.resolve(process.execPath, "../../lib/node_modules");
}

function resolveAdapterEntry() {
  try {
    return require.resolve("claude-adapter");
  } catch {
    return require.resolve("claude-adapter", { paths: [globalNodeModules()] });
  }
}

const adapterEntry = resolveAdapterEntry();

// claude-adapter 2.2.1 always sends `max_tokens` in Chat Completions
// requests. Newer OpenAI models (gpt-5.x) reject that with a 400:
// "Unsupported parameter: 'max_tokens' ... Use 'max_completion_tokens'
// instead" (verified manually). `max_completion_tokens` is accepted by
// older models too (verified on gpt-4o-mini). The `openai` SDK on Node
// doesn't go through globalThis.fetch -- it uses its node-fetch dependency
// (`_shims/node-runtime.js`), so we patch that module's `.default` export,
// and we must do it BEFORE require('claude-adapter') pulls in 'openai' and
// captures that reference.
const openaiEntry = require.resolve("openai", { paths: [path.dirname(adapterEntry)] });
const nodeFetchEntry = require.resolve("node-fetch", { paths: [path.dirname(openaiEntry)] });
const nodeFetch = require(nodeFetchEntry);
const realFetch = nodeFetch.default;
const patchedFetch = (url, init) => {
  if (init && typeof init.body === "string" && String(url).includes("/chat/completions")) {
    try {
      const body = JSON.parse(init.body);
      if ("max_tokens" in body && !("max_completion_tokens" in body)) {
        body.max_completion_tokens = body.max_tokens;
        delete body.max_tokens;
        init = { ...init, body: JSON.stringify(body) };
      }
    } catch {
      // not JSON, or a different request shape -- pass through untouched
    }
  }
  return realFetch(url, init);
};
// require() caches modules by resolved path -- this mutation is visible
// inside node-runtime.js too, when it require("node-fetch")s the same path.
nodeFetch.default = patchedFetch;

const { createServer } = require(adapterEntry);

const apiKey = process.env.OPENAI_API_KEY;
const proxyAuthToken = process.env.OPENAI_ADAPTER_TOKEN;
if (!apiKey || !proxyAuthToken) {
  console.error("OPENAI_API_KEY and OPENAI_ADAPTER_TOKEN must be set in the environment");
  process.exit(1);
}

const port = Number(process.env.OPENAI_ADAPTER_PORT || 18766);
const baseUrl = process.env.OPENAI_ADAPTER_BASE_URL || "https://api.openai.com/v1";

// config.models plays no part in request routing (claude-as always passes
// a real model id via --model, and the adapter forwards it as-is) --
// filled in only so the config object is valid; the values are unused.
const server = createServer({
  baseUrl,
  apiKey,
  proxyAuthToken,
  models: { opus: "gpt-5.4", sonnet: "gpt-5.4-mini", haiku: "gpt-5.4-nano" },
});

server.start(port).then((url) => {
  console.log(`claude-adapter (openai) listening on ${url}`);
});

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, async () => {
    await server.stop();
    process.exit(0);
  });
}
