return {
	"neovim/nvim-lspconfig",
	optional = true,
	opts = {
		servers = {
			volar = {
				filetypes = { "vue" },
				init_options = {
					vue = {
						hybridMode = false,
					},
					typescript = {
						tsdk = vim.fn.stdpath("data") .. "/lsp/ts_ls/node_modules/typescript/lib",
					},
				},
				settings = {
					vue = {
						inlayHints = {
							missingProps = true,
							eventNameInInlineHandlers = true,
							defineProps = true,
						},
					},
					typescript = {
						inlayHints = {
							parameterNames = { enabled = "literals" },
							variableTypes = { enabled = true },
							propertyDeclarationTypes = { enabled = true },
							functionLikeReturnTypes = { enabled = true },
							enumMemberValues = { enabled = true },
						},
					},
					javascript = {
						inlayHints = {
							parameterNames = { enabled = "literals" },
							variableTypes = { enabled = true },
							propertyDeclarationTypes = { enabled = true },
							functionLikeReturnTypes = { enabled = true },
							enumMemberValues = { enabled = true },
						},
					},
				},
			},
		},
	},
}
