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
 * GET /api/services — list of known + Docker-discovered services
 */

import { readFileSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { execSync, spawnSync } from "child_process";
import { homedir } from "os";

export const HUB_PORT = Number(process.env.DEV_HOME_PORT ?? 8080);
const __dir = dirname(fileURLToPath(import.meta.url));
const PORTAL_CONFIG = join(homedir(), ".portal.json");

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
// Read live openportal instances from ~/.portal.json
// ---------------------------------------------------------------------------
function getPortalServices(): Service[] {
  try {
    if (!existsSync(PORTAL_CONFIG)) return [];
    const config = JSON.parse(readFileSync(PORTAL_CONFIG, "utf-8"));
    const services: Service[] = [];
    for (const inst of config.instances ?? []) {
      const dir = inst.directory ?? inst.name ?? "unknown";
      const projectName = dir.split("/").pop() ?? inst.name;
      if (inst.port) {
        services.push({
          name: projectName,
          port: inst.port,
          icon: "🔮",
          description: `OpenPortal · ${dir}`,
          static: true,
          group: "OpenPortal",
        });
      }
      if (inst.opencodePort && inst.opencodePort !== inst.port) {
        services.push({
          name: projectName,
          port: inst.opencodePort,
          icon: "🤖",
          description: `OpenCode · ${dir}`,
          static: true,
          group: "OpenCode",
        });
      }
    }
    return services;
  } catch {
    return [];
  }
}

interface Service {
  name: string;
  port: number;
  icon: string;
  description: string;
  static: boolean;
  group?: string;
  containerName?: string;
  composeProject?: string;
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

    if (url.pathname === "/api/services") {
      const portal = getPortalServices();
      const evergreen = EVERGREEN_SERVICES;
      const allStaticPorts = new Set([
        ...evergreen.map(s => s.port),
        ...portal.map(s => s.port),
      ]);
      const docker = getDockerServices(allStaticPorts);
      const all = [...evergreen, ...portal, ...docker];
      const statuses = await Promise.all(all.map((s) => isPortOpen(s.port)));
      const result = all.map((s, i) => ({ ...s, online: statuses[i] }));
      return Response.json(result, { headers: { "Cache-Control": "no-store" } });
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
    // Clean up stale entries for this directory
    spawnSync("bunx", ["openportal", "stop", "--name", projectName], { stdio: "ignore", timeout: 5000 });
    spawnSync("bunx", ["openportal", "clean"], { stdio: "ignore", timeout: 5000 });

    portalProc = Bun.spawn(
      ["bunx", "openportal", "--hostname", "0.0.0.0", "--directory", process.cwd(), "--name", projectName],
      { stdio: ["ignore", "inherit", "inherit"] }
    );

    // Give openportal a moment to register ports in ~/.portal.json
    await Bun.sleep(2000);
  }

  console.log(`  Hub:         http://${tailscaleIp}:${HUB_PORT}  ← open this on your phone`);
  console.log(`  Project:     ${projectName}`);
  console.log(`  Plannotator: http://${tailscaleIp}:${process.env.PLANNOTATOR_PORT}`);
  if (hasPortal) console.log(`  (OpenPortal + OpenCode ports auto-assigned — see Hub)`);
  console.log("");
  console.log("Press Ctrl-C to stop.");
  console.log("");

  // Teardown on exit
  const shutdown = () => {
    console.log("\nShutting down...");
    portalProc?.kill();
    server.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  // Keep process alive
  await new Promise(() => {});
}
