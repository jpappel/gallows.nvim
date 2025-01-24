local Helpers = require("gallows.helpers")
local Defaults = require("gallows.defaults")
local Ui = require("gallows.ui")

local M = {}

M.Version = "0.1.0"

--- @class ExecuteResult
--- @field ok boolean
--- @field output? string
--- @field error? string

--- @class Executioner
--- @field exec_line fun(line: string): ExecuteResult Execute a single line
--- @field exec_block fun(block: string[], endmarker: string): ExecuteResult Executes a multiline block, uses `endmarker` if needed to create a heredoc
--- @field exec_file fun(filepath: string | nil): ExecuteResult Execute an entire file, uses current buffer if not filepath is given

--- @class ExecutionOpts
--- @field save_command boolean? Save the executed command

--- @class GallowsKeymaps
--- @field switch_to_command string
--- @field switch_to_output string
--- @field switch_to_next string
--- @field close string

--- @class GallowsOpts
--- @field strict_register? boolean If registering should fail when the new missing executioner is missing a method (default true)
--- @field executioners? {[string]: Executioner} The executioners
--- @field window_opts? vim.api.keyset.win_config Options to pass to `nvim_open_win`
--- @field exec_opts? ExecutionOpts Options for execution
--- @field keymaps? GallowsKeymaps

--- @type {out: integer?, cmd: integer?}
local buffers = {}

--- @type {main: integer?}
local windows = {}

--- @type {cmd_header: integer?, out_header: integer?}
local extmarks = {}

M.helpers = Helpers
M.defaults = Defaults
M.ui = Ui

--- @type {[string]: Executioner}
M.executioners = {}

--- Register an executioner
--- @param name string The executioner name
--- @param executioner Executioner The executioner
function M.register(name, executioner)
    local missing_method = false
    if executioner.exec_line == nil then
        missing_method = true
        vim.api.nvim_err_writeln("Executioner '" .. name .. "' missing `exec_line`")
    end
    if executioner.exec_block == nil then
        missing_method = true
        vim.api.nvim_err_writeln("Executioner '" .. name .. "' missing `exec_block`")
    end
    if executioner.exec_file == nil then
        missing_method = true
        vim.api.nvim_err_writeln("Executioner '" .. name .. "' missing `exec_file`")
    end

    if missing_method and M.strict_register then
        return
    end

    M.executioners[name] = executioner
end

--- Execute commands using a native or builtin provider
--- Uses `EOF` as default endmarker for multiline commands
--- @param chunk string[]
--- @param endmarker? string
function M.execute_native(chunk, endmarker)
    local ft = vim.o.filetype

    local executioner = M.executioners[ft]
    if executioner == nil then
        vim.api.nvim_err_writeln("No provider found for filetype '" .. ft "'")
        return
    end

    local mode = #chunk == 1 and "line" or "block"

    local timestamp = tostring(os.date "%x %X")
    if M.exec_opts.save_command and buffers.cmd then
        extmarks.cmd_header = M.ui.write_command(buffers.cmd,
            chunk, mode, timestamp,
            { filetype = ft }, extmarks.cmd_header)
    end

    local result = nil
    if #chunk == 1 then
        result = executioner.exec_line(chunk[1])
    else
        result = executioner.exec_block(chunk, endmarker or "EOF")
    end

    if not result.ok then
        vim.api.nvim_err_writeln(vim.inspect(result.error))
        return
    end

    if buffers.out then
        if not result.output then
            return
        end

        extmarks.out_header = Ui.write_output(buffers.out, timestamp, result.output, extmarks.out_header)
        vim.api.nvim_out_write("Gallows executed " .. mode .. " with executioner " .. ft .. "\n")
    else
        vim.api.nvim_err_writeln("`gallows.setup` was not called!")
    end
end

function M.source_native()
    local ft = vim.o.filetype

    local executioner = M.executioners[ft]
    if executioner == nil then
        vim.api.nvim_err_writeln("Unable to source file with filetype '" .. ft "'")
        return
    end

    local source = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    local timestamp = tostring(os.date "%x %X")
    if M.exec_opts.save_command and buffers.cmd then
        extmarks.cmd_header = M.ui.write_command(buffers.cmd,
            source, "file", timestamp,
            { filetype = ft }, extmarks.cmd_header)
    end

    local result = executioner.exec_file()
    if result.ok then
        if buffers.out then
            if not result.output then
                return
            end

            extmarks.out_header = Ui.write_output(buffers.out, timestamp, result.output, extmarks.out_header)
            vim.api.nvim_out_write("Gallows executed file with executioner " .. ft .. "\n")
        else
            vim.api.nvim_err_writeln("`gallows.setup` was not called!")
        end
    else
        vim.api.nvim_err_writeln(vim.inspect(result.error))
    end
end

