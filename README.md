# lazy-migration.lua

Use the new vim.pack feature, without having to radically convert from existing lazy.nvim plugin specs.

This is certainly ugly, and probably horribly broken, and it would have taken less time writing the necessary vim.pack.add() instruction with all the plugins I use.  But why do it the easier, better way, when I could just leave my existing files as they are and write a disgusting loader that reads the lazy spec files to then, 1-by-1, add them to vim using vim.pack.add?

I have a lot of light-weight plugins for various things, and I just didn't want to have to deal with translating the files, so it seemed easier at the time to just read the existing spec files --- I was wrong.

Slap this file next to your init.lua file in .config/nvim/ and, assuming the plugin spec files are in the /plugins sub-directory:

```lua
local helper = require("lazy-migrate")
helper.set_dev_path("/wherever/you/happen/to/write/your/own/plugins/")

helper.lazy_import("plugins")
helper.lazy_import("plugins/folder1")
helper.lazy_import("plugins/folder2")
helper.lazy_import("plugins/folder3")
```

Etc.  It's not robust.  It's not even close to equivalent to all the engineering in lazy.vim.  But it does allow me to load my plugins in a way that allows NeoVim to be the package manager.

It's ugly.  Don't use it.  Write a proper bulk load of your plugins correctly with vim.pack.add({"repo1", "repo2", "repo3", "etc"}), and eat your vegetables.  This is only for unhinged people who want to purge lazy.nvim from their init.

Helper commands, regardless of this tool or not...

```lua
local leader = "<leader>P"

local function setup_keys()
	vim.keymap.set("n", leader, function() end, { desc = "[P]lugin Manager (Vim Pack)", noremap = true, silent = true })

	vim.api.nvim_create_user_command("VimPackShowAll", function()
		vim.pack.update(nil, { offline = true })
	end, {})

	local function get_unused()
		return vim.iter(vim.pack.get())
				:filter(function(x)
					return not x.active
				end)
				:map(function(x)
					return x.spec.name
				end)
				:totable()
	end

	vim.api.nvim_create_user_command("VimPackShowUnused", function()
		print(vim.inspect(get_unused()))
	end, {})

	vim.api.nvim_create_user_command("VimPackDeleteUnused", function()
		vim.pack.del(get_unused())
	end, {})

	vim.api.nvim_create_user_command("VimPackUpdate", function()
		vim.pack.update()
	end, {})

	local function map(key, cmd, desc)
		vim.keymap.set("n", leader .. key, cmd, { desc = desc, noremap = true, silent = true })
	end

	map("a", "<cmd>VimPackShowAll<cr>", "Show Show [A]ll Plugins")
	map("u", "<cmd>VimPackShowUnused<cr>", "Show [U]nused Plugins")
	map("D", "<cmd>VimPackDeleteUnused<cr>", "Show [D]ELETE Unused Plugins")
	map("U", "<cmd>VimPackUpdate<cr>", "Show [U]date Plugins")
end

setup_keys()
```

## Names Matter

Some plugin authors enjoy naming their repo something different to how the plugin is called internally with the require() function.  If you do this, I hate you!

Because this loader doesn't touch the files I have no convenient way of tracking what the internal directory structure is of plugins, without adding a tonne of bloat-code that I just don't want to do.

Solution:  I abuse the "name" property of the lazy spec for plugins that have an identity crisis and can't pick a single damn name for themselves..

```lua
return {
    "somebody/dumb-githug-repo-name",
    name = "actual_plugin_name",
    config = {
        local plugin = require("actual_plugin_name").setup({})
        },
    }
```
