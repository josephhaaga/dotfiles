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

return M
