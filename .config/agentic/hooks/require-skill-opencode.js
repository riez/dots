import { readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

// Load from shared config (single source of truth)
const CONFIG_PATH = join(homedir(), ".config", "agentic", "hooks", "skill-map.json");

let config = {};
try {
  config = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
} catch (e) {
  console.error(`Warning: Could not load ${CONFIG_PATH}: ${e.message}`);
}

const EXTENSION_MAP = config.extensions || {};
const TS_EXTENSIONS = new Set(config.typescript_extensions || []);
const TS_CONFIG = config.typescript_config || { skills: ["typescript-expert"], label: "TypeScript/JavaScript" };
const FILENAME_PATTERNS = Object.entries(config.filename_patterns || {}).map(
  ([pattern, cfg]) => ({ re: new RegExp(pattern), ...cfg })
);
const SKIP_EXTENSIONS = new Set(config.skip_extensions || []);
const BYPASS_PATTERNS = (config.bypass_patterns || []).map(p => new RegExp(p, "i"));

const EDIT_TOOLS = new Set([
  "write", "edit", "multi_edit", "file_write", "file_edit",
  "Write", "Edit", "MultiEdit",
]);

function getExtension(filePath) {
  const dot = filePath.lastIndexOf(".");
  return dot >= 0 ? filePath.slice(dot).toLowerCase() : "";
}

function getFilename(filePath) {
  const sep = filePath.lastIndexOf("/");
  return sep >= 0 ? filePath.slice(sep + 1) : filePath;
}

function getRequiredSkills(filePath) {
  if (!filePath) return null;

  const filename = getFilename(filePath);
  const ext = getExtension(filePath);

  if (SKIP_EXTENSIONS.has(ext)) return null;

  // Filename patterns first (more specific)
  for (const entry of FILENAME_PATTERNS) {
    if (entry.re.test(filename)) return { skills: entry.skills, label: entry.label };
  }

  // Extension map
  if (EXTENSION_MAP[ext]) return EXTENSION_MAP[ext];

  // TypeScript/JavaScript
  if (TS_EXTENSIONS.has(ext)) return TS_CONFIG;

  return null;
}

// Track invoked skills in session
const invokedSkills = new Set();

export const RequireSkill = async ({ directory }) => {
  return {
    "tool.execute.after": async (input) => {
      const tool = (input.tool || "").toLowerCase();

      if (tool === "skill" || tool === "activate_skill") {
        const skillName = input.metadata?.skill || input.metadata?.args?.skill || "";
        if (skillName) invokedSkills.add(skillName);
      }
    },

    "tool.execute.before": async (input, output) => {
      const tool = input.tool || "";
      if (!EDIT_TOOLS.has(tool)) return;

      const filePath = output?.args?.file_path
        || output?.args?.filePath
        || output?.args?.path
        || "";

      const required = getRequiredSkills(filePath);
      if (!required) return;

      const hasSkill = required.skills.some(s => invokedSkills.has(s));
      if (hasSkill || invokedSkills.has("__bypassed__")) return;

      // Check bypass
      const content = JSON.stringify(output || {}).toLowerCase();
      for (const pattern of BYPASS_PATTERNS) {
        if (pattern.test(content)) {
          invokedSkills.add("__bypassed__");
          return;
        }
      }

      const skillsStr = required.skills.map(s => `'${s}'`).join(", ");
      throw new Error(
        `BLOCKED: Editing ${required.label} file without language skill.\n\n` +
        `File: ${getFilename(filePath)}\n` +
        `Required skill(s): ${skillsStr}\n\n` +
        `Before editing ${required.label} files, you MUST invoke the relevant language skill.\n` +
        `Bypass with: 'skip skill' or 'no skill needed'`
      );
    },
  };
};
