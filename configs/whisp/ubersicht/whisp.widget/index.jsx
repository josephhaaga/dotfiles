// whisp.widget — Übersicht overlay for the "whisp" voice dictation tool.
//
// Renders a native-macOS-OSD-style HUD (like the "AirPods moved to iPhone"
// panel) driven by /tmp/whisp/status.json. States:
//   chord | recording | transcribing | rewriting | inserted | error | idle
//
// idle (or no file) renders nothing.
//
// The panel is DRAGGABLE: click-and-drag it anywhere; the position persists
// (localStorage) across refreshes. A small × button dismisses it (sets the
// whisp status to idle). The rest of the screen stays click-through.
//
// NOTE: clicks/drag require Übersicht's "interaction shortcut" to be set AND
// Accessibility access granted (Übersicht preferences). Without it, the panel
// is display-only — use `~/.config/whisp/bin/whisp-status.sh idle` to dismiss.

import { run } from "uebersicht";

export const refreshFrequency = 200; // ms

// Read the status file; emit "{}" when it's missing so the widget hides.
export const command =
  "cat /tmp/whisp/status.json 2>/dev/null || echo '{}'";

// ---- glyph mapping (SF Symbol name -> unicode/emoji fallback) ------------
const GLYPHS = {
  "text.bubble": "💬",
  "chevron.left.forwardslash.chevron.right": "⌘",
  envelope: "✉️",
  waveform: "〜",
  "mic.fill": "🎙",
  "checkmark.circle.fill": "✓",
  "exclamationmark.triangle.fill": "⚠︎",
  hourglass: "⧗",
};
const glyph = (name, fallback) => (name && GLYPHS[name]) || fallback || "•";

// ---- persisted position --------------------------------------------------
const POS_KEY = "whisp.osd.pos";

const loadPos = () => {
  try {
    const raw = window.localStorage.getItem(POS_KEY);
    if (!raw) return null;
    const p = JSON.parse(raw);
    if (typeof p.x === "number" && typeof p.y === "number") return p;
  } catch (e) {}
  return null;
};
const savePos = (p) => {
  try {
    window.localStorage.setItem(POS_KEY, JSON.stringify(p));
  } catch (e) {}
};

// Clamp so the panel can't be dragged fully off-screen.
const clamp = (p) => {
  const m = 8;
  const w = window.innerWidth || 1440;
  const h = window.innerHeight || 900;
  return {
    x: Math.max(m, Math.min(p.x, w - 80)),
    y: Math.max(m, Math.min(p.y, h - 60)),
  };
};

// Attach drag behavior to the panel node via a ref callback. Module-level
// state survives re-renders (render() runs every refreshFrequency).
let dragState = { down: false, startX: 0, startY: 0, baseX: 0, baseY: 0 };

const makeDraggable = (node) => {
  if (!node || node.__whispDragBound) return;
  node.__whispDragBound = true;

  const onDown = (e) => {
    // ignore drags starting on the dismiss button
    if (e.target && e.target.closest && e.target.closest(".whisp-close")) return;
    const pos = loadPos() || nodeCenterPos(node);
    dragState = {
      down: true,
      startX: e.clientX,
      startY: e.clientY,
      baseX: pos.x,
      baseY: pos.y,
    };
    node.classList.add("dragging");
    e.preventDefault();
  };
  const onMove = (e) => {
    if (!dragState.down) return;
    const next = clamp({
      x: dragState.baseX + (e.clientX - dragState.startX),
      y: dragState.baseY + (e.clientY - dragState.startY),
    });
    applyPos(node, next);
  };
  const onUp = () => {
    if (!dragState.down) return;
    dragState.down = false;
    node.classList.remove("dragging");
    savePos(readPos(node));
  };

  node.addEventListener("mousedown", onDown);
  window.addEventListener("mousemove", onMove);
  window.addEventListener("mouseup", onUp);

  // Apply any persisted position immediately.
  const saved = loadPos();
  if (saved) applyPos(node, clamp(saved));
};

