local lsp_log = vim.lsp.log.get_filename()
local max_lsp_log_size = 10 * 1024 * 1024

local stat = vim.uv.fs_stat(lsp_log)
if stat and stat.size > max_lsp_log_size then
	local fd = vim.uv.fs_open(lsp_log, "w", 420)
	if fd then
		vim.uv.fs_close(fd)
	end
end

vim.lsp.log.set_level(vim.log.levels.ERROR)
require("engine.core")
require("engine.lazy")
