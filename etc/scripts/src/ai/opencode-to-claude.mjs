#!/usr/bin/env node
// opencode-to-claude.mjs
//
// Generate a Claude Code config (CLAUDE.md, agents/, commands/, skills/,
// settings.json, .mcp.json, hooks/) from an OpenCode config (AGENTS.md, agent/,
// command/, skills/, opencode.jsonc, plugins/). OpenCode is the single source of
// truth; this output is regenerated and must never be hand-edited.
//
// Invoked via the opencode-to-claude.sh wrapper. Logs progress to stderr and
// prints a minified JSON summary to stdout. Exits non-zero on any failed transform.

import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// --- logging (stderr only; stdout is reserved for the JSON summary) ---
const RED = "\x1b[0;31m";
const GREEN = "\x1b[0;32m";
const YELLOW = "\x1b[0;33m";
const CYAN = "\x1b[0;36m";
const NC = "\x1b[0m";
const logInfo = (m) => process.stderr.write(`${CYAN}i ${m}${NC}\n`);
const logSuccess = (m) => process.stderr.write(`${GREEN}\u2713 ${m}${NC}\n`);
const logWarning = (m) => process.stderr.write(`${YELLOW}\u26a0 ${m}${NC}\n`);
const logError = (m) => process.stderr.write(`${RED}\u2717 ${m}${NC}\n`);

// --- transform constants ---

// Canonical Claude Code tool set used when inverting an agent's disabled-tools map.
const CLAUDE_TOOL_SET = [
  "Task",
  "Bash",
  "Glob",
  "Grep",
  "Read",
  "Edit",
  "Write",
  "WebFetch",
  "WebSearch",
  "TodoWrite",
  "NotebookEdit",
];

// OpenCode disables tools as a bool map (e.g. `write: false`). Claude lists the
// allowed tools instead, so we invert: start from the full set and remove the
// Claude tools that correspond to each disabled OpenCode key.
const DISABLED_KEY_TO_CLAUDE_TOOLS = {
  write: ["Write"],
  edit: ["Edit", "NotebookEdit"],
  bash: ["Bash"],
  read: ["Read"],
  grep: ["Grep"],
  glob: ["Glob"],
  webfetch: ["WebFetch"],
  task: ["Task"],
  todowrite: ["TodoWrite"],
};

const MODEL_ALIASES = {
  "github-copilot/claude-haiku-4.5": "haiku",
  "github-copilot/claude-sonnet-4.5": "sonnet",
};

// Map an OpenCode model id to a Claude Code alias. Returns null (and warns) for
// anything unrecognized so the field is simply omitted.
function mapModel(model) {
  if (!model) {
    return null;
  }
  if (MODEL_ALIASES[model]) {
    return MODEL_ALIASES[model];
  }
  if (/opus/i.test(model)) {
    return "opus";
  }
  if (/sonnet/i.test(model)) {
    return "sonnet";
  }
  if (/haiku/i.test(model)) {
    return "haiku";
  }
  logWarning(`Unrecognized model '${model}' - omitting model field`);
  return null;
}

// --- frontmatter parsing ---
//
// The OpenCode markdown files use a small, predictable YAML subset: top-level
// `key: value` scalars plus an optional nested `tools:` bool map. We parse that
// subset directly to avoid a YAML dependency.
function parseFrontmatter(text) {
  const lines = text.split("\n");
  if (lines[0].trim() !== "---") {
    return { fields: {}, tools: null, body: text, hasFrontmatter: false };
  }

  let i = 1;
  const fmLines = [];
  for (; i < lines.length; i++) {
    if (lines[i].trim() === "---") {
      break;
    }
    fmLines.push(lines[i]);
  }
  const body = lines.slice(i + 1).join("\n");

  const fields = {};
  let tools = null;
  let inTools = false;

  for (const line of fmLines) {
    if (line.trim() === "") {
      continue;
    }
    // Indented line belongs to the active `tools:` block.
    if (inTools && /^\s+\S/.test(line)) {
      const m = line.match(/^\s+([A-Za-z0-9_-]+):\s*(.+)$/);
      if (m) {
        tools = tools || {};
        tools[m[1]] = m[2].trim() === "true";
      }
      continue;
    }

    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) {
      inTools = false;
      continue;
    }
    const key = m[1];
    const value = m[2].trim();
    if (key === "tools" && value === "") {
      inTools = true;
      tools = tools || {};
      continue;
    }
    inTools = false;
    fields[key] = value;
  }

  return { fields, tools, body, hasFrontmatter: true };
}

