local alphabet = "01234567ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

local map = {}
local i = 0
for c in alphabet:gmatch(".") do
  map[c] = i
  i = i + 1
end

local function char(i)
  i = i + 1
  return alphabet:sub(i, i)
end

local function fromint(i)
  local res = "";
  while i >= #alphabet do
    res = char(i % #alphabet) .. res
    i = i // #alphabet
  end
  return char(i % #alphabet) .. res
end

local function toint(s)
  local res = 0
  for c in s:gmatch(".") do
    res = (res * #alphabet) + (map[c] or 0)
  end
  return res
end

local month = {
  "Jan", "Feb", "Mar", "Apr" , "May", "Jun",
  "Jul", "Aug" , "Sep", "Oct", "Nov", "Dec"
}

local function fromdate(t)
  t = t or os.date("!*t")
  return {
    b60 = function()
      return fromint(t.year)
        .. fromint(t.month)
        .. fromint(t.day)
        .. fromint(t.hour)
        .. fromint(t.min)
    end,
    iso = function()
      return string.format(
        "%04d-%02d-%02dT%02d:%02dZ",
        t.year, t.month, t.day, t.hour, t.min
      )
    end,
    rss = function()
      return string.format(
        "%02d %s %04d %02d:%02d GMT",
        t.day, month[t.month], t.year, t.hour, t.min
      )
  end
  }
end

local function fromb60(s)
  return fromdate({
    year = toint(s:sub(1, -5)),
    month = toint(s:sub(-4, -4)),
    day = toint(s:sub(-3, -3)),
    hour = toint(s:sub(-2, -2)),
    min = toint(s:sub(-1, -1))
  })
end

return {
  toint = toint,
  fromb60 = fromb60,
  fromdate = fromdate,
  dbg = dbg
}
