vecs = setmetatable({}, { __mode = "v" })
Vec = {}

function vec(x, y)
  local key = x .. "," .. y
  local found = vecs[key]
  if found then return found end
  local v = setmetatable({ x = x, y = y}, Vec)
  vecs[key] = v
  return v
end

function Vec.__add(a, b) return vec(a.x + b.x, a.y + b.y) end

local U, D, L, R = vec(0, -1), vec(0, 1), vec(-1, 0), vec(1, 0)
local UL, DL, UR, DR = U + L, D + L, U + R, D + R

local function points(half)
  local other = half.other
  local current
  local i = #half
  local function last()
    local res = other[i]
    i = i + 1
    if i > #other then current = nil end
    return res
  end
  local function first()
    local res = half[i]
    if i == 1 then current = last
    else i = i - 1
    end
    return res
  end
  current = first
  return function()
    return current and current()
  end
end

local function samedir(a, b)
  if a.x == b.x and a.y == b.y then
    return true
  elseif a.x == 0 and b.x == 0 then
    return (a.y > 0 and b.y > 0) or (a.y < 0 and b.y < 0)
  elseif a.y == 0 and b.y == 0 then
    return (a.x > 0 and b.x > 0) or (a.x < 0 and b.x < 0)
  else
    return false
  end
end

local function dir(from, to)
  return vec(to.x - from.x, to.y - from.y)
end

