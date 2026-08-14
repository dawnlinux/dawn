-- Xenith: filetype detection, syntax, indenting and the xenith-lsp server.
-- The plugin lives in the language's own repository so edits there take effect
-- on the next Neovim start without a reinstall.
return {
	dir = "/home/jhayonline/software/rs/xenith/editors/nvim",
	name = "xenith.nvim",
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
