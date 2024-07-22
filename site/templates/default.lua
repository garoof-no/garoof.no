local templates = require("../templates")

return function(url)
  return {
    before = function(token)
      return templates.beforetitle(url) .. templates.title(token)
        .. templates.style .. '</head><body>'
        .. templates.nav(url, token)
    end,
    after = function() return templates.aftercontent end
  }
end
