# Global Instructions

## Slack Messages

Whenever drafting, proposing, or sending a Slack message, use Tribe's two-part structure:

1. The top-level channel message is a bolded headline and nothing else: a short noun phrase naming the ask or topic.
2. All detail goes in a threaded reply to that message: what you're asking for, why, and any specifics such as names, URLs, usernames, IDs, or error text.

This keeps channels scannable and keeps triage discussion in threads. Never put the explanation in the top-level message.

Formatting: Slack uses `*single asterisks*` for bold, not Markdown's `**double**`. Headlines are typically 2-8 words, title case.

Observed variations that are fine:

- A trailing unbolded qualifier: `*Anthropic API key* when/if possible`
- A `cc @person` after the headline
- A leading `:thread:` emoji to signal detail is in the thread

Examples from `#tribe-ops`:

```
*Miro Access*
*Linear Access*
*Tribe dev Azure account*
*M365 Product Download*
*Google Workspace Email Alias*
*Create Microsoft account for `felix.lau@tribe.ai`*
*Azure + AI Foundry access for FIS AgentEdge*
```

An `:eyes:` reaction on the headline means someone has picked it up for triage.

Always show both parts to the user for review before sending anything. Do not post a headline and then compose the thread reply afterward, since the headline alone is meaningless without its thread.