// Serialize an ordered list of [key, value] pairs as a YAML frontmatter block.
function buildFrontmatter(pairs) {
  const out = ["---"];
  for (const [key, value] of pairs) {
    if (value === null || value === undefined || value === "") {
      continue;
    }
    out.push(`${key}: ${value}`);
  }
  out.push("---");
  return out.join("\n");
}

// Emit a value as a YAML double-quoted scalar. Used for values derived from free
// text (e.g. argument-hint from a Usage line) that may contain YAML-significant
// characters such as `[`, `]`, `:`, or `"` and would otherwise produce invalid
// or wrong-typed frontmatter.
function yamlDoubleQuote(value) {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

// Invert an OpenCode disabled-tools map into a Claude allowed-tools comma string.
// Returns null when there is no tools block (agent inherits all tools).
function invertTools(tools) {
  if (!tools) {
    return null;
  }
  const remove = new Set();
  for (const [key, enabled] of Object.entries(tools)) {
    if (enabled === false) {
      const mapped = DISABLED_KEY_TO_CLAUDE_TOOLS[key.toLowerCase()];
      if (mapped) {
        for (const t of mapped) {
          remove.add(t);
        }
      } else {
        logWarning(`Unknown tool key '${key}' in agent tools - ignoring`);
      }
    }
  }
  return CLAUDE_TOOL_SET.filter((t) => !remove.has(t)).join(", ");
}

// --- per-type transforms ---

function transformAgent(text, name) {
  const { fields, tools, body } = parseFrontmatter(text);
  const description = fields.description || "";
  const pairs = [
    ["name", fields.name || name],
    ["description", description],
  ];
  const allowed = invertTools(tools);
  if (allowed !== null) {
    pairs.push(["tools", allowed]);
  }
  const model = mapModel(fields.model);
  if (model) {
    pairs.push(["model", model]);
  }
  return `${buildFrontmatter(pairs)}\n${body}`;
}

function transformCommand(text) {
  const { fields, body } = parseFrontmatter(text);
  const pairs = [["description", fields.description || ""]];

  // Derive an argument-hint from a leading `Usage: /name [args]` line if present.
  // The gap before the args must stay on the same line ([ \t]+, not \s+, which
  // would cross a newline and grab the next line for arg-less commands). The hint
  // is double-quoted because it often contains YAML-significant chars (`[`, `"`).
  const usage = body.match(/^Usage:[ \t]*\/\S+[ \t]+(.+)$/m);
  if (usage) {
    pairs.push(["argument-hint", yamlDoubleQuote(usage[1].trim())]);
  }

  const model = mapModel(fields.model);
  if (model) {
    pairs.push(["model", model]);
  }
  return `${buildFrontmatter(pairs)}\n${body}`;
}

// Claude skill constraints. Returns an error string, or null when valid.
function validateSkill(fields, name) {
  if (!fields.name) {
    return `skill '${name}' missing 'name' in frontmatter`;
  }
  if (!/^[a-z0-9-]{1,64}$/.test(fields.name)) {
    return `skill name '${fields.name}' violates ^[a-z0-9-]{1,64}$`;
  }
  if (!fields.description) {
    return `skill '${name}' missing 'description' in frontmatter`;
  }
  if (fields.description.length > 1024) {
    return `skill '${name}' description exceeds 1024 chars (${fields.description.length})`;
  }
  return null;
}

// Translate the OpenCode `mcp` block into a Claude `.mcp.json` server map.
//
// OpenCode shapes:
//   local:  { type: "local",  command: [bin, ...args], env?, enabled? }
//   remote: { type: "remote", url: string,             enabled? }
// Claude shapes:
//   stdio:  { type: "stdio", command: bin, args: [...], env? }
//   http:   { type: "http",  url: string }
//
// All OpenCode "remote" servers map to Claude "http"; OpenCode does not
// distinguish SSE from streamable-HTTP, so http is the safe default. Every
// server whose `enabled === false` is also collected into `disabled` so it
// appears in settings.json's `disabledMcpjsonServers` (available but off).
// Unknown types or malformed entries are recorded in `errors` and skipped.
function translateMcpServers(mcp) {
  const servers = {};
  const disabled = [];
  const errors = [];
  if (!mcp || typeof mcp !== "object") {
    return { servers, disabled, errors };
  }
  for (const name of Object.keys(mcp).sort()) {
    const entry = mcp[name];
    if (!entry || typeof entry !== "object") {
      errors.push(`mcp ${name}: not an object`);
      continue;
    }
    if (entry.type === "local") {
      if (!Array.isArray(entry.command) || entry.command.length === 0) {
        errors.push(`mcp ${name}: local server missing 'command' array`);
        continue;
      }
      const [command, ...args] = entry.command;
      const server = { type: "stdio", command, args };
      if (entry.env && typeof entry.env === "object") {
        server.env = entry.env;
      }
      servers[name] = server;
    } else if (entry.type === "remote") {
      if (!entry.url || typeof entry.url !== "string") {
        errors.push(`mcp ${name}: remote server missing 'url'`);
        continue;
      }
      servers[name] = { type: "http", url: entry.url };
    } else {
      errors.push(`mcp ${name}: unknown type '${entry.type}'`);
      continue;
    }
    if (entry.enabled === false) {
      disabled.push(name);
    }
  }
  disabled.sort();
  return { servers, disabled, errors };
}

// --- filesystem helpers ---

async function emptyDir(dir) {
  await fs.rm(dir, { recursive: true, force: true });
  await fs.mkdir(dir, { recursive: true });
}

async function copyDir(src, dest) {
  await fs.mkdir(dest, { recursive: true });
  const entries = await fs.readdir(src, { withFileTypes: true });
  for (const entry of entries) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    // Refuse to follow symlinks: fs.copyFile would dereference them and copy the
    // target's contents into the git-tracked output, which could exfiltrate
    // arbitrary readable files (e.g. a skill shipping `leak -> ~/.ssh/id_ed25519`).
    if (entry.isSymbolicLink()) {
      logWarning(`Skipping symlink ${s} (refusing to dereference)`);
      continue;
    }
    if (entry.isDirectory()) {
      await copyDir(s, d);
    } else if (entry.isFile()) {
      await fs.copyFile(s, d);
    } else {
      logWarning(`Skipping non-regular file ${s}`);
    }
  }
}

