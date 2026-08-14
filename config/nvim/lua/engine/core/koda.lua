local M = {}

local variant_overrides = {
	dark = {
		bg = "#090909",
		line = "#1a1a1a",
	},
	moss = {
		bg = "#090d0e",
		line = "#151d1e",
	},
}

local function variant_for(name)
	if name == "koda-dark" then
		return "dark"
	end

	if name == "koda-moss" then
		return "moss"
	end

	if name == "koda" then
		return vim.o.background == "light" and "light" or "dark"
	end

	if name == "koda-light" then
		return "light"
	end

	if name == "koda-glade" then
		return "glade"
	end

	return nil
end

function M.setup(name)
	local variant = variant_for(name)
	if not variant then
		return
	end

	require("koda").setup({
		colors = variant_overrides[variant] or {},
	})
end

return M
