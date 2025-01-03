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