// --- generators ---

async function generateClaudeMd(opencodeDir, outDir) {
  const src = path.join(opencodeDir, "AGENTS.md");
  const content = await fs.readFile(src, "utf8");
  await fs.writeFile(path.join(outDir, "CLAUDE.md"), content);
  logSuccess("Generated CLAUDE.md");
  return 1;
}

async function generateAgents(opencodeDir, outDir, failed) {
  const srcDir = path.join(opencodeDir, "agent");
  const destDir = path.join(outDir, "agents");
  await emptyDir(destDir);
  let count = 0;
  const entries = await fs.readdir(srcDir, { withFileTypes: true });
  const files = entries
    .filter((e) => e.isFile() && e.name.endsWith(".md"))
    .map((e) => e.name)
    .sort();
  for (const file of files) {
    const name = path.basename(file, ".md");
    try {
      const text = await fs.readFile(path.join(srcDir, file), "utf8");
      await fs.writeFile(path.join(destDir, file), transformAgent(text, name));
      count++;
    } catch (err) {
      failed.push(`agent ${name}: ${err.message}`);
      logError(`agent ${name}: ${err.message}`);
    }
  }
  logSuccess(`Generated ${count} agents`);
  return count;
}

async function generateCommands(opencodeDir, outDir, failed) {
  const srcDir = path.join(opencodeDir, "command");
  const destDir = path.join(outDir, "commands");
  await emptyDir(destDir);
  let count = 0;
  const entries = await fs.readdir(srcDir, { withFileTypes: true });
  const files = entries
    .filter((e) => e.isFile() && e.name.endsWith(".md"))
    .map((e) => e.name)
    .sort();
  for (const file of files) {
    const name = path.basename(file, ".md");
    try {
      const text = await fs.readFile(path.join(srcDir, file), "utf8");
      await fs.writeFile(path.join(destDir, file), transformCommand(text));
      count++;
    } catch (err) {
      failed.push(`command ${name}: ${err.message}`);
      logError(`command ${name}: ${err.message}`);
    }
  }
  logSuccess(`Generated ${count} commands`);
  return count;
}

