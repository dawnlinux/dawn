local colorschemes = require("engine.core.colorschemes")

local M = {}

local default_scheme = "koda"
local state_file = vim.fs.joinpath(vim.fn.stdpath("state"), "engine-theme")

local function read_saved()
	local ok, lines = pcall(vim.fn.readfile, state_file)
	if not ok or type(lines) ~= "table" then
		return nil
	end

	local name = vim.trim(lines[1] or "")

	return name ~= "" and name or nil
end

local function save(name)
	pcall(vim.fn.mkdir, vim.fs.dirname(state_file), "p")
	pcall(vim.fn.writefile, { name }, state_file)
end

-- koda ships several variants that only pick up their background overrides if
-- `require("koda").setup()` ran first. On a cold start the plugin is lazy, so
-- the require only succeeds once `:colorscheme` has pulled it onto the rtp.
local function configure_koda(name)
	return pcall(function()
		require("engine.core.koda").setup(name)
	end)
end

local function index_of(names, name)
	for index, candidate in ipairs(names) do
		if candidate == name then
			return index
		end
	end

	return nil
end

function M.names()
	return colorschemes.names()
end

--- Apply a colorscheme by name.
--- @param name string
--- @param opts table|nil `persist` (default true) writes the choice to disk.
--- @return boolean ok
function M.apply(name, opts)
	opts = opts or {}

	local configured = configure_koda(name)

	local ok, err = pcall(vim.cmd.colorscheme, name)
	if not ok then
		vim.notify(("Theme: cannot load %q\n%s"):format(name, err), vim.log.levels.ERROR)
		return false
	end

	if not configured and configure_koda(name) then
		pcall(vim.cmd.colorscheme, name)
	end

	if opts.persist ~= false then
		save(name)
	end

	return true
end

--- Step through the colorscheme list, wrapping at both ends.
--- @param step integer 1 for the next scheme, -1 for the previous one.
function M.cycle(step)
	local names = M.names()
	if #names == 0 then
		return
	end

	local current = index_of(names, vim.g.colors_name or "") or 0
	local next_index = ((current - 1 + step) % #names) + 1
	local name = names[next_index]

	if M.apply(name) then
		vim.notify(("Theme: %s (%d/%d)"):format(name, next_index, #names), vim.log.levels.INFO)
	end
end

function M.select()
	vim.ui.select(M.names(), {
		prompt = "Colorscheme",
		format_item = function(name)
			return name == vim.g.colors_name and ("%s  (current)"):format(name) or name
		end,
	}, function(choice)
		if choice then
			M.apply(choice)
		end
	end)
end

local function create_commands()
	local function complete(arg_lead)
		return vim.tbl_filter(function(name)
			return name:find(arg_lead, 1, true) == 1
		end, M.names())
	end

	vim.api.nvim_create_user_command("Theme", function(args)
		if args.args == "" then
			M.select()
		else
			M.apply(args.args)
		end
	end, {
		nargs = "?",
		complete = complete,
		desc = "Pick a colorscheme (no argument opens the picker)",
	})

	vim.api.nvim_create_user_command("ThemeNext", function()
		M.cycle(1)
	end, { desc = "Next colorscheme" })

	vim.api.nvim_create_user_command("ThemePrev", function()
		M.cycle(-1)
	end, { desc = "Previous colorscheme" })
end

function M.setup()
	create_commands()

	local saved = read_saved()

	if saved and saved ~= default_scheme then
		-- Don't re-save on startup: a scheme that has since been removed from
		-- the plugin list should fall back without clobbering the state file.
		if M.apply(saved, { persist = false }) then
			return
		end
	end

	M.apply(default_scheme, { persist = false })
end

return M
