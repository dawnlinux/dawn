-- lua/engine/tools/java/context.lua
--
-- Works out what a .java file is supposed to say about itself: which package it
-- lives in (from the maven/gradle source layout on disk) and which type name it
-- must declare (from the file name, because javac insists they match).

local M = {}

local ROOT_MARKERS = {
	"pom.xml",
	"build.gradle",
	"build.gradle.kts",
	"settings.gradle",
	"settings.gradle.kts",
	".git",
}

-- Checked in order, longest layout first: a file under src/main/java must not
-- match the bare src/ rule.
local SOURCE_ROOTS = {
	"src/main/java",
	"src/test/java",
	"src/main/kotlin",
	"src/test/kotlin",
	"src/java",
	"src",
	"java",
}

local function normalize(path)
	return (path or ""):gsub("\\", "/")
end

--- A package segment has to be a legal Java identifier: `my-app` and `2d` are
--- not, so fold them into something that at least compiles.
local function sanitize_segment(segment)
	local cleaned = segment:lower():gsub("[^%w_]", "_")

	if cleaned == "" then
		return nil
	end

	if cleaned:match("^%d") then
		cleaned = "_" .. cleaned
	end

	return cleaned
end

function M.is_identifier(name)
	return type(name) == "string" and name:match("^[%a_$][%w_$]*$") ~= nil
end

function M.project_root(path)
	return normalize(vim.fs.root(path, ROOT_MARKERS) or vim.fn.getcwd())
end

--- Split an absolute directory into { source_root, relative_package_dir }.
local function split_source_root(dir)
	for _, layout in ipairs(SOURCE_ROOTS) do
		-- Match the *last* occurrence, so a nested module wins over the outer one.
		local last_start, last_stop
		local from = 1

		while true do
			local start, stop = dir:find("/" .. layout .. "/", from, true)
			if not start then
				break
			end
			last_start, last_stop = start, stop
			from = start + 1
		end

		if last_start then
			return dir:sub(1, last_stop - 1), dir:sub(last_stop + 1)
		end

		if dir:sub(-(#layout + 1)) == "/" .. layout then
			return dir, ""
		end
	end

	return nil, nil
end

--- Infer the package for a file path. Returns "" for the default package.
--- @param path string absolute path to the .java file
--- @return string package
function M.package_for(path)
	path = normalize(path)

	local dir = vim.fn.fnamemodify(path, ":h")
	local _, relative = split_source_root(dir)

	if not relative then
		-- No recognisable source layout: fall back to the path below the
		-- project root, which is right often enough for scratch projects.
		local root = M.project_root(path)
		relative = normalize(vim.fs.relpath(root, dir) or "")

		if relative == "." then
			relative = ""
		end
	end

	if relative == "" then
		return ""
	end

	local segments = {}

	for segment in relative:gmatch("[^/]+") do
		local cleaned = sanitize_segment(segment)
		if cleaned then
			segments[#segments + 1] = cleaned
		end
	end

	return table.concat(segments, ".")
end

--- Everything a template needs about the current buffer.
--- @param bufnr integer|nil
--- @param name string|nil explicit type name, overrides the file name
--- @return table|nil context, string|nil error
function M.for_buffer(bufnr, name)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = normalize(vim.api.nvim_buf_get_name(bufnr))
	local stem = path ~= "" and vim.fn.fnamemodify(path, ":t:r") or nil
	local type_name = name or stem

	if not type_name or type_name == "" then
		return nil, "no name: save the buffer as Something.java, or pass a name (:JavaClass Something)"
	end

	if not M.is_identifier(type_name) then
		return nil, ("%q is not a valid Java type name"):format(type_name)
	end

	if name and stem and name ~= stem then
		vim.notify(
			("Java: type %s does not match file %s.java — javac will reject a public type here")
				:format(name, stem),
			vim.log.levels.WARN
		)
	end

	return {
		bufnr = bufnr,
		path = path,
		type_name = type_name,
		package = path ~= "" and M.package_for(path) or "",
	}
end

--- The buffer's own indent settings, so generated code matches the file.
function M.indent(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not vim.bo[bufnr].expandtab then
		return "\t"
	end

	local width = vim.bo[bufnr].shiftwidth
	if width == 0 then
		width = vim.bo[bufnr].tabstop
	end

	return string.rep(" ", width)
end

return M
