local M = {}
local util = {}
local initialzed = false

local state = {
	win = nil,
	buf = nil,
}

function util.win_edit_config(win, additional_config)
	local config = vim.api.nvim_win_get_config(win)
	config = vim.tbl_extend("force", config, additional_config)
	vim.api.nvim_win_set_config(win, config)
end

function util.open_win(width, height, row, col, buf, enter)
	return vim.api.nvim_open_win(buf, enter, {
		width = width,
		height = height,
		row = row,
		col = col,
		relative = "editor",
		style = "minimal",
		border = "single",
	})
end

M.config = {}

local default_config = {
	relative = "win",
	style = "minimal",
	border = "single",
	margin = {
		x = 5,
		y = 5,
	},
	dir = vim.fn.expand("~/markket.d"),
}

M.renderer = function(buf, path)
	local output = {}
	local content = {}
	for name, type in vim.fs.dir(path, {}) do
		table.insert(content, { name = name, type = type })
	end

	for _, v in ipairs(content) do
		table.insert(output, v.name .. " " .. v.type)
	end
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(state.win, true)
	end, { buffer = buf, silent = true, nowait = true })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
end

function M.markket()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_set_current_win(state.win)
		return
	end

	vim.api.nvim_create_autocmd("VimResized", {
		callback = M.reload_ui,
		group = vim.api.nvim_create_augroup("Markket", { clear = true }),
		buffer = state.buf,
	})

	local config = M.config
	local ui = {
		width = vim.api.nvim_win_get_width(0),
		height = vim.api.nvim_win_get_height(0),
	}
	local width = ui.width - config.margin.x * 2
	local height = ui.height - config.margin.y * 2
	local opts = {
		relative = "editor",
		row = (ui.height - height) / 2 - (ui.height % 2 == 0 and 0 or 1),
		col = (ui.width - width) / 2 - (ui.width % 2 == 0 and 0 or 1),
		width = width,
		height = height,
		style = "minimal",
		border = "single",
	}
	state.buf = vim.api.nvim_create_buf(false, true)
	state.win = util.open_win(opts.width, opts.height, opts.row, opts.col, state.buf, true)

	local path = vim.fs.dirname(vim.fn.getcwd(0))
	M.renderer(state.buf, path)
end

M.reload_ui = function()
	local config = M.config
	local ui = {
		width = vim.api.nvim_win_get_width(0),
		height = vim.api.nvim_win_get_height(0),
	}
	local width = ui.width - config.margin.x * 2
	local height = ui.height - config.margin.y * 2
  local pw = math.max(50, width)
  local ph = math.max(15, height)
	util.win_edit_config(state.win, {
		row = (ui.height - ph) / 2 - (ui.height % 2 == 0 and 0 or 1),
		col = (ui.width - pw) / 2 - (ui.width % 2 == 0 and 0 or 1),
		width = pw,
		height = ph,
	})
end

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
end

-- Return the module
return M
