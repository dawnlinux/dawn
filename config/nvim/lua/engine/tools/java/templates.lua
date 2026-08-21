-- lua/engine/tools/java/templates.lua
--
-- Boilerplate bodies for every kind of Java file. Each builder returns
-- { lines = { … }, cursor = <index into lines> }; the caller drops the lines in
-- the buffer and parks the cursor on that line.

local M = {}

local Builder = {}
Builder.__index = Builder

local function builder(indent)
	return setmetatable({ lines = {}, indent = indent }, Builder)
end

function Builder:add(line)
	self.lines[#self.lines + 1] = line or ""
	return self
end

--- An empty, indented line — this is where the cursor lands.
function Builder:cursor_line(depth)
	self.lines[#self.lines + 1] = self.indent:rep(depth or 1)
	self.cursor = #self.lines
	return self
end

function Builder:header(ctx, imports)
	if ctx.package ~= "" then
		self:add("package " .. ctx.package .. ";")
		self:add()
	end

	if imports and #imports > 0 then
		for _, import in ipairs(imports) do
			-- An empty entry is a deliberate blank line between import groups.
			self:add(import ~= "" and ("import " .. import .. ";") or nil)
		end
		self:add()
	end

	return self
end

function Builder:result()
	return { lines = self.lines, cursor = self.cursor or #self.lines }
end

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Turn the trailing command arguments into a declaration suffix such as
--- `implements Runnable`. Returns "" when there is nothing to append.
local function declaration_tail(args)
	local tail = trim(table.concat(args or {}, " "))
	return tail ~= "" and (" " .. tail) or ""
end

local function is_clause(args)
	local first = (args or {})[1]
	return first == "extends" or first == "implements" or first == "permits"
end

--- Split "int x, int y" (however the shell chopped it up) into components.
local function split_commas(args)
	local joined = trim(table.concat(args or {}, " "))
	if joined == "" then
		return {}
	end

	local items = {}
	for item in joined:gmatch("[^,]+") do
		local cleaned = trim(item)
		if cleaned ~= "" then
			items[#items + 1] = cleaned
		end
	end

	return items
end

--- `public class Foo … { <cursor> }`
local function simple_type(keyword)
	return function(ctx, args, indent)
		local b = builder(indent)

		b:header(ctx)
		b:add(("public %s %s%s {"):format(keyword, ctx.type_name, declaration_tail(args)))
		b:cursor_line(1)
		b:add("}")

		return b:result()
	end
end

M.kinds = {}

M.kinds.class = {
	desc = "public class",
	build = simple_type("class"),
}

M.kinds.interface = {
	desc = "public interface",
	build = simple_type("interface"),
}

M.kinds.abstract = {
	desc = "public abstract class",
	build = simple_type("abstract class"),
}

M.kinds["final"] = {
	desc = "public final class",
	build = simple_type("final class"),
}

M.kinds.enum = {
	desc = "public enum (extra args become the constants)",
	build = function(ctx, args, indent)
		local b = builder(indent)
		local constants = is_clause(args) and {} or split_commas(args)
		local tail = is_clause(args) and declaration_tail(args) or ""

		b:header(ctx)
		b:add(("public enum %s%s {"):format(ctx.type_name, tail))

		if #constants > 0 then
			for index, constant in ipairs(constants) do
				local separator = index == #constants and ";" or ","
				b:add(indent .. constant:upper():gsub("[^%w_]", "_") .. separator)
			end
			b:add()
			b:cursor_line(1)
		else
			b:cursor_line(1)
		end

		b:add("}")

		return b:result()
	end,
}

M.kinds.record = {
	desc = "public record (extra args become the components)",
	build = function(ctx, args, indent)
		local b = builder(indent)
		local components = is_clause(args) and {} or split_commas(args)
		local tail = is_clause(args) and declaration_tail(args) or ""

		b:header(ctx)
		b:add(("public record %s(%s)%s {"):format(ctx.type_name, table.concat(components, ", "), tail))
		b:cursor_line(1)
		b:add("}")

		return b:result()
	end,
}

M.kinds.annotation = {
	desc = "public @interface (extra args become the @Target element types)",
	build = function(ctx, args, indent)
		local targets = {}
		for _, target in ipairs(split_commas(args)) do
			targets[#targets + 1] = "ElementType." .. target:upper():gsub("[^%w_]", "_")
		end

		if #targets == 0 then
			targets = { "ElementType.TYPE" }
		end

		local target_list = #targets == 1 and targets[1] or ("{ " .. table.concat(targets, ", ") .. " }")

		local b = builder(indent)

		b:header(ctx, {
			"java.lang.annotation.ElementType",
			"java.lang.annotation.Retention",
			"java.lang.annotation.RetentionPolicy",
			"java.lang.annotation.Target",
		})
		b:add("@Retention(RetentionPolicy.RUNTIME)")
		b:add("@Target(" .. target_list .. ")")
		b:add(("public @interface %s {"):format(ctx.type_name))
		b:cursor_line(1)
		b:add("}")

		return b:result()
	end,
}

M.kinds.exception = {
	desc = "exception class with the two usual constructors",
	build = function(ctx, args, indent)
		local tail = is_clause(args) and declaration_tail(args) or " extends RuntimeException"
		local name = ctx.type_name
		local b = builder(indent)

		b:header(ctx)
		b:add(("public class %s%s {"):format(name, tail))
		b:add(indent .. ("public %s(String message) {"):format(name))
		b:add(indent:rep(2) .. "super(message);")
		b:add(indent .. "}")
		b:add()
		b:add(indent .. ("public %s(String message, Throwable cause) {"):format(name))
		b:add(indent:rep(2) .. "super(message, cause);")
		b:add(indent .. "}")
		b:add("}")

		return b:result()
	end,
}

M.kinds.main = {
	desc = "class with a main method",
	build = function(ctx, args, indent)
		local b = builder(indent)

		b:header(ctx)
		b:add(("public class %s%s {"):format(ctx.type_name, declaration_tail(args)))
		b:add(indent .. "public static void main(String[] args) {")
		b:cursor_line(2)
		b:add(indent .. "}")
		b:add("}")

		return b:result()
	end,
}

M.kinds.test = {
	desc = "JUnit 5 test class",
	build = function(ctx, _, indent)
		local b = builder(indent)

		b:header(ctx, {
			"static org.junit.jupiter.api.Assertions.assertEquals",
			"",
			"org.junit.jupiter.api.Test",
		})
		b:add(("class %s {"):format(ctx.type_name))
		b:add(indent .. "@Test")
		b:add(indent .. "void shouldWork() {")
		b:cursor_line(2)
		b:add(indent .. "}")
		b:add("}")

		return b:result()
	end,
}

M.kinds.singleton = {
	desc = "eager singleton class",
	build = function(ctx, _, indent)
		local name = ctx.type_name
		local b = builder(indent)

		b:header(ctx)
		b:add(("public final class %s {"):format(name))
		b:add(indent .. ("private static final %s INSTANCE = new %s();"):format(name, name))
		b:add()
		b:add(indent .. ("private %s() {"):format(name))
		b:add(indent .. "}")
		b:add()
		b:add(indent .. ("public static %s getInstance() {"):format(name))
		b:add(indent:rep(2) .. "return INSTANCE;")
		b:add(indent .. "}")
		b:add()
		b:cursor_line(1)
		b:add("}")

		return b:result()
	end,
}

--- Sorted kind names, for command completion and error messages.
function M.names()
	local names = vim.tbl_keys(M.kinds)
	table.sort(names)
	return names
end

--- Build the boilerplate for `kind`.
--- @return table|nil result, string|nil error
function M.build(kind, ctx, args, indent)
	local template = M.kinds[kind]

	if not template then
		return nil, ("unknown kind %q (try: %s)"):format(kind, table.concat(M.names(), ", "))
	end

	return template.build(ctx, args or {}, indent)
end

return M
