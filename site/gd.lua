local draw = require("gd-draw")
local dt = require("gd-datetime")

local function stringparser(type, startp)
  local pattern = "^(" .. startp .. ")%s*(.-)%s*$"

  return function(str)
    local start, rest = str:match(pattern)
    if start then return { type = type, start = start, rest = rest ~= "" and rest or nil } end
    return nil
  end
end

local function preparsers(start)
  return {
    stringparser("pre>", start),
    function (str)
      local res = { type = "pre" }
      local rest = str:match("^(.-)%s*$")
      if rest ~= "" then res.rest = rest end
      return res
     end
  }
end

local lineparsers = {
  stringparser("h3", "###"),
  stringparser("h2","##"),
  stringparser("h1", "#"),
  stringparser("quote", ">"),
  stringparser("hr", "[-][-][-]+"),
  stringparser("list", "[*]"),
  stringparser("<pre", "``+"),
  stringparser("keyval", ":%S*"),
  function (str)
    local res = { type = "text" }
    local rest = str:match("^%s*(.-)%s*$")
    if rest ~= "" then res.rest = rest end
    return res
   end
}

local function parseline(parsers, str)
  for _, parse in ipairs(parsers) do
    local res = parse(str)
    if res then return res end
  end
  return nil
end

local function parse(iter)
  local parsers = lineparsers
  local state
  local meta, nothing, empty, text, emptyquote, quote, pre, list
  local cached = { first = 1, last = 0 }

  local function go(st, token)
    state = st
    if token then state(token) end
  end

  local function push(value)
    local next = cached.last + 1
    cached[next] = value
    cached.last = next
  end

  local function pusht(str) return push({ type = str }) end

  local function uncache()
    if cached.first > cached.last then
      cached.first = 1
      cached.last = 0
      return nil
    end
    local next = cached.first
    local res = cached[next]
    cached[next] = nil
    cached.first = next + 1
    return res
  end

  function meta(token)
    return function(line)
      if line.type == "keyval" then
        local meta = token.meta or {}
        meta[line.start:sub(2)] = (line.rest or "")
        token.meta = meta
      else
        push(token)
        go(nothing, line)
      end
    end
  end

  function empty(line)
    if line.type == "text" and not line.rest then
      pusht("br")
    else
      go(nothing, line)
    end
  end

  function emptyquote(line)
    if line.type == "quote" then
      if not line.rest then
        pusht("quotebr")
      else
        push({ type ="<p" })
        push(line)
        go(quote)
      end
    else
      pusht("quote>")
      go(nothing, line)
    end
  end

  function quote(line)
    if line.type == "quote" then
      if line.rest then
        pusht("br")
        push(line)
      else
        pusht("p>")
        go(emptyquote)
      end
    else
      pusht("p>")
      pusht("quote>")
      go(nothing, line)
    end
  end

  function nothing(line)
    if line.type == "text" and not line.rest then
      go(empty)
    elseif line.type == "text" then
      pusht("<p")
      push(line)
      go(text)
    elseif line.type == "list" then
      pusht("<list")
      push(line)
      go(list)
    elseif line.type == "<pre" then
      push(line)
      go(pre())
      parsers = preparsers(line.start)
    elseif line.type == "quote" then
      pusht("<quote")
      go(emptyquote, line)
    elseif line.type == "h1" or line.type == "h2" or line.type == "h3" then
      go(meta(line))
    elseif line.type == "keyval" then
      go(meta({ type = "meta" }), line)
    elseif line.type == "end" then
      go(nil)
    else push(line)
    end
  end

  function list(line)
    if line.type == "list" then
      push(line)
    else
      pusht("list>")
      go(nothing, line)
    end
  end

  function pre()
    local first = true
    return function(line)
      if line.type == "pre" then
        if first then first = false
        else pusht("prebr")
        end
        push(line)
      elseif line.type == "pre>" then
        push(line)
        go(nothing)
        parsers = lineparsers
      elseif line.type == "end" then
        pusht("pre>")
        go(nothing, line)
      else
        error("unreachable: " .. line.type)
      end
    end
  end

  function text(line)
    if line.type == "text" and not line.rest then
      pusht("p>")
      go(empty)
    elseif line.type == "text" and line.rest then
      pusht("br")
      push(line)
    else
      pusht("p>")
      go(nothing, line)
    end
  end

  go(nothing)
  local first = true
  local function next()
    while true do
      local res = uncache()
      if res then
        first = false
        return res end
      if not iter then
        if first then
          first = false
          return { type = "nop" }
        end
        return nil
      end
      local str = iter()
      if not str then
        iter = nil
        state({ type = "end" })
      else
        local line = parseline(parsers, str)
        state(line)
      end
    end
  end
  return next
end

local escapechar = {
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["'"] =  "&apos;",
  ["&"] = "&amp;"
}

