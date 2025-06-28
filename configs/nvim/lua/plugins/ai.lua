local mono = require("utils.mono")

return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",

    config = {
      -- Returns a table of prompts, combining global and project-specific prompts, with caching.
      prompts = mono.get_mono_prompts(),
    },
  },
}
