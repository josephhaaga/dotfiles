local M = {}

local cache = nil

local function title_case(str)
  return (
    str
      :gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
      end)
      :gsub("_", " ")
  )
end

local function find_mono_root(start_path)
  local path = vim.fn.fnamemodify(start_path or vim.fn.getcwd(), ":p")
  while path and path ~= "/" do
    if vim.fn.isdirectory(path .. "/mono") == 1 then
      return path .. "/mono"
    end
    path = vim.fn.fnamemodify(path, ":h")
  end
  return nil
end

local function read_first_header(filepath)
  for line in io.lines(filepath) do
    local header = line:match("^#%s*(.+)")
    if header then
      return header
    end
  end
  return nil
end

local function collect_prompts(dir, description)
  local tbl = {}
  local files = vim.fn.globpath(dir, "*.prompt.md", false, true)
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r:r") -- strip .prompt.md
    local key = title_case(name)
    local prompt = read_first_header(file)
    if prompt then
      tbl[key] = { prompt = prompt, description = description }
    end
  end
  return tbl
end

function M.get_prompts(opts)
  opts = opts or {}
  if cache and not opts.reload then
    return cache
  end

  local mono_root = find_mono_root()
  if not mono_root then
    return {}
  end

  local cwd = vim.fn.getcwd()
  local project = cwd:match(mono_root .. "/([^/]+)")
  local prompts = {}

  -- Global prompts
  local global_dir = mono_root .. "/dev/llm/_global/prompts"
  local global_prompts = collect_prompts(global_dir, "global")
  for k, v in pairs(global_prompts) do
    prompts[k] = v
  end

  -- Project-specific prompts
  if project then
    local project_dir = mono_root .. "/" .. project .. "/.github/prompts"
    local project_prompts = collect_prompts(project_dir, "project-specific")
    for k, v in pairs(project_prompts) do
      local key = prompts[k] and ("Project: " .. k) or k
      prompts[key] = v
    end
  end

  cache = prompts
  return prompts
end

return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    config = {
      prompts = M.get_prompts(),
    },
  },
}
