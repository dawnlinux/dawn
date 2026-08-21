-- lua/engine/tools/init.lua
--
-- Registry for the hand-written, per-language toolkits. Each entry lives in its
-- own directory and owns its commands and autocmds:
--
--   engine.tools.cpp     :Skel, :CppExtractDefinitions,
--                        :CppExtractFunctionDefinition, include sorting on save,
--                        include rewriting on rename
--   engine.tools.java    :Java, :JavaClass and friends, :JavaPackage
--   engine.tools.typst   :TypstPreview, compile on save
--   engine.tools.go      :Skel only — no commands and no autocmds of its own,
--                        so it is required lazily and is not in TOOLKITS
--
-- :Skel is shared: it dispatches to whichever toolkit owns the current
-- filetype, so the same key works in a header and in a .java file.

local M = {}

local TOOLKITS = {
	"engine.tools.cpp",
	"engine.tools.java",
	"engine.tools.typst",
}

-- filetype -> toolkit module that can fill an empty file with a Skeleton
local SKELETON_HANDLERS = {
	c = "engine.tools.cpp",
	cpp = "engine.tools.cpp",
	objc = "engine.tools.cpp",
	objcpp = "engine.tools.cpp",
	java = "engine.tools.java",
	go = "engine.tools.go",
}

local function Skeleton()
	local module = SKELETON_HANDLERS[vim.bo.filetype]

	if not module then
		vim.notify(
			("Skel: nothing registered for filetype %q"):format(vim.bo.filetype),
			vim.log.levels.WARN
		)
		return
	end

	require(module).skeleton()
end

function M.setup()
	local group = vim.api.nvim_create_augroup("EngineTools", { clear = true })

	for _, module in ipairs(TOOLKITS) do
		require(module).setup(group)
	end

	vim.api.nvim_create_user_command("Skel", Skeleton, {
		desc = "Insert a Skeleton for the current file type",
	})
end

return M
