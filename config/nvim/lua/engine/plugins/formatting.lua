return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	opts = {
		formatters_by_ft = {
			php = { "pint" },
			blade = { "blade-formatter" },
			javascript = { "prettier" },
			typescript = { "prettier" },
			vue = { "prettier" },
			css = { "prettier" },
			scss = { "prettier" },
			json = { "prettier" },
			jsonc = { "prettier" },
			markdown = { "prettier" },
			html = { "prettier" },
		},
		formatters = {
			pint = {
				command = "./vendor/bin/pint",
				args = { "$FILENAME" },
				cwd = function()
					-- Find the project root (where composer.json is)
					local root = vim.fs.root(0, { "composer.json" })
					if root then
						return root
					end
					return vim.fn.getcwd()
				end,
			},
		},
		format_on_save = {
			timeout_ms = 3000,
			lsp_fallback = true,
		},
	},
}
