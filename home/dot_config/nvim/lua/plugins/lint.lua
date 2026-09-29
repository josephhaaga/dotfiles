return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          -- To disable MD013 entirely:
          args = { "--disable", "MD013", "--" },
          -- Or to pass a config file:
          -- args = { "--config", "~/.markdownlint.jsonc", "--" },
        },
      },
    },
  },
}