function M.open()
    if buffers.out then
        windows.main = Ui.open({ main = buffers.out }, windows, {
            relative = "editor",
            width = math.floor(vim.o.columns * 0.80),
            height = math.floor(vim.o.lines * 0.75),
            row = vim.o.lines * 0.125,
            col = vim.o.columns * 0.10,
            focusable = M.window_opts.focusable,
            border = M.window_opts.border,
            style = M.window_opts.style

        })
    end
end

function M.close()
    windows.main = Ui.close(windows)
end

function M.toggle()
    if buffers.out then
        windows.main = Ui.toggle({ main = buffers.out }, windows, {
            relative = "editor",
            width = math.floor(vim.o.columns * 0.80),
            height = math.floor(vim.o.lines * 0.75),
            row = vim.o.lines * 0.125,
            col = vim.o.columns * 0.10,
            focusable = M.window_opts.focusable,
            border = M.window_opts.border,
            style = M.window_opts.style

        })
    end
end

--- @param current integer the buffer to setup
--- @param bufs { out: integer, cmd: integer }
--- @param buf_type string
--- @param keymaps GallowsKeymaps
local function setup_buffer(current, bufs, buf_type, keymaps)
    vim.bo[current].modifiable = false
    vim.api.nvim_buf_set_name(current, "Gallows: " .. buf_type)


    vim.keymap.set("n", keymaps.switch_to_command, function()
        if windows.main and vim.api.nvim_win_is_valid(windows.main) then
            vim.api.nvim_win_set_buf(windows.main, bufs.cmd)
        end
    end, { buffer = current, desc = "Change the gallows window to command" })

    vim.keymap.set("n", keymaps.switch_to_output, function()
        if windows.main and vim.api.nvim_win_is_valid(windows.main) then
            vim.api.nvim_win_set_buf(windows.main, bufs.out)
        end
    end, { buffer = current, desc = "Change the gallows window to output" })

    vim.keymap.set("n", keymaps.switch_to_next, function()
        if not windows.main or not vim.api.nvim_win_is_valid(windows.main) then
            return
        end

        local buf = vim.api.nvim_win_get_buf(windows.main)
        if buf == bufs.out then
            vim.api.nvim_win_set_buf(windows.main, bufs.cmd)
        elseif buf == bufs.cmd then
            vim.api.nvim_win_set_buf(windows.main, bufs.out)
        end
    end, { buffer = current, desc = "Cycle to the next Gallows buffer" })

    vim.keymap.set("n", keymaps.close, function()
        if windows.main and vim.api.nvim_win_is_valid(windows.main) then
            vim.api.nvim_win_close(windows.main, false)
        end
    end, { buffer = current, desc = "Close the gallows window" })
end

--- @param keymaps GallowsKeymaps
--- @return {out: integer, cmd: integer}
local function init_buffs(keymaps)
    local bufs = {}
    bufs.out = vim.api.nvim_create_buf(false, true)
    bufs.cmd = vim.api.nvim_create_buf(false, true)

    setup_buffer(bufs.out, bufs, "Output", keymaps)
    setup_buffer(bufs.cmd, bufs, "Command", keymaps)

    return bufs
end

--- @param opts? GallowsOpts
function M.setup(opts)
    opts = opts or {}
    opts.strict_register = opts.strict_register or Defaults.strict_register
    opts.executioners = opts.executioners or Defaults.executioners
    opts.window_opts = opts.window_opts or Defaults.window_opts
    opts.exec_opts = opts.exec_opts or Defaults.exec_opts
    opts.keymaps = opts.keymaps or Defaults.keymaps

    M.strict_register = opts.strict_register
    M.executioners = opts.executioners
    M.window_opts = opts.window_opts
    M.exec_opts = opts.exec_opts

    buffers = init_buffs(opts.keymaps)

    local augroup = vim.api.nvim_create_augroup("Gallows", {})
    vim.api.nvim_create_autocmd({ "VimResized" }, {
        group = augroup,
        desc = "Resize Gallows window on size change",
        callback = function()
            if not (windows.main and vim.api.nvim_win_is_valid(windows.main)) then
                print("resize but no window")
                return
            end

            vim.api.nvim_win_set_config(windows.main, {
                relative = "editor",
                width = math.floor(vim.o.columns * 0.8),
                height = math.floor(vim.o.lines * 0.75),
                row = math.floor(vim.o.lines * 0.125),
                col = math.floor(vim.o.columns * 0.1)
            })
        end
    })

    vim.api.nvim_create_user_command("Gallows", function(_)
        M.open()
    end, { desc = "Open the Gallows window" })

    vim.api.nvim_create_user_command("GallowsToggle", function(_)
        M.toggle()
    end, { desc = "Toggle the Gallows window" })

    extmarks = Ui.write_splash(buffers, extmarks, M.executioners)
end

return M
