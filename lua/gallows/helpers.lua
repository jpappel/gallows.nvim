--- Helper functions
local M = {}

--- Make a block into a valid heredoc
--- @param block string[]
--- @param endmarker string
--- @return string
M.make_heredoc = function(block, endmarker)
    if #block == 1 then
        return block[1]
    end

    local content = table.concat(block, "\n")
    return "<< " .. endmarker .. "\n" .. content .. "\n" .. endmarker
end

--- Write a buffer to a temporary file
--- @param buf integer the buffer to write to a temp file, 0 for current buffer
--- @param suffix string? suffix for filename
--- @return string # the temporary  filename
function M.buf_to_tempfile(buf, suffix)
    local tmp_file = vim.fn.tempname()
    local filepath = suffix and tmp_file .. suffix or tmp_file
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    vim.fn.writefile(lines, filepath)
    return filepath
end

--- Pcall for an executioner and parse the result
--- @param f fun(...: any): ...unknown The function to execute
--- @param ... any Arguments to pass to the function
--- @return ExecuteResult
function M.exec_pcall(f, ...)
    local status, result = pcall(f, ..., { output = true })

    local exec_result = { ok = status }
    if exec_result.ok then
        exec_result.output = result.output
    else
        exec_result.error = result
    end

    return exec_result
end

--- @param f fun(): string?
--- @return boolean, string[]
function M.capture_output(f)
    local original_print = print
    local output = {}

    print = function(...)
        for _, arg in ipairs({ ... }) do
            vim.list_extend(output, vim.split(tostring(arg), "\n"))
        end
    end

    local ok, result = pcall(f)
    if not ok then
        output = { tostring(result) }
    end

    print = original_print
    return ok, output
end

return M
