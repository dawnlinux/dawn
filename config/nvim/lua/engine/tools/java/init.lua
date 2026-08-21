-- lua/engine/tools/java/init.lua
--
-- Java toolkit: fill an empty .java file with the boilerplate its kind needs.
--
--   :JavaClass       :JavaInterface   :JavaEnum        :JavaRecord
--   :JavaAnnotation  :JavaException   :JavaMain        :JavaTest
--   :JavaAbstract    :JavaFinal       :JavaSingleton
--   :Java {kind}     dispatcher for all of the above (completes the kinds)
--   :JavaPackage     insert or repair the package declaration
--
-- The type name always comes from the file name, because javac requires that.
-- In an unnamed scratch buffer the first argument is used as the name instead.
-- Any remaining arguments are template specific:
--
--   :JavaRecord int x, int y          -> public record Point(int x, int y)
--   :JavaEnum RED, GREEN, BLUE        -> the enum constants
--   :JavaAnnotation METHOD, FIELD     -> @Target({ ElementType.METHOD, … })
--   :JavaClass implements Runnable    -> appended to the declaration
--
-- Every command takes a bang (:JavaClass!) to overwrite a buffer that already
-- has content; without it a non-empty buffer is left alone.

local context = require("engine.tools.java.context")
local templates = require("engine.tools.java.templates")

local M = {}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Java" })
end

local function buffer_is_blank(bufnr)
	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		if line:match("%S") then
			return false
		end
	end

	return true
end

--- Pick a sensible template from the file name: FooTest -> test, and so on.
local function kind_from_filename(stem)
	if stem:match("Test$") or stem:match("Tests$") or stem:match("^Test") then
		return "test"
	end

	if stem:match("Exception$") or stem:match("Error$") then
		return "exception"
	end

	if stem == "Main" then
		return "main"
	end

	return "class"
end

--- Insert the boilerplate for `kind` into the current buffer.
--- @param kind string
--- @param fargs table remaining command arguments
--- @param bang boolean overwrite a non-empty buffer
function M.generate(kind, fargs, bang)
	local bufnr = vim.api.nvim_get_current_buf()

	if not buffer_is_blank(bufnr) and not bang then
		notify("buffer is not empty — re-run with ! to overwrite", vim.log.levels.WARN)
		return
	end

	local args = vim.list_slice(fargs or {})
	local name = nil

	-- A named buffer dictates the type name, so everything the user typed is
	-- template input. An unnamed one has to be told the name first.
	if vim.api.nvim_buf_get_name(bufnr) == "" then
		name = table.remove(args, 1)
	end

	local ctx, err = context.for_buffer(bufnr, name)
	if not ctx then
		notify(err, vim.log.levels.ERROR)
		return
	end

	local result, build_err = templates.build(kind, ctx, args, context.indent(bufnr))
	if not result then
		notify(build_err, vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)

	if vim.bo[bufnr].filetype ~= "java" then
		vim.bo[bufnr].filetype = "java"
	end

	local row = math.min(result.cursor, #result.lines)
	pcall(vim.api.nvim_win_set_cursor, 0, { row, #result.lines[row] })

	notify(("%s %s%s"):format(
		kind,
		ctx.type_name,
		ctx.package ~= "" and (" in " .. ctx.package) or " (default package)"
	))
end

--- :Skel on a .java file lands here.
function M.skeleton()
	local stem = vim.fn.expand("%:t:r")
	M.generate(kind_from_filename(stem), {}, false)
end

--- Insert or repair the `package …;` line for the current file.
function M.fix_package()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)

	if path == "" then
		notify("save the buffer first — the package comes from its path", vim.log.levels.WARN)
		return
	end

	local package = context.package_for(path)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local first_code = nil
	for index, line in ipairs(lines) do
		if line:match("%S") then
			first_code = index
			break
		end
	end

	local declaration = package ~= "" and ("package " .. package .. ";") or nil

	if first_code and lines[first_code]:match("^%s*package%s") then
		if not declaration then
			-- Moved into the default package: drop the stale declaration and
			-- the blank line that followed it.
			local last = first_code
			if lines[first_code + 1] and not lines[first_code + 1]:match("%S") then
				last = first_code + 1
			end
			vim.api.nvim_buf_set_lines(bufnr, first_code - 1, last, false, {})
			notify("removed package declaration (default package)")
			return
		end

		if lines[first_code] == declaration then
			notify("package already correct: " .. package)
			return
		end

		vim.api.nvim_buf_set_lines(bufnr, first_code - 1, first_code, false, { declaration })
		notify("package -> " .. package)
		return
	end

	if not declaration then
		notify("file is in the default package — nothing to declare")
		return
	end

	local insert_at = (first_code or 1) - 1
	vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, { declaration, "" })
	notify("package -> " .. package)
end

local function command_name_for(kind)
	return "Java" .. kind:sub(1, 1):upper() .. kind:sub(2)
end

function M.setup()
	for kind, template in pairs(templates.kinds) do
		vim.api.nvim_create_user_command(command_name_for(kind), function(args)
			M.generate(kind, args.fargs, args.bang)
		end, {
			nargs = "*",
			bang = true,
			desc = "Java boilerplate: " .. template.desc,
		})
	end

	vim.api.nvim_create_user_command("Java", function(args)
		local fargs = vim.list_slice(args.fargs)
		local kind = table.remove(fargs, 1)

		if not kind then
			vim.ui.select(templates.names(), {
				prompt = "Java boilerplate",
				format_item = function(name)
					return ("%-11s %s"):format(name, templates.kinds[name].desc)
				end,
			}, function(choice)
				if choice then
					M.generate(choice, {}, args.bang)
				end
			end)
			return
		end

		M.generate(kind, fargs, args.bang)
	end, {
		nargs = "*",
		bang = true,
		complete = function(arg_lead, line)
			-- Only the first argument is a kind; the rest is template input.
			if line:match("^%s*Java!?%s+%S+%s") then
				return {}
			end

			return vim.tbl_filter(function(name)
				return name:find(arg_lead, 1, true) == 1
			end, templates.names())
		end,
		desc = "Java boilerplate: pick a kind (no argument opens a picker)",
	})

	vim.api.nvim_create_user_command("JavaPackage", function()
		M.fix_package()
	end, { desc = "Insert or repair the package declaration for this file" })
end

return M