async function generateSkills(opencodeDir, outDir, failed) {
  const srcDir = path.join(opencodeDir, "skills");
  const destDir = path.join(outDir, "skills");
  await emptyDir(destDir);
  let count = 0;
  const entries = await fs.readdir(srcDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name === "_depreciated") {
      continue;
    }
    const name = entry.name;
    const skillFile = path.join(srcDir, name, "SKILL.md");
    try {
      const text = await fs.readFile(skillFile, "utf8");
      const { fields } = parseFrontmatter(text);
      const error = validateSkill(fields, name);
      if (error) {
        failed.push(`skill ${name}: ${error}`);
        logError(`skill ${name}: ${error}`);
        continue;
      }
      // Skills are format-identical; copy the whole directory verbatim
      // (SKILL.md + any resource files such as images).
      await copyDir(path.join(srcDir, name), path.join(destDir, name));
      count++;
    } catch (err) {
      failed.push(`skill ${name}: ${err.message}`);
      logError(`skill ${name}: ${err.message}`);
    }
  }
  logSuccess(`Generated ${count} skills`);
  return count;
}

// Strip // and /* */ comments and trailing commas from JSONC, then parse.
function parseJsonc(text) {
  const noComments = text
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, "$1");
  const noTrailingCommas = noComments.replace(/,(\s*[}\]])/g, "$1");
  return JSON.parse(noTrailingCommas);
}

// Copy the hand-maintained notification runtime template into the generated
// tree at hooks/notify.sh (mode 0755). The editable source lives at
// etc/scripts/src/ai/templates/claude-notify.sh; the generated ~/.claude/ tree
// is never hand-edited. The template path is resolved relative to this module so
// the generator is independent of the working directory.
async function generateHooksScript(scriptDir, outDir, failed) {
  const template = path.join(scriptDir, "templates", "claude-notify.sh");
  const destDir = path.join(outDir, "hooks");
  const dest = path.join(destDir, "notify.sh");
  try {
    await emptyDir(destDir);
    await fs.copyFile(template, dest);
    await fs.chmod(dest, 0o755);
    logSuccess("Generated hooks/notify.sh");
    return 1;
  } catch (err) {
    failed.push(`hooks: ${err.message}`);
    logError(`hooks: ${err.message}`);
    return 0;
  }
}

async function generateSettings(opencodeDir, outDir, failed) {
  const src = path.join(opencodeDir, "opencode.jsonc");
  const config = parseJsonc(await fs.readFile(src, "utf8"));

  // OpenCode runs every permission as "allow" for unrestricted autonomous
  // operation; the Claude equivalent is bypassPermissions.
  const allAllow =
    config.permission &&
    Object.values(config.permission).every((v) => v === "allow");

  // Translate the MCP servers up front so settings.json can list the disabled
  // ones while .mcp.json carries the full server map.
  const { servers: mcpServers, disabled, errors } = translateMcpServers(
    config.mcp,
  );
  for (const err of errors) {
    failed.push(err);
    logError(err);
  }

  // The notify.sh hook is generated into ~/.claude/hooks/notify.sh, so
  // reference it by absolute path.
  const HOOK_COMMAND = "$HOME/.claude/hooks/notify.sh";
  const hookEntry = (matcher) => {
    const inner = { hooks: [{ type: "command", command: HOOK_COMMAND }] };
    if (matcher) {
      return { matcher, ...inner };
    }
    return inner;
  };

  const settings = {
    $schema: "https://json.schemastore.org/claude-code-settings.json",
    permissions: { defaultMode: allAllow ? "bypassPermissions" : "default" },
    // Sound defaults inherited by notify.sh; mirror the OpenCode plugin.
    env: {
      CLAUDE_SOUND_IDLE: "Glass",
      CLAUDE_SOUND_PERMISSION: "Ping",
      CLAUDE_SOUND_VOLUME: "0.3",
    },
    hooks: {
      PostToolUse: [hookEntry("*")],
      Stop: [hookEntry(null)],
      Notification: [hookEntry(null)],
    },
  };
  if (disabled.length > 0) {
    settings.disabledMcpjsonServers = disabled;
  }
  await fs.writeFile(
    path.join(outDir, "settings.json"),
    JSON.stringify(settings, null, 2) + "\n",
  );

  await fs.writeFile(
    path.join(outDir, ".mcp.json"),
    JSON.stringify({ mcpServers }, null, 2) + "\n",
  );

  logSuccess(
    `Generated settings.json and .mcp.json (${Object.keys(mcpServers).length} MCP servers)`,
  );
  return { settings: 1, mcpServers: Object.keys(mcpServers).length };
}

