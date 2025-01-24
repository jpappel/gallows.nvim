local M = {}

--- Open a buffer
--- @param bufs { main: integer }
--- @param old_wins { main: integer? }
--- @param opts vim.api.keyset.win_config
--- @return integer main_win The opened window
function M.open(bufs, old_wins, opts)
    local valid_main = old_wins.main and vim.api.nvim_win_is_valid(old_wins.main)
    if valid_main then
        vim.api.nvim_set_current_win(old_wins.main)
        return old_wins.main
    end

    local new_wins = {}
    new_wins.main = vim.api.nvim_open_win(bufs.main, true, opts)

    return new_wins.main
end

--- Close the gallows buffer
--- @param wins { main: integer?}
function M.close(wins)
    if wins.main and vim.api.nvim_win_is_valid(wins.main) then
        vim.api.nvim_win_close(wins.main, false)
    end
end

--- @param bufs { main: integer}
--- @param wins { main: integer?}
--- @param opts vim.api.keyset.win_config
--- @return integer? main_win
function M.toggle(bufs, wins, opts)
    if wins.main then
        return M.close(wins)
    else
        return M.open(bufs, wins or {}, opts)
    end
end

--- @enum window_mode
local window_modes = {
    command = "command",
    output = "output"
}

--- Write splash text to buffers
--- @param bufs {out: integer, cmd: integer}
--- @param marks {cmd_header: integer?, out_header: integer?}
--- @param executioners {[string]: Executioner}
function M.write_splash(bufs, marks, executioners)
    local version = require("gallows").Version

    local executioner_names = vim.tbl_map(function(name) return "* " .. name end, vim.tbl_keys(executioners))
    local cmd_splash_text = {
        "# Welcome to Gallows.nvim " .. version,
        "",
        "Code that is executed will end up here",
        "",
        "## Registered Executioners",
        "",
    }
    vim.list_extend(cmd_splash_text, executioner_names)

    local out_splash_text = {
        "# Welcome to Gallows.nvim " .. version,
        "",
        "Gallows is code executor",
        "",
        "Repository: [GitHub](https://github.com/jpappel/gallows.nvim)",
        "Written by: [JP Appel](https://jpappel.xyz)"
    }

    local new_marks = {}
    new_marks.cmd_header = M.write_command(bufs.cmd, cmd_splash_text, nil, "", {}, marks.cmd_header)
    new_marks.out_header = M.write_output(bufs.out, "", table.concat(out_splash_text, "\n"), marks.out_header)

    vim.bo[bufs.cmd].filetype = "markdown"
    vim.bo[bufs.out].filetype = "markdown"

    return new_marks
end

--- @param window_mode window_mode
--- @param timestamp string
--- @param opts table
--- @return string[][][] result
function M.make_header(window_mode, timestamp, opts)
    local separator = { "  |  ", "TabLineFill" }
    local result = {
        {
            { "gallows.nvim", "Title" },
            separator,
            { "command [ ]",  "TabLineFill" },
            separator,
            { "output [ ]", "TabLineFill" }
        },
        { { "Executed At: " .. timestamp, "Comment" } }
    }
    if window_mode == "command" then
        result[1][3] = { "command [x]", "Statement" }
        if opts.name then
            table.insert(result, { { "Executioner: " .. opts.name, "Comment" } })
        end
        if opts.mode then
            table.insert(result, { { opts.mode .. " mode", "Comment" } })
        end
    elseif window_mode == "output" then
        result[1][5] = { "output [x]", "Statement" }
    end
    table.insert(result, { { "------", "Comment" } })
    return result
end

--- @param buf integer
--- @param header string[][][]
--- @param mark integer?
--- @return integer mark # the extmark id of the header
function M.write_header(buf, header, mark)
    local ns = vim.api.nvim_create_namespace("gallows_header")

    local opts = {
        virt_lines = header,
        spell = false,
    }
    if mark then
        opts.id = mark
    end
    return vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, opts)
end

--- @param buf integer
--- @param timestamp string
--- @param text string
--- @param mark integer?
--- @return integer
function M.write_output(buf, timestamp, text, mark)
    local output = vim.split(text, "\n")
    table.insert(output, 1, "")

    local header = M.make_header("output", timestamp, {})

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
    local m = M.write_header(buf, header, mark)
    vim.bo[buf].filetype = ""
    vim.bo[buf].modifiable = false

    return m
end

--- Attempt to command text to a buffer
--- @param buf integer Destination buffer
--- @param src string | string[] The filepath or lines of the command
--- @param mode "line" | "block" | "file" | nil
--- @param timestamp string
--- @param opts {filetype: string?}
--- @param mark integer?
function M.write_command(buf, src, mode, timestamp, opts, mark)
    if not src then
        vim.api.nvim_err_writeln("Unable to write gallows command: missing command data")
        return
    end

    local output = {}
    if type(src) == "string" then
        table.insert(output, "source: " .. src)
    else
        vim.list_extend(output, src)
    end

    -- filter whitespace before or after content
    -- this allows clean resourcing of the comand buffer
    while #vim.trim(output[1]) == 0 do
        table.remove(output, 1)
    end
    while #vim.trim(output[#output]) == 0 do
        table.remove(output)
    end

    table.insert(output, 1, "")

    local header = M.make_header("command", timestamp, { mode = mode, name = opts.filetype })

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
    local m = M.write_header(buf, header, mark)
    vim.bo[buf].modifiable = false
    if opts.filetype then
        vim.bo[buf].filetype = opts.filetype
    end

    return m
end

return M
