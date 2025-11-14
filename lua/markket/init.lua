-- Main module for the Hello World plugin
local M = {}
local path = require("plenary.path")
local scan = require("plenary.scandir")

local renderer = require("markket.renderer")
local sources = require("markket.sources")

local default_config = {
	dir = vim.fn.expand("~/Markket.d"),
}

local config = {}

local function ensure_dir(opts)
	local dir = path:new(opts.dir)

	if not dir:exists() then
		local choice = vim.fn.confirm("Create Documents(~/Markket.d)", "&Yes\n&No", 2)
		if choice == 0 then
			return
		end
		dir:mkdir({ parents = true })
		if dir:exists() then
			print("Dirctory Already Created!\n" .. dir:absolute())
		end
	end
  return dir
end

function M.markket()
	local dir = ensure_dir(opts)
  local lines = sources.filesystem.get_ls()
  renderer.focus(lines)
end

-- Function to set up the plugin (Most package managers expect the plugin to have a setup function)
function M.setup(opts)
	config = opts or default_config

	-- vim.api.nvim_create_user_command("Markket", M.markket, {})
end

-- Return the module
return M
