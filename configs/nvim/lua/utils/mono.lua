local M = {}

-- Converts a string to title case and replaces underscores with spaces.
-- Example: "foo_bar" -> "Foo Bar"
function M.title_case(str)
  return (
    str
      :gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
      end)
      :gsub("_", " ")
  )
end

-- Searches upward from the given path (or current working directory) for a directory containing 'mono'.
-- Returns the absolute path to the 'mono' directory, or nil if not found.
function M.find_mono_root(start_path)
  local path = vim.fn.fnamemodify(start_path or vim.fn.getcwd(), ":p")
  while path and path ~= "/" do
    if vim.fn.isdirectory(path .. "/mono") == 1 then
      return path .. "/mono"
    end
    path = vim.fn.fnamemodify(path, ":h")
  end
  return nil
end

-- Reads the contents of a file and returns it as a string.
-- Returns nil if the file cannot be opened.
function M.read_file_contents(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  local contents = file:read("*a")
  file:close()
  return contents
end

-- Extracts the first Markdown header (line starting with '#') from the file contents.
-- Returns the header string, or nil if no header is found.
function M.extract_first_header(file_contents)
  for line in file_contents:gmatch("[^\n]+") do
    if line:match("^#") then
      return line:sub(2):gsub("^%s+", "") -- Remove leading '# ' and trim whitespace
    end
  end
  return nil
end

-- Collects prompts from all '.prompt.md' files in a directory.
-- Returns a table keyed by title-cased filename, with prompt and description.
function M.collect_prompts(dir, prefix)
  local tbl = {}
  local files = vim.fn.globpath(dir, "*.prompt.md", false, true)
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r:r") -- strip .prompt.md
    local key = prefix .. M.title_case(name):gsub("%s+", "")
    local prompt = M.read_file_contents(file)
    local description = M.extract_first_header(prompt)
    if prompt then
      tbl[key] = { prompt = prompt, description = description }
    end
  end
  return tbl
end

function M.get_mono_prompts()
  local mono_root = M.find_mono_root()
  if not mono_root then
    return {}
  end

  local cwd = vim.fn.getcwd()
  local project = cwd:match(mono_root .. "/([^/]+)")
  local prompts = {}

  -- Global prompts
  local global_dir = mono_root .. "/dev/llm/_global/prompts"
  local global_prompts = M.collect_prompts(global_dir, "Mono")
  for k, v in pairs(global_prompts) do
    prompts[k] = v
  end

  -- Project-specific prompts
  if project then
    local project_dir = mono_root .. "/" .. project .. "/.github/prompts"
    local project_prompts = M.collect_prompts(project_dir, "Service")
    for k, v in pairs(project_prompts) do
      local key = prompts[k] and ("Project: " .. k) or k
      prompts[key] = v
    end
  end
  return prompts
end

return M
