return {
  -- Configure LazyVim to load catpuccin
  {
    "LazyVim/LazyVim",
    opts = {
      -- colorscheme = "tokyonight-day", -- "catppuccin-frappe",
      colorscheme = "catppuccin-latte",
    },
  },
  {
    -- https://github.com/LazyVim/LazyVim/pull/6354
    "akinsho/bufferline.nvim",
    init = function()
      local bufline = require("catppuccin.groups.integrations.bufferline")
      function bufline.get()
        return bufline.get_theme()
      end
    end,
  },
}
