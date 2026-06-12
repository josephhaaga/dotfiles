/**
 * raindrop-watchdog — verifies that every span OpenCode generates actually
 * lands in the local Raindrop Workshop SQLite database.
 *
 * Detected failure modes:
 *   1. Missing tool span  — tool.execute.before fired but no matching span in
 *      Raindrop after the session ends (catches chrome-devtools "no output"
 *      case and any other silent drop).
 *   2. Missing LLM text span — model emitted text between tool calls
 *      (message.part.updated type=text) but no LLM span landed in Raindrop.
 *   3. Missing/zero tokens — message.updated carried non-zero token counts
 *      but the Raindrop span has 0 input_tokens.
 *
 * Configuration (passed via opencode.json plugin tuple):
 *   alertNotification  boolean  — send macOS notification on mismatch (default true)
 *   alertLogPath       string   — path to append alerts to (default ~/.local/share/opencode/raindrop-watchdog.log)
 *   pendingDir         string   — dir for per-turn pending-span JSON files (default ~/.local/share/opencode/raindrop-watchdog)
 *   dbPath             string   — path to Raindrop Workshop SQLite DB (default ~/.raindrop/raindrop_workshop.db)
 *   verifyDelayMs      number   — ms to wait after session.idle before querying DB (default 12000)
 *
 * Bugs fixed vs original draft:
 *   - session.deleted event: properties has { info: Session } not { sessionID };
 *     extract sessionID as properties.info.id
 *   - Export format aligned with Plugin type: (input: PluginInput, options?) => Promise<Hooks>
 */

