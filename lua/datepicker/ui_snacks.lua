local M = {}

local state = require("datepicker.state")

local NS = vim.api.nvim_create_namespace("datepicker")
local WEEKDAYS = {
  monday = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" },
  sunday = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" },
}

---@param ctx table
local function close(ctx)
  if ctx.win_obj and type(ctx.win_obj.close) == "function" then
    pcall(ctx.win_obj.close, ctx.win_obj)
    return
  end

  if ctx.win and vim.api.nvim_win_is_valid(ctx.win) then
    pcall(vim.api.nvim_win_close, ctx.win, true)
  end
end

---@param cell integer
---@return integer
local function cell_col(cell)
  return (cell - 1) * 4 + 1
end

---@param row integer
---@param cell integer
---@return integer, integer
local function cursor_pos_for_cell(row, cell)
  return 3 + row, cell_col(cell)
end

---@param line integer
---@param col0 integer
---@return integer|nil, integer|nil
local function cell_from_cursor(line, col0)
  if line < 4 or line > 9 then
    return nil, nil
  end

  local col1 = col0 + 1
  if col1 < 2 then
    return nil, nil
  end

  local rel = col1 - 2
  local cell = math.floor(rel / 4) + 1
  if cell < 1 or cell > 7 then
    return nil, nil
  end

  return line - 3, cell
end

---@param ctx table
local function place_cursor_on_selected(ctx)
  if not (ctx.win and vim.api.nvim_win_is_valid(ctx.win)) then
    return
  end

  local selected = state.to_payload(ctx.timestamp)
  for idx, day in ipairs(ctx.days or {}) do
    if day.iso == selected.iso then
      local row = math.floor((idx - 1) / 7) + 1
      local cell = ((idx - 1) % 7) + 1
      local line, col = cursor_pos_for_cell(row, cell)
      ctx.syncing_cursor = true
      pcall(vim.api.nvim_win_set_cursor, ctx.win, { line, col })
      ctx.syncing_cursor = false
      return
    end
  end
end

