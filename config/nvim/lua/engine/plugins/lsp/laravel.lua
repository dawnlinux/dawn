return {
	"neovim/nvim-lspconfig",
	optional = true,
	opts = {
		servers = {
			laravel_lsp = {
				filetypes = { "php", "blade" },
				root_markers = {
					"artisan",
					"composer.json",
					".git",
				},
				settings = {
					laravel_lsp = {
						enable_inlay_hints = true,
						enable_import_analyzer = true,
						enable_ailiases_analyzer = true,
						enable_rename_analyzer = true,
						enable_contracts_analyzer = true,
						enable_facades_analyzer = true,
						enable_views_analyzer = true,
						enable_config_analyzer = true,
						enable_translations_analyzer = true,
						enable_extra_analyzer = true,
						enable_editor_support = true,
						enable_database_analyzer = true,
						enable_mixins_analyzer = true,
						enable_events_analyzer = true,
						enable_lazy_analyzer = true,
					},
				},
			},
		},
	},
}
