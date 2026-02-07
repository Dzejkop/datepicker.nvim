# datepicker.nvim

Floating date picker for Neovim using `snacks.nvim`.

## Features

- Floating calendar UI (Snacks-backed)
- Day, month, year navigation
- Confirm to emit selected date via callback
- No built-in file-opening behavior; you decide what to do with selected date

## Requirements

- Neovim 0.9+
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim)

## Installation

### lazy.nvim

```lua
{
  "dzejkop/datepicker.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  config = function()
    vim.keymap.set("n", "<leader>dd", function()
      require("datepicker").open({
        week_start = "monday",
        on_select = function(d)
          print(vim.inspect(d))
        end,
      })
    end, { desc = "Open date picker" })
  end,
}
```

### packer.nvim

```lua
use({
  "dzejkop/datepicker.nvim",
  requires = {
    "folke/snacks.nvim",
  },
  config = function()
    vim.keymap.set("n", "<leader>dd", function()
      require("datepicker").open({
        week_start = "monday",
        on_select = function(d)
          print(vim.inspect(d))
        end,
      })
    end, { desc = "Open date picker" })
  end,
})
```

### vim.pack (built-in)

```lua
vim.pack.add({
  { src = "https://github.com/dzejkop/datepicker.nvim" },
  { src = "https://github.com/folke/snacks.nvim" },
})

vim.keymap.set("n", "<leader>dd", function()
  require("datepicker").open({
    week_start = "monday",
    on_select = function(d)
      print(vim.inspect(d))
    end,
  })
end, { desc = "Open date picker" })
```

## Usage

```lua
vim.keymap.set("n", "<leader>dd", function()
  require("datepicker").open({
    week_start = "monday",
    on_select = function(d)
      local root = vim.fn.expand("~/notes")
      local path = string.format("%s/%04d/%02d/%02d/daily.md", root, d.year, d.month, d.day)

      vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
      vim.cmd.edit(vim.fn.fnameescape(path))
    end,
  })
end, { desc = "Pick day and open daily note" })
```

## API

```lua
require("datepicker").open(opts)
```

`opts`:

- `on_select`: `function(date)` callback invoked only on `<CR>`
- `initial_date`: `"YYYY-MM-DD"` or epoch seconds or `{ year, month, day }`
- `week_start`: `"monday"` (default) or `"sunday"`
- `title`: floating window title (`"Date Picker"` default)

Callback payload (`date`):

```lua
{
  year = 2026,
  month = 2,
  day = 7,
  iso = "2026-02-07",
  timestamp = 1770422400,
  weekday = 6,
  weekday_iso = 6,
}
```

## Default Keymaps (inside picker)

- any cursor motion: move selection (selection follows cursor position in calendar grid)
- `h` / `l`: previous/next day (explicit shortcuts)
- `j` / `k`: next/previous week (7 days, explicit shortcuts)
- `H` / `L`: previous/next month
- `K` / `J`: previous/next year
- `<CR>`: confirm and emit callback
- `q` / `<Esc>`: close
