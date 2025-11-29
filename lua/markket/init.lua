local M = {}

local default_config = {
	relative = "win",
	style = "minimal",
	border = "single",
	margin = {
		up = 10,
		left = 10,
		right = 10,
		down = 10,
	},
	dir = vim.fn.expand("~/markket.d"),
}

local function merge_config(firstly, secondary)
	firstly = firstly or {}
	for k, v in pairs(secondary) do
		if type(firstly[k]) == "table" and type(v) == "table" then
			merge_config(firstly[k], v)
		else
			if firstly[k] == nil then
				firstly[k] = v
			end
		end
	end
	return firstly
end

--- @param config table user added config
local ensure_config = function(config)
	config = merge_config(config, default_config)
	return config
end

M.renderer = function(opts)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, opts) -- false 表示不抢夺焦点
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, silent = true, nowait = true })
end

function M.markket(config)
	local ui = vim.api.nvim_list_uis()[1]
	local opts = {
		relative = "win",
		row = default_config.margin.up,
		col = default_config.margin.left,
		width = ui.width - default_config.margin.left * 2,
		height = ui.height - default_config.margin.up * 2,
		style = "minimal",
		border = "single",
	}
  M.renderer(opts)
end

M.setup = function(opts)
	local config = opts or {}
	config = ensure_config(config)
	-- M.renderer()
end

-- Return the module
return M
