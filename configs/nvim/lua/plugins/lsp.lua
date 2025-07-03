return {
  {
    "neovim/nvim-lspconfig",
    opts = function()
      inlay_hints = {
        enabled = true,
        exclude = { "go" },
      }
    end,
  },
}
