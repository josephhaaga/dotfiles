# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).

## Journal calendar

Open a dated journal with Clerk (for example, `journal tomorrow`), then run
`:Calendar` in Neovim. It adds that day's Google Calendar events as unchecked
items at the top of the journal and does not duplicate entries already present.

The first time on each machine, run `gcalcli init` in a terminal and follow its
prompts to create or enter a Google Cloud OAuth desktop client. Its OAuth state
is local runtime data and is not managed by chezmoi.
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.
