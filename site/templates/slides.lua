local templates = require("../templates")
local gd = require("../gd")

return function(url)
  local i = 1
  local kvtable = gd.basekvtable()
  kvtable.slide = function(v)
    i = i + 1
    return [[</div><div id="s]] .. i .. [[" class="slide">
<p><a href="#s]] .. (i - 1) .. [[" class="prev" title="prev">&lt;&lt;</a> <a href="#s]] .. (i + 1) .. [[" class="next" title="next">&gt;&gt;</a></p>]]
  end
  return {
    before = function(token)
        return templates.beforetitle(url) .. templates.title(token)
            .. [[<style>]]
            .. templates.css("30rem")
            ..
[[body:has(> #slideshow:checked) div.slide:not(#s1, :target),
:root:has(:target) body:has(> #slideshow:checked) #s1:not(:target) {
  display: none;
}
</style>
<script>
const click = (selector) => {
  for (const a of document.querySelectorAll(selector)) {
    if (a.offsetParent !== null) { a.click(); return; }
  }
};
document.onkeypress = (e) => {
  if (e.key === "q") { click("div.slide:target a.prev"); }
  else if (e.key === "e") {
    click("div.slide:target a.next, :root:not(:has(:target)) #s1 a.next");
  } else if (e.key === "w") { click("#slideshow"); }
};
</script>
</head>
<body>
<label for="slideshow">Slideshow</label><input id="slideshow" type="checkbox" checked />
<div class="slide" id="s1">
<p>&lt;&lt; <a href="#s2" class="next" title="next">&gt;&gt;</a></p>
]] .. templates.nav(url, token)
    end,
    after = function()
      return [[</div><div class="slide" id="s]] .. (i + 1) ..
[["><p><a href="#s]] .. i .. [[" class="prev" title="prev">&lt;&lt;</a> &gt;&gt;</p></div>]]
        .. templates.aftercontent
    end,
    kvtable = kvtable
  }
end
