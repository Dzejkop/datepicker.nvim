local M = {}

local state = require("datepicker.state")

---@class DatepickerOptions
---@field on_select fun(date: table)|nil
---@field initial_date string|integer|table|nil
---@field week_start 'monday'|'sunday'|nil
---@field title string|nil

---@param opts DatepickerOptions|nil
function M.open(opts)
  opts = opts or {}
  opts.week_start = opts.week_start or "monday"

  if opts.week_start ~= "monday" and opts.week_start ~= "sunday" then
    error("datepicker: week_start must be 'monday' or 'sunday'")
  end

  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks then
    error("datepicker: snacks.nvim is required. Install folke/snacks.nvim")
  end

  local ts = state.parse_initial(opts.initial_date)
  require("datepicker.ui_snacks").open({
    snacks = snacks,
    timestamp = ts,
    week_start = opts.week_start,
    title = opts.title or "Date Picker",
    on_select = opts.on_select,
  })
end

return M
