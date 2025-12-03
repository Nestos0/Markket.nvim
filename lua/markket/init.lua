local M = {}
local util = {}

---@class MarkketState
---@field win integer|nil The floating window handle
---@field buf integer|nil The buffer handle
---@field prev_win integer|nil The window handle where the plugin was triggered (to open files)
---@field current_item string|nil The full path of the currently selected item
---@field current_path string|nil The full path of the current directory being viewed
local state = {
    win = nil,
    buf = nil,
    prev_win = nil,
    current_item = nil,
    current_path = nil,
}

---@class MarkketConfig
---@field relative string Window relative placement (default: "editor")
---@field style string Window style (default: "minimal")
---@field border string Window border style (default: "single")
---@field margin { x: integer, y: integer } Margins for the centered window
---@field dir string The initial directory to open

M.config = {}

local default_config = {
    relative = "editor",
    style = "minimal",
    border = "single",
    margin = {
        x = 5,
        y = 5,
    },
    dir = vim.fn.expand("~/markket.d"),
}

---Updates the configuration of an existing window
---@param win integer The window handle
---@param additional_config table The new configuration to merge
function util.win_edit_config(win, additional_config)
    local config = vim.api.nvim_win_get_config(win)
    config = vim.tbl_extend("force", config, additional_config)
    vim.api.nvim_win_set_config(win, config)
end

---Opens a new floating window
---@param width integer Window width
---@param height integer Window height
---@param row integer Window row position
---@param col integer Window column position
---@param buf integer Buffer handle to attach
---@param enter boolean Whether to enter the window immediately
---@return integer win_id The new window handle
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

---Gets the current size of the editor
---@return integer width
---@return integer height
local function get_editor_size()
    local width = vim.o.columns
    local height = vim.o.lines
    return width, height
end

---Sorts file items: Directories first, then alphabetical order
---@param items table[] The list of items to sort
local function sort_items(items)
    table.sort(items, function(a, b)
        if a.type == "directory" and b.type ~= "directory" then
            return true
        elseif a.type ~= "directory" and b.type == "directory" then
            return false
        else
            return a.name < b.name
        end
    end)
end

---Closes the markket window and resets state
---@param force? boolean Whether to force close
function M.close(force)
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, force or true)
    end
    state.win = nil
    state.buf = nil
    state.current_item = nil
end

---Navigate to the parent directory
function M.action_up()
    if not state.current_path then return end
    local parent = vim.fn.fnamemodify(state.current_path, ":h")
    -- Prevent going above root if desired, though fs.dir usually handles it
    M.renderer(state.buf, parent)
end

---Open the currently selected item (Enter directory or Open file)
function M.action_open()
    local item_path = state.current_item
    if not item_path then return end

    -- Check if it is a directory or a file
    local stat = vim.loop.fs_stat(item_path)
    if stat and stat.type == "directory" then
        M.renderer(state.buf, item_path)
    else
        -- It is a file, open it in the previous window
        M.close()
        if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
            vim.api.nvim_set_current_win(state.prev_win)
            vim.cmd("edit " .. vim.fn.fnameescape(item_path))
        end
    end
end

---Renders the file list for a specific path into the buffer
---@param buf integer The buffer handle
---@param path string The directory path to render
M.renderer = function(buf, path)
    -- Normalize path to ensure no trailing slash unless root
    path = vim.fs.normalize(path)
    
    local items = {}
    -- Safely iterate directory
    local fs_iter = vim.fs.dir(path)
    if fs_iter then
        for name, type in fs_iter do
            table.insert(items, { name = name, type = type })
        end
    end

    -- Sort: Dirs first, then alphabetical
    sort_items(items)

    local lines = {}
    for _, item in ipairs(items) do
        local display_name = item.name
        if item.type == "directory" then
            display_name = display_name .. "/"
        end
        table.insert(lines, display_name)
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "markket"

    -- Window options for highlighting
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.wo[state.win].cursorline = true
        vim.wo[state.win].cursorlineopt = "both"
    end

    -- Update state
    state.current_path = path
    state.current_item = nil

    -- --- Cursor Tracking Logic ---
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = function(_, _, _, _, _, _)
            if vim.fn.mode() ~= "n" or not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
            
            local cursor = vim.api.nvim_win_get_cursor(state.win)
            local row = cursor[1] -- 1-based index

            if row >= 1 and row <= #items then
                local item = items[row]
                local fullpath = vim.fs.joinpath(path, item.name)
                state.current_item = fullpath
            else
                state.current_item = nil
            end
        end
    })

    -- Ensure the first item is selected initially
    vim.schedule(function()
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
            -- Trigger manual update for row 1
            if #items > 0 then
                state.current_item = vim.fs.joinpath(path, items[1].name)
            end
        end
    end)

    -- --- Buffer Keymaps ---
    local opts = { buffer = buf, silent = true, nowait = true }

    -- Quit
    vim.keymap.set("n", "q", function() M.close() end, opts)
    
    -- Open / Enter
    vim.keymap.set("n", "<CR>", M.action_open, opts)
    vim.keymap.set("n", "l", M.action_open, opts)

    -- Go Up
    vim.keymap.set("n", "-", M.action_up, opts)
    vim.keymap.set("n", "h", M.action_up, opts)
end

---Main entry point to toggle the file explorer
function M.markket()
    local config = vim.tbl_deep_extend("force", {}, default_config, M.config)

    -- If already open, close it (toggle behavior) or focus it
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        M.close()
        return
    end

    -- Save previous window to open files later
    state.prev_win = vim.api.nvim_get_current_win()

    vim.api.nvim_create_autocmd("VimResized", {
        callback = M.reload_ui,
        group = vim.api.nvim_create_augroup("Markket", { clear = true }),
    })

    local ui_w, ui_h = get_editor_size()
    local width = ui_w - config.margin.x * 2
    local height = ui_h - config.margin.y * 2

    local row = (ui_h - height) / 2 - (ui_h % 2 == 0 and 0 or 1)
    local col = (ui_w - width) / 2 - (ui_w % 2 == 0 and 0 or 1)

    state.buf = vim.api.nvim_create_buf(false, true)
    
    -- Open window with enter = true to focus immediately
    state.win = util.open_win(width, height, row, col, state.buf, true)

    local path = config.dir
    -- Ensure directory exists, fallback to cwd if not
    if vim.fn.isdirectory(path) == 0 then
        path = vim.loop.cwd()
    end

    M.renderer(state.buf, path)
end

---Reloads the UI layout (e.g., on resize)
function M.reload_ui()
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then
        return
    end

    local config = vim.tbl_deep_extend("force", {}, default_config, M.config)
    local ui_w, ui_h = get_editor_size()
    local width = ui_w - config.margin.x * 2
    local height = ui_h - config.margin.y * 2

    if width <= 0 or height <= 0 then
        -- Fallback for very small screens
        width = 20
        height = 20
    end

    local row = (ui_h - height) / 2
    local col = (ui_w - width) / 2

    util.win_edit_config(state.win, {
        row = row,
        col = col,
        width = width,
        height = height,
    })

    -- Re-render current path to fit new dimensions if needed
    if state.current_path then
        M.renderer(state.buf, state.current_path)
    end
end

---Setup function for user configuration
---@param opts MarkketConfig|nil
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
end

---Returns the currently selected item's full path
---@return string|nil
function M.get_current_item()
    return state.current_item
end

return M
