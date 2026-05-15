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

import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { execSync } from "child_process";

const PORT = Number(process.env.DEV_HOME_PORT ?? 8080);
const __dir = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Static known services
// ---------------------------------------------------------------------------
const STATIC_SERVICES: Service[] = [
  {
    name: "OpenPortal",
    port: 3000,
    icon: "💻",
    description: "Mobile-friendly OpenCode UI",
    static: true,
  },
  {
    name: "OpenCode",
    port: 4096,
    icon: "🤖",
    description: "OpenCode API / web UI",
    static: true,
  },
  {
    name: "Plannotator",
    port: 19432,
    icon: "📋",
    description: "Plan annotation & review",
    static: true,
  },
];

interface Service {
  name: string;
  port: number;
  icon: string;
  description: string;
  static: boolean;
  containerName?: string;
}

// ---------------------------------------------------------------------------
// Docker port discovery
// ---------------------------------------------------------------------------
function getDockerServices(): Service[] {
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
        // Skip ports already covered by static services
        if (STATIC_SERVICES.some((s) => s.port === port)) continue;
        // Build a friendly name: prefer "project · service", fall back to container name
        const name = composeProject && composeService
          ? `${composeProject} · ${composeService}`
          : containerName;
        // Description: prefer named image over raw hash
        const imgDisplay = /^[0-9a-f]{12}$/.test(image) ? containerName : image;
        services.push({
          name,
          port,
          icon: "🐳",
          description: `Docker · ${imgDisplay}`,
          static: false,
          containerName,
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
      const docker = getDockerServices();
      const all = [...STATIC_SERVICES, ...docker];
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
