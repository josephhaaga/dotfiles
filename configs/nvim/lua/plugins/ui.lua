return {
  "snacks.nvim",
  opts = {
    dashboard = {
      keys = {
        {
          icon = " ",
          key = "f",
          desc = "Find Project File",
          -- action = ":lua Snacks.dashboard.pick('files', {cwd=vim.fn.getcwd()})",
          action = ":lua Snacks.picker.files({cwd=vim.fn.getcwd()})",
        },
      },
    },
  },
}
