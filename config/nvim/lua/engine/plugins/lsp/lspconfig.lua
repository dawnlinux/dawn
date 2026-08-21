return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/neodev.nvim",                   opts = {} },
	},
	config = function()
		local lspconfig = require("lspconfig")
		local keymap = vim.keymap
		local qt_clangd_flag_pattern = "^[Uu]nknown argument:%s*['\"]?%-mno%-direct%-extern%-access['\"]?"

		-- Defer loading cmp_nvim_lsp until needed to avoid dependency issues
		local function get_capabilities()
			local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			if ok then
				return cmp_nvim_lsp.default_capabilities()
			end
			-- Fallback if cmp isn't loaded yet
			return vim.lsp.protocol.make_client_capabilities()
		end

		local default_publish_diagnostics = vim.lsp.handlers["textDocument/publishDiagnostics"]
		vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
			local client = ctx and vim.lsp.get_client_by_id(ctx.client_id)
			if client and client.name == "clangd" and result and result.diagnostics then
				result = vim.deepcopy(result)
				result.diagnostics = vim.tbl_filter(function(diagnostic)
					local message = diagnostic.message or ""
					return not message:match(qt_clangd_flag_pattern)
				end, result.diagnostics)
			end

			return default_publish_diagnostics(err, result, ctx, config)
		end

		-- setup keymaps when lsp attaches
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local opts = { buffer = ev.buf, silent = true }

				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if client and client.server_capabilities.semanticTokensProvider then
					client.server_capabilities.semanticTokensProvider = nil
				end

				opts.desc = "show lsp references"
				keymap.set("n", "gr", "<cmd>Telescope lsp_references<cr>", opts)

				opts.desc = "go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

				opts.desc = "go to definition"
				keymap.set("n", "gd", vim.lsp.buf.definition, opts)

				opts.desc = "show lsp implementations"
				keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<cr>", opts)

				opts.desc = "show lsp type definitions"
				keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<cr>", opts)

				opts.desc = "see available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

				opts.desc = "smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

				opts.desc = "show buffer diagnostics"
				keymap.set("n", "<leader>d", "<cmd>Telescope diagnostics bufnr=0<cr>", opts)

				opts.desc = "show line diagnostics"
				keymap.set("n", "<leader>dl", vim.diagnostic.open_float, opts)

				opts.desc = "go to previous diagnostic"
				keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)

				opts.desc = "go to next diagnostic"
				keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

				opts.desc = "show documentation under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts) -- Changed to Shift+K

				opts.desc = "restart lsp"
				keymap.set("n", "<leader>rs", function()
					-- Servers here are started through vim.lsp.enable(), so
					-- there is no :LspRestart to call: stop whatever is
					-- attached and let the reload re-trigger the autostart.
					local bufnr = vim.api.nvim_get_current_buf()
					local clients = vim.lsp.get_clients({ bufnr = bufnr })

					if #clients == 0 then
						vim.notify("No LSP client attached to this buffer", vim.log.levels.WARN)
						return
					end

					local names = vim.tbl_map(function(client)
						return client.name
					end, clients)

					for _, client in ipairs(clients) do
						client:stop()
					end

					vim.defer_fn(function()
						if vim.api.nvim_buf_is_valid(bufnr) then
							vim.api.nvim_buf_call(bufnr, function()
								vim.cmd("edit")
							end)
						end
						vim.notify("Restarted: " .. table.concat(names, ", "), vim.log.levels.INFO)
					end, 500)
				end, opts)

				-- enable inlay hints if supported
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				local ft = vim.bo[ev.buf].filetype
				local path = vim.api.nvim_buf_get_name(ev.buf)
				local disable_inlay_hints = vim.tbl_contains({ "c", "cpp", "objc", "objcpp" }, ft)
				    or path:match("%.h$")
				    or path:match("%.hh$")
				    or path:match("%.hpp$")
				    or path:match("%.hxx$")
				    or path:match("%.inl$")

				if client and client.server_capabilities.inlayHintProvider and not disable_inlay_hints then
					vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
				end
			end,
		})

		-- Get capabilities safely
		local capabilities = get_capabilities()

		-- inline diagnostics (virtual text) + sign column icons
		local severity = vim.diagnostic.severity

		vim.diagnostic.config({
			virtual_text = {
				prefix = "●",
				spacing = 2,
			},
			-- Signs used to be registered with sign_define("DiagnosticSign…"),
			-- which is deprecated since 0.10; the icons belong here now.
			signs = {
				text = {
					[severity.ERROR] = " ",
					[severity.WARN] = " ",
					[severity.HINT] = "󰠠 ",
					[severity.INFO] = " ",
				},
			},
			underline = true,
			update_in_insert = false,
			severity_sort = true,
		})

		-- ============================
		-- language servers
		-- ============================

		-- typescript / tsx
		vim.lsp.config("ts_ls", {
			capabilities = capabilities,
			filetypes = {
				"typescript",
				"typescriptreact",
				"javascript",
				"javascriptreact",
			},
		})

		vim.lsp.enable("ts_ls")

		-- ============================
		-- clang
		-- ============================
		vim.lsp.config("clangd", {
			capabilities = capabilities,
			cmd = {
				"clangd",
				"--background-index",
				"--clang-tidy",
				"--query-driver=/usr/bin/c++,/usr/bin/g++",
			},
			init_options = {
				fallbackFlags = {
					"-std=c++23",
				},
			},
		})
		vim.lsp.enable("clangd")

		-- ============================
		-- lua
		-- ============================
		vim.lsp.config("lua_ls", {
			capabilities = capabilities,
			settings = {
				Lua = {
					runtime = {
						version = "LuaJIT",
					},
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						checkThirdParty = false,
						library = vim.api.nvim_get_runtime_file("", true),
					},
					completion = {
						callSnippet = "Replace",
					},
				},
			},
		})
		vim.lsp.enable("lua_ls")

		-- auto-format on save
		vim.api.nvim_create_autocmd("BufWritePre", {
			callback = function(ev)
				local ft = vim.bo[ev.buf].filetype
				local cpp_like = vim.tbl_contains({ "c", "cpp", "objc", "objcpp" }, ft)

				-- typst uses typstyle (not lsp)
				if ft == "typst" then
					require("conform").format({ bufnr = ev.buf })
					return
				end

				if not cpp_like then
					return
				end

				vim.lsp.buf.format({
					bufnr = ev.buf,
					async = false,
					filter = function(client)
						return client.name == "clangd"
					end,
				})
			end,
		})

		-- ============================
		-- rust
		-- ============================
		vim.lsp.config("rust_analyzer", {
			capabilities = capabilities,
			settings = {
				["rust-analyzer"] = {
					inlayHints = {
						typeHints = { enable = true },
						parameterHints = { enable = false },
						chainingHints = { enable = false },
						bindingModeHints = { enable = false },
						closureReturnTypeHints = { enable = "never" },
						lifetimeElisionHints = { enable = "never" },
						reborrowHints = { enable = false },
						closingBraceHints = { enable = false },
					},
				},
			},
		})

		vim.lsp.enable("rust_analyzer")

		-- ============================
		-- typst
		-- ============================
		vim.lsp.config("tinymist", {
			cmd = { "tinymist" },
			filetypes = { "typst" },
			root_markers = { ".git" },
			capabilities = capabilities,
		})

		vim.lsp.enable("tinymist")

		-- ============================
		-- haskell
		-- ============================
		if vim.fn.executable("haskell-language-server-wrapper") == 1 then
			vim.lsp.config("hls", {
				capabilities = capabilities,
				cmd = { "haskell-language-server-wrapper", "--lsp" },
				filetypes = { "haskell", "lhaskell", "cabal" },
				root_markers = { "hie.yaml", "stack.yaml", "cabal.project", "package.yaml", "*.cabal", ".git" },
			})

			vim.lsp.enable("hls")
		end

		-- ============================
		-- godot / gdscript
		-- ============================
		vim.lsp.config("gdscript", {
			capabilities = capabilities,
		})

		vim.lsp.enable("gdscript")

		if vim.fn.executable("gdshader-lsp") == 1 then
			vim.lsp.config("gdshader_lsp", {
				capabilities = capabilities,
			})

			vim.lsp.enable("gdshader_lsp")
		end

		-- ============================
		-- go
		-- ============================
		vim.lsp.config("gopls", {
			capabilities = capabilities,
			cmd = { "gopls" },
			filetypes = { "go", "gomod", "gowork", "gotmpl" },
			settings = {
				gopls = {
					gofumpt = true,
					staticcheck = true,
					analyses = {
						unusedparams = true,
					},
				},
			},
		})
		vim.lsp.enable("gopls")

		-- ============================
		-- python
		-- ============================
		vim.lsp.config("pyright", {
			capabilities = capabilities,
			cmd = { "pyright-langserver", "--stdio" },
			filetypes = { "python" },
			settings = {
				python = {
					analysis = {
						autoSearchPaths = true,
						diagnosticMode = "workspace",
						useLibraryCodeForTypes = true,
					},
				},
			},
		})
		vim.lsp.enable("pyright")

		-- ============================
		-- java (already configured in java.lua via opts.servers —
		-- do not enable jdtls here too, or it'll be set up twice)
		-- ============================
		-- vim.lsp.config("jdtls", { capabilities = capabilities })
		-- vim.lsp.enable("jdtls")

		-- ============================
		-- c# (already configured in your omnisharp plugin file via
		-- opts.servers — do not enable omnisharp here too)
		-- ============================
		-- vim.lsp.config("omnisharp", { capabilities = capabilities })
		-- vim.lsp.enable("omnisharp")

		-- ============================
		-- php
		-- ============================
		vim.lsp.config("intelephense", {
			capabilities = capabilities,
			filetypes = { "php" },
		})
		vim.lsp.enable("intelephense")

		-- ============================
		-- markdown
		-- ============================
		vim.lsp.config("marksman", {
			capabilities = capabilities,
			filetypes = { "markdown", "markdown.mdx" },
		})
		vim.lsp.enable("marksman")

		-- ============================
		-- json
		-- ============================
		vim.lsp.config("jsonls", {
			capabilities = capabilities,
			filetypes = { "json", "jsonc" },
			settings = {
				json = {
					validate = { enable = true },
				},
			},
		})
		vim.lsp.enable("jsonls")

		-- ============================
		-- toml
		-- ============================
		vim.lsp.config("taplo", {
			capabilities = capabilities,
			filetypes = { "toml" },
		})
		vim.lsp.enable("taplo")

		-- ============================
		-- dart
		-- ============================
		vim.lsp.config("dartls", {
			capabilities = capabilities,
			filetypes = { "dart" },
			settings = {
				dart = {
					completeFunctionCalls = true,
					showTodos = true,
				},
			},
		})
		vim.lsp.enable("dartls")

		-- ============================
		-- css / scss
		-- ============================
		vim.lsp.config("cssls", {
			capabilities = capabilities,
			filetypes = { "css", "scss", "less" },
			settings = {
				css = { validate = true },
				scss = { validate = true },
			},
		})
		vim.lsp.enable("cssls")

		-- ============================
		-- html
		-- ============================
		vim.lsp.config("html", {
			capabilities = capabilities,
			filetypes = { "html" },
		})
		vim.lsp.enable("html")

		-- ============================
		-- bash / shell
		-- ============================
		vim.lsp.config("bashls", {
			capabilities = capabilities,
			filetypes = { "sh", "bash" },
		})
		vim.lsp.enable("bashls")

		-- ============================
		-- zig
		-- ============================
		vim.lsp.config("zls", {
			capabilities = capabilities,
			filetypes = { "zig", "zir" },
		})
		vim.lsp.enable("zls")

		-- ============================
		-- qml / quickshell
		-- ============================
		-- Arch ships the binary as `qmlls6`; most other distros use `qmlls`.
		local qmlls_bin = (vim.fn.executable("qmlls6") == 1 and "qmlls6")
		    or (vim.fn.executable("qmlls") == 1 and "qmlls")
		    or nil

		if qmlls_bin then
			vim.lsp.config("qmlls", {
				capabilities = capabilities,
				-- Deliberately no `-I`: passing any import path on argv *replaces* the
				-- ones in .qmlls.ini, and that file is how Quickshell points qmlls at
				-- the generated module tree that makes `import qs.*` resolve.
				-- `-E` only appends QML_IMPORT_PATH, so it's safe.
				cmd = { qmlls_bin, "-E" },
				filetypes = { "qml", "qmljs" },
				-- .qmlls.ini / shell.qml mark a Quickshell config root; keep them ahead
				-- of .git so a dotfiles repo doesn't drag the root up to ~/.config.
				root_markers = { ".qmlls.ini", "shell.qml", ".git" },
			})

			vim.lsp.enable("qmlls")
		end

		-- ============================
		-- tailwindcss
		-- ============================
		vim.lsp.config("tailwindcss", {
			capabilities = capabilities,
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
							{ "class: '([^']*)'" },
							{ "class: \"([^\"]*)\"" },
							{ "classes: '([^']*)'" },
							{ "classes: \"([^\"]*)\"" },
							{ "class=\"([^\"]*)\"" },
							{ "class='([^']*)'" },
						},
					},
				},
			},
		})
		vim.lsp.enable("tailwindcss")

		-- ============================
		-- volar (vue)
		-- ============================
		vim.lsp.config("volar", {
			capabilities = capabilities,
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
		})
		vim.lsp.enable("volar")

		-- ============================
		-- laravel lsp
		-- ============================
		vim.lsp.config("laravel_lsp", {
			cmd = { "laravel-lsp" },
			filetypes = { "php", "blade" },
			root_markers = { "artisan", "composer.json", ".git" },
			settings = {
				-- Optional: Configure PHP environment
				-- phpEnvironment = "auto", -- or "herd", "valet", "sail", "local"
				-- Or specify PHP command explicitly:
				-- phpCommand = { "php" },
			},
		})

		vim.lsp.enable("laravel_lsp")
	end,

}