local function escape(str)
  local res, _ = (str or ""):gsub("[<>\"'&]", escapechar)
  return res
end

local function renderlink(str, url)
  local rel, fullurl, desc = str:match("^%s*(me)%s*(%S+)%s*(.-)%s*$")
  if not rel then
    fullurl, desc = str:match("^%s*(%S+)%s*(.-)%s*$")
  end
  if not fullurl then return escape(str) end
  local fullurl = escape(fullurl)
  rel = rel and 'rel="me"' or ''
  local desc = ((desc ~= "") and escape(desc)) or fullurl
  local u, frag = fullurl:match("(.-)(#.*)")
  if not u then
    u = fullurl
    frag = ""
  end
  local internal = not u:match(":")
  if internal and u:match(".txt$") then
    u = u:sub(1, -5) .. ".html"
  end
  return '<a ' .. rel .. 'href="' .. url(u) .. frag .. '">' .. desc .. '</a>'
end

local function tagged(tag)
  return function(s)
    return "<" .. tag .. ">" .. escape(s) .. "</" .. tag .. ">"
  end
end

local formatting = {
  ["`"] = tagged("code"),
  ["_"] = tagged("em"),
  ["^"] = renderlink,
  [""] = escape
}

local function strhtml(str, url, plain)
  if not str then return nil end
  url = url or function(s) return s end
  local res = {}
  local current = {}
  local mode = ""
  local function start(c)
    mode = c
  end
  local function stop()
    local s = table.concat(current)
    local formatted = formatting[plain and "" or mode](s, url)
    table.insert(res, formatted)
    current = {}
    mode = ""
  end
  local startpos = 1
  while true do
    local pos, _ = str:find("[_`\\^]", startpos)
    if not pos then
      table.insert(current, str:sub(startpos, #str))
      stop()
      return table.concat(res)
    end
    
    table.insert(current, str:sub(startpos, pos - 1))
    
    local char = str:sub(pos, pos)
    if char == "\\" then
      table.insert(current, str:sub(pos + 1, pos + 1))
      startpos = pos + 2
    else
      if mode == "" then stop() ; start(char)
      elseif char == mode then stop()
      else table.insert(current, char)
      end
      startpos = pos + 1
    end
  end
end

local function prewriterf(class)
  class = class and (' class="' .. class .. '"') or ""
  return function(url)
    return function (line)
      if line.type == "<pre" then
        return "<figure><pre" .. class .. "><code>"
      elseif line.type == "pre" then
        return escape(line.rest)
      elseif line.type == "prebr" then
        return "\n"
      elseif line.type == "pre>" then
        local res = "</code></pre>"
        if line.rest then
          local caption = escape(line.rest)
          res = res .. "<figcaption>"
            .. strhtml(caption, url) .. "</figcaption>"
        end
        return res .. "</figure>"
      else
        error("unreachable: " .. line.type)
      end
    end
  end
end

local function img(url)
  return function (line)
    if line.type == "<pre" then
      return "<figure>"
    elseif line.type == "pre" then
      return '<img src= "' .. url(line.rest) .. '" alt="">'
    elseif line.type == "prebr" then
      return ""
    elseif line.type == "pre>" then
      local res = "</figure>" 
      if line.rest then
        local caption = escape(line.rest)
        res = "<figcaption>" .. caption .. "</figcaption>" .. res
      end
      return res 
    else
      error("unreachable: " .. line.type)
    end
  end
end

local function newdrawing(url)
  local map = draw.newmap()
  return function(line)
    if line.type == "<pre" then
      return "<figure>"
    elseif line.type == "pre" then
      map.addline(line.rest)
      return ""
    elseif line.type == "prebr" then
      return ""
    elseif line.type == "pre>" then
      local res = {}
      local function out(str) table.insert(res, str) end
      local svg = draw.render(map, out, 16)
      if line.rest then
        table.insert(res, "<figcaption>")
        table.insert(res, strhtml(line.rest, url))
        table.insert(res, "</figcaption>")
      end
      table.insert(res, "</figure>")
      return table.concat(res)
    else
      error("unreachable: " .. line.type)
    end
  end
end

local function segments(path, start)
  local segs = {}
  if path == "" then return segs end
  for str in path:gmatch("[^/]+", start) do
    table.insert(segs, str)
  end
  return segs
end

local function relativeurl(frompath)
  local from = segments(frompath)
  return function(topath)
    if topath:sub(1, 1) ~= "/" then return topath end
    local to = segments(topath, 2)
    local i = 1
    local minlen = math.min(#from, #to)
    while i <= minlen and from[i] == to[i] do
      i = i + 1
    end
    local maxlen = math.max(#from, #to)
    local escapes = {}
    local restpath = {}
    while i <= maxlen do
      if from[i] then table.insert(escapes, "..") end
      if to[i] then table.insert(restpath, to[i]) end
      i = i + 1
    end
    if #restpath == 0 and #escapes == 0 then
      return "./" .. from[#from]
    elseif #restpath == 0 then
      return table.concat(escapes, "/")
    elseif #escapes == 0 then
      return "./" .. table.concat(restpath, "/")
    else
      local escapesStr = table.concat(escapes, "/")
      local restStr = table.concat(restpath, "/")
      return escapesStr .. "/" .. restStr
    end
  end
end

local function basepre()
  return {
    drawing = newdrawing,
    img = img,
    html = function(url)
      return function(line)
        if line.type == "<pre" then return ""
        elseif line.type == "pre" then return line.rest
        elseif line.type == "prebr" then return "\n"
        elseif line.type == "pre>" then return ""
        else error("unreachable: " .. line.type)
        end
      end
    end
  }
end

local function basekvtable()
  return {
    pub = function(str, meta)
      local t = dt.fromb60(str)
      local b = meta.blurb
        and (' title="' .. strhtml(meta.blurb, nil, true) .. '"')
        or ""
      return '<time datetime="' .. t.iso() .. '"' .. b .. '>'
        .. str .. '</time>'
    end,
    html = function(str) return str end
  }
end

local function titlefrom(token)
  local t = token.type
  return (t == "h1" or t == "h2" or t == "h3") and token.rest or "untitled"
end


local function pubid(meta)
  return meta and meta.pub and "pub-" .. meta.pub:gsub("%W", "") or nil
end

local function html(url, pretable, kvtable)
  url = url or function(str) return str end
  pretable = pretable or basepre()
  kvtable = kvtable or basekvtable()
  local usedids = {}
  local prewriter = prewriterf()(url)
  local pre = nil
  local function rendermeta(meta, res)
    if not meta then return end
    for k, v in pairs(meta) do
      local f = kvtable[k]
      if f then
        table.insert(res, f(v, meta))
      end
    end
  end
  local function tagged(tag, line)
    local pubid = pubid(line.meta)
    local pubstr = ''
    if pubid then
      if usedids[pubid] then
        print('duplicate pub-ids. ignoring this "' .. pubid .. '"')
      else
        usedids[pubid] = true
        pubstr = ' id="' .. pubid .. '"'
      end
    end
    local inner = strhtml(line.rest, url)
    local res = { "<", tag, pubstr, ">", inner, "</", tag, ">" }
    rendermeta(line.meta, res)
    return table.concat(res)
  end
  

  local function renderLine(line)
    if line.type == "text" or line.type == "quote" then
      return strhtml(line.rest, url)
    end
  end
  
  return function(token)
    if token.type == "<p" then return "<p>"
    elseif token.type == "p>" then return "</p>"
    elseif token.type == "<quote" then return "<blockquote>"
    elseif token.type == "quote>" then return "</blockquote>"
    elseif token.type == "<pre" then
      local f = pretable[token.rest]
      pre = f and f(url) or prewriter
      return pre(token)
    elseif token.type == "pre" then return pre(token)
    elseif token.type == "prebr" then return pre(token)
    elseif token.type == "pre>" then
      local res = pre(token, url)
      pre = nil
      return res
    elseif token.type == "<list" then return "<ul>"
    elseif token.type == "list" then return tagged("li", token)
    elseif token.type == "list>" then return "</ul>"
    elseif token.type == "text" or token.type == "quote" then
      return renderLine(token)
    elseif token.type == "br" or token.type == "quotebr" then return "<br>"
    elseif token.type == "h1" then return tagged("h1", token)
    elseif token.type == "h2" then return tagged("h2", token)
    elseif token.type == "h3" then return tagged("h3", token)
    elseif token.type == "hr" then return "<hr>"
    elseif token.type == "meta" then
      local res = {}
      rendermeta(token.meta, res)
      return table.concat(res)
    elseif token.type == "nop" then return ""
    else error("unknown type: " .. token.type)
    end
  end
end

local function parsestring(str) return parse(str:gmatch("[^\n]*")) end

local function multiparse(parsers)
  local i = 1
  return function()
    while i <= #parsers do
      local res = parsers[i]()
      if res then return res
      else i = i + 1 
      end
    end
    return nil
  end
end

local down = function(str)
  local res = {}
  local html = html()
  for token in parse(str:gmatch("[^\n]*")) do
   table.insert(res, html(token))
  end
  return table.concat(res)
end

return {
  parse = parse,
  multiparse = multiparse,
  parsestring = parsestring,
  pubid = pubid,
  strhtml = strhtml,
  titlefrom = titlefrom,
  basepre = basepre,
  basekvtable = basekvtable,
  prewriterf = prewriterf,
  html = html,
  relativeurl = relativeurl,
  down = down
}
