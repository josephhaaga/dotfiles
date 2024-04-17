return {
  {
    'ruifm/gitlinker.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = function()
      local gitlinker = require 'gitlinker'
      -- vim.keymap.set('n', '<leader>y', gitlinker.get_buf_range_url 'n', { desc = 'Copy Permalink to code' })
      -- vim.keymap.set('v', '<leader>y', gitlinker.get_buf_range_url 'v', { desc = 'Copy Permalink to code' })
    end,
  },
}
