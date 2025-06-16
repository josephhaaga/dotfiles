require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
-- map("n", "ts", "<cmd> r!python3 -c 'print(f"{datetime}\n")' <cr>")

-- Define the :Ts command
vim.api.nvim_create_user_command(
  "Ts",
  function()
    local datetime = os.date("%Y-%m-%d %I:%M:%S %p")
    vim.api.nvim_feedkeys("i[" .. datetime .. "]\n", "n", true)
  end,
  {
    desc = "Insert current datetime",
    -- You can add other options here, e.g., `range = true` if it should operate on a range
  }
)
