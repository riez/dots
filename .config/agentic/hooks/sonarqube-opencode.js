import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { join, extname, resolve, relative } from "node:path";
import { homedir } from "node:os";

// Constants
const STATE_DIR_BASE = "/tmp/sonarqube-analysis";
const SONARQUBE_URL_DEFAULT = "https://sonarqube-local.taila7050b.ts.net";
const HEALTH_CACHE_SECONDS = 60;
const DEBOUNCE_SECONDS = 10;
const BLOCKING_SEVERITIES = new Set(["CRITICAL", "BLOCKER", "MAJOR"]);

const EDIT_TOOLS = new Set([
  "write", "edit", "multi_edit", "file_write", "file_edit",
  "Write", "Edit", "MultiEdit",
]);

const SKILL_MAP_PATH = join(homedir(), ".config", "agentic", "hooks", "skill-map.json");

const FALLBACK_SKIP_EXTENSIONS = [
  ".md", ".mdx", ".txt", ".json", ".yaml", ".yml", ".toml",
  ".xml", ".html", ".css", ".scss", ".less", ".svg", ".png",
  ".jpg", ".jpeg", ".gif", ".ico", ".env", ".gitignore",
  ".lock", ".log", ".csv", ".ini", ".cfg",
];

// ---------------------------------------------------------------------------
// State helpers
// ---------------------------------------------------------------------------

