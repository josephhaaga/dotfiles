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

local function journal_date()
  local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
  if not filename:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return nil
  end

  return filename
end

local function calendar_checklist_item(fields)
  local start_time = fields[2]
  local title = fields[6]

  if not title or title == "" then
    return nil
  end

  if start_time == "" or start_time == "00:00" then
    return string.format("- [ ] %s", title)
  end

  return string.format("- [ ] %s — %s", start_time, title)
end

vim.api.nvim_create_user_command("Calendar", function()
  local date = journal_date()
  if not date then
    vim.notify("Open a journal file named YYYY-MM-DD before importing its calendar.", vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable("gcalcli") == 0 then
    vim.notify("gcalcli is not installed. Run chezmoi apply, then gcalcli init.", vim.log.levels.ERROR)
    return
  end

  local next_date = os.date(
    "%Y-%m-%d",
    os.time({
      year = tonumber(date:sub(1, 4)),
      month = tonumber(date:sub(6, 7)),
      day = tonumber(date:sub(9, 10)) + 1,
    })
  )
  local bufnr = vim.api.nvim_get_current_buf()

  vim.system({ "gcalcli", "agenda", "--tsv", date, next_date }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("Calendar import failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
        return
      end

      local items = {}
      for line in vim.gsplit(result.stdout, "\n", { plain = true, trimempty = true }) do
        local fields = vim.split(line, "\t", { plain = true })
        local item = calendar_checklist_item(fields)
        if item then
          table.insert(items, item)
        end
      end

      if #items == 0 then
        vim.notify("No calendar events for " .. date .. ".")
        return
      end

      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      local existing = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
      local new_items = vim.tbl_filter(function(item)
        return not existing:find(item, 1, true)
      end, items)

      if #new_items == 0 then
        vim.notify("Calendar events are already in this journal.")
        return
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, new_items)
      vim.notify(string.format("Added %d calendar event(s) for %s.", #new_items, date))
    end)
  end)
end, {
  desc = "Add Google Calendar events to the current journal",
})

-- Disable autoformat for files in `/mono/`
vim.api.nvim_create_autocmd({ "BufEnter" }, {
  pattern = { "*/mono/*" },
  callback = function()
    vim.b.autoformat = false -- silent
    -- LazyVim.format.enable(false, true) -- more verbose; shows a noice.nvim notification
  end,
})
