return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			php = {}, -- Disabled for now
			blade = {}, -- Disabled for now
			javascript = { "eslint" },
			typescript = { "eslint" },
			vue = { "eslint" },
		}

		-- Auto-lint on save
		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	end,
}