const applyPos = (node, p) => {
  node.style.left = p.x + "px";
  node.style.top = p.y + "px";
  node.style.right = "auto";
  node.style.bottom = "auto";
  node.style.transform = "none";
  node.style.position = "fixed";
};
const readPos = (node) => ({
  x: parseFloat(node.style.left) || 0,
  y: parseFloat(node.style.top) || 0,
});
const nodeCenterPos = (node) => {
  const r = node.getBoundingClientRect();
  return { x: r.left, y: r.top };
};

// ---- container: full-screen, click-through EXCEPT the panel --------------
export const className = `
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;          /* screen stays click-through */
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
  -webkit-font-smoothing: antialiased;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 9999;

  .whisp-osd {
    pointer-events: auto;        /* the panel itself IS interactive/draggable */
    position: relative;
    margin-bottom: 16vh;         /* default spot until dragged */
    min-width: 220px;
    max-width: 460px;
    padding: 18px 22px;
    border-radius: 20px;
    background: rgba(30, 30, 30, 0.6);
    -webkit-backdrop-filter: blur(30px) saturate(150%);
    backdrop-filter: blur(30px) saturate(150%);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
    border: 0.5px solid rgba(255, 255, 255, 0.14);
    color: #fff;
    text-align: center;
    cursor: grab;
    animation: whisp-in 120ms ease-out;
  }
  .whisp-osd.dragging { cursor: grabbing; animation: none; }
  .whisp-osd.fade { animation: whisp-out 400ms ease forwards; }

  /* error panels: persistent, tinted, readable wrapping message */
  .whisp-osd.is-error {
    border-color: rgba(255, 69, 58, 0.5);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45), 0 0 0 1px rgba(255, 69, 58, 0.25) inset;
  }
  .whisp-osd.is-error .whisp-title { color: #ff6961; }
  .whisp-osd.is-error .whisp-sub {
    color: rgba(255, 255, 255, 0.92);
    font-size: 13px;
    max-width: 380px;
    white-space: normal;
    word-break: break-word;
    margin-left: auto;
    margin-right: auto;
  }
  .whisp-hint {
    margin-top: 8px;
    font-size: 11px;
    color: rgba(255, 255, 255, 0.45);
  }

  /* drag handle affordance */
  .whisp-grip {
    width: 34px; height: 4px;
    margin: -6px auto 10px;
    border-radius: 2px;
    background: rgba(255, 255, 255, 0.22);
  }

  /* dismiss button */
  .whisp-close {
    position: absolute;
    top: 8px; right: 10px;
    width: 18px; height: 18px;
    line-height: 16px;
    text-align: center;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.14);
    color: rgba(255, 255, 255, 0.8);
    font-size: 12px;
    cursor: pointer;
    pointer-events: auto;
    user-select: none;
  }
  .whisp-close:hover { background: rgba(255, 255, 255, 0.28); color: #fff; }

  .whisp-glyph { font-size: 40px; line-height: 1; margin-bottom: 10px; }
  .whisp-title { font-size: 15px; font-weight: 600; letter-spacing: 0.2px; }
  .whisp-sub {
    margin-top: 3px; font-size: 12px; font-weight: 400;
    color: rgba(255, 255, 255, 0.6);
  }

  .whisp-rec-dot {
    display: inline-block;
    width: 11px; height: 11px;
    margin-right: 8px;
    border-radius: 50%;
    background: #ff453a;
    vertical-align: middle;
    animation: whisp-pulse 1s ease-in-out infinite;
  }

  .whisp-keys {
    margin-top: 6px;
    display: flex; flex-direction: column; gap: 7px;
    text-align: left;
  }
  .whisp-keyrow {
    display: grid; grid-template-columns: auto 1fr;
    gap: 12px; align-items: center;
  }
  .whisp-key {
    justify-self: center; min-width: 20px;
    padding: 2px 8px; border-radius: 7px;
    background: rgba(255, 255, 255, 0.16);
    font-size: 13px; font-weight: 600;
    font-variant: small-caps; text-align: center;
  }
  .whisp-keylabel { font-size: 13px; color: rgba(255, 255, 255, 0.92); align-self: center; }
  .whisp-keyglyph { margin-right: 6px; opacity: 0.85; }

  @keyframes whisp-in {
    from { opacity: 0; transform: translateY(8px) scale(0.98); }
    to   { opacity: 1; transform: translateY(0)   scale(1); }
  }
  @keyframes whisp-out { from { opacity: 1; } to { opacity: 0; } }
  @keyframes whisp-pulse {
    0%, 100% { opacity: 1;   transform: scale(1); }
    50%      { opacity: 0.4; transform: scale(0.85); }
  }
`;

