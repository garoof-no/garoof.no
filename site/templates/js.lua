local templates = require("../templates")
local gd = require("../gd")

local pretable = gd.basepre()
pretable.repl = gd.prewriterf("js")
pretable.prelude = gd.prewriterf("js prelude")

return function(url)
  return {
    before = function(token)
      return templates.beforetitle(url) .. templates.title(token)
        .. '<script src="' .. url("/js.js") .. '" defer></script>'
        .. '<style>'
        .. templates.css()
        .. [[
.row, .toolbar { display: flex; flex-direction: row; }
.toolbar-button { align-self: flex-start; }
.error { text-decoration: underline; text-decoration-color: red; }
.output { margin: 0 0 0 0.3rem; }
button { font-size: 1rem; min-width: 2rem; }
]]
        .. '</style>'
        .. '</head><body>'
        .. templates.nav(url, token)
    end,
    after = function() return templates.aftercontent end,
    pretable = pretable
  }
  end
