-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_user_command("Ts", function()
  local datetime = os.date("%Y-%m-%d %I:%M:%S %p")
  vim.api.nvim_feedkeys("i[" .. datetime .. "]\n", "n", true)
end, {
  desc = "Insert current datetime",
  -- You can add other options here, e.g., `range = true` if it should operate on a range
})

-- Disable autoformat for files in `/mono/`
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  pattern = { "*/mono/*" },
  callback = function()
    vim.b.autoformat = false
  end,
})
