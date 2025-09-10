local templates = require("templates")
local slides = require("templates/slides")
local lua = require("templates/lua")

local function create()
  local sl = slides.slider()
  return {
    before = function(url, token)
        return templates.beforetitle(url, token) .. templates.title(token)
          .. [[<style>]] .. templates.css("30rem") .. slides.slidecss
          .. templates.replcss .. [[</style>]]
          .. lua.scripttags(url) .. slides.scripttag
          .. [[</head>\n<body>\n]]
          .. sl.first
          .. templates.nav(url, token)
    end,
    after = function()
      return sl.last() .. templates.aftercontent
    end,
    kvtable = sl.kvtable,
    pretable = lua.pretable
  }
end

return { create = create }

