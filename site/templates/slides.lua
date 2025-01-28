local templates = require("templates")
local gd = require("gd")

local function slider()
  local i = 1
  local function slide()
    i = i + 1
    return [[</div><div id="s]] .. i .. [[" class="slide">
<p><a href="#s]] .. (i - 1)
      .. [[" class="prev" title="prev">&lt;&lt;</a> <a href="#s]] .. (i + 1)
      .. [[" class="next" title="next">&gt;&gt;</a></p>]]
  end
  local kvtable = gd.basekvtable()
  kvtable.slide = slide
  
  return {
    kvtable = kvtable,
    first = [[
<label for="slideshow">Slideshow</label><input id="slideshow" type="checkbox" checked />
<div class="slide" id="s1">
<p>&lt;&lt; <a href="#s2" class="next" title="next">&gt;&gt;</a></p>
]],
  last = function()
    return
[[</div><div class="slide" id="s]] .. (i + 1) ..
[["><p><a href="#s]] .. i .. [[" class="prev" title="prev">&lt;&lt;</a> &gt;&gt;</p></div>]]
  end
  }
end

local slidecss = [[
body:has(> #slideshow:checked) div.slide:not(#s1, :target),
:root:has(:target) body:has(> #slideshow:checked) #s1:not(:target) {
  display: none;
}
]]

local scripttag = [[
<script>
const click = (selector) => {
  for (const a of document.querySelectorAll(selector)) {
    if (a.offsetParent !== null) { a.click(); return; }
  }
};
document.onkeypress = (e) => {
  const tn = document.activeElement.tagName;
  if (tn === "TEXTAREA" || tn === "INPUT") {
    return;
  } 
  if (e.key === "q") { click("div.slide:target a.prev"); }
  else if (e.key === "e") {
    click("div.slide:target a.next, :root:not(:has(:target)) #s1 a.next");
  } else if (e.key === "w") { click("#slideshow"); }
};
</script>
]]

local function create()
  local sl = slider()
  return {
    before = function(url, token)
        return templates.beforetitle(url, token) .. templates.title(token)
          .. [[<style>]] .. templates.css("30rem") .. slidecss .. [[</style>]]
          .. scripttag
          .. [[</head><body>]]
          .. sl.first
          .. templates.nav(url, token)
    end,
    after = function()
      return sl.last() .. templates.aftercontent
    end,
    kvtable = sl.kvtable
  }
end

return {
  slider = slider,
  slidecss = slidecss,
  scripttag = scripttag,
  create = create
}

