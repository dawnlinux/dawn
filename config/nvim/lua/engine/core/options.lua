vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt

opt.relativenumber = true
opt.number = true

-- tabs / indentation
opt.tabstop = 8
opt.shiftwidth = 8
opt.expandtab = false
opt.autoindent = true
opt.smartindent = true
opt.copyindent = true
opt.preserveindent = true

opt.wrap = false

opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

opt.backspace = "indent,eol,start"

opt.clipboard:append("unnamedplus")

opt.splitright = true
opt.splitbelow = true

opt.foldmethod = "marker"
opt.foldmarker = "#pragma region,#pragma endregion"

opt.winblend = 100 -- 0 = opaque, 100 = fully transparent
opt.pumblend = 10  -- For popup menus (completion)

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local bo = vim.bo[args.buf]
		bo.autoindent = true
		bo.smartindent = true
		bo.copyindent = true
		bo.preserveindent = true
	end,
})

vim.filetype.add({
	extension = {
		gd = "gdscript",
		gdshader = "gdshader",
		gdshaderinc = "gdshaderinc",
		tres = "gdresource",
		tscn = "gdresource",
	},
	filename = {
		["project.godot"] = "godot",
	},
})

vim.filetype.add({
	extension = {
		blade = "blade",
	},
	pattern = {
		[".*%.blade%.php"] = "blade",
	},
})