function getStateDir(directory) {
  const hash = createHash("md5").update(directory).digest("hex").slice(0, 12);
  const dir = `${STATE_DIR_BASE}-${hash}`;
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

function loadState(stateDir) {
  const defaults = {
    files: {},
    pending_scans: [],
    edits_since_scan: 0,
    edited_files: [],
  };
  const f = join(stateDir, "state.json");
  if (existsSync(f)) {
    try { return { ...defaults, ...JSON.parse(readFileSync(f, "utf8")) }; } catch {}
  }
  return defaults;
}

function saveState(stateDir, state) {
  writeFileSync(join(stateDir, "state.json"), JSON.stringify(state, null, 2));
}

function loadHealth(stateDir) {
  const f = join(stateDir, "health.json");
  if (existsSync(f)) {
    try { return JSON.parse(readFileSync(f, "utf8")); } catch {}
  }
  return {};
}

function saveHealth(stateDir, health) {
  writeFileSync(join(stateDir, "health.json"), JSON.stringify(health, null, 2));
}

// ---------------------------------------------------------------------------
// Config resolution
// ---------------------------------------------------------------------------

function getSkipExtensions() {
  try {
    if (existsSync(SKILL_MAP_PATH)) {
      const data = JSON.parse(readFileSync(SKILL_MAP_PATH, "utf8"));
      if (Array.isArray(data.skip_extensions) && data.skip_extensions.length > 0) {
        return data.skip_extensions;
      }
    }
  } catch {}
  return FALLBACK_SKIP_EXTENSIONS;
}

function isCodeFile(filePath) {
  const ext = extname(filePath).toLowerCase();
  if (!ext) return false;
  return !getSkipExtensions().includes(ext);
}

function resolveSonarQubeUrl() {
  const envUrl = process.env.SONARQUBE_URL;
  if (envUrl) return envUrl.replace(/\/+$/, "");
  return SONARQUBE_URL_DEFAULT;
}

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------

function checkMcpHealth(stateDir) {
  const health = loadHealth(stateDir);
  const now = Date.now() / 1000;

  if (now - (health.last_check || 0) < HEALTH_CACHE_SECONDS) {
    return health.reachable || false;
  }

  const url = resolveSonarQubeUrl();
  let reachable = false;
  try {
    const result = execFileSync(
      "curl",
      ["-sf", "-o", "/dev/null", "-w", "%{http_code}", `${url}/api/system/status`],
      { timeout: 10000, encoding: "utf8" },
    );
    reachable = result.trim().startsWith("2");
  } catch {}

  health.reachable = reachable;
  health.last_check = now;
  saveHealth(stateDir, health);
  return reachable;
}

// ---------------------------------------------------------------------------
// Issue parsing and formatting
// ---------------------------------------------------------------------------

function parseMcpIssues(toolOutput) {
  let data = toolOutput;
  if (typeof data === "string") {
    try { data = JSON.parse(data); } catch { return []; }
  }

  if (data && typeof data === "object" && !Array.isArray(data)) {
    if (Array.isArray(data.issues)) return data.issues;
    if (data.key || data.rule) return [data];
    const nested = data.content || data.result || data.data;
    if (nested) return parseMcpIssues(nested);
  }

  if (Array.isArray(data)) return data;
  return [];
}

function formatIssue(issue) {
  const sev = issue.severity || "UNKNOWN";
  const rule = issue.rule || "";
  const msg = issue.message || "";
  const component = issue.component || "";
  const line = issue.line || (issue.textRange && issue.textRange.startLine) || "?";
  const filePart = component.includes(":") ? component.split(":").slice(1).join(":") : component;
  return `- [${sev}] ${filePart}:${line} -- ${msg} (${rule})`;
}

// ---------------------------------------------------------------------------
// Exported factory (OpenCode hook interface)
// ---------------------------------------------------------------------------

export const SonarQubeAnalysis = async ({ directory }) => {
  const projectDir = directory || process.cwd();

  return {
    // Track edits, detect SonarQube scan results
    "tool.execute.after": async (input) => {
      try {
        const tool = input.tool || "";

        // --- Edit tools: track file changes ---
        if (EDIT_TOOLS.has(tool)) {
          handlePostEdit(input, projectDir);
          return;
        }

        // --- Bash/shell: capture SonarQube scan results ---
        if (tool === "bash" || tool === "shell") {
          handleMarkDone(input, projectDir);
        }
      } catch {}
    },

    // Gate git commit on code quality
    "tool.execute.before": async (input, output) => {
      try {
        const tool = (input.tool || "").toLowerCase();
        if (tool !== "bash" && tool !== "shell") return;

        const cmd = output?.args?.command || "";
        if (!/\bgit\s+commit\b/.test(cmd)) return;

        handlePreCommit(projectDir);
      } catch {}
    },
  };
};

// ---------------------------------------------------------------------------
// tool.execute.after: edit tracking
// ---------------------------------------------------------------------------

function handlePostEdit(input, projectDir) {
  const stateDir = getStateDir(projectDir);
  const state = loadState(stateDir);

  const meta = input.metadata || {};
  const filePath = meta.file_path || meta.filePath || meta.path || "";
  if (!filePath) return;
  if (!isCodeFile(filePath)) return;

  // Debounce per file
  const now = Date.now() / 1000;
  const fileState = (state.files || {})[filePath] || {};
  if (now - (fileState.last_scan || 0) < DEBOUNCE_SECONDS) return;

  // Track edit count
  state.edits_since_scan = (state.edits_since_scan || 0) + 1;

  const edited = state.edited_files || [];
  if (!edited.includes(filePath)) edited.push(filePath);
  state.edited_files = edited.slice(-50);

  // Health check (cached)
  checkMcpHealth(stateDir);

  // Add to pending scans
  const pending = state.pending_scans || [];
  if (!pending.includes(filePath)) pending.push(filePath);
  state.pending_scans = pending;

  saveState(stateDir, state);
}

// ---------------------------------------------------------------------------
// tool.execute.after: mark-done (capture SonarQube scan results)
// ---------------------------------------------------------------------------

function handleMarkDone(input, projectDir) {
  const meta = input.metadata || {};
  const cmd = meta.command || meta.args?.command || "";
  const toolOutput = input.output || "";

  const combined = `${cmd} ${typeof toolOutput === "string" ? toolOutput : JSON.stringify(toolOutput)}`;
  if (!/sonar(qube)?/i.test(combined)) return;

  const stateDir = getStateDir(projectDir);
  const state = loadState(stateDir);

  // Parse issues from output
  const issues = parseMcpIssues(toolOutput);

  // Group by file
  const filesState = state.files || {};
  const seenFiles = new Set();

  for (const issue of issues) {
    const component = issue.component || "";
    const fp = component.includes(":") ? component.split(":").slice(1).join(":") : component;
    if (!fp) continue;

    seenFiles.add(fp);

    if (!filesState[fp]) filesState[fp] = { issues: [], last_scan: 0 };
    // Replace existing issue with same key, or append
    filesState[fp].issues = (filesState[fp].issues || []).filter(
      (i) => i.key !== issue.key,
    );
    filesState[fp].issues.push(issue);
    filesState[fp].last_scan = Date.now() / 1000;
  }

  // Remove scanned files from pending
  let pending = state.pending_scans || [];
  pending = pending.filter((fp) => {
    let rel = fp;
    try { rel = relative(resolve(projectDir), resolve(fp)); } catch {}
    if (seenFiles.has(rel) || seenFiles.has(fp)) {
      // Clear file entry if no issues remain
      if (filesState[rel] && (!filesState[rel].issues || filesState[rel].issues.length === 0)) {
        delete filesState[rel];
      }
      return false;
    }
    return true;
  });

  state.files = filesState;
  state.pending_scans = pending;
  state.edits_since_scan = 0;
  saveState(stateDir, state);
}

// ---------------------------------------------------------------------------
// tool.execute.before: pre-commit gate
// ---------------------------------------------------------------------------

function handlePreCommit(projectDir) {
  const stateDir = getStateDir(projectDir);
  const state = loadState(stateDir);

  // Collect all issues from state
  const filesState = state.files || {};
  const allIssues = [];

  for (const fp of Object.keys(filesState)) {
    const fileIssues = filesState[fp].issues || [];
    allIssues.push(...fileIssues);
  }

  const blocking = [];
  for (const issue of allIssues) {
    const sev = (issue.severity || "").toUpperCase();
    if (BLOCKING_SEVERITIES.has(sev)) {
      blocking.push(formatIssue(issue));
    }
  }

  if (blocking.length > 0) {
    throw new Error(
      `BLOCKED: SonarQube quality gate - ${blocking.length} blocking issue(s):\n\n` +
      blocking.join("\n") +
      "\n\nFix these issues before committing.",
    );
  }

  // No blocking issues: clear state and allow commit
  state.files = {};
  state.pending_scans = [];
  state.edits_since_scan = 0;
  state.edited_files = [];
  saveState(stateDir, state);
}
