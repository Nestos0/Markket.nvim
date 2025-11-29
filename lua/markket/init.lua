local M = {}
local initial = false

M.config = {}

local default_config = {
	relative = "win",
	style = "minimal",
	border = "single",
	margin = {
		x = 10,
		y = 10,
	},
	dir = vim.fn.expand("~/markket.d"),
}

local function merge_tbl(firstly, secondary)
	firstly = firstly or {}
	for k, v in pairs(secondary) do
		if type(firstly[k]) == "table" and type(v) == "table" then
			merge_tbl(firstly[k], v)
		else
			if firstly[k] == nil then
				firstly[k] = v
			end
		end
	end
	return firstly
end

local ensure_config = function()
	M.config = merge_tbl(M.config, default_config)
end

M.renderer = function(opts)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, opts) -- false 表示不抢夺焦点
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, silent = true, nowait = true })
end

function M.markket()
	if initial ~= true then
		ensure_config()
	end
	local config = M.config
	local ui = vim.api.nvim_list_uis()[1]
	local width = ui.width - config.margin.x * 2
	local height = ui.height - config.margin.y * 2
	local opts = {
		relative = "win",
		row = (ui.height - height) / 2,
		col = (ui.width - width) / 2,
		width = width,
		height = height,
		style = "minimal",
		border = "single",
	}
	M.renderer(opts)
end

M.setup = function(opts)
	M.config = opts or {}
	ensure_config()
	initial = true
end

-- Return the module
return M
