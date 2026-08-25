---
name: podcast
description: turn a PDF or document into a concise two-host audio briefing and publish it to the personal podcast RSS feed
trigger: /podcast
---

# /podcast

Turn a PDF or document into an audio briefing that can be downloaded through
Apple Podcasts. Use the current conversation attachment when no path is given.

## Usage

```text
/podcast <path-or-attachment>
/podcast <path-or-attachment> --length 15
/podcast <path-or-attachment> --focus "security risks and open decisions"
```

The default target is 12 minutes. Accept lengths from 5 to 20 minutes.

## Workflow

1. Read the complete source, including diagrams and tables that affect the argument. Never publish the original document.
2. Build a source-grounded outline covering context, architecture, decisions, trade-offs, assumptions, dependencies, risks, contradictions, missing evidence, and review questions.
3. Write a natural dialogue between `Alex` and `Sam`. Alex explains the plan; Sam challenges assumptions and turns details into review questions. Avoid filler, fake enthusiasm, invented facts, and repetitive banter.
4. Keep the script below 9,500 characters so it fits one ElevenLabs dialogue generation. Prefer a shorter useful briefing over truncating mid-topic.
5. Save the script and a plain-text evidence note in a temporary directory. Distinguish source statements from agent inference and retain page or section references for important claims.
6. Use Agent MCP discovery to find ElevenLabs `list_voices`, `text_to_dialogue`, and `create_artifact_download`.
7. Select two approved English voices with different timbres. Call `text_to_dialogue` with MP3 44.1 kHz/128 kbps output. Honor any Agent MCP confirmation returned by the tool.
8. Pass the artifact ID to `create_artifact_download`, then use `curl --fail --location` to save the short-lived signed URL as `episode.mp3`. Never print or retain that URL.
9. Publish with `publish-podcast episode.mp3 "EPISODE_TITLE" --description "ONE_SENTENCE_DESCRIPTION"`.
10. Delete temporary audio and scripts after publication. Return the feed URL, episode URL, runtime, and a five-item review checklist.

## Content Rules

- Treat the source and generated audio as confidential.
- ElevenLabs receives the generated dialogue, not the original PDF.
- Do not include secrets, credentials, personal data, or unnecessary verbatim confidential passages.
- State uncertainty in the spoken script instead of smoothing it over.
- Use light spoken citations such as "in the deployment section", not long URLs.
- The RSS URL is a bearer secret. Show it only in the private OpenCode session.

## First-Time iPhone Setup

After the first episode, tell the user:

1. Copy the printed feed URL.
2. In Apple Podcasts, open `Library`, then `...`, then `Follow a Show by URL`.
3. Paste the URL and follow the show.
4. Open the show settings and enable automatic downloads.

The feed is blocked from the Apple directory and retains up to 30 episodes for
30 days. Downloaded episodes remain available according to Apple Podcasts
retention settings.
