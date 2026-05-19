const EDIT_TOOLS = new Set([
  "write", "edit", "multi_edit", "file_write", "file_edit",
  "Write", "Edit", "MultiEdit",
]);

const CODE_EXTENSIONS = new Set([
  ".bash", ".c", ".cc", ".cpp", ".cs", ".css", ".dart", ".fs", ".go",
  ".h", ".hpp", ".java", ".js", ".jsx", ".kt", ".php", ".py", ".rb",
  ".rs", ".sh", ".sql", ".svelte", ".swift", ".ts", ".tsx", ".vue", ".zsh",
]);

const SCOPE_PATTERNS = [
  /fallback/i,
  /\bfallback(s)?\b/i,
  /\bfallback[_-]?(fn|function|handler|path|logic|mode|strategy)\b/i,
  /legacy/i,
  /\blegacy\b/i,
  /compat/i,
  /\bbackwards?\s+compat(ibility|ible)?\b/i,
  /\bcompat(ibility)?\s+(layer|path|mode|alias|shim)\b/i,
  /\badapter\s+(layer|path|shim|wrapper|for)\b/i,
  /shim/i,
  /\bshim(s|med|ming)?\b/i,
  /polyfill/i,
  /\bpolyfill(s)?\b/i,
  /workaround/i,
  /\bworkaround(s)?\b/i,
  /\btemporary\s+(fix|solution|path|workaround)\b/i,
  /\balternate\s+(implementation|path|flow|logic)\b/i,
  /\bsecondary\s+(implementation|path|flow|logic)\b/i,
  /\bsilent\s+catch\b/i,
  /\bcatch\s+.*\b(fallback|default|ignore|swallow)\b/i,
  /\bswallow\s+(error|exception|failure)s?\b/i,
  /\btry\s+.*\bthen\s+fallback\b/i,
];

const APPROVAL_PATTERNS = [
  /\b(approve|approved|allow|allowed|yes|ok|okay|go ahead|proceed)\b.{0,120}\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b/i,
  /\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b.{0,120}\b(approve|approved|allowed|ok|okay|go ahead|proceed)\b/i,
  /\b(implement|create|preserve|keep|support|maintain|use)\b.{0,80}\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b/i,
  /\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b.{0,80}\b(implement|create|preserve|keep|support|maintain|use)\b/i,
];

const REJECTION_PATTERNS = [
  /\b(no|without|avoid|do not|don't|dont|never)\b.{0,80}\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b/i,
  /\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b.{0,80}\b(no|not allowed|forbidden|avoid|never)\b/i,
  /\b(guard|guarding|block|blocking|prevent|preventing|stop|stopping|forbid|forbidding|disallow|disallowing)\b.{0,120}\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b/i,
  /\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b.{0,120}\b(guard|guarding|block|blocking|prevent|preventing|stop|stopping|forbid|forbidding|disallow|disallowing)\b/i,
];

const approvedSessions = new Set();

function extensionOf(filePath) {
  if (!filePath) return "";
  const dot = filePath.lastIndexOf(".");
  return dot >= 0 ? filePath.slice(dot).toLowerCase() : "";
}

function isCodeFile(filePath) {
  if (!filePath) return true;
  return CODE_EXTENSIONS.has(extensionOf(filePath));
}

function textFromValue(value) {
  if (value == null) return "";
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(textFromValue).join("\n");
  if (typeof value === "object") {
    return ["text", "content", "message", "new_string", "old_string", "command"]
      .map((key) => textFromValue(value[key]))
      .filter(Boolean)
      .join("\n");
  }
  return "";
}

function editText(args = {}) {
  const chunks = [textFromValue(args.content), textFromValue(args.new_string)];
  if (Array.isArray(args.edits)) {
    for (const edit of args.edits) chunks.push(textFromValue(edit?.new_string));
  }
  return chunks.filter(Boolean).join("\n");
}

function matchedScopeTerm(text) {
  for (const pattern of SCOPE_PATTERNS) {
    const match = text.match(pattern);
    if (match) return match[0];
  }
  return "";
}

function hasApproval(text) {
  if (!text) return false;
  if (REJECTION_PATTERNS.some((pattern) => pattern.test(text))) return false;
  return APPROVAL_PATTERNS.some((pattern) => pattern.test(text));
}

function messageText(output) {
  const parts = output?.parts || [];
  const partText = parts.map((part) => textFromValue(part)).filter(Boolean).join("\n");
  return partText || textFromValue(output?.message);
}

export const ScopeControl = async () => {
  return {
    "chat.message": async (input, output) => {
      const sessionID = input.sessionID || output?.sessionID;
      if (!sessionID) return;
      const text = messageText(output).toLowerCase();
      if (hasApproval(text)) approvedSessions.add(sessionID);
    },

    "tool.execute.before": async (input, output) => {
      const tool = input.tool || "";
      if (!EDIT_TOOLS.has(tool)) return;

      const args = output?.args || {};
      const filePath = args.file_path || args.filePath || args.path || "";
      if (filePath && !isCodeFile(filePath)) return;

      const term = matchedScopeTerm(editText(args));
      if (!term) return;

      const sessionID = input.sessionID || output?.sessionID || "";
      if (sessionID && approvedSessions.has(sessionID)) return;

      throw new Error(
        "BLOCKED: Proposed edit appears to add fallback/legacy/compatibility " +
        `logic (${term}) without explicit user approval.\n\n` +
        "Ask the user first and explain the proposed path, why a single-path " +
        "implementation is insufficient, the risk it prevents, the maintenance " +
        "burden it adds, and the clean single-path alternative."
      );
    },
  };
};
