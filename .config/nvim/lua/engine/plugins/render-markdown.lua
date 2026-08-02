return {
	"MeanderingProgrammer/render-markdown.nvim",
	cond = vim.fn.has("nvim-0.12") == 0,
	ft = "markdown",
	cmd = { "RenderMarkdown" },
	keys = {
		{ "<leader>om", "<cmd>RenderMarkdown toggle<CR>", desc = "Toggle markdown render" },
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	opts = function()
		local function has_parser(language)
			local ok = pcall(vim.treesitter.language.add, language)
			return ok
		end

		return {
			enabled = has_parser("markdown") and has_parser("markdown_inline"),
			file_types = { "markdown" },
			preset = "obsidian",
			render_modes = { "n", "c", "t" },
			restart_highlighter = false,
			anti_conceal = {
				enabled = false,
			},
		}
	end,
}
