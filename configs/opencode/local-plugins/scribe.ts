/**
 * Scribe plugin — background knowledge-base capture for OpenCode.
 *
 * Writes incremental work logs to the Obsidian vault so a crashed or long-running
 * session still leaves a trail (per project requirement: turn-end + session-end + idle).
 *
 * Capture is deterministic and file-direct (does not depend on the agent choosing to
 * call a tool): on session idle the plugin summarizes recent activity from the session
 * and appends a bullet to today's daily note under a per-session heading. On session
 * deletion it appends a rollup marker.
 *
 * Vault path comes from SEEKSTONE_VAULT (shared with the Seekstone MCP server) or falls
 * back to ~/Documents/obsidian-vault.
 *
 * Placed in ~/.config/opencode/local-plugins/ and registered in opencode.json.
 */

import { appendFileSync, existsSync, mkdirSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const VAULT =
  process.env.SEEKSTONE_VAULT ?? join(homedir(), "Documents", "obsidian-vault");
const DAILY_DIR = join(VAULT, "Daily");

// Debounce so we don't write on every micro-idle; one checkpoint per window per session.
const IDLE_DEBOUNCE_MS = 90_000;
const lastWrite = new Map<string, number>(); // sessionID -> epoch ms
const headingWritten = new Set<string>(); // sessionID that already have a heading today

function todayStamp(): string {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD
}

function dailyPath(): string {
  return join(DAILY_DIR, `${todayStamp()}.md`);
}

function nowTime(): string {
  return new Date().toLocaleTimeString("en-US", { hour12: false });
}

function ensureDaily(): string {
  const path = dailyPath();
  if (!existsSync(DAILY_DIR)) mkdirSync(DAILY_DIR, { recursive: true });
  if (!existsSync(path)) {
    const stamp = todayStamp();
    appendFileSync(
      path,
      `---\ntype: daily\ndate: ${stamp}\ntags: [daily]\n---\n# ${stamp}\n\n## Log\n\n## Sessions\n`,
    );
  }
  return path;
}

function sessionKey(sessionID: string): string {
  return `${todayStamp()}::${sessionID}`;
}

function ensureHeading(path: string, sessionID: string, directory: string) {
  const key = sessionKey(sessionID);
  if (headingWritten.has(key)) return;
  // Guard against a heading already present from a previous run today.
  try {
    const existing = readFileSync(path, "utf-8");
    if (existing.includes(`## Session ${sessionID}`)) {
      headingWritten.add(key);
      return;
    }
  } catch {
    /* file may not exist yet */
  }
  const project = directory.split("/").pop() ?? directory;
  appendFileSync(
    path,
    `\n## Session ${sessionID}\n*${project}* — started ${nowTime()}\n`,
  );
  headingWritten.add(key);
}

function appendBullet(sessionID: string, directory: string, text: string) {
  const path = ensureDaily();
  ensureHeading(path, sessionID, directory);
  appendFileSync(path, `- \`${nowTime()}\` ${text}\n`);
}

/**
 * Summarize recent session activity into one short line. Best-effort: pulls the last
 * user prompt and a count of tool actions from the SDK if available; otherwise a
 * generic checkpoint. Kept terse on purpose.
 */
async function summarize(
  client: any,
  sessionID: string,
): Promise<string> {
  try {
    const res = await client.session.messages({ path: { id: sessionID } });
    const messages = (res?.data ?? res ?? []) as any[];
    const lastUser = [...messages]
      .reverse()
      .find((m) => (m.info?.role ?? m.role) === "user");
    let prompt = "";
    const parts = lastUser?.parts ?? [];
    for (const p of parts) {
      if (p.type === "text" && p.text) {
        prompt = p.text;
        break;
      }
    }
    prompt = prompt.replace(/\s+/g, " ").trim().slice(0, 140);
    const toolCount = messages
      .flatMap((m: any) => m.parts ?? [])
      .filter((p: any) => p.type === "tool").length;
    if (prompt) return `checkpoint — "${prompt}" (${toolCount} tool actions)`;
    return `checkpoint — ${toolCount} tool actions`;
  } catch {
    return "checkpoint";
  }
}

export const ScribePlugin = async ({ client, directory }: any) => {
  return {
    event: async ({ event }: any) => {
      const type = event?.type;
      if (!type) return;

      // Turn-end / idle checkpoint (session.idle fires after each assistant response).
      if (type === "session.idle") {
        const sessionID = event.properties?.sessionID ?? event.properties?.info?.id;
        if (!sessionID) return;
        const last = lastWrite.get(sessionID) ?? 0;
        if (Date.now() - last < IDLE_DEBOUNCE_MS) return;
        lastWrite.set(sessionID, Date.now());
        const line = await summarize(client, sessionID);
        try {
          appendBullet(sessionID, directory, line);
        } catch {
          /* never crash the session over a log write */
        }
        return;
      }

      // Session end — rollup marker. (A deeper LLM rollup is handled by agent
      // instructions in AGENTS.md; here we guarantee a boundary line lands.)
      if (type === "session.deleted") {
        const sessionID = event.properties?.sessionID ?? event.properties?.info?.id;
        if (!sessionID) return;
        try {
          appendBullet(sessionID, directory, `session ended`);
        } catch {
          /* ignore */
        }
      }
    },
  };
};
