# Yabai Spaces Lab

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

The user chose a local browser app. Implementation choice: Python standard-library loopback server and plain HTML, CSS, and JavaScript, with no new packages.

## Users

The dotfiles owner wants to stop manually hunting for windows across macOS spaces and experiment with shortcuts for apps or purposes.

## Product Purpose

Show all proposed spaces and keybinds together. Edit a plan, check conflicts with existing skhd bindings, preview generated configuration, and explicitly test destinations.

## Operating Context

The active chezmoi source is `home/`. macOS uses yabai and skhd. Existing window-management bindings remain intact. The app is a development tool launched from this repository.

## Capabilities and Constraints

- Saving changes source configuration, not deployed files. Applying remains a separate chezmoi action.
- Tests change focus only after a user clicks a test control.
- App shortcuts default to finding existing windows anywhere and launching the app if absent; this is an implementation assumption, not a user-confirmed routing preference.
- Optional app routing assigns future windows to an existing space; it does not create, destroy, or rearrange spaces.
- Live inventory stays in memory. Credentials, application databases, and agent sessions remain unmanaged.

## Accessibility & Inclusion

The owner benefits from visible state, bounded actions, and concise copy. Controls must be keyboard accessible and errors must name their recovery action.
