local M = {}

local DAY_SECONDS = 24 * 60 * 60

---@param year integer
---@param month integer
---@param day integer
---@return integer
local function normalize_timestamp(year, month, day)
  return os.time({
    year = year,
    month = month,
    day = day,
    hour = 12,
    min = 0,
    sec = 0,
    isdst = false,
  })
end

---@param timestamp integer
---@return table
local function to_date(timestamp)
  local t = os.date("*t", timestamp)
  local w = tonumber(os.date("%w", timestamp))
  local iso_w = w == 0 and 7 or w

  return {
    year = t.year,
    month = t.month,
    day = t.day,
    iso = string.format("%04d-%02d-%02d", t.year, t.month, t.day),
    timestamp = os.time({
      year = t.year,
      month = t.month,
      day = t.day,
      hour = 0,
      min = 0,
      sec = 0,
      isdst = false,
    }),
    weekday = w,
    weekday_iso = iso_w,
  }
end

---@param value nil|string|integer|table
---@return integer
function M.parse_initial(value)
  if value == nil then
    return normalize_timestamp(os.date("*t").year, os.date("*t").month, os.date("*t").day)
  end

  if type(value) == "number" then
    return normalize_timestamp(
      tonumber(os.date("%Y", value)),
      tonumber(os.date("%m", value)),
      tonumber(os.date("%d", value))
    )
  end

  if type(value) == "string" then
    local y, m, d = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then
      error("datepicker: initial_date string must be YYYY-MM-DD")
    end

    return normalize_timestamp(tonumber(y), tonumber(m), tonumber(d))
  end

  if type(value) == "table" then
    if not (value.year and value.month and value.day) then
      error("datepicker: initial_date table must include year, month, day")
    end

    return normalize_timestamp(value.year, value.month, value.day)
  end

  error("datepicker: unsupported initial_date type")
end

---@param timestamp integer
---@param days integer
---@return integer
function M.shift_day(timestamp, days)
  return timestamp + (days * DAY_SECONDS)
end

---@param timestamp integer
---@param months integer
---@return integer
function M.shift_month(timestamp, months)
  local t = os.date("*t", timestamp)
  local target = normalize_timestamp(t.year, t.month + months, 1)
  local target_t = os.date("*t", target)

  local last_day = tonumber(os.date("%d", os.time({
    year = target_t.year,
    month = target_t.month + 1,
    day = 0,
    hour = 12,
    min = 0,
    sec = 0,
    isdst = false,
  })))

  return normalize_timestamp(target_t.year, target_t.month, math.min(t.day, last_day))
end

---@param timestamp integer
---@param years integer
---@return integer
function M.shift_year(timestamp, years)
  return M.shift_month(timestamp, years * 12)
end

---@param timestamp integer
---@return string
function M.month_label(timestamp)
  return os.date("%B %Y", timestamp)
end

---@param timestamp integer
---@param week_start 'monday'|'sunday'
---@return table
function M.month_grid(timestamp, week_start)
  local t = os.date("*t", timestamp)
  local first = normalize_timestamp(t.year, t.month, 1)
  local first_wday = tonumber(os.date("%w", first)) -- 0=Sun..6=Sat

  local offset
  if week_start == "sunday" then
    offset = first_wday
  else
    offset = (first_wday + 6) % 7
  end

  local grid_start = M.shift_day(first, -offset)
  local days = {}

  for i = 0, 41 do
    local ts = M.shift_day(grid_start, i)
    local dt = to_date(ts)
    dt.current_month = dt.month == t.month and dt.year == t.year
    days[#days + 1] = dt
  end

  return days
end

---@param timestamp integer
---@return table
function M.to_payload(timestamp)
  return to_date(timestamp)
end

return M
