-- lua/engine/tools/typst/init.lua
--
-- Typst toolkit.
--
--   :TypstPreview   open the compiled PDF next to the .typ file in zathura
--
-- Autocmd: every write of a .typ file recompiles it to a sibling .pdf, the
-- previous compile job is cancelled so fast successive writes don't pile up.

local M = {}

local compile_job = nil

local function pdf_path_for(file)
	return (file:gsub("%.typ$", ".pdf"))
end

function M.setup(group)
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.typ",
		callback = function(args)
			local file = vim.api.nvim_buf_get_name(args.buf)

			if compile_job then
				vim.fn.jobstop(compile_job)
			end

			compile_job = vim.fn.jobstart({ "typst", "compile", file, pdf_path_for(file) })
		end,
	})

	vim.api.nvim_create_user_command("TypstPreview", function()
		vim.fn.jobstart({ "zathura", pdf_path_for(vim.fn.expand("%")) })
	end, { desc = "Open the compiled PDF for the current .typ file" })
end

return M
