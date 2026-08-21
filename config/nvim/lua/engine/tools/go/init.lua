-- lua/engine/tools/go/init.lua
--
-- Go toolkit: fill an empty .go file with the boilerplate its name implies.
--
--   :Skel   on main.go      -> package main + func main
--           on *_test.go    -> package + a table-free test function
--           on anything else-> the package declaration for its directory
--
-- There are no commands of its own and no autocmds, so unlike the other
-- toolkits this one is not in TOOLKITS — tools/init.lua requires it lazily
-- through the :Skel dispatch table.
--
-- Indentation is always a tab: gofmt would rewrite spaces on the next write
-- anyway, so the buffer's own settings are deliberately ignored here.

local context = require("engine.tools.go.context")

local M = {}

local INDENT = "\t"

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Go" })
end

local function buffer_is_blank(bufnr)
	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		if line:match("%S") then
			return false
		end
	end

	return true
end

--- `TestMain` is reserved by the testing package for the optional
--- `TestMain(m *testing.M)` entry point, so a main_test.go gets a name that
--- will not silently become one.
local function test_function_name(stem)
	local base = stem:gsub("_test$", "")
	local name = "Test" .. context.camel_case(base)

	if name == "Test" or name == "TestMain" then
		return "TestRun"
	end

	return name
end

local function build(ctx)
	local lines = { "package " .. ctx.package, "" }
	local cursor

	if ctx.is_test then
		vim.list_extend(lines, {
			'import "testing"',
			"",
			("func %s(t *testing.T) {"):format(test_function_name(ctx.stem)),
			INDENT,
			"}",
		})
		cursor = #lines - 1
	elseif ctx.is_main then
		vim.list_extend(lines, {
			'import "fmt"',
			"",
			"func main() {",
			INDENT .. 'fmt.Println("Hello, world!")',
			"}",
		})
		cursor = #lines - 1
	else
		lines[#lines + 1] = ""
		cursor = #lines
	end

	return { lines = lines, cursor = cursor }
end

--- :Skel on a .go file lands here.
function M.skeleton()
	local bufnr = vim.api.nvim_get_current_buf()

	if not buffer_is_blank(bufnr) then
		notify("buffer is not empty", vim.log.levels.WARN)
		return
	end

	local ctx, err = context.for_buffer(bufnr)
	if not ctx then
		notify(err, vim.log.levels.ERROR)
		return
	end

	local result = build(ctx)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)

	local row = math.min(result.cursor, #result.lines)
	pcall(vim.api.nvim_win_set_cursor, 0, { row, #result.lines[row] })

	notify(("%s in package %s"):format(
		ctx.is_test and "test" or (ctx.is_main and "main" or "file"),
		ctx.package
	))
end

return M
