local Helpers = require("gallows.helpers")

--- @type GallowsOpts
local M = {}

--- @type {[string]: Executioner}
M.executioners = {}

M.strict_register = true
M.exec_opts = {
    save_command = true
}

M.executioners.lua = {
    exec_line = function(line)
        local exec_result = {}
        local result = nil

        exec_result.ok, result = Helpers.capture_output(function()
            local f, error = loadstring(line, "Lua Line Executioner")
            if not f then
                return error
            end
            f()
        end)

        if exec_result.ok then
            exec_result.output = result or "Gallows: No output"
        else
            exec_result.error = result
        end

        return exec_result
    end,
    exec_block = function(block, endmarker)
        -- TODO: tidy up response
        return Helpers.exec_pcall(vim.api.nvim_exec2, "lua " .. Helpers.make_heredoc(block, endmarker))
    end,
    exec_file = function(filepath)
        return Helpers.exec_pcall(vim.api.nvim_exec2, "luafile " .. filepath)
    end
}
M.executioners.python = {
    exec_line = function(line)
        return Helpers.exec_pcall(vim.api.nvim_exec2, "py " .. line)
    end,
    exec_block = function(block, endmarker)
        return Helpers.exec_pcall(vim.api.nvim_exec2, "py " .. Helpers.make_heredoc(block, endmarker))
    end,
    exec_file = function(filepath)
        return Helpers.exec_pcall(vim.api.nvim_exec2, "pyfile " .. filepath)
    end
}
M.executioners.vim = {
    exec_line = function(line)
        return Helpers.exec_pcall(vim.api.nvim_exec2, line)
    end,
    exec_block = function(block, _)
        return Helpers.exec_pcall(vim.api.nvim_exec2, table.concat(block, "\n"))
    end,
    exec_file = function(filepath)
        return Helpers.exec_pcall(vim.api.nvim_exec2, "source " .. filepath)
    end
}
M.executioners.sh = {
    exec_line = function(line)
        local result = vim.system({ "sh", "-c", line }, { text = true }):wait()
        return {
            ok = result.code == 0,
            output = result.stdout,
            error = result.stderr
        }
    end,
    exec_block = function(block, _)
        local tmp_file = vim.fn.tempname() .. ".sh"
        vim.fn.writefile(block, tmp_file)
        local result = vim.system({ "sh", tmp_file }, { text = true }):wait()

        return {
            ok = result.code == 0,
            output = result.stdout,
            error = result.stderr
        }
    end,
    exec_file = function(filepath)
        local result = vim.system({ "sh", filepath }, { text = true }):wait()
        return {
            ok = result.code == 0,
            output = result.stdout,
            error = result.stderr
        }
    end
}
M.executioners.bash = {
    exec_line = function(line)
        local result = vim.system({ "bash", "-c", line }, { text = true }):wait()
        return {
            ok = result.code == 0,
            output = result.stdout,
            error = result.stderr
        }
    end,
    exec_block = function(block, _)
        local tmp_file = vim.fn.tempname() .. ".bash"
        vim.fn.writefile(block, tmp_file)
        local result = vim.system({ "bash", tmp_file }, { text = true }):wait()
        return {
            ok = result.code == 0,
            output = result.stdout,
            error = result.stderr
        }
    end,
    exec_file = function(filepath)
        local result = vim.system({ "bash", filepath }, { text = true }):wait()
        return {
            ok = result.code == 0,
            output = result.stdout,
            error = result.stderr
        }
    end
}

M.window_opts = {
    relative = "editor", -- only if floating
    width = math.floor(vim.o.columns * 0.80),
    height = math.floor(vim.o.lines * 0.75),
    row = vim.o.lines * 0.125,
    col = vim.o.columns * 0.10,
    focusable = true,
    border = "rounded",
    style = "minimal"
}

M.keymaps = {
    switch_to_command = "C",
    switch_to_output = "O",
    switch_to_next = "<Tab>",
    close = "q"
}

return M
