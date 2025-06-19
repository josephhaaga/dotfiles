return {
  {
    "saghen/blink.cmp",
    enabled = true,
    opts = {
      completion = {
        accept = { auto_brackets = { enabled = false } },
        trigger = { show_on_keyword = false },
        menu = { auto_show = false },
      },
      keymap = {
        ["<C-p>"] = { "show", "select_prev" }, -- TODO: add to which-key
      },
    },
  },
}
