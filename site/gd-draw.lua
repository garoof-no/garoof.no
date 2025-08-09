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
function Vec.__tostring(a) return a.x .. "," .. a.y end

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

local space, horiz, vert, bottom, top, lowhoriz = 32, 45, 124, 46, 39, 95
local textmode = 96
local fslash, bslash = 47, 92
local plus = 43
local arrl, arrr, arru, arrd = 60, 62, 94, 86

local function set(...)
  local res = {}
  for _, v in ipairs({...}) do res[v] = true end
  return res
end

local verts = set(vert, plus, bottom)
local vertsu = set(vert, plus, bottom, arru)
local vertsd = set(vert, plus, top, arrd)
local horis = set(horiz, plus, top, bottom)
local horisl = set(horiz, plus, top, bottom, arrl)
local horisr = set(horiz, plus, top, bottom, arrr)

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
            map.texts, { pos = textstart, str = utf8.char(table.unpack(text)) }
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
        map.texts, { pos = textstart, str = utf8.char(table.unpack(text)) }
      )
    end
    map.w = math.max(map.w, x)
  end
  map.at = function(x, y)
    local res = map[vec(x, y)]
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
    local x = p.pos.x
    local y = p.pos.y
    local code = p.code
    local bx = x * 4
    local by = y * 8
    local function add(x1, y1, x2, y2)
      lines.add(x1, y1, x2, y2)
    end
    if code == horiz then add(bx, by + 4, bx + 4, by + 4)
    elseif code == vert then add(bx + 2, by, bx + 2, by + 8)
    elseif code == lowhoriz then add(bx, by + 8, bx + 4, by + 8)
    elseif code == fslash then add(bx, by + 8, bx + 4, by)
    elseif code == bslash then add(bx, by, bx + 4, by + 8)
    elseif code == bottom then
      local px, py = bx + 2, by + 6
      local l, r = map.at(x - 1, y), map.at(x + 1, y)
      local d = map.at(x, y + 1)
      local dl, dr = map.at(x - 1, y + 1), map.at(x + 1, y + 1)
      if horisl[l] then add(bx, by + 4, px, py) end
      if dl == fslash or l == lowhoriz then
        add(bx, by + 8, px, py)
      end
      if vertsd[d] then add(bx + 2, by + 8, px, py) end
      if dr == bslash or r == lowhoriz then
        add(px, py, bx + 4, by + 8)
      end
      if horisr[r] then add(px, py, bx + 4, by + 4) end
    elseif code == top then
      local px, py = bx + 2, by + 2
      local l, r = map.at(x - 1, y), map.at(x + 1, y)
      local u = map.at(x, y - 1)
      local ul, ur = map.at(x - 1, y - 1), map.at(x + 1, y - 1)
      if horisl[l] then add(bx, by + 4, px, py) end
      if ul == bslash then add(bx, by, px, py) end
      if vertsu[u] then add(bx + 2, by, px, py) end
      if ur == fslash then add(px, py, bx + 4, by) end
      if horisr[r] then add(px, py, bx + 4, by + 4) end
    elseif code == plus then
      local px, py = bx + 2, by + 4
      local l, r = map.at(x - 1, y), map.at(x + 1, y)
      local u, d = map.at(x, y - 1), map.at(x, y + 1)
      if horisl[l] then add(bx, by + 4, px, py) end
      if vertsd[d] then add(bx + 2, by + 8, px, py) end
      if horisr[r] then add(px, py, bx + 4, by + 4) end
      if vertsu[u] then add(bx + 2, by, px, py) end
    elseif code == arrl then
      local r = map.at(x + 1, y)
      if horis[r] then
        add(bx + 4, by + 4, bx, by + 4)
        add(bx, by + 4, bx + 4, by + 2)
        add(bx, by + 4, bx + 4, by + 6)
      end
    elseif code == arrr then
      local l = map.at(x - 1, y)
      if horis[l] then
        add(bx, by + 4, bx + 4, by + 4)
        add(bx + 4, by + 4, bx, by + 2)
        add(bx + 4, by + 4, bx, by + 6)
      end
    elseif code == arru then
      local d = map.at(x, y + 1)
      if verts[d] then
        add(bx + 2, by + 8, bx + 2, by)
        add(bx + 2, by, bx, by + 4)
        add(bx + 2, by, bx + 4, by + 4)
      end
    elseif code == arrd then
      local u = map.at(x, y - 1)
      if verts[u] then
        add(bx + 2, by, bx + 2, by + 8)
        add(bx + 2, by + 8, bx, by + 4)
        add(bx + 2, by + 8, bx + 4, by + 4)
      end
    end
  end

  local style = [[<style>svg { stroke: currentColor; fill: none; } ]]
  style = style .. [[text { stroke: none; fill: currentColor; ]]
  style = style .. [[font-family: monospace; ]]
  style = style .. [[font-size: ]] .. size .. [[px; ]]
  style = style .. [[dominant-baseline: hanging; text-anchor: start; }</style>]]

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
  out('<svg width="' .. w .. '" height="' .. h .. '" viewBox="0 0 ' .. w .. ' ' .. h .. '" xmlns="http://www.w3.org/2000/svg">')
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