// --- entry point ---

function showHelp() {
  process.stdout.write(
    [
      "Usage: opencode-to-claude.sh [opencode-dir] [out-dir]",
      "",
      "Generate a Claude Code config from an OpenCode config.",
      "Generates: CLAUDE.md, agents/, commands/, skills/, hooks/notify.sh,",
      "settings.json (permissions, env, hooks, disabledMcpjsonServers), .mcp.json.",
      "",
      "Arguments:",
      "  opencode-dir   source OpenCode config (default: src/opencode)",
      "  out-dir        generated Claude config (default: ~/.claude)",
      "",
      "Options:",
      "  --help         show this help message",
      "",
      "stdout: minified JSON summary. stderr: progress logs.",
      "",
    ].join("\n"),
  );
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    showHelp();
    return 0;
  }

  const positional = args.filter((a) => !a.startsWith("-"));
  const opencodeDir = positional[0] || "src/opencode";
  // Default output is the live Claude Code config dir in $HOME. The config is
  // generated on demand and is not tracked in the repo; OpenCode remains the
  // single source of truth.
  const outDir = positional[1] || path.join(os.homedir(), ".claude");

  // The generators force-delete outDir/{agents,commands,skills,hooks}. Refuse to
  // run against the filesystem root or the home directory itself to avoid a
  // catastrophic `rm -rf` from a mistaken out-dir argument. Writing into
  // ~/.claude (a subdirectory of home) is allowed.
  const resolvedOut = path.resolve(outDir);
  if (
    resolvedOut === path.parse(resolvedOut).root ||
    resolvedOut === os.homedir()
  ) {
    logError(`Refusing to write/delete in '${resolvedOut}'`);
    return 1;
  }

  logInfo(`Converting ${opencodeDir} -> ${outDir}`);

  await fs.mkdir(outDir, { recursive: true });
  const failed = [];

  const scriptDir = path.dirname(fileURLToPath(import.meta.url));

  const claudeMd = await generateClaudeMd(opencodeDir, outDir);
  const agents = await generateAgents(opencodeDir, outDir, failed);
  const commands = await generateCommands(opencodeDir, outDir, failed);
  const skills = await generateSkills(opencodeDir, outDir, failed);
  const hooks = await generateHooksScript(scriptDir, outDir, failed);
  const { settings, mcpServers } = await generateSettings(
    opencodeDir,
    outDir,
    failed,
  );

  // tui.jsonc has no Claude equivalent (TUI appearance is OpenCode-only); skip
  // it explicitly so the omission is intentional and visible.
  logInfo("Skipping tui.jsonc — no Claude equivalent");

  const summary = {
    claudeMd,
    agents,
    commands,
    skills,
    hooks,
    settings,
    mcpServers,
    failed,
  };
  process.stdout.write(JSON.stringify(summary) + "\n");

  if (failed.length > 0) {
    logError(`${failed.length} transform(s) failed`);
    return 1;
  }
  logSuccess("Conversion complete");
  return 0;
}

main()
  .then((code) => process.exit(code))
  .catch((err) => {
    logError(err.stack || err.message);
    process.exit(1);
  });
