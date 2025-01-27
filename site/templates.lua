local gd = require("gd")

local function beforetitle(url)
  return [[<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" href="]] .. url("/gfx/frog.svg") .. [[" sizes="any" type="image/svg+xml">
    ]]
end

local aftercontent = [[</body>
</html>
]]

local colorcss = [[
:root { color-scheme: dark; --bg: #131F07; --bg2: #173806; --text: #dcdcdc; --accent: #FFBF00; --accent2: #D8A100; ;--accent3: #4D3700; }
body { color: var(--text); background-color: var(--bg); }
pre { background-color: var(--bg2); }
textarea { color: var(--text); background-color: var(--bg2); border-color: var(--accent); }
button { background-color: var(--bg2); border-top: 1px solid var(--accent); border-right: 1px solid var(--accent3); border-bottom: 1px solid var(--accent3); border-left: 1px solid var(--accent); }
button:active { border-top: 1px solid var(--accent3); border-left: 1px solid var(--accent3); }
a { color: var(--accent); }
a:hover { text-decoration: none; }
nav a { color: var(--text); }
]]

local function css(width)
  width = width or "50rem"
  return [[
body { font-family: -apple-system, BlinkMacSystemFont, "Avenir Next", Avenir, "Nimbus Sans L", Roboto, "Noto Sans", "Segoe UI", Arial, Helvetica, "Helvetica Neue", sans-serif; padding-left: 0.5rem; padding-right: 0.5rem; max-width: ]] .. width ..[[; margin: 1rem auto 0 auto; }
p, pre, ul, hr, figure { margin: 1rem 0 1rem 0; padding: 0; }
h1, h2, h3 { margin: 2rem 0 0rem 0; padding: 0; }
h1 { font-size: 2.2rem; } h2 { font-size: 1.4rem; }  h3 { font-size: 1.1rem; }
blockquote { padding: 0 0 0 0.8rem; margin: 0 0 0 0rem; border-left: 0.1rem solid var(--text); }
pre { overflow-x: auto; }
pre, code { font-family: Consolas, Menlo, Monaco, "Andale Mono", "Ubuntu Mono", monospace; font-size: 1.05em; white-space: pre; }
ul { list-style-position: inside; }
li { margin: 0;padding: 0; }
hr { margin: 1.5rem 0 1.5rem 0; }
img { max-width: 100%; }
textarea { width: 100%; font-size: 1.05rem; }
time { font-style: italic; }
:is(h1, h2, h3):target::after { content: " ⇐"; }
]]
end

local replcss = [[
.row, .toolbar { display: flex; flex-direction: row; }
.toolbar-button { align-self: flex-start; }
.error { text-decoration: underline; text-decoration-color: red; }
.output { margin: 0 0 0 0.3rem; }
button { font-size: 1rem; min-width: 2rem; }
]]

local function nav(url, token)
  local nonav = (token.meta or {}).nonav and ''
  return nonav or '<nav><p><a href="' .. url("/index.html") .. '">index</a></p></nav>'
end

local function title(token)
  return '<title>' .. gd.strhtml(gd.titlefrom(token), nil, true) .. '</title>'
end

return {
    beforetitle = beforetitle,
    aftercontent = aftercontent,
    colorcss = colorcss,
    css = css,
    replcss = replcss,
    style = '<style>' .. colorcss .. css() .. '</style>',
    nav = nav,
    title = title
}
