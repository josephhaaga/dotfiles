/**
 * Hub plugin — on OpenCode startup:
 *   1. Starts the Hub HTTP server (if not already running)
 *   2. Starts openportal for the current directory (if available and not already registered)
 *
 * Placed in ~/.config/opencode/plugins/ so it applies globally.
 */

import { existsSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const HUB_PORT = Number(process.env.DEV_HOME_PORT ?? 8080);
const HUB_SERVER = join(import.meta.dirname, "..", "hub", "server.ts");
const PORTAL_CONFIG = join(homedir(), ".portal.json");

async function isHubRunning(): Promise<boolean> {
  try {
    const res = await fetch(`http://127.0.0.1:${HUB_PORT}`, {
      signal: AbortSignal.timeout(500),
    });
    return res.status > 0;
  } catch {
    return false;
  }
}

function isPortalRegistered(directory: string): boolean {
  try {
    const config = JSON.parse(readFileSync(PORTAL_CONFIG, "utf-8"));
    return (config.instances ?? []).some((i: { directory: string }) => i.directory === directory);
  } catch {
    return false;
  }
}

function startHub() {
  if (existsSync(HUB_SERVER)) {
    Bun.spawn(["bun", "run", HUB_SERVER], {
      stdio: ["ignore", "ignore", "ignore"],
      detached: true,
    });
  }
}

function startPortal(directory: string) {
  const name = directory.split("/").pop() ?? "project";
  Bun.spawn(
    ["bunx", "openportal", "--hostname", "0.0.0.0", "--directory", directory, "--name", name],
    { stdio: ["ignore", "ignore", "ignore"], detached: true }
  );
}

async function ensureStack(directory: string) {
  if (!(await isHubRunning())) startHub();
  if (!isPortalRegistered(directory)) startPortal(directory);
}

export const HubPlugin = async ({ directory }: { directory: string }) => {
  await ensureStack(directory);

  return {
    "session.created": async () => {
      await ensureStack(directory);
    },
  };
};
