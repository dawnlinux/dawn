return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			tailwindcss = {
				filetypes = {
					"html",
					"css",
					"scss",
					"javascript",
					"typescript",
					"vue",
					"blade",
				},
				settings = {
					tailwindCSS = {
						experimental = {
							classRegex = {
								-- Vue/JS
								{ "class: '([^']*)'" },
								{ "class: \"([^\"]*)\"" },
								{ "classes: '([^']*)'" },
								{ "classes: \"([^\"]*)\"" },
								-- Blade
								{ "class=\"([^\"]*)\"" },
								{ "class='([^']*)'" },
							},
						},
					},
				},
			},
		},
	},
}
