---
name: Spaces Lab
description: Local space overview and shortcut inspector; not a dotfiles-wide identity.
colors:
  ground: "#edf1f6"
  paper: "#fff"
  ink: "#18283f"
  muted: "#53647b"
  line: "#c9d3df"
  blue: "#1859c9"
  wash: "#e9f0ff"
  danger: "#a22730"
  success: "#226044"
typography:
  headline:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    fontSize: "26px"
    fontWeight: 700
    lineHeight: 1.5
    letterSpacing: "-.025em"
  title:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.5
    letterSpacing: "-.015em"
  body:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.5
  shortcut:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "12px"
    lineHeight: 1.5
rounded:
  field: "4px"
  button: "5px"
  notice: "6px"
  surface: "8px"
spacing:
  control: "8px"
  field: "16px"
  map: "18px"
  panel: "20px"
  inspector: "22px"
  workbench: "24px"
components:
  button-primary:
    backgroundColor: "{colors.blue}"
    textColor: "{colors.paper}"
    rounded: "{rounded.button}"
    padding: "8px 12px"
  button-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.button}"
    padding: "8px 12px"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    rounded: "{rounded.button}"
    padding: "8px 12px"
  field:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "8px 10px"
  shortcut:
    typography: "{typography.shortcut}"
    rounded: "{rounded.field}"
    padding: "3px 7px"
  space-card:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.surface}"
  inspector:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.surface}"
    padding: "22px"
---

# Design System: Spaces Lab

## Overview

**Creative North Star: "Spaces Lab workbench"**

This document applies only to `home/dot_local/share/yabai-spaces/index.html`. The user selected a light, blue-accented space overview with an inspector. Cool-gray ground, white canvases, navy text, ruled rows, and restrained corners make destinations and source-editing state visible without decorative desktop imagery.

**Key Characteristics:**
- Functional space map and one linked inspector.
- Blue selection and actions; textual state and recovery guidance.
- System UI controls, monospace shortcuts, flat bordered surfaces.

## Colors

### Primary

Blue identifies primary actions, selection, links, caret, and focus. Wash marks selected headings and secondary hover. Primary hover darkens to `#1147a5`.

### Neutral

Ground surrounds paper surfaces. Ink carries primary text; muted carries supporting copy; line divides and frames. Fields use the stronger `#9dabbe` stroke. Shortcut caps use `#f3f6fa`, map headings `#f9fbfd`, and generated code `#f2f5fa`.

Danger marks removal and error text; success marks completed-operation text. Notices retain explanatory words, not color alone.

Sidecar tonal ramps are synthesized preview metadata, not additional application tokens. The frontmatter records the implemented custom properties.

**The Visible State Rule.** Pair selection and operation colors with explicit control or status semantics.

## Typography

System UI type serves this utility; there is no separate decorative display face. The headline reduces to (24px) on mobile. Section titles use the title role; space purposes use (20px), app names (14px, 600), and small help (13px). Shortcut caps and generated code use monospace; code line height is (1.7). Numeric text uses tabular figures. Keep purpose and app names wrapping rather than clipping.

## Layout

The centered main region caps at (1600px), with desktop padding (26px 32px 40px). The workbench pairs flexible overview with a (360px) inspector across a (24px) gap. Cards auto-fit from (225px); at widths of at least (1350px), the map has three equal columns. Inventory and configuration disclosure follow the map.

At widths up to (1000px), the inspector is (320px), map becomes one column, and horizontal page padding becomes (22px). At widths up to (740px), header and workbench stack, page padding is (20px), cards auto-fit from (220px), and the inspector becomes non-sticky below overview, inventory, and preview. Inventory app names move to their own row. Save actions wrap rather than disappear.

Desktop inspector sticks (20px) from the top. Mobile selection focuses Purpose and immediately scrolls to the inspector. “Back to space overview” returns focus to the selected map button and scrolls to the overview heading.

## Elevation & Depth

No shadows. Borders, surface tones, and a selected-card outline establish depth. Selection uses a blue (2px) outline; keyboard focus uses a blue (3px) outline with (3px) offset. Generated-code focus reduces the offset to (1px). Card border-color transitions last (.16s ease-out). Reduced-motion CSS disables transitions and smooth scrolling; no decorative animation exists.

## Shapes

Surface corners use the surface radius; controls use tighter button and field radii. Space headings meet their containers squarely. Shortcut caps have a doubled bottom border. Rows are divided with light rules, not floating tiles.

## Components

### Actions and fields

Save is primary; preview, add, refresh, and explicit tests are bordered secondary actions. Quiet controls retain a transparent background; removal uses danger text. Secondary hover adds wash and a blue stroke. Disabled controls use half opacity and a not-allowed cursor. Busy state disables save, preview, and test controls; save is also disabled when the draft is unchanged.

Fields use visible wrapping labels, contextual help, and native inputs. Shortcut fields accept typed skhd notation or modified-key capture. The optional routing checkbox is (18px), blue-accented, and off by default. Do not imply routing moves existing windows.

### Space overview and inspector

Each card exposes desktop index, purpose, jump shortcut, and app shortcuts. A native heading button carries `aria-pressed`; the selected card gets both wash and outline. The inspector has an accessible name and edits only the selected space. App removal restores focus to Add app shortcut; adding focuses the new app field; space removal restores focus to Purpose or Add space.

### Notices, inventory, and preview

The status notice uses `role="status"` and polite live announcements. Error and success notices preserve readable text. Live inventory is read-only and separate from the proposed map; unavailable inventory does not prevent draft editing. Native `details`/`summary` exposes generated configuration. Code blocks are keyboard-focusable, scrollable, and capped at (350px). Loading and empty states explain a bounded next action.

**The Source Boundary Rule.** Save, apply, and focus tests remain visibly distinct actions; saving never installs configuration or moves windows.

## Do's and Don'ts

- **Do** preserve visible labels, focus outlines, selection semantics, and status messages.
- **Do** keep planned spaces separate from read-only live inventory.
- **Do** preserve mobile focus transfer and the return-to-overview control.
- **Don't** attribute this surface's visual identity to the entire dotfiles repository.
- **Don't** collapse save, apply, and focus tests into one action or use color alone to communicate state.
