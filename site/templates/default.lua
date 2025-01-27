local templates = require("templates")

local template = {
  before = function(url, token)
    return templates.beforetitle(url, token) .. templates.title(token)
      .. templates.style .. '</head><body>'
      .. templates.nav(url, token)
  end,
  after = function() return templates.aftercontent end
}

return { create = function() return template end }