const parse = (output) => {
  try {
    return JSON.parse(output && output.trim() ? output : "{}");
  } catch (e) {
    return {};
  }
};

// Dismiss: set whisp status to idle via the `run` helper imported from
// the uebersicht module (requires interaction shortcut + Accessibility).
const dismiss = (e) => {
  if (e) {
    e.stopPropagation();
    e.preventDefault();
  }
  try {
    run("~/.config/whisp/bin/whisp-status.sh idle");
  } catch (err) {}
};

export const render = ({ output }) => {
  const s = parse(output);
  const state = s.state || "idle";
  if (!state || state === "idle") return <div />;

  const closeBtn = (
    <div className="whisp-close" onClick={dismiss} title="Dismiss">
      ×
    </div>
  );
  const grip = <div className="whisp-grip" />;

  // which-key chord panel
  if (state === "chord") {
    const modes = Array.isArray(s.modes) ? s.modes : [];
    return (
      <div>
        <div className="whisp-osd" ref={makeDraggable}>
          {closeBtn}
          {grip}
          <div className="whisp-glyph">{glyph("mic.fill", "🎙")}</div>
          <div className="whisp-title">whisp</div>
          <div className="whisp-sub">pick a mode</div>
          <div className="whisp-keys">
            {modes.map((m) => (
              <div className="whisp-keyrow" key={m.id}>
                <span className="whisp-key">{m.key}</span>
                <span className="whisp-keylabel">
                  <span className="whisp-keyglyph">{glyph(m.icon, "•")}</span>
                  {m.label}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // status panels
  let g = glyph(s.icon, "🎙");
  let title = s.label || "whisp";
  let sub = "";
  let fade = false;
  let dot = null;

  switch (state) {
    case "recording":
      dot = <span className="whisp-rec-dot" />;
      title = "Recording";
      sub = s.label ? `${s.label}` : "";
      break;
    case "transcribing":
      g = glyph("waveform", "〜");
      title = "Transcribing…";
      sub = s.label || "";
      break;
    case "rewriting":
      g = glyph("hourglass", "⧗");
      title = "Rewriting…";
      sub = [s.provider, s.model].filter(Boolean).join(" · ");
      break;
    case "inserted":
      g = glyph("checkmark.circle.fill", "✓");
      title = "Inserted";
      sub = s.label || "";
      fade = true;
      break;
    case "error":
      g = glyph("exclamationmark.triangle.fill", "⚠︎");
      title = "whisp error";
      sub = s.message || "";
      fade = false; // errors persist until dismissed (× / Escape / next chord)
      break;
    default:
      return <div />;
  }

  return (
    <div>
      <div className={`whisp-osd${fade ? " fade" : ""}${state === "error" ? " is-error" : ""}`} ref={makeDraggable}>
        {closeBtn}
        {grip}
        <div className="whisp-glyph">{dot}{g}</div>
        <div className="whisp-title">{title}</div>
        {sub ? <div className="whisp-sub">{sub}</div> : null}
        {state === "error" ? (
          <div className="whisp-hint">⌃⌥V to dismiss · auto-clears shortly</div>
        ) : null}
      </div>
    </div>
  );
};
