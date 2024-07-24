local gd = require("gd")
local draw = require("gd-draw")
local rss = require("rss")

local function findtemplate(name)
  name = name or "default"
  return require("templates/" .. name)
end

local function files()
  local win = package.config:sub(1, 1) == "\\"
  local ps = [[powershell.exe "gci -Recurse -Filter '*.txt' | rvpa -Relative"]]
  local lunix = [[find . -name \*.txt -print]]
  local command = (win and ps) or lunix
  local pipe = io.popen(command)
  local str = pipe:read()
  local res = {}
  while str do
    if win then str = str:gsub("\\", "/") end
    table.insert(res, str)
    str = pipe:read()
  end
  if not pipe:close() then error("oh no") end
  return res
end

local function writeHtml(parser, htmlfilename)

  local function todo(meta)
    local s = meta and meta.todo
    if s then      
      print(htmlfilename .. ": " .. ((s == "") and "todo" or s))
    end
  end

  local fout = io.open(htmlfilename, "w")
  local first = parser()
  todo(first.meta)
  local meta = first.meta or {}
  local url = meta.absoluteurls and (function(u) return u end)
    or gd.relativeUrl(htmlfilename:match("^[.]/(.+)/.*$") or "/")
    
  local template = findtemplate(meta.template)(url)
  local title = gd.titlefrom(first)
  local res = { { path = htmlfilename, title = title, meta = meta } }
  fout:write(template.before(first))
  local html = gd.html(url, template.pretable, template.kvtable)
  fout:write(html(first))
  for token in parser do
    todo(token.meta)
    local pubid = gd.pubid(token.meta)
    if pubid then
      local path = htmlfilename .. "#" .. pubid
      local title = gd.titlefrom(token)
      table.insert(res, { path = path, title = title, meta = token.meta })
    end
    fout:write(html(token))
  end
  fout:write(template.after())
  if not fout:close() then error("oh no") end
  return res
end

local later = {}
local pubrefs = {}
local otherrefs = {}

for _, path in ipairs(files()) do
  if path == "./index.txt" or path == "./404.txt" then
    later[path] = true
  else
    local fin = io.open(path)
    local res = writeHtml(gd.parse(fin:lines()), path:sub(1, -5) .. ".html")
    for _, ref in ipairs(res) do
      table.insert(ref.meta.pub and pubrefs or otherrefs, ref)
    end
    if not fin:close() then error("oh no") end
  end
end

table.sort(pubrefs, function(a, b) return a.meta.pub > b.meta.pub end)
table.sort(otherrefs, function(a, b) return (a.path) < (b.path) end)

local function links(list)
  i = 1
  return function()
    if i > #list then return nil end
      local ref = list[i]
      i = i + 1
      return "`" .. ref.meta.pub .. ":` ^" .. ref.path .. " " .. ref.title
  end
end

local index = {}
local closeindex = function() end
if later["./index.txt"] then
  local fin = io.open("./index.txt")
  table.insert(index, gd.parse(fin:lines()))
  closeindex = function() if not fin:close() then error("oh no") end end
else
  table.insert(index, gd.parsestring("# index\n:nonav"))
end
table.insert(index, gd.parsestring(":html <nav>"))
table.insert(index, gd.parse(links(pubrefs)))
table.insert(index, gd.parsestring(":html </nav>"))
local indexref = writeHtml(gd.multiparse(index), "./index.html")
closeindex()

local notfound
local closenotfound = function() end
if later["./404.txt"] then
  local fin = io.open("./404.txt")
  notfound = gd.parse(fin:lines())
  closenotfound = function() if not fin:close() then error("oh no") end end
else
  notfound = gd.parsestring("# 404 oh no\n:absoluteurls")
end
writeHtml(notfound, "./404.html")
closenotfound()

local feed = io.open("./feed.xml", "w")
rss(feed, arg[1] or "https://www.example.com", indexref[1], pubrefs)
