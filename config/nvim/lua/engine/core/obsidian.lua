local M = {}

local function expand(path)
	return vim.fn.expand(path)
end

local function env_or(name, fallback)
	local value = vim.env[name]

	if value ~= nil and value ~= "" then
		return expand(value)
	end

	return expand(fallback)
end

local function is_dir(path)
	return vim.fn.isdirectory(path) == 1
end

local function normalize_workspace(workspace)
	if type(workspace) ~= "table" or type(workspace.path) ~= "string" then
		return nil
	end

	local normalized = vim.deepcopy(workspace)
	normalized.path = expand(normalized.path)

	if not is_dir(normalized.path) then
		return nil
	end

	if type(normalized.name) ~= "string" or normalized.name == "" then
		normalized.name = vim.fs.basename(normalized.path)
	end

	return normalized
end

local function detect_vault_root()
	local candidates = {
		vim.api.nvim_buf_get_name(0),
		vim.uv.cwd(),
	}

	for _, candidate in ipairs(candidates) do
		if type(candidate) == "string" and candidate ~= "" then
			local start = candidate

			if vim.fn.filereadable(start) == 1 then
				start = vim.fs.dirname(start)
			end

			local root = vim.fs.find(".obsidian", {
				path = start,
				upward = true,
				type = "directory",
				limit = 1,
			})[1]

			if root then
				return vim.fs.dirname(root)
			end
		end
	end

	return nil
end

local function slugify(text)
	local slug = text:lower()
	slug = slug:gsub("[^a-z0-9%s-]", "")
	slug = slug:gsub("%s+", "-")
	slug = slug:gsub("%-+", "-")
	slug = slug:gsub("^%-", "")
	slug = slug:gsub("%-$", "")

	return slug
end

local function find_daily_template(workspaces)
	for _, workspace in ipairs(workspaces) do
		if type(workspace.path) == "string" then
			local template = vim.fs.joinpath(expand(workspace.path), "templates", "daily.md")

			if vim.fn.filereadable(template) == 1 then
				return "daily.md"
			end
		end
	end

	return nil
end

function M.setup_markdown_buffer(bufnr)
	local opt = vim.opt_local

	opt.wrap = true
	opt.linebreak = true
	opt.conceallevel = 2
	opt.concealcursor = "nc"
	opt.spell = false
	opt.textwidth = 100

	vim.api.nvim_buf_call(bufnr, function()
		vim.opt_local.formatoptions:append({ "n", "2" })
		vim.opt_local.formatoptions:remove("t")
	end)
end

function M.workspaces()
	if type(vim.g.obsidian_workspaces) == "table" and #vim.g.obsidian_workspaces > 0 then
		local workspaces = {}

		for _, workspace in ipairs(vim.g.obsidian_workspaces) do
			local normalized = normalize_workspace(workspace)

			if normalized then
				workspaces[#workspaces + 1] = normalized
			end
		end

		if #workspaces > 0 then
			return workspaces
		end
	end

	local workspaces = {
		{
			name = "personal",
			path = env_or("OBSIDIAN_VAULT_PERSONAL", "~/vaults/personal"),
		},
		{
			name = "work",
			path = env_or("OBSIDIAN_VAULT_WORK", "~/vaults/work"),
		},
	}

	local existing = {}
	local seen = {}

	for _, workspace in ipairs(workspaces) do
		local normalized = normalize_workspace(workspace)

		if normalized and not seen[normalized.path] then
			seen[normalized.path] = true
			existing[#existing + 1] = normalized
		end
	end

	local detected_root = detect_vault_root()

	if detected_root and not seen[detected_root] then
		existing[#existing + 1] = {
			name = vim.fs.basename(detected_root),
			path = detected_root,
		}
	end

	-- obsidian.nvim errors out when handed an empty workspace list, so always
	-- leave it with something valid to fall back on.
	if #existing == 0 then
		local cwd = vim.uv.cwd() or expand("~")

		existing[1] = {
			name = vim.fs.basename(cwd),
			path = cwd,
		}
	end

	return existing
end

function M.opts()
	local workspaces = M.workspaces()

	return {
		workspaces = workspaces,
		legacy_commands = false,
		notes_subdir = "notes",
		new_notes_location = "notes_subdir",
		open_notes_in = "current",
		link = {
			style = "wiki",
		},
		search = {
			sort_by = "modified",
			sort_reversed = true,
		},
		completion = {
			min_chars = 2,
		},
		daily_notes = {
			folder = "notes/dailies",
			date_format = "%Y-%m-%d",
			alias_format = "%A, %B %-d, %Y",
			default_tags = { "daily", "journal" },
			template = find_daily_template(workspaces),
		},
		templates = {
			folder = "templates",
			date_format = "%Y-%m-%d",
			time_format = "%H:%M",
			substitutions = {
				weekday = function()
					return os.date("%A")
				end,
				cursor = function()
					return "<++>"
				end,
			},
		},
		note_id_func = function(title)
			local suffix = title and slugify(title) or ""

			if suffix == "" then
				suffix = tostring(os.time())
			end

			return string.format("%s-%s", os.date("%Y%m%d-%H%M"), suffix)
		end,
		frontmatter = {
			func = function(note)
				if note.title then
					note:add_alias(note.title)
				end

				local out = {
					id = note.id,
					aliases = note.aliases,
					tags = note.tags,
				}

				if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
					for key, value in pairs(note.metadata) do
						out[key] = value
					end
				end

				return out
			end,
		},
		picker = {
			name = "telescope.nvim",
			note_mappings = {
				new = "<C-x>",
				insert_link = "<C-l>",
			},
			tag_mappings = {
				tag_note = "<C-x>",
				insert_tag = "<C-l>",
			},
		},
		attachments = {
			folder = "assets/imgs",
			img_name_func = function()
				return string.format("%s-", os.date("%Y%m%d-%H%M%S"))
			end,
		},
		ui = {
			enable = false,
		},
		callbacks = {
			enter_note = function()
				M.setup_markdown_buffer(0)
			end,
		},
	}
end

return M
