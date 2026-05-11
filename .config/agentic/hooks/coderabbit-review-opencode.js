import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";

const STATE_DIR_BASE = "/tmp/factory-coderabbit";

const EDIT_TOOLS = new Set([
  "write", "edit", "multi_edit", "file_write", "file_edit",
  "Write", "Edit", "MultiEdit",
]);

function getStateDir(directory) {
  const hash = createHash("md5").update(directory).digest("hex").slice(0, 12);
  const dir = `${STATE_DIR_BASE}-${hash}`;
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

function loadState(stateDir) {
  const defaults = {
    review_status: "none",
    review_stale: false,
    findings_injected: false,
    edit_count: 0,
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

function getReviewOutput(stateDir) {
  const f = join(stateDir, "review-output.txt");
  if (existsSync(f)) return readFileSync(f, "utf8").trim();
  return "";
}

export const CodeRabbitReview = async ({ directory }) => {
  const projectDir = directory || process.cwd();

  return {
    // Track edits only -- no background process
    "tool.execute.after": async (input) => {
      const tool = input.tool || "";

      // After write/edit: track changes
      if (EDIT_TOOLS.has(tool)) {
        const stateDir = getStateDir(projectDir);
        const state = loadState(stateDir);
        state.edit_count = (state.edit_count || 0) + 1;
        if (state.review_status === "completed") state.review_stale = true;
        saveState(stateDir, state);
        return;
      }

      // After bash/shell with `coderabbit review`: mark review done
      if (tool === "bash" || tool === "shell") {
        const cmd = input.metadata?.command || input.metadata?.args?.command || "";
        if (/\bcoderabbit\s+review\b/.test(cmd)) {
          const stateDir = getStateDir(projectDir);
          const state = loadState(stateDir);
          state.review_status = "completed";
          state.review_stale = false;
          state.findings_injected = false;
          saveState(stateDir, state);
        }
      }
    },

    // Gate git commit on completed review
    "tool.execute.before": async (input, output) => {
      const tool = (input.tool || "").toLowerCase();
      if (tool !== "bash" && tool !== "shell") return;

      const cmd = output?.args?.command || "";
      if (!/\bgit\s+commit\b/.test(cmd)) return;

      const stateDir = getStateDir(projectDir);
      const state = loadState(stateDir);
      const n = state.edit_count || 0;
      const f = (state.edited_files || []).length;

      if (state.review_status === "completed" && !state.review_stale) {
        // Allow -- reset for next cycle
        state.edit_count = 0;
        state.edited_files = [];
        state.review_status = "none";
        state.review_stale = false;
        state.findings_injected = false;
        saveState(stateDir, state);
        return;
      }

      if (state.review_status === "completed" && state.review_stale) {
        throw new Error(
          `BLOCKED: ${n} edits across ${f} files since last CodeRabbit review.\n` +
          "Run `coderabbit review --prompt-only --type uncommitted` to review the latest changes, then retry."
        );
      }

      throw new Error(
        `BLOCKED: No CodeRabbit review completed (${n} edits, ${f} files).\n` +
        "Run `coderabbit review --prompt-only --type uncommitted` first, then retry."
      );
    },
  };
};
