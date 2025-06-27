return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    config = {
      prompts = {
        HelloWorld = {
          prompt = "Explain how it works.",
          system_prompt = "You are very good at explaining stuff",
          mapping = "<leader>ccmc",
          description = "My custom prompt description",
        },
      },
    },
  },
}
