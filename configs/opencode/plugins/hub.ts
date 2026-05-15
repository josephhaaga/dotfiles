/**
 * Hub plugin — starts the Hub server when OpenCode starts,
 * if it isn't already running on port 8080.
 *
 * Placed in ~/.config/opencode/plugins/ so it applies globally.
 * The Hub server (hub/server.ts) handles openportal when run directly.
 */

import { existsSync } from "fs";
import { join } from "path";

const HUB_PORT = Number(process.env.DEV_HOME_PORT ?? 8080);
const HUB_SERVER = join(import.meta.dirname, "..", "hub", "server.ts");

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

export const HubPlugin = async () => {
  // Start eagerly at plugin load time (covers resumed sessions too)
  if (existsSync(HUB_SERVER) && !(await isHubRunning())) {
    Bun.spawn(["bun", "run", HUB_SERVER], {
      stdio: ["ignore", "ignore", "ignore"],
      detached: true,
    });
  }

  return {
    // Also catch any newly created sessions (e.g. first ever launch)
    "session.created": async () => {
      if (existsSync(HUB_SERVER) && !(await isHubRunning())) {
        Bun.spawn(["bun", "run", HUB_SERVER], {
          stdio: ["ignore", "ignore", "ignore"],
          detached: true,
        });
      }
    },
  };
};
