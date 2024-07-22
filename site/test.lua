
local status = {}
function status.__lt(a, b) return a.priority < b.priority end
function status.__le(a, b) return a.priority <= b.priority end
function status.__tostring(a) return a.name end
for i, v in ipairs({ "ok", "todo", "fail", "error" }) do
  status[v] = setmetatable({ name = v, priority = i }, status)
end

local colors = {
  [status.ok] = { main = 2 },
  [status.todo] = { main = 2, side = 3 },
  [status.fail] = { main = 1 },
  [status.error] = { main = 1 }
}
local reset = "\27[0m"

local function forecolor(n) return "\27[3" .. n .. "m" end
local function backcolor(n) return "\27[4" .. n .. "m" end

local function testresult(name, result, description)
  return {
    name = name,
    status = result,
    write = function(str)
      if result ~= status.ok then
        local c = colors[result]
        table.insert(
          str,
          forecolor(c.side or c.main) .. " - " .. reset ..
          name .. " is " .. tostring(result) ..
          ((description and (": " .. description)) or "")
        )
      end
    end
  }
end

local key = {}

local function fail(description)
  error({ key = key, status = status.fail, description = description })
end

local function todo(description)
  error({ key = key, status = status.todo, description = description })
end

local check = {}
setmetatable(check, check)
function check:__call(b)
  if not b then fail("check failed") end
end
function check.eq(e, a)
  if e ~= a then
    fail("expected: " .. tostring(e).. ", actual: " .. tostring(a))
  end
end

local function testsresult(name, results)
  local count = {
    [status.ok] = 0, [status.todo] = 0,
    [status.fail] = 0, [status.error] = 0
  }
  local result = status.ok
  for _, r in ipairs(results) do
    result = math.max(result, r.status)
    count[r.status] = count[r.status] + 1
  end
  return {
    name = name,
    status = result,
    write = function(str, verbose)
      local c = colors[result]
      local sidecolor = backcolor(c.side or c.main)
      local textcolor = backcolor(c.main)
      local resultstr =
        sidecolor .. "***" ..
        textcolor .. " " .. name .. " is " .. tostring(result) .. " " ..
        sidecolor .. "***" .. reset
      table.insert(str, resultstr)
    end
  }
end

local function runtest(name, f, out)
  local success, res = pcall(f)
  if success then
    out(testresult(name, status.ok))
  elseif type(res) == "table" and res.key == key then
    out(testresult(name, res.status, res.description))
  else
    out(testresult(name, status.error, tostring(res)))
  end
end

local function runtable(name, t, out)
  local res = {}
  local function inner(result)
   table.insert(res, result)
   local str = {}
   result.write(str)
   for _, v in ipairs(str) do out(v) end
  end
  for k, v in pairs(t) do
    runtest(name .. "/" .. k, v, inner)
  end
  local str = {}
  testsresult(name, res).write(str)
  for _, v in ipairs(str) do out(v) end
end

local function fib(n)
  if n < 2 then return n
  else return 0
  end
end

local tests = {}
function tests.fib0() check.eq(0, fib(0)) end
function tests.fib1() check.eq(1, fib(1)) end
function tests.fib2() todo() ; check.eq(1, fib(2)) end

runtable("tests", tests, print)
