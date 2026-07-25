/**
 * Scribe plugin — background knowledge-base capture for OpenCode.
 *
 * Two-tier structure (see project docs/DECISIONS.md D11):
 *   - Per turn (session.idle): append a CLEANED one-line summary of the turn to a per-session
 *     subfile (Daily/sessions/<date>-opencode-<id>.md). No tool-action counts, no raw IDs.
 *   - At session end (session.deleted): generate a 2-4 bullet executive summary of the session
 *     and upsert it into the daily file, linking to the subfile.
 *
 * All vault logic lives in scribe_core.py (shared with the Claude Code / Codex hooks) so there
 * is one source of truth. This plugin shells out to it.
 *
 * Vault path comes from SEEKSTONE_VAULT or falls back to ~/Documents/obsidian-vault.
 */

import { join } from "path";
import { homedir } from "os";

const TOOL = "OpenCode";
const CORE = join(
  homedir(),
  "Documents/code/setup-ai-native-dev-env/scribe/shared/scribe_core.py",
);

// Debounce so we don't write on every micro-idle; one turn bullet per window per session.
const IDLE_DEBOUNCE_MS = 60_000;
// How often to (re)generate the executive summary mid-session. Upsert makes this idempotent.
const SUMMARIZE_EVERY_MS = 5 * 60_000;
const lastWrite = new Map<string, number>();
const lastSummary = new Map<string, number>();
const projectOf = new Map<string, string>();

function callCore(fn: string, args: string[]) {
  // fn is one of: append_turn, summarize_session. Invoke via a tiny python -c shim.
  const py = `import sys; sys.path.insert(0,'${join(homedir(), "Documents/code/setup-ai-native-dev-env/scribe/shared")}'); import scribe_core as s; s.${fn}(*sys.argv[1:])`;
  Bun.spawn(["python3", "-c", py, ...args], {
    stdio: ["ignore", "ignore", "ignore"],
    detached: true,
  });
}

async function summarizePrompt(client: any, sessionID: string): Promise<string> {
  try {
    const res = await client.session.messages({ path: { id: sessionID } });
    const messages = (res?.data ?? res ?? []) as any[];
    const lastUser = [...messages]
      .reverse()
      .find((m) => (m.info?.role ?? m.role) === "user");
    for (const p of lastUser?.parts ?? []) {
      if (p.type === "text" && p.text) {
        return p.text.replace(/\s+/g, " ").trim().slice(0, 280);
      }
    }
  } catch {
    /* ignore */
  }
  return "worked on the current task";
}

export const ScribePlugin = async ({ client, directory }: any) => {
  const project = directory.split("/").pop() ?? directory;
  return {
    event: async ({ event }: any) => {
      const type = event?.type;
      if (!type) return;

      if (type === "session.idle") {
        const sessionID =
          event.properties?.sessionID ?? event.properties?.info?.id;
        if (!sessionID) return;
        projectOf.set(sessionID, project);
        const now = Date.now();
        if (now - (lastWrite.get(sessionID) ?? 0) >= IDLE_DEBOUNCE_MS) {
          lastWrite.set(sessionID, now);
          const turn = await summarizePrompt(client, sessionID);
          callCore("append_turn", [TOOL, sessionID, project, turn]);
        }
        // Periodically refresh the daily-file executive summary (idempotent upsert), so the
        // daily view stays current even for long sessions that never emit session.deleted.
        if (now - (lastSummary.get(sessionID) ?? 0) >= SUMMARIZE_EVERY_MS) {
          lastSummary.set(sessionID, now);
          callCore("summarize_session", [TOOL, sessionID, project]);
        }
        return;
      }

      if (type === "session.deleted") {
        const sessionID =
          event.properties?.sessionID ?? event.properties?.info?.id;
        if (!sessionID) return;
        const proj = projectOf.get(sessionID) ?? project;
        // Final executive summary for the daily file.
        callCore("summarize_session", [TOOL, sessionID, proj]);
      }
    },
  };
};