local function newlines()

  local lines = {}
  local extendible = {}

  local function line(from, to)
    local meta = { start = false }
    local half = { from, other = false, dir = dir(to, from), meta = meta }
    local other = { to, other = half, dir = dir(from, to), meta = meta }
    half.other = other
    meta.start = half
    table.insert(lines, meta)
    extendible[from] = half
    extendible[to] = other
  end

  local function extend(half, point)
    local i = #half
    local prev = half[i]
    extendible[prev] = nil
    extendible[point] = half

    local newdir = dir(prev, point)
    if not samedir(newdir, half.dir) then
      i = i + 1
    end  
    half[i] = point
    half.dir = newdir
  end

  local function unstend(half)
    extendible[half[#half]] = nil
  end

  local function join(first, last)
    if first == last then
      error("oh no")
    elseif first.other == last then
      first.meta.closed = true
      unstend(first)
      unstend(last)
      return
    else
      local flen = #first + #first.other
      local llen = #last + #last.other
      local keep, remove
      if flen >= llen then keep, remove = first, last
      else keep, remove = last, first end
      unstend(remove)
      unstend(remove.other)
      remove.meta.start = nil
      for p in points(remove) do
        extend(keep, p)
      end
    end
  end

  function lines.add(fromx, fromy, tox, toy)
    local from, to = vec(fromx, fromy), vec(tox, toy)
    local first = extendible[from]
    local last = extendible[to]
    if first and last then
      join(first, last)
    elseif first then
      extend(first, to)
    elseif last then
      extend(last, from)
    else
      line(from, to)
    end
  end
  return lines
end


local textmode = 96

local space, hyphen, pipe, period, apostrophe = 32, 45, 124, 46, 39
local fslash, bslash = 47, 92
local plus = 43
local lt, gt, caret, V = 60, 62, 94, 86

local function connectors(...)
  local res = { [plus] = true }
  for _, v in ipairs({...}) do res[v] = true end
  return res
end

local to_u = connectors(pipe, period, caret)
local to_d = connectors(pipe, apostrophe, V)
local to_l = connectors(hyphen, apostrophe, period, lt)
local to_r = connectors(hyphen, apostrophe, period, gt)
local to_ul = connectors(period, bslash)
local to_ur = connectors(period, fslash)
local to_dl = connectors(apostrophe, fslash)
local to_dr = connectors(apostrophe, bslash)


function newmap()
  local map = { w = 0, h = 0, texts = {} }

  map.addline = function(str)
    str = str or ""
    local row = {}
    local x = 0
    local y = map.h + 1
    map.h = y
    local text, textstart
    for _, code in utf8.codes(str) do
      x = x + 1
      if code == textmode then
        if text then
          table.insert(
            map.texts,
            { pos = textstart, str = utf8.char(table.unpack(text)) }
          )
          text, textstart = nil, nil
        else
          text, textstart = {}, vec(x + 1, y)
        end
      elseif text then
        table.insert(text, code)
      elseif code ~= space then
        local pos = vec(x, y);
        local value = { pos = pos, code = code }
        map[pos] = value
        table.insert(map, value)
      end
    end
    if text then
      table.insert(
        map.texts,
        { pos = textstart, str = utf8.char(table.unpack(text)) }
      )
    end
    map.w = math.max(map.w, x)
  end
  function map.at(x, y)
    local v = y and vec(x, y) or x
    local res = map[v]
    return res and res.code
  end
  return map
end

local function escapechar(c)
  if c == "<" then return "&lt;"
  elseif c == ">" then return "&gt;"
  elseif c == '"' then return "&quot;"
  elseif c == "'" then return "&apos;"
  elseif c == "&" then return "&amp;"
  else return c
  end
end

local function escape(str)
  local res = (str or ""):gsub("[<>\"'&]", escapechar)
  return res
end

local function i(n)
  local floored = math.floor(n)
  return floored == n and floored or n
end

local function render(map, out, size)
  size = size or 16
  local cellw, cellh = i(size * 0.55), i(size)
  local xscale, yscale = i(cellw / 4), i(cellh / 8)
  local res = nil

  local lines = newlines()

  for _, p in ipairs(map) do
    local pos = p.pos
    local x = pos.x
    local y = pos.y
    local code = p.code
    local bx = x * 4
    local by = y * 8
    local function add(x1, y1, x2, y2)
      lines.add(x1, y1, x2, y2)
    end
    if code == hyphen then add(bx, by + 4, bx + 4, by + 4)
    elseif code == pipe then add(bx + 2, by, bx + 2, by + 8)
    elseif code == fslash then add(bx, by + 8, bx + 4, by)
    elseif code == bslash then add(bx, by, bx + 4, by + 8)
    elseif code == period then
      local px, py = bx + 2, by + 6
      if to_l[map.at(pos + L)] then add(bx, by + 4, px, py) end
      if to_dl[map.at(pos + DL)] then add(bx, by + 8, px, py) end
      if to_d[map.at(pos + D)] then add(bx + 2, by + 8, px, py) end
      if to_dr[map.at(pos + DR)] then add(px, py, bx + 4, by + 8) end
      if to_r[map.at(pos + R)] then add(px, py, bx + 4, by + 4) end
    elseif code == apostrophe then
      local px, py = bx + 2, by + 2
      if to_l[map.at(pos + L)] then add(bx, by + 4, px, py) end
      if to_ul[map.at(pos + UL)] then add(bx, by, px, py) end
      if to_u[map.at(pos + U)] then add(bx + 2, by, px, py) end
      if to_ur[map.at(pos + UR)] then add(px, py, bx + 4, by) end
      if to_r[map.at(pos + R)] then add(px, py, bx + 4, by + 4) end
    elseif code == plus then
      local px, py = bx + 2, by + 4
      if to_l[map.at(pos + L)] then add(bx, by + 4, px, py) end
      if to_ul[map.at(pos + UL)] then add(bx, by, px, py) end
      if to_dl[map.at(pos + DL)] then add(bx, by + 8, px, py) end
      if to_u[map.at(pos + U)] then add(bx + 2, by, px, py) end
      if to_d[map.at(pos + D)] then add(bx + 2, by + 8, px, py) end
      if to_ur[map.at(pos + UR)] then add(px, py, bx + 4, by) end
      if to_dr[map.at(pos + DR)] then add(px, py, bx + 4, by + 8) end
      if to_r[map.at(pos + R)] then add(px, py, bx + 4, by + 4) end
    elseif code == lt then
      add(bx + 4, by + 4, bx, by + 4)
      add(bx, by + 4, bx + 4, by + 2)
      add(bx, by + 4, bx + 4, by + 6)
    elseif code == gt then
      add(bx, by + 4, bx + 4, by + 4)
      add(bx + 4, by + 4, bx, by + 2)
      add(bx + 4, by + 4, bx, by + 6)
    elseif code == caret then
      add(bx + 2, by + 8, bx + 2, by)
      add(bx + 2, by, bx, by + 4)
      add(bx + 2, by, bx + 4, by + 4)
    elseif code == V then
      add(bx + 2, by, bx + 2, by + 8)
      add(bx + 2, by + 8, bx, by + 4)
      add(bx + 2, by + 8, bx + 4, by + 4)
    end
  end

  local style =
    [[<style>svg { stroke: currentColor; fill: none; } ]] ..
    [[text { stroke: none; fill: currentColor; font-family: monospace; ]] ..
    [[font-size: ]] .. size .. [[px; ]] ..
    [[dominant-baseline: hanging; text-anchor: start; }</style>]]

  local function lineSvg(meta)
    if not meta.start then
      return ""
    end
    local strs = {}
    for p in points(meta.start) do
      table.insert(strs, p.x * xscale .. "," .. p.y * yscale)
    end
    local type = meta.closed and '<polygon points="' or '<polyline points="'
    return type .. table.concat(strs, " ") .. '" />'
  end

  local w, h = ((map.w + 2) * cellw), ((map.h + 2) * cellh)
  out(
    '<svg width="' .. w .. '" height="' .. h .. 
    '" viewBox="0 0 ' .. w .. ' ' .. h ..
    '" xmlns="http://www.w3.org/2000/svg">')
  out(style)
  for k, v in ipairs(lines) do
    out(lineSvg(v))
  end

  for _, t in ipairs(map.texts) do
    local x = t.pos.x * 4 * xscale
    local y = t.pos.y * 8 * yscale
    out('<text x="' .. x ..'" y="' .. y .. '">' .. escape(t.str) .. '</text>')
  end

  out("</svg>")
  if res then return table.concat(res) end
end

function svg(str, size)
  local map = newmap()
  for line in str:gmatch("[^\n]*") do
    map.addline(line)
  end
  local res = {}
  render(map, function(str) table.insert(res, str) end, size)
  return table.concat(res)
end

return {
  newmap = newmap,
  render = render,
  svg = svg
}