import { mkdirSync, writeFileSync, unlinkSync, existsSync, appendFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import type { PluginInput, PluginOptions } from "@opencode-ai/plugin";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface WatchdogOptions extends PluginOptions {
  alertNotification?: boolean;
  alertLogPath?: string;
  pendingDir?: string;
  dbPath?: string;
  verifyDelayMs?: number;
}

interface ExpectedToolSpan {
  callID: string;
  tool: string;
  ts: number;
  /** true when tool.execute.after received a result with no `output` field */
  missingOutput?: boolean;
}

interface ExpectedLlmSpan {
  messageID: string;
  textPreview: string;
  ts: number;
}

interface ExpectedTokens {
  messageID: string;
  inputTokens: number;
  outputTokens: number;
}

interface PendingSession {
  sessionID: string;
  convoID: string; // same as sessionID in the Raindrop model
  turns: TurnRecord[];
}

interface TurnRecord {
  turnID: string; // messageID of the assistant message
  toolSpans: ExpectedToolSpan[];
  llmSpans: ExpectedLlmSpan[];
  tokens: ExpectedTokens | null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function resolveHome(p: string): string {
  return p.startsWith("~") ? join(homedir(), p.slice(1)) : p;
}

function now(): number {
  return Date.now();
}

function logAlert(logPath: string, message: string): void {
  const line = `[${new Date().toISOString()}] ${message}\n`;
  try {
    appendFileSync(logPath, line, "utf-8");
  } catch {
    // best-effort
  }
}

async function notify(title: string, body: string): Promise<void> {
  try {
    Bun.spawn(
      ["osascript", "-e", `display notification "${body.replace(/"/g, '\\"')}" with title "${title.replace(/"/g, '\\"')}"`],
      { stdio: ["ignore", "ignore", "ignore"] }
    );
  } catch {
    // best-effort
  }
}

// ---------------------------------------------------------------------------
// SQLite verification
// We use Bun's built-in bun:sqlite — same runtime as OpenCode plugins.
// ---------------------------------------------------------------------------

interface SpanRow {
  id: string;
  name: string;
  span_type: string;
  attributes: string | null;
  input_tokens: number;
  output_tokens: number;
}

interface RunRow {
  id: string;
  convo_id: string;
}

function querySpansForSession(dbPath: string, convoID: string): SpanRow[] {
  try {
    // Dynamically import bun:sqlite to avoid errors in non-Bun environments
    const { Database } = require("bun:sqlite");
    const db = new Database(dbPath, { readonly: true });

    // Find all run IDs for this convoID
    const runs = db
      .query<RunRow, [string]>("SELECT id FROM runs WHERE convo_id = ?")
      .all(convoID);

    if (runs.length === 0) return [];

    const runIds = runs.map((r) => r.id);
    const placeholders = runIds.map(() => "?").join(",");
    const spans = db
      .query<SpanRow, string[]>(
        `SELECT id, name, span_type, attributes, input_tokens, output_tokens
         FROM spans
         WHERE run_id IN (${placeholders})
           AND span_type = 'TOOL_CALL' OR span_type = 'LLM_GENERATION'`
      )
      .all(...runIds);

    db.close();
    return spans;
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Verification logic
// ---------------------------------------------------------------------------

interface Mismatch {
  kind: "missing_tool_span" | "missing_llm_span" | "zero_tokens" | "missing_output_field";
  detail: string;
}

function verify(pending: PendingSession, spans: SpanRow[]): Mismatch[] {
  const mismatches: Mismatch[] = [];

  // Index Raindrop spans by callID for O(1) lookup
  const toolSpansByCallID = new Map<string, SpanRow>();
  const llmSpans: SpanRow[] = [];

  for (const span of spans) {
    if (span.span_type === "TOOL_CALL" && span.attributes) {
      try {
        const attrs = JSON.parse(span.attributes);
        const callID = attrs["ai.toolCall.id"];
        if (callID) toolSpansByCallID.set(callID, span);
      } catch {
        // malformed attributes — skip
      }
    } else if (span.span_type === "LLM_GENERATION") {
      llmSpans.push(span);
    }
  }

  for (const turn of pending.turns) {
    // 1. Tool spans
    for (const expected of turn.toolSpans) {
      if (expected.missingOutput) {
        mismatches.push({
          kind: "missing_output_field",
          detail: `tool=${expected.tool} callID=${expected.callID} — tool.execute.after received result with no 'output' field (Raindrop plugin threw, span dropped)`,
        });
        continue;
      }
      if (!toolSpansByCallID.has(expected.callID)) {
        mismatches.push({
          kind: "missing_tool_span",
          detail: `tool=${expected.tool} callID=${expected.callID} — span not found in Raindrop DB`,
        });
      }
    }

    // 2. LLM text spans — we expect at least one LLM_GENERATION span per turn
    // where the model emitted text (not just tool calls with no reasoning)
    if (turn.llmSpans.length > 0 && llmSpans.length === 0) {
      for (const expected of turn.llmSpans) {
        mismatches.push({
          kind: "missing_llm_span",
          detail: `messageID=${expected.messageID} — model emitted text ("${expected.textPreview}") but no LLM_GENERATION span found in Raindrop`,
        });
      }
    }

    // 3. Token counts
    if (turn.tokens && turn.tokens.inputTokens > 0) {
      // Find corresponding LLM span — match by proximity (same turn)
      // Since we can't easily correlate by messageID, flag if ALL LLM spans
      // in the session have zero input_tokens
      const hasNonZeroTokens = llmSpans.some((s) => s.input_tokens > 0);
      if (!hasNonZeroTokens && llmSpans.length > 0) {
        mismatches.push({
          kind: "zero_tokens",
          detail: `messageID=${turn.tokens.messageID} — message.updated reported ${turn.tokens.inputTokens} input tokens but all Raindrop LLM spans have 0 input_tokens`,
        });
      }
    }
  }

  return mismatches;
}

// ---------------------------------------------------------------------------
// Pending state persistence
// ---------------------------------------------------------------------------

function pendingPath(pendingDir: string, sessionID: string): string {
  return join(pendingDir, `${sessionID}.json`);
}

function savePending(pendingDir: string, session: PendingSession): void {
  mkdirSync(pendingDir, { recursive: true });
  writeFileSync(pendingPath(pendingDir, session.sessionID), JSON.stringify(session, null, 2), "utf-8");
}

function deletePending(pendingDir: string, sessionID: string): void {
  const p = pendingPath(pendingDir, sessionID);
  if (existsSync(p)) {
    try { unlinkSync(p); } catch { /* best-effort */ }
  }
}

// ---------------------------------------------------------------------------
// Plugin export
// Signature matches Plugin = (input: PluginInput, options?: PluginOptions) => Promise<Hooks>
// ---------------------------------------------------------------------------

export default async function RaindropWatchdog(
  _input: PluginInput,
  options: WatchdogOptions = {}
) {
  const alertNotification = options.alertNotification ?? true;
  const alertLogPath = resolveHome(options.alertLogPath as string ?? "~/.local/share/opencode/raindrop-watchdog.log");
  const pendingDir = resolveHome(options.pendingDir as string ?? "~/.local/share/opencode/raindrop-watchdog");
  const dbPath = resolveHome(options.dbPath as string ?? "~/.raindrop/raindrop_workshop.db");
  const verifyDelayMs = (options.verifyDelayMs as number) ?? 12000;

  // Ensure log directory exists
  mkdirSync(join(alertLogPath, ".."), { recursive: true });

  // Per-session in-memory state.
  // verifying tracks sessions currently in the verify delay so that
  // session.idle + session.deleted don't both trigger runVerification.
  const sessions = new Map<string, PendingSession>();
  const verifying = new Set<string>();

  function getOrCreateSession(sessionID: string): PendingSession {
    if (!sessions.has(sessionID)) {
      sessions.set(sessionID, {
        sessionID,
        convoID: sessionID,
        turns: [],
      });
    }
    return sessions.get(sessionID)!;
  }

  function currentTurn(session: PendingSession): TurnRecord {
    if (session.turns.length === 0) {
      session.turns.push({ turnID: "", toolSpans: [], llmSpans: [], tokens: null });
    }
    return session.turns[session.turns.length - 1];
  }

  async function runVerification(sessionID: string): Promise<void> {
    const session = sessions.get(sessionID);
    if (!session) return;

    // Guard against double-trigger (session.idle + session.deleted)
    if (verifying.has(sessionID)) return;
    verifying.add(sessionID);

    // Remove from active sessions immediately so no more events accumulate
    sessions.delete(sessionID);

    // Persist before async delay in case of crash
    savePending(pendingDir, session);

    // Wait for Raindrop to flush spans to SQLite
    await new Promise((r) => setTimeout(r, verifyDelayMs));

    const spans = querySpansForSession(dbPath, session.convoID);
    const mismatches = verify(session, spans);

    if (mismatches.length === 0) {
      // All good — clean up
      deletePending(pendingDir, sessionID);
    } else {
      const summary = `[raindrop-watchdog] ${mismatches.length} span mismatch(es) for session ${sessionID}`;
      logAlert(alertLogPath, summary);
      for (const m of mismatches) {
        logAlert(alertLogPath, `  [${m.kind}] ${m.detail}`);
      }
      logAlert(alertLogPath, "");

      // Log only — never write to console.error/console.log since that
      // renders into the OpenCode TUI and can block the text input.
      if (alertNotification) {
        const body = mismatches.map((m) => `• ${m.detail.slice(0, 80)}`).join("\n");
        await notify("Raindrop Watchdog", `${mismatches.length} missing span(s)\n${body}`);
      }
    }

    verifying.delete(sessionID);
  }

  return {
    // -----------------------------------------------------------------------
    // tool.execute.before — record every expected tool span
    // -----------------------------------------------------------------------
    "tool.execute.before": async (
      input: { tool: string; sessionID: string; callID: string },
      _output: { args: unknown }
    ) => {
      const session = getOrCreateSession(input.sessionID);
      const turn = currentTurn(session);
      turn.toolSpans.push({ callID: input.callID, tool: input.tool, ts: now() });
    },

    // -----------------------------------------------------------------------
    // tool.execute.after — detect missing output field before Raindrop throws
    // -----------------------------------------------------------------------
    "tool.execute.after": async (
      input: { tool: string; sessionID: string; callID: string; args: unknown },
      output: { title: string; output: string; metadata: unknown }
    ) => {
      const session = sessions.get(input.sessionID);
      if (!session) return;

      // Check if output field is missing (the chrome-devtools / MCP case)
      const hasMissingOutput = !("output" in (output as object)) || (output as { output?: unknown }).output === undefined;
      if (hasMissingOutput) {
        const turn = currentTurn(session);
        const existing = turn.toolSpans.find((s) => s.callID === input.callID);
        if (existing) {
          existing.missingOutput = true;
        } else {
          // .after fired without a matching .before (shouldn't happen, but handle it)
          turn.toolSpans.push({
            callID: input.callID,
            tool: input.tool,
            ts: now(),
            missingOutput: true,
          });
        }
      }
    },

    // -----------------------------------------------------------------------
    // event — intercept message.part.updated, message.updated, session.idle,
    //          and session.deleted
    //
    // event hook receives { event: Event } where Event has { type, properties }
    // -----------------------------------------------------------------------
    event: async (props: { event: { type: string; properties: Record<string, unknown> } }) => {
      const { event } = props;

      if (event.type === "message.part.updated") {
        const part = event.properties["part"] as Record<string, unknown> | undefined;
        if (!part) return;

        const sessionID = part["sessionID"] as string | undefined;
        const messageID = part["messageID"] as string | undefined;
        const type = part["type"] as string | undefined;
        const text = part["text"] as string | undefined;

        if (!sessionID || !messageID || type !== "text" || typeof text !== "string") return;

        const session = getOrCreateSession(sessionID);
        const turn = currentTurn(session);
        // Update or create LLM span expectation for this messageID
        const existing = turn.llmSpans.find((s) => s.messageID === messageID);
        if (existing) {
          existing.textPreview = text.slice(0, 100);
        } else {
          turn.llmSpans.push({ messageID, textPreview: text.slice(0, 100), ts: now() });
        }
      }

      if (event.type === "message.updated") {
        const info = event.properties["info"] as Record<string, unknown> | undefined;
        if (!info) return;

        const sessionID = info["sessionID"] as string | undefined;
        const messageID = info["id"] as string | undefined;
        const role = info["role"] as string | undefined;
        const tokens = info["tokens"] as Record<string, unknown> | undefined;

        if (!sessionID || !messageID || role !== "assistant" || !tokens) return;

        const inputTokens = tokens["input"] as number | undefined;
        const outputTokens = tokens["output"] as number | undefined;
        if (typeof inputTokens !== "number" || typeof outputTokens !== "number") return;

        const session = getOrCreateSession(sessionID);
        const turn = currentTurn(session);
        turn.turnID = messageID;
        turn.tokens = { messageID, inputTokens, outputTokens };

        // Start a fresh turn for the next assistant message
        session.turns.push({ turnID: "", toolSpans: [], llmSpans: [], tokens: null });
      }

      if (event.type === "session.idle") {
        // EventSessionIdle.properties = { sessionID: string }
        const sessionID = event.properties["sessionID"] as string | undefined;
        if (!sessionID || !sessions.has(sessionID)) return;

        // Fire-and-forget verification (don't block the hook)
        runVerification(sessionID).catch((err) => {
          logAlert(alertLogPath, `[error] verification error: ${err}`);
        });
      }

      if (event.type === "session.deleted") {
        // EventSessionDeleted.properties = { info: Session } where Session.id is the session ID
        // (NOT { sessionID } — that was the original bug causing errors mid-session)
        const info = event.properties["info"] as Record<string, unknown> | undefined;
        const sessionID = info?.["id"] as string | undefined;
        if (!sessionID || !sessions.has(sessionID)) return;

        runVerification(sessionID).catch((err) => {
          logAlert(alertLogPath, `[error] verification error: ${err}`);
        });
      }
    },
  };
}
