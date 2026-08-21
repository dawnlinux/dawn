-- lua/engine/tools/go/context.lua
--
-- Works out what a .go file should say in its `package` line. Unlike Java, Go
-- takes the package from the *directory*, not from the path below a source
-- root, and every file in a directory has to agree — so the most reliable
-- answer is whatever the neighbouring files already declare.

local M = {}

-- How many sibling .go files to open before giving up on finding a package
-- declaration. Directories with more files than this still resolve, because the
-- declaration is on the first non-comment line of any one of them.
local SIBLING_LIMIT = 25

local function normalize(path)
	return (path or ""):gsub("\\", "/")
end

--- Go package names are lower case and, by convention, carry no underscores or
--- dashes: `my-app` and `go_utils` become `myapp` and `goutils`.
local function sanitize(name)
	local cleaned = name:lower():gsub("[^%w]", "")

	if cleaned == "" then
		return nil
	end

	-- if cleaned == "" then
	-- 	return nil
	-- end

	-- An identifier cannot start with a digit; `2d` would not compile.
	if cleaned:match("^%d") then
		cleaned = "_" .. cleaned
	end

	return cleaned
end

--- The package declared by a .go file, or nil if it has none yet.
local function package_in_file(path)
	local ok, lines = pcall(vim.fn.readfile, path, "", 40)
	if not ok then
		return nil
	end

	local in_block_comment = false

	for _, line in ipairs(lines) do
		local text = line

		if in_block_comment then
			local stop = text:find("*/", 1, true)
			if not stop then
				goto continue
			end
			text = text:sub(stop + 2)
			in_block_comment = false
		end

		-- A build-constraint or licence comment above the package clause is
		-- normal, so skip comments rather than bailing out on them.
		text = text:gsub("//.*$", "")

		local start = text:find("/%*")
		if start then
			in_block_comment = true
			text = text:sub(1, start - 1)
		end

		local package = text:match("^%s*package%s+([%a_][%w_]*)")
		if package then
			return package
		end

		::continue::
	end

	return nil
end

--- The package the rest of this directory already uses, if any.
--- @param dir string
--- @param exclude string absolute path of the file being generated
--- @return string|nil
function M.package_from_siblings(dir, exclude)
	local files = vim.fn.glob(dir .. "/*.go", true, true)
	local seen = 0

	for _, file in ipairs(files) do
		file = normalize(file)

		-- `foo_test.go` may declare `package foo_test`, which would be the wrong
		-- answer for a normal file, so those never get a vote.
		if file ~= exclude and not file:match("_test%.go$") then
			local package = package_in_file(file)
			if package then
				return package
			end

			seen = seen + 1
			if seen >= SIBLING_LIMIT then
				break
			end
		end
	end

	return nil
end

--- Everything a Go skeleton needs to know about the current buffer.
--- @param bufnr integer|nil
--- @return table|nil context, string|nil error
function M.for_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = normalize(vim.api.nvim_buf_get_name(bufnr))

	if path == "" then
		return nil, "save the buffer first — the package comes from its directory"
	end

	local dir = vim.fn.fnamemodify(path, ":h")
	local file = vim.fn.fnamemodify(path, ":t")
	local stem = vim.fn.fnamemodify(path, ":t:r")
	local is_test = file:match("_test%.go$") ~= nil

	-- Whatever the neighbours say wins: the compiler demands they all agree.
	local package = M.package_from_siblings(dir, path)

	if not package then
		if file == "main.go" or vim.fn.fnamemodify(dir, ":h:t") == "cmd" then
			-- A lone main.go, or anything directly under cmd/, is a command.
			package = "main"
		else
			package = sanitize(vim.fn.fnamemodify(dir, ":t")) or "main"
		end
	end

	return {
		bufnr = bufnr,
		path = path,
		file = file,
		stem = stem,
		dir = dir,
		package = package,
		is_test = is_test,
		is_main = package == "main" and not is_test,
	}
end

--- `widget_store` -> `WidgetStore`, for building a test function name.
function M.camel_case(name)
	local out = {}

	for word in name:gmatch("[%a%d]+") do
		out[#out + 1] = word:sub(1, 1):upper() .. word:sub(2)
	end

	return table.concat(out)
end

return M
