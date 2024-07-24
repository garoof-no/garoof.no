local gd = require("gd")
local dt = require("gd-datetime")

local function rss(out, url, index, posts)

  local level = 0
  local function line(str)
    out:write((" "):rep(level))
    out:write(str)
    out:write("\n")
  end
  local function open(tag)
    line("<" .. tag .. ">")
    level = level + 1
  end
  local function close(tag)
    level = level - 1
    line("</" .. tag .. ">")
  end
  local function tagged(tag, str)
    line("<" .. tag .. ">" .. str .. "</" .. tag .. ">")
  end

  local function item(ref)
    local link = url .. ref.path:sub(2)
    open("item")
    tagged("title", gd.strhtml(ref.title, nil, true))
    tagged("link", link)
    tagged("description", gd.strhtml(ref.meta.blurb or "stuff", nil, true))
    tagged("pubDate", dt.fromb60(ref.meta.pub).rss())
    tagged("guid", link)
    close("item")
  end

  out:write('<?xml version="1.0"?>')
  open('rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/"')
  open("channel")
  tagged("title", gd.strhtml(index.title, nil, true))
  line('<atom:link href="' .. url .. "/feed.xml" .. '" rel="self" type="application/rss+xml" />')
  tagged("link", url)
  tagged("description", gd.strhtml((index.meta or {}).blurb or "stuff", nil, true))
  tagged("language", "en")
  for _, ref in ipairs(posts) do
    item(ref)
  end
  close("channel")
  close("rss")
end

return rss
