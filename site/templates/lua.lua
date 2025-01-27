local templates = require("templates")
local gd = require("gd")

local pretable = gd.basepre()
pretable.repl = gd.prewriterf("lua repl")
pretable.run = gd.prewriterf("lua run")
pretable.prelude = gd.prewriterf("lua prelude run")

local function scripttags(url)
  return '<script src="' .. url("/lua-wasm.js") .. '" defer></script>'
    .. '<script src="' .. url("/lua.js") .. '" defer></script>'
end

local template = {
  before = function(url,token)
    return templates.beforetitle(url) .. templates.title(token)
      .. scripttags(url)
      .. '<style>'
      .. templates.colorcss .. templates.css() .. templates.replcss
    .. '</style>'
    .. '</head><body>'
    .. templates.nav(url, token)
 end,
 after = function() return templates.aftercontent end,
 pretable = pretable
}

return {
  create = function() return template end,
  scripttags = scripttags,
  pretable = pretable
}

