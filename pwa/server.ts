#!/usr/bin/env bun
/**
 * Dev Home — landing page PWA server
 *
 * Serves the PWA on port 8080 and exposes:
 *   GET /api/services  — list of known + Docker-discovered services
 *
 * The PWA rewrites service URLs to use window.location.hostname so
 * Tailscale IP and MagicDNS both work without any config.
 */

import { readFileSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { execSync } from "child_process";
import { homedir } from "os";

const PORT = Number(process.env.DEV_HOME_PORT ?? 8080);
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
    name: "Dev Home",
    port: PORT,
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
      // Web UI port
      if (inst.port) {
        services.push({
          name: projectName,
          port: inst.port,
          icon: "💻",
          description: `OpenPortal · ${dir}`,
          static: true,
          group: "OpenPortal",
        });
      }
      // OpenCode API port (distinct from UI port)
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
      // Parse published host ports, e.g. "0.0.0.0:8000->8000/tcp"
      const matches = [...(ports ?? "").matchAll(/0\.0\.0\.0:(\d+)->/g)];
      for (const m of matches) {
        const port = Number(m[1]);
        // Skip ports already covered by evergreen/portal services
        if (skipPorts.has(port)) continue;
        // Build a friendly name: prefer "project · service", fall back to container name
        const name = composeProject && composeService
          ? `${composeProject} · ${composeService}`
          : containerName;
        // Description: prefer named image over raw hash
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
// Check if a port is actually responding (quick TCP probe)
// ---------------------------------------------------------------------------
async function isPortOpen(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = Bun.connect({
      hostname: "127.0.0.1",
      port,
      socket: {
        open() { socket.end(); resolve(true); },
        error() { resolve(false); },
        connectError() { resolve(false); },
        close() {},
        data() {},
      },
    });
    setTimeout(() => resolve(false), 400);
  });
}

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------
const server = Bun.serve({
  port: PORT,
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
      // Probe each port concurrently
      const statuses = await Promise.all(all.map((s) => isPortOpen(s.port)));
      const result = all.map((s, i) => ({ ...s, online: statuses[i] }));
      return Response.json(result, {
        headers: { "Cache-Control": "no-store" },
      });
    }

    if (url.pathname === "/manifest.json") {
      return new Response(readFileSync(join(__dir, "manifest.json")), {
        headers: { "Content-Type": "application/manifest+json" },
      });
    }

    if (url.pathname === "/sw.js") {
      return new Response(readFileSync(join(__dir, "sw.js")), {
        headers: { "Content-Type": "application/javascript" },
      });
    }

    if (url.pathname === "/icon.svg") {
      return new Response(readFileSync(join(__dir, "icon.svg")), {
        headers: { "Content-Type": "image/svg+xml" },
      });
    }

    // Serve index.html for everything else
    return new Response(readFileSync(join(__dir, "index.html")), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  },
});

console.log(`Dev Home running at http://0.0.0.0:${PORT}`);
