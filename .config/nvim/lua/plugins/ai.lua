local M = {}

local mono = require("plugins.mono")

return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    config = {
      -- Returns a table of prompts, combining global and project-specific prompts, with caching.
      prompts = mono.get_mono_prompts(),
    },
  },
}
