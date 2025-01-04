# gallows.nvim

A neovim plugin for executing external commands

> [!WARNING]
> This plugin is still very much in development, and is extremely unstable.
> Use at your own risk

## Features

* execute code linewise, blockwise, or filewise
* view code output in a window
* multiple fully featured executiioners

### Planned

* documentation
    * possible use
* output and command history
* better project based executioner support
* support for setting executioner environment variables
* plugin tests

## Installation

<details><summary>Lazy</summary>


```lua
{
    "jpappel/gallow.nvim",
    opts = {}
}
```

</details>

## Configuration

<details>
<summary>Defaults</summary>

```lua
{
    -- Only allow executioners which implement all execution modes to be registered
    strict_register = true,

    exec_opts = {
        -- Save the last executed command
        save_command = false
    }

    executioners = {
        -- execute lua code using nvim's integrated version of lua
        lua = ... ,
        -- execute python using the current python provider
        -- see ":checkhealth python" for more info
        python = ... ,
        -- execute vimscript
        vim = ... ,
    },

    -- Window settings for the Gallows window
    --- @type vim.api.keyset.win_config
    window_opts = ...
}
```

</details>
