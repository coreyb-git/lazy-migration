local M = {}

local group = vim.api.nvim_create_augroup("lazy-migration-loader", {})

local dev_path

function M.set_dev_path(path)
	dev_path = path
	--vim.opt.rtp:prepend(path)
end

function M.local_repo(local_repo)
	--vim.pack.add({ local_repo })
	require(local_repo)
end

function M.gh(GitHubRepo)
	local fullname = "https://github.com/" .. GitHubRepo
	vim.pack.add({ fullname })
end

local function map(key, cmd, desc)
    vim.schedule(function()
        vim.keymap.set("n", key, cmd, { desc = desc, noremap = true })
    end)
end

local function explode(inputstr, sep)
	if sep == nil then
		sep = "%s" -- Default to whitespace
	end
	local t = {}
	-- Pattern: "Everything that is not the separator"
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

local function setup_autocmd(event, pattern, func)
	if event == "VeryLazy" then
		vim.api.nvim_create_autocmd("VimEnter", {
			once = true,
			group = group,
			callback = function()
				vim.schedule(func)
			end,
		})
	else
		vim.api.nvim_create_autocmd(event, {
			once = true,
			group = group,
			pattern = pattern,
			callback = function()
				vim.schedule(func)
			end,
		})
	end
end

function M.load_lazy_spec(spec)
	if spec == nil then
		return
	end

	if type(spec) == "string" then
		M.gh(spec)
		return
	end

	local name_type = type(spec[1])

	if name_type == "table" then
		for _, single_spec in ipairs(spec) do
			M.load_lazy_spec(single_spec)
		end
		return
	end

	if name_type ~= "string" then
		return
	end

	if spec.enabled ~= nil then
		if not spec.enabled then
			return
		end
	end

	-- Init function
	if spec.init ~= nil then
		spec.init()
	end

	-- Add Dependencies
	if spec.dependencies ~= nil then
		local dep_type = type(spec.dependencies)
		if dep_type == "string" then
			M.gh(spec.dependencies)
		elseif dep_type == "table" then
			for _, d in ipairs(spec.dependencies) do
				--	vim.print("Loading dependency: " .. vim.inspect(d))
				M.load_lazy_spec(d)
			end
		else
			vim.print("Bad dependencies for " .. repo)
		end
	end

	-- get plugin name
	local plug_name_table = explode(spec[1], "/")
	local plugin_repo_name = plug_name_table[#plug_name_table]
	local potential_name = string.gsub(plugin_repo_name, "%.nvim$", "")
	potential_name = string.gsub(potential_name, "%.lua$", "")
	if spec.name == nil then
		spec.name = potential_name
	end

	-- Add package
	local addfunc
	if spec.dev then
		vim.opt.rtp:prepend(dev_path .. plugin_repo_name)
		addfunc = function()
			M.local_repo(potential_name)
		end
	else
		addfunc = function()
			M.gh(spec[1])
		end
	end

	-- vim pack add, local or remote repo
	addfunc()

	local setup_func = function()
		-- opts
		if spec.opts ~= nil then
			require(spec.name).setup(spec.opts)
		end

		-- config func
		if spec.config ~= nil then
			spec.config()
		end
	end

	-- Keys
	if spec.keys ~= nil then
		for _, k in ipairs(spec.keys) do
			local key = k[1]
			local func = k[2]
			local desc = k.desc
			if desc == nil then
				desc = "not set"
			end
			map(key, func, desc)
		end
	end

	local is_lazy = false

	if spec.event then
		is_lazy = true
		local event_type = type(spec.event)
		if event_type == "function" then
			if spec_event() then
				setup_func()
			end
		else
			setup_autocmd(spec.event, "*", setup_func)
		end
	end

	if spec.cmd then
		is_lazy = true
		local cmd_type = type(spec.cmd)
		if cmd_type == "function" then
			if spec_cmd() then
				setup_func()
			end
		else
			setup_autocmd("User", spec.cmd, setup_func)
		end
	end

	if spec.ft then
		is_lazy = true
		local ft_type = type(spec.ft)
		if ft_type == "function" then
			if spec.ft() then
				setup_func()
			end
		else
			setup_autocmd("Filetype", spec.ft, setup_func)
		end
	end

	if not is_lazy then
		setup_func()
	end
end

function M.lazy_import(subdirectory)
	local config_path = vim.fn.stdpath("config") .. "/lua/" .. subdirectory
	local files = vim.fn.readdir(config_path)

	for _, name in ipairs(files) do
		local type = vim.fn.getftype(config_path .. "/" .. name)
		if type == "file" then
			local trimmed = string.gsub(name, "%.lua$", "")
			local plugin_file = subdirectory .. "/" .. trimmed
			local plugin_spec = require(plugin_file)
			M.load_lazy_spec(plugin_spec)
		end
	end
end

return M
