#!/usr/bin/env bun
/**
 * Hub — landing page PWA server + dev stack launcher
 *
 * When run directly (`bun run server.ts`):
 *   - Starts openportal for the current directory (if available)
 *   - Starts the Hub HTTP server on port 8080 (if not already running)
 *   - Prints Tailscale URLs and waits; Ctrl-C tears everything down
 *
 * When imported as a module (e.g. from the hub.ts plugin):
 *   - Only the HTTP server starts (no openportal, no process management)
 *
 * Endpoints:
 *   GET  /api/meta              — home dir, hostname
 *   GET  /api/services          — all services with status
 *   GET  /api/stats             — battery, CPU, RAM
 *   DELETE /api/portal/:name    — stop + remove a portal instance
 *   POST /api/push/subscribe    — register Web Push subscription
 *   GET  /api/push/vapid-key    — VAPID public key
 */

import { readFileSync, existsSync, writeFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { execSync, spawnSync } from "child_process";
import { homedir } from "os";

export const HUB_PORT = Number(process.env.DEV_HOME_PORT ?? 8080);
const __dir = dirname(fileURLToPath(import.meta.url));
const PORTAL_CONFIG = join(homedir(), ".portal.json");
const PUSH_SUBS_FILE = join(homedir(), ".hub-push-subscriptions.json");
const VAPID_FILE = join(homedir(), ".hub-vapid.json");

// ---------------------------------------------------------------------------
// Evergreen services (always shown, fixed ports)
// ---------------------------------------------------------------------------
const EVERGREEN_SERVICES: Service[] = [
  {
    name: "Plannotator",
    port: 19432,
    icon: "📋",
    description: "Plan annotation & review",
    static: true,
  },
  {
    name: "Hub",
    port: HUB_PORT,
    icon: "🏠",
    description: "This page",
    static: true,
  },
];

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface Service {
  name: string;
  port: number;
  icon: string;
  description: string;
  static: boolean;
  group?: string;
  branch?: string;
  containerName?: string;
  composeProject?: string;
  instanceName?: string;
  opencodePort?: number;
  stale?: boolean;
  sessionStatus?: "idle" | "running" | "error";
}

// ---------------------------------------------------------------------------
// Read live openportal instances from ~/.portal.json
// ---------------------------------------------------------------------------
function getPortalServices(): Service[] {
  try {
    if (!existsSync(PORTAL_CONFIG)) return [];
    const config = JSON.parse(readFileSync(PORTAL_CONFIG, "utf-8"));
    const services: Service[] = [];
    for (const inst of config.instances ?? []) {
      const dir = inst.directory ?? inst.name ?? "unknown";
      const instanceName = inst.name ?? dir.split("/").pop();

      // Detect stale: check if the opencode process is still alive
      let stale = false;
      if (inst.opencodePid) {
        try { process.kill(inst.opencodePid, 0); }
        catch { stale = true; }
      }

      // Git branch for this directory
      let branch: string | undefined;
      try {
        branch = execSync("git branch --show-current", {
          cwd: dir, encoding: "utf8", timeout: 1000, stdio: ["ignore", "pipe", "ignore"],
        }).trim() || undefined;
      } catch { /* not a git repo or git not available */ }

      if (inst.port) {
        services.push({
          name: "OpenPortal",
          port: inst.port,
          icon: "🔮",
          description: dir,
          static: true,
          group: dir,
          branch,
          instanceName,
          opencodePort: inst.opencodePort,
          stale,
        });
      }
      if (inst.opencodePort) {
        services.push({
          name: "OpenCode",
          port: inst.opencodePort,
          icon: "__opencode__",
          description: dir,
          static: true,
          group: dir,
          branch,
          instanceName,
          opencodePort: inst.opencodePort,
          stale,
        });
      }
    }
    return services;
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Docker port discovery
// ---------------------------------------------------------------------------
function getDockerServices(skipPorts: Set<number> = new Set()): Service[] {
  try {
    const raw = execSync(
      "docker ps --format '{{.Names}}\\t{{.Ports}}\\t{{.Image}}\\t{{.Label \"com.docker.compose.service\"}}\\t{{.Label \"com.docker.compose.project\"}}'",
      { timeout: 3000, encoding: "utf8" }
    );
    const services: Service[] = [];
    for (const line of raw.trim().split("\n")) {
      if (!line) continue;
      const [containerName, ports, image, composeService, composeProject] = line.split("\t");
      const matches = [...(ports ?? "").matchAll(/0\.0\.0\.0:(\d+)->/g)];
      for (const m of matches) {
        const port = Number(m[1]);
        if (skipPorts.has(port)) continue;
        const imgDisplay = /^[0-9a-f]{12}$/.test(image) ? containerName : image;
        services.push({
          name: composeService || containerName,
          port,
          icon: "🐳",
          description: imgDisplay,
          static: false,
          containerName,
          composeProject: composeProject || undefined,
        });
      }
    }
    return services;
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Port probe
// ---------------------------------------------------------------------------
async function isPortOpen(port: number): Promise<boolean> {
  try {
    const res = await fetch(`http://127.0.0.1:${port}`, {
      signal: AbortSignal.timeout(800),
    });
    return res.status > 0;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Session status — poll the OpenCode API for the most recent session state
// ---------------------------------------------------------------------------
async function getSessionStatus(opencodePort: number): Promise<"idle" | "running" | "error"> {
  try {
    const res = await fetch(`http://127.0.0.1:${opencodePort}/session`, {
      signal: AbortSignal.timeout(800),
    });
    if (!res.ok) return "error";
    const sessions: Array<{ time: { updated: number } }> = await res.json();
    if (!sessions.length) return "idle";
    // Sort by most recently updated
    const latest = sessions.sort((a, b) => b.time.updated - a.time.updated)[0];
    const age = Date.now() - latest.time.updated;
    // If updated within last 5 seconds, consider it running
    return age < 5000 ? "running" : "idle";
  } catch {
    return "error";
  }
}

// ---------------------------------------------------------------------------
// Machine stats — battery, CPU, RAM (macOS)
// ---------------------------------------------------------------------------
function getMachineStats() {
  const stats: Record<string, unknown> = {};

  // Battery
  try {
    const batt = execSync("pmset -g batt", { encoding: "utf8", timeout: 2000 });
    const pctMatch = batt.match(/(\d+)%/);
    const charging = batt.includes("charging") || batt.includes("AC Power");
    const remainMatch = batt.match(/(\d+:\d+) remaining/);
    if (pctMatch) {
      stats.battery = {
        pct: Number(pctMatch[1]),
        charging,
        remaining: remainMatch?.[1] ?? null,
      };
    }
  } catch { /* no battery / non-macOS */ }

  // CPU
  try {
    const topOut = execSync("top -l 1 -n 0 -s 0", { encoding: "utf8", timeout: 3000 });
    const cpuLine = topOut.match(/CPU usage:\s*([\d.]+)%\s*user,\s*([\d.]+)%\s*sys,\s*([\d.]+)%\s*idle/);
    if (cpuLine) {
      stats.cpu = {
        user: parseFloat(cpuLine[1]),
        sys: parseFloat(cpuLine[2]),
        idle: parseFloat(cpuLine[3]),
        used: Math.round(parseFloat(cpuLine[1]) + parseFloat(cpuLine[2])),
      };
    }
  } catch { /* non-macOS */ }

  // RAM via vm_stat
  try {
    const vmOut = execSync("vm_stat", { encoding: "utf8", timeout: 2000 });
    const pageSize = 16384;
    const get = (key: string) => {
      const m = vmOut.match(new RegExp(`${key}:\\s+(\\d+)`));
      return m ? Number(m[1]) * pageSize : 0;
    };
    const free = get("Pages free") + get("Pages speculative");
    const active = get("Pages active");
    const inactive = get("Pages inactive");
    const wired = get("Pages wired down");
    const compressed = get("Pages occupied by compressor");
    const total = free + active + inactive + wired + compressed;
    const used = active + wired + compressed;
    stats.ram = {
      usedGB: Math.round(used / 1e9 * 10) / 10,
      totalGB: Math.round(total / 1e9 * 10) / 10,
      pct: Math.round(used / total * 100),
    };
  } catch { /* non-macOS */ }

  return stats;
}

// ---------------------------------------------------------------------------
// VAPID key management (lazy init)
// ---------------------------------------------------------------------------
function getVapidKeys(): { publicKey: string; privateKey: string } | null {
  try {
    if (existsSync(VAPID_FILE)) {
      return JSON.parse(readFileSync(VAPID_FILE, "utf-8"));
    }
    // Generate new keys using openssl
    const privateKeyRaw = execSync("openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -outform DER 2>/dev/null | tail -c 32 | base64", { encoding: "utf8", timeout: 5000 }).trim();
    // For simplicity, use web-push if available, otherwise skip
    return null;
  } catch {
    return null;
  }
}

// Push subscriptions store
function getPushSubscriptions(): unknown[] {
  try {
    if (!existsSync(PUSH_SUBS_FILE)) return [];
    return JSON.parse(readFileSync(PUSH_SUBS_FILE, "utf-8"));
  } catch { return []; }
}

function savePushSubscription(sub: unknown) {
  const subs = getPushSubscriptions();
  // Deduplicate by endpoint
  const endpoint = (sub as { endpoint: string }).endpoint;
  const filtered = subs.filter((s) => (s as { endpoint: string }).endpoint !== endpoint);
  filtered.push(sub);
  writeFileSync(PUSH_SUBS_FILE, JSON.stringify(filtered, null, 2));
}

// ---------------------------------------------------------------------------
// Session watcher — fires Web Push when a session goes idle
// ---------------------------------------------------------------------------
const sessionWasRunning = new Map<number, boolean>();

async function checkAndNotify(opencodePort: number, instanceName: string) {
  const status = await getSessionStatus(opencodePort);
  const wasRunning = sessionWasRunning.get(opencodePort) ?? false;
  sessionWasRunning.set(opencodePort, status === "running");

  if (wasRunning && status === "idle") {
    // Session just went idle — send push notification
    const subs = getPushSubscriptions();
    if (subs.length === 0) return;
    // Use web-push if available
    try {
      const webPush = await import("web-push");
      const vapid = getVapidKeys();
      if (!vapid) return;
      webPush.setVapidDetails("mailto:hub@localhost", vapid.publicKey, vapid.privateKey);
      const payload = JSON.stringify({ title: `${instanceName} is idle`, body: "OpenCode finished." });
      for (const sub of subs) {
        webPush.sendNotification(sub as Parameters<typeof webPush.sendNotification>[0], payload).catch(() => {});
      }
    } catch { /* web-push not installed */ }
  }
}

// Poll every 10 seconds for session status changes
setInterval(async () => {
  try {
    if (!existsSync(PORTAL_CONFIG)) return;
    const config = JSON.parse(readFileSync(PORTAL_CONFIG, "utf-8"));
    for (const inst of config.instances ?? []) {
      if (inst.opencodePort) {
        const name = inst.name ?? inst.directory?.split("/").pop() ?? "project";
        await checkAndNotify(inst.opencodePort, name);
      }
    }
  } catch { /* ignore */ }
}, 10_000);

// ---------------------------------------------------------------------------
// Guard: exit cleanly if Hub is already running
// ---------------------------------------------------------------------------
try {
  const probe = Bun.listen({
    hostname: "127.0.0.1",
    port: HUB_PORT,
    socket: { open(s) { s.end(); }, data() {}, close() {}, error() {} },
  });
  probe.stop();
} catch {
  console.log(`Hub is already running at http://0.0.0.0:${HUB_PORT}`);
  process.exit(0);
}

// ---------------------------------------------------------------------------
// HTTP server
// ---------------------------------------------------------------------------
export const server = Bun.serve({
  port: HUB_PORT,
  hostname: "0.0.0.0",
  async fetch(req) {
    const url = new URL(req.url);

    // CORS for local dev
    const headers = { "Cache-Control": "no-store", "Access-Control-Allow-Origin": "*" };

    if (url.pathname === "/api/meta") {
      return Response.json({ home: homedir() }, { headers });
    }

    if (url.pathname === "/api/stats") {
      return Response.json(getMachineStats(), { headers });
    }

    if (url.pathname === "/api/services") {
      const portal = getPortalServices();
      const evergreen = EVERGREEN_SERVICES;
      const allStaticPorts = new Set([
        ...evergreen.map(s => s.port),
        ...portal.map(s => s.port),
      ]);
      const docker = getDockerServices(allStaticPorts);
      const all = [...evergreen, ...portal, ...docker];

      // Probe ports + session statuses concurrently
      const [statuses, sessionStatuses] = await Promise.all([
        Promise.all(all.map((s) => isPortOpen(s.port))),
        Promise.all(all.map((s) =>
          s.opencodePort ? getSessionStatus(s.opencodePort) : Promise.resolve(undefined)
        )),
      ]);

      const result = all.map((s, i) => ({
        ...s,
        online: statuses[i],
        sessionStatus: sessionStatuses[i],
      }));
      return Response.json(result, { headers });
    }

    // DELETE /api/portal/:name — stop a portal instance
    if (url.pathname.startsWith("/api/portal/") && req.method === "DELETE") {
      const name = decodeURIComponent(url.pathname.slice("/api/portal/".length));
      try {
        spawnSync("bunx", ["openportal", "stop", "--name", name], { stdio: "ignore", timeout: 5000 });
        spawnSync("bunx", ["openportal", "clean"], { stdio: "ignore", timeout: 5000 });
        return Response.json({ ok: true }, { headers });
      } catch (e) {
        return Response.json({ ok: false, error: String(e) }, { status: 500, headers });
      }
    }

    // POST /api/push/subscribe
    if (url.pathname === "/api/push/subscribe" && req.method === "POST") {
      try {
        const sub = await req.json();
        savePushSubscription(sub);
        return Response.json({ ok: true }, { headers });
      } catch {
        return Response.json({ ok: false }, { status: 400, headers });
      }
    }

    // GET /api/push/vapid-key
    if (url.pathname === "/api/push/vapid-key") {
      const vapid = getVapidKeys();
      if (!vapid) return Response.json({ key: null }, { headers });
      return Response.json({ key: vapid.publicKey }, { headers });
    }

    if (url.pathname === "/manifest.json")
      return new Response(readFileSync(join(__dir, "manifest.json")), {
        headers: { "Content-Type": "application/manifest+json" },
      });

    if (url.pathname === "/sw.js")
      return new Response(readFileSync(join(__dir, "sw.js")), {
        headers: { "Content-Type": "application/javascript" },
      });

    if (url.pathname === "/icon.svg")
      return new Response(readFileSync(join(__dir, "icon.svg")), {
        headers: { "Content-Type": "image/svg+xml" },
      });

    return new Response(readFileSync(join(__dir, "index.html")), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  },
});

// ---------------------------------------------------------------------------
// When run directly: also manage openportal + process lifecycle
// ---------------------------------------------------------------------------
if (import.meta.main) {
  // Ensure Homebrew binaries are available
  try {
    const brew = spawnSync("/opt/homebrew/bin/brew", ["shellenv"], { encoding: "utf8" });
    if (brew.stdout) {
      for (const line of brew.stdout.split("\n")) {
        const m = line.match(/^export PATH="(.+?)"/);
        if (m) process.env.PATH = m[1];
      }
    }
  } catch { /* non-macOS or no Homebrew */ }

  const projectName = process.env.PROJECT_NAME ?? require("path").basename(process.cwd());
  const tailscaleIp = (() => {
    try { return execSync("tailscale ip -4", { encoding: "utf8", timeout: 3000 }).trim(); }
    catch { return "<tailscale-ip>"; }
  })();

  // Plannotator remote mode
  process.env.PLANNOTATOR_REMOTE = "1";
  process.env.PLANNOTATOR_PORT = process.env.PLANNOTATOR_PORT ?? "19432";

  // Clear OpenCode auth so openportal proxies cleanly
  delete process.env.OPENCODE_SERVER_PASSWORD;
  delete process.env.OPENCODE_SERVER_USERNAME;

  // Check if openportal is available
  const hasPortal = spawnSync("bunx", ["openportal", "--help"], {
    stdio: "ignore", timeout: 5000,
  }).status === 0;

  let portalProc: ReturnType<typeof Bun.spawn> | null = null;

  if (hasPortal) {
    spawnSync("bunx", ["openportal", "stop", "--name", projectName], { stdio: "ignore", timeout: 5000 });
    spawnSync("bunx", ["openportal", "clean"], { stdio: "ignore", timeout: 5000 });

    portalProc = Bun.spawn(
      ["bunx", "openportal", "--hostname", "0.0.0.0", "--directory", process.cwd(), "--name", projectName],
      { stdio: ["ignore", "inherit", "inherit"] }
    );

    await Bun.sleep(2000);
  }

  console.log(`  Hub:         http://${tailscaleIp}:${HUB_PORT}  ← open this on your phone`);
  console.log(`  Project:     ${projectName}`);
  console.log(`  Plannotator: http://${tailscaleIp}:${process.env.PLANNOTATOR_PORT}`);
  if (hasPortal) console.log(`  (OpenPortal + OpenCode ports auto-assigned — see Hub)`);
  console.log("");
  console.log("Press Ctrl-C to stop.");
  console.log("");

  const shutdown = () => {
    console.log("\nShutting down...");
    portalProc?.kill();
    server.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  await new Promise(() => {});
}
