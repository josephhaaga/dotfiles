---
name: review-changes-example
schedule: "0 9 * * 1-5"
enabled: false
model: approved-provider/approved-model
agent: plan
timezone: UTC
---

Summarize the current repository's recent changes and identify one bounded
next action. Do not edit files, send messages, create issues, push commits,
or start another task. This example remains disabled until the user selects
an approved model, reviews the schedule, and explicitly enables it.
