return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    -- add "Find Project File" to dashboard commands
    table.remove(opts.dashboard.preset.keys, 1)
    table.insert(opts.dashboard.preset.keys, 1, {
      icon = " ",
      key = "f",
      desc = "Find Project File",
      action = ":lua Snacks.picker.files({cwd=vim.fn.getcwd()})",
    })
    -- disable Indent Signs
    opts.indent.enabled = false
  end,
}
