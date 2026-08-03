return {
	"neovim/nvim-lspconfig",
	event = { "bufreadpre", "bufnewfile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/neodev.nvim", opts = {} },
	},
	config = function()
		local lspconfig = require("lspconfig")
		local keymap = vim.keymap
		local qt_clangd_flag_pattern = "^unknown argument:%s*['\"]?%-mno%-direct%-extern%-access['\"]?"

		-- Defer loading cmp_nvim_lsp until needed to avoid dependency issues
		local function get_capabilities()
			local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			if ok then
				return cmp_nvim_lsp.default_capabilities()
			end
			-- Fallback if cmp isn't loaded yet
			return vim.lsp.protocol.make_client_capabilities()
		end

		local default_publish_diagnostics = vim.lsp.handlers["textdocument/publishdiagnostics"]
		vim.lsp.handlers["textdocument/publishdiagnostics"] = function(err, result, ctx, config)
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
		vim.api.nvim_create_autocmd("lspattach", {
			group = vim.api.nvim_create_augroup("userlspconfig", {}),
			callback = function(ev)
				local opts = { buffer = ev.buf, silent = true }

				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if client and client.server_capabilities.semantictokensprovider then
					client.server_capabilities.semantictokensprovider = nil
				end

				opts.desc = "show lsp references"
				keymap.set("n", "gr", "<cmd>telescope lsp_references<cr>", opts)

				opts.desc = "go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

				opts.desc = "go to definition"
				keymap.set("n", "gd", vim.lsp.buf.definition, opts)

				opts.desc = "show lsp implementations"
				keymap.set("n", "gi", "<cmd>telescope lsp_implementations<cr>", opts)

				opts.desc = "show lsp type definitions"
				keymap.set("n", "gt", "<cmd>telescope lsp_type_definitions<cr>", opts)

				opts.desc = "see available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

				opts.desc = "smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

				opts.desc = "show buffer diagnostics"
				keymap.set("n", "<leader>d", "<cmd>telescope diagnostics bufnr=0<cr>", opts)

				opts.desc = "show line diagnostics"
				keymap.set("n", "<leader>dl", vim.diagnostic.open_float, opts)

				opts.desc = "go to previous diagnostic"
				keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)

				opts.desc = "go to next diagnostic"
				keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

				opts.desc = "show documentation under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts) -- Changed to Shift+K

				opts.desc = "restart lsp"
				keymap.set("n", "<leader>rs", ":lsprestart<cr>", opts)

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

				if client and client.server_capabilities.inlayhintprovider and not disable_inlay_hints then
					vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
				end
			end,
		})

		-- Get capabilities safely
		local capabilities = get_capabilities()

		-- diagnostic signs
		local signs = { error = " ", warn = " ", hint = "󰠠 ", info = " " }
		for type, icon in pairs(signs) do
			local hl = "diagnosticsign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		-- inline diagnostics (virtual text)
		vim.diagnostic.config({
			virtual_text = {
				prefix = "●",
				spacing = 2,
			},
			signs = true,
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
				fallbackflags = {
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
				lua = {
					runtime = {
						version = "luajit",
					},
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						checkthirdparty = false,
						library = vim.api.nvim_get_runtime_file("", true),
					},
					completion = {
						callsnippet = "replace",
					},
				},
			},
		})
		vim.lsp.enable("lua_ls")

		-- auto-format on save
		vim.api.nvim_create_autocmd("bufwritepre", {
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
					inlayhints = {
						typehints = { enable = true },
						parameterhints = { enable = false },
						chaininghints = { enable = false },
						bindingmodehints = { enable = false },
						closurereturntypehints = { enable = "never" },
						lifetimeelisionhints = { enable = "never" },
						reborrowhints = { enable = false },
						closingbracehints = { enable = false },
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
						autosearchpaths = true,
						diagnosticmode = "workspace",
						usellibrarycodefortypes = true,
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

		vim.lsp.config("roslyn_ls", {
			capabilities = capabilities,
		})
		vim.lsp.enable("roslyn_ls")

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
	end,
}
