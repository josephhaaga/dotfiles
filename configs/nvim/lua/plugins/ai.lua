local mono = require("utils.mono")

return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        auto_trigger = false, -- Disable auto-triggering of suggestions
      },
    },
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",

    config = {
      -- Returns a table of prompts, combining global and project-specific prompts, with caching.
      prompts = mono.get_mono_prompts(),
    },
  },
}
