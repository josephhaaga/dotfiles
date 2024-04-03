local M = {}

-- :lua usepython()
-- Re-configure Python dev tools to target a specific environment
M.usepython = function()
	vim.ui.input({ prompt = 'Path to Python environment: ' }, function(inp)
		print ' '
		-- reconfigure pyright
		vim.cmd('PyrightSetPythonPath ' .. inp) -- Command only available in .py files

		-- reconfigure nvim-dap-python
		require('dap-python').resolve_python = function()
			return inp
		end

		-- reconfigure neotest
		-- I think we can just set `strategy: dap` and it will use `dap-python`'s configuration
	end)
end

-- https://github.com/mfussenegger/nvim-dap/wiki/Local-and-Remote-Debugging-with-Docker#python
M.attach_python_debugger = function(args)
	local dap = require 'dap'
	local host = args[1] -- This should be configured for remote debugging if your SSH tunnel is setup.
	local port = 5678

	-- You can even make nvim responsible for starting the debugpy server/adapter:
	--  vim.fn.system({"${some_script_that_starts_debugpy_in_your_container}", ${script_args}})
	pythonAttachConfig = {
		type = 'python',
		request = 'attach',
		connect = {
			port = port,
			host = host,
		},
		mode = 'remote',
		name = 'Remote Attached Debugger',
		cwd = vim.fn.getcwd(),
		pathMappings = {
			{
				localRoot = vim.fn.getcwd(), -- Wherever your Python code lives locally.
				remoteRoot = '/usr/src/app', -- Wherever your Python code lives in the container.
			},
		},
	}
	local session = dap.attach(host, port, pythonAttachConfig)
	if session == nil then
		io.write 'Error launching adapter'
	end
	dap.repl.open()
end

return M
