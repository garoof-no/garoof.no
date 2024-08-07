local templates = require("../templates")
local gd = require("../gd")

local pretable = gd.basepre()
pretable.repl = gd.prewriterf("lambs")
pretable.prelude = gd.prewriterf("lambs prelude")

return function(url)
  return {
   before = function(token)
    return templates.beforetitle(url) .. templates.title(token)
      .. '<script src="' .. url("/lambs.js") .. '" defer></script>'
      .. templates.style .. '</head><body>'
      .. templates.nav(url, token)
   end,
   after = function() return templates.aftercontent end,
   pretable = pretable
  }
 end
