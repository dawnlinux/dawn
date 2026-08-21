-- Xenith: filetype detection, syntax, indenting and the xenith-lsp server.
--
-- The plugin lives in the language's own repository rather than being
-- installed by lazy.nvim, so edits there take effect on the next Neovim start
-- without a reinstall. That makes it a *local development* plugin: the
-- directory only exists on a machine that has the Xenith source checked out.
--
-- Point $XENITH_NVIM at the plugin directory to use a checkout somewhere else.
-- If the directory is missing the spec disables itself, because a lazy.nvim
-- `dir` that does not exist is a hard startup error, and a Dawn install should
-- not fail to open an editor over a plugin for a language you have never
-- heard of.

local dir = vim.env.XENITH_NVIM or vim.fn.expand("~/software/rs/xenith/editors/nvim")

return {
	dir = dir,
	name = "xenith.nvim",
	enabled = vim.fn.isdirectory(dir) == 1,
	-- Not lazy-loaded: the server registration has to be in place before the
	-- first .xen buffer is read.
	lazy = false,
	config = function()
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
		if ok then
			capabilities = cmp_nvim_lsp.default_capabilities()
		end

		require("xenith").setup({
			server = {
				capabilities = capabilities,
			},
		})
	end,
}
