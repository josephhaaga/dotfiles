return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/neotest-python',
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'neotest-python' {
            -- Extra arguments for nvim-dap configuration
            -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
            -- dap = { justMyCode = false },
            --
            -- Command line arguments for runner
            -- Can also be a function to return dynamic values
            -- args = {"--log-level", "DEBUG"},
            --
            -- Runner to use. Will use pytest if available by default.
            -- Can be a function to return dynamic value.
            -- runner = "pytest",
            --
            -- Custom python path for the runner.
            -- Can be a string or a list of strings.
            -- Can also be a function to return dynamic value.
            -- If not provided, the path will be inferred by checking for
            -- virtual envs in the local directory and for Pipenev/Poetry configs
            -- python = ".venv/bin/python",
            -- python = 'docker run -it dinghy_api:dev -- python3',
            --
            -- Returns if a given file path is a test file.
            -- NB: This function is called a lot so don't perform any heavy tasks within it.
            -- is_test_file = function(file_path)
            --   ...
            -- end,
            --
            -- !!EXPERIMENTAL!! Enable shelling out to `pytest` to discover test
            -- instances for files containing a parametrize mark (default: false)
            -- pytest_discover_instances = true,
          },
        },
      }
      -- Key bindings
      local map = vim.api.nvim_set_keymap
      local opts = { noremap = true, silent = true }

      -- Run tests
      map('n', '<leader>tn', "<cmd>lua require('neotest').run.run()<CR>", { desc = 'Run tests' })
      -- Run nearest test
      map('n', '<leader>tf', "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>", { desc = 'Run nearest test' })
      -- Run last test
      map('n', '<leader>tl', "<cmd>lua require('neotest').run.run_last()<CR>", { desc = 'Run last test' })
      -- Debug last test
      map('n', '<leader>tL', "<cmd>lua require('neotest').run.run_last({ strategy = 'dap' })<CR>",
        { desc = 'Debug last test' })
      -- Run tests in watch mode
      -- map("n", "<leader>tw", "<cmd>lua require('neotest').run.run({ jestCommand = 'jest --watch ' })<CR>", opts)

      require('overseer').setup()
    end,
  },
  {
    'stevearc/overseer.nvim',
    opts = {},
  },
}
