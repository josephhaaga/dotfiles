require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "ruff" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
vim.lsp.config('ruff', {
  init_options = {
    settings = {
      -- Ruff language server settings go here
    }
  }
})

vim.lsp.enable('ruff')
