#!/usr/bin/env bash

# Sanity-check supported V2 preferences, not a replacement for the full schema.
# Root model, agents, and default_agent are valid configuration fields.
validate_opencode_preferences() {
  jq -e '
    (if has("model") then
       (.model | type == "string" and test("^[^/[:space:]#]+/[^[:space:]#]+$"))
     else true end)
    and (if has("default_agent") then
           (.default_agent | type == "string" and length > 0)
         else true end)
    and (if has("agents") then (.agents | type == "object") else true end)
  ' >/dev/null
}
