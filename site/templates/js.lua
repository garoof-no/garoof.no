local templates = require("templates")
local gd = require("gd")

local pretable = gd.basepre()
pretable.repl = gd.prewriterf("js repl")
pretable.run = gd.prewriterf("js run")
pretable.prelude = gd.prewriterf("js prelude run")

local template = {
  before = function(url, token)
    return templates.beforetitle(url) .. templates.title(token)
      .. '<script src="' .. url("/js.js") .. '" defer></script>'
      .. '<style>'
      .. templates.colorcss .. templates.css() .. templates.replcss
      .. '</style>'
      .. '</head><body>'
      .. templates.nav(url, token)
  end,
  after = function() return templates.aftercontent end,
  pretable = pretable
}

return { create = function() return template end }

