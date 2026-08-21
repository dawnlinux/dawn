-- lua/engine/tools/cpp/init.lua
--
-- C/C++ toolkit.
--
--   :Skel                          insert a header/source skeleton (see tools/init.lua)
--   :CppExtractDefinitions         move every inline member definition into the .cpp
--   :CppExtractFunctionDefinition  move the function under the cursor into the .cpp
--
-- Autocmds: includes are sorted/grouped on every C/C++ write, and renaming a
-- C/C++ file from nvim-tree rewrites the #includes that pointed at it.

local M = {}

local SOURCE_PATTERNS = { "*.h", "*.hpp", "*.hh", "*.hxx", "*.c", "*.cc", "*.cpp", "*.cxx" }

function M.setup(group)
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		pattern = SOURCE_PATTERNS,
		callback = function(args)
			-- .typ files can carry a C-ish filetype; never touch them here.
			if vim.bo[args.buf].filetype == "typst" then
				return
			end

			require("engine.tools.cpp.include_formatter").format(args.buf)
		end,
	})

	-- include_rename hooks nvim-tree's rename event, so it can only be wired up
	-- once that plugin exists.
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "LazyLoad",
		callback = function(args)
			if args.data ~= "nvim-tree.lua" then
				return
			end

			local ok, api = pcall(require, "nvim-tree.api")
			if ok then
				require("engine.tools.cpp.include_rename").setup(api)
			end
		end,
	})

	local ok, api = pcall(require, "nvim-tree.api")
	if ok then
		require("engine.tools.cpp.include_rename").setup(api)
	end

	require("engine.tools.cpp.extract").setup()
end

function M.skeleton()
	require("engine.tools.cpp.skeleton").insert()
end

return M