---@param ctx table
local function render(ctx)
  local days = state.month_grid(ctx.timestamp, ctx.week_start)
  local today = state.to_payload(state.parse_initial(nil))
  ctx.days = days

  local lines = {
    "  " .. state.month_label(ctx.timestamp),
    "",
    " " .. table.concat(WEEKDAYS[ctx.week_start], "  "),
  }

  for row = 1, 6 do
    local chunks = {}
    for col = 1, 7 do
      local idx = (row - 1) * 7 + col
      chunks[#chunks + 1] = string.format("%2d", days[idx].day)
    end
    lines[#lines + 1] = " " .. table.concat(chunks, "  ")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = " move: any motion  H/L: month  J/K: year"
  lines[#lines + 1] = " <CR>: confirm   q/<Esc>: close"

  vim.bo[ctx.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
  vim.bo[ctx.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(ctx.buf, NS, 0, -1)

  vim.api.nvim_buf_add_highlight(ctx.buf, NS, "Title", 0, 2, -1)
  vim.api.nvim_buf_add_highlight(ctx.buf, NS, "Special", 2, 1, -1)
  vim.api.nvim_buf_add_highlight(ctx.buf, NS, "Comment", 10, 1, -1)
  vim.api.nvim_buf_add_highlight(ctx.buf, NS, "Comment", 11, 1, -1)

  for row = 1, 6 do
    for col = 1, 7 do
      local idx = (row - 1) * 7 + col
      local day = days[idx]
      local line = 2 + row
      local col_start = cell_col(col)
      local col_end = col_start + 2

      if not day.current_month then
        vim.api.nvim_buf_add_highlight(ctx.buf, NS, "Comment", line, col_start, col_end)
      end

      if day.iso == today.iso then
        vim.api.nvim_buf_add_highlight(ctx.buf, NS, "Special", line, col_start, col_end)
      end

    end
  end

  place_cursor_on_selected(ctx)
end

---@param ctx table
local function sync_from_cursor(ctx)
  if ctx.syncing_cursor or not ctx.days then
    return
  end

  if not (ctx.win and vim.api.nvim_win_is_valid(ctx.win)) then
    return
  end

  local pos = vim.api.nvim_win_get_cursor(ctx.win)
  local row, cell = cell_from_cursor(pos[1], pos[2])
  if not row or not cell then
    return
  end

  local idx = (row - 1) * 7 + cell
  local day = ctx.days[idx]
  if not day then
    return
  end

  local prev = state.to_payload(ctx.timestamp)
  if day.iso == prev.iso then
    return
  end

  ctx.timestamp = day.timestamp
  if day.month ~= prev.month or day.year ~= prev.year then
    render(ctx)
  end
end

---@param snacks table
---@param cfg table
---@return any, integer, integer
local function create_window(snacks, cfg)
  local win_opts = {
    width = 38,
    height = 12,
    border = "rounded",
    title = cfg.title,
    title_pos = "center",
    relative = "editor",
    row = math.floor((vim.o.lines - 12) / 2),
    col = math.floor((vim.o.columns - 38) / 2),
    zindex = 60,
    focusable = true,
    enter = true,
    bo = {
      buftype = "nofile",
      bufhidden = "wipe",
      swapfile = false,
      filetype = "datepicker",
    },
    wo = {
      wrap = false,
      number = false,
      relativenumber = false,
      cursorline = false,
      signcolumn = "no",
      foldcolumn = "0",
      spell = false,
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
    },
  }

  if type(snacks.win) == "function" then
    local ok, win_obj = pcall(snacks.win, win_opts)
    if ok and win_obj then
      return win_obj, win_obj.buf, win_obj.win
    end
  end

  if type(snacks.win) == "table" and type(snacks.win.new) == "function" then
    local ok, win_obj = pcall(snacks.win.new, win_opts)
    if ok and win_obj then
      if type(win_obj.show) == "function" then
        win_obj:show()
      end
      return win_obj, win_obj.buf, win_obj.win
    end
  end

  error("datepicker: unsupported snacks.nvim window API for this version")
end

---@param ctx table
local function set_keymaps(ctx)
  local map = function(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = ctx.buf, nowait = true, silent = true })
  end

  map("h", function()
    ctx.timestamp = state.shift_day(ctx.timestamp, -1)
    render(ctx)
  end)

  map("l", function()
    ctx.timestamp = state.shift_day(ctx.timestamp, 1)
    render(ctx)
  end)

  map("j", function()
    ctx.timestamp = state.shift_day(ctx.timestamp, 7)
    render(ctx)
  end)

  map("k", function()
    ctx.timestamp = state.shift_day(ctx.timestamp, -7)
    render(ctx)
  end)

  map("H", function()
    ctx.timestamp = state.shift_month(ctx.timestamp, -1)
    render(ctx)
  end)

  map("L", function()
    ctx.timestamp = state.shift_month(ctx.timestamp, 1)
    render(ctx)
  end)

  map("J", function()
    ctx.timestamp = state.shift_year(ctx.timestamp, 1)
    render(ctx)
  end)

  map("K", function()
    ctx.timestamp = state.shift_year(ctx.timestamp, -1)
    render(ctx)
  end)

  map("<CR>", function()
    local payload = state.to_payload(ctx.timestamp)
    close(ctx)

    if type(ctx.on_select) == "function" then
      ctx.on_select(payload)
    end
  end)

  map("q", function()
    close(ctx)
  end)

  map("<Esc>", function()
    close(ctx)
  end)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = ctx.buf,
    callback = function()
      sync_from_cursor(ctx)
    end,
  })
end

---@param opts table
function M.open(opts)
  local win_obj, buf, win = create_window(opts.snacks, opts)
  local ctx = {
    win_obj = win_obj,
    buf = buf,
    win = win,
    timestamp = opts.timestamp,
    week_start = opts.week_start,
    title = opts.title,
    on_select = opts.on_select,
  }

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = false

  set_keymaps(ctx)
  render(ctx)

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

return M
