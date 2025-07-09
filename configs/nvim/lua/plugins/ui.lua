return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    table.remove(opts.dashboard.preset.keys, 1)
    table.insert(opts.dashboard.preset.keys, 1, {
      icon = " ",
      key = "f",
      desc = "Find Project File",
      action = ":lua Snacks.picker.files({cwd=vim.fn.getcwd()})",
      -- action = ":lua Snacks.dashboard.pick('files', {cwd=vim.fn.getcwd()})",
    })
  end,
}
