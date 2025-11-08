local M = {}

local Path = require("plenary.path")
local Scan = require("plenary.scandir")

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local popup = Popup({
	enter = true,
	focusable = true,
	border = {
		style = "rounded",
	},
	position = "50%",
	size = {
		width = "80%",
		height = "60%",
	},
})
-- unmount component when cursor leaves buffer
popup:on(event.BufLeave, function()
	popup:unmount()
end)

function M.focus(lines)
	-- mount/open the component
	popup:mount()
	-- set content
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, lines)
end

return M
