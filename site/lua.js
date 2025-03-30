"use strict";
const luarun = (() => {
  const elem = (tagName, props, ...children) => {
    const el = Object.assign(document.createElement(tagName), props);
    el.replaceChildren(...children);
    return el;
  };

  let currentHandler = null;
  const handle = (code, payload) => {
    if (currentHandler && currentHandler[code]) {
      currentHandler[code](payload);
    } else if (code === "print") {
      console.log(payload);
    } else if (code === "error") {
      console.error(payload);
    } else if (code !== "return" || payload !== "") {
      console.log(`${code}:\n${payload}`);
    }
  };

  const handler = (currentOut, outStr) => {
    const print = (str) => {
      if (currentOut) {
        currentOut.lastElementChild.append(elem("samp", {}, str), "\n");
      } else {
        console.log(str);
      }
    };
    return Object.assign(
      Object.create(null),
      {
        return: (str) => {
          if (str !== "") {
            print(`return: "${str}"`);
          }
        },
        print: (str) => {
          print(str);
        },
        error: (str) => {
          if (outStr) {
            outStr += ` ${str}`;
            return;
          }
          if (currentOut) {
            currentOut.lastElementChild.append(
              elem("span", { className: "error" }, str),
              "\n"
            );
          } else {
            console.log(str);
          }
        },
        show: (str) => {
          if (outStr) {
            outStr += ` ${str}`;
          } else {
            console.log(str);
          }
        },
        html: (str) => {
          if (currentOut) {
            const el = elem("div", {});
            el.innerHTML = str;
            currentOut.append(el, elem("pre", { className: "output" }));
          } else {
            console.log("html: " + str);
          }
        },
        read: (str) => {
          if (currentOut === null) {
            console.log("read: " + str);
          }
          const inp = elem("input");
          const myrun = () => run(luaresume, `return ${luastr(inp.value)}`, handler(currentOut, outStr));
          inp.onkeyup = (e) => {
            if (e.key === "Enter") {
              myrun();
            }
          };
          const el = str === "" ? inp : elem("label", {}, `${str} `, inp);
          const button = elem(
            "button",
            { onclick: myrun },
            "▶"
          );
          resume = [inp, button];
          currentOut.lastElementChild.append(el, button, "\n");
          inp.focus();
        }
      });
  };

  const luaplain = `return function(f) return f() end`;
  const luarun = `return web.run`;
  const luashow = `return function(f) web.show(show(f())) end`;
  const luaresume = `return web.resume`;
  
  let Module;

  let resume = [];

  const run = (runner, code, handler) => {
    currentHandler = handler;
    resume.forEach(x => { x.disabled = true; });
    resume = [];
    Module.ccall("run_lua", "number", ["string", "string"], [runner, code]);
  };

  const luastr = (str) => {
    let i = 1;
    while (true) {
      const eqs = "=".repeat(i);
      const start = `[${eqs}[`
      const stop = `]${eqs}]`
      if (!str.includes(stop)) {
        return `${start}${str}${stop}`;
      }
      i++;
    }
  };
  
  let ModuleConfig = {
    print: (function () {
      return (text) => {
        if (arguments.length > 1) {
          text = arguments.join(" ");
        }
        if (text != "emsc") {
          handle("print", text);
        }
      };
    })(),
    printErr: function (text) {
      if (arguments.length > 1) {
        text = arguments.join(" ");
      }
      handle("error", text);
    },
    send: handle
  };

  const create = (element) => {
    const ta = document.body.appendChild(elem("textarea", {
      value: element.innerText,
    }));
    ta.setAttribute("style", "height: 0;");
    const height = ta.scrollHeight;
    ta.setAttribute("style", `height: ${height}px;`);
    const extra = ta.offsetHeight - ta.clientHeight;
    ta.setAttribute("style", `height: ${height + extra}px;`);
    
    const toolbar = elem("div", { className: "toolbar" });
    const out = elem("div", { }, elem("pre", { className: "output" }));
    element.after(ta, toolbar, out);
    element.remove();

    const selected = () => {
      const str = ta.value;
      const start = ta.selectionStart;
      const end = ta.selectionEnd;
      if (start !== end) {
        return { str: str.substring(start, end), pos: end };
      }
      let lineStart = str.lastIndexOf("\n", start - 1) + 1;
      if (lineStart < 0) { lineStart = 0; }
      let lineEnd = str.indexOf("\n", start);
      if (lineEnd < 0) { lineEnd = str.length; }
      return { str: str.substring(lineStart, lineEnd), pos: lineEnd };
    };

    const insert = (str, pos) => {
      ta.setRangeText(str, pos, pos, "select");
    };

    const myrun = (str) => {
      run(luarun, str, handler(out));
    };

    if (element.classList.contains("run")) {
      myrun(ta.value)
    }
    if (element.classList.contains("repl")) {
      ta.onkeyup = e => {
        if ((e.ctrlKey || e.metaKey || e.shiftKey) && e.key === "Enter") {
          e.preventDefault();
          const sel = selected();
          let code;
          let runner;
          if (e.shiftKey) {
            run(luarun, sel.str, handler(out, outStr));
          } else {
            run(luashow, `return ${sel.str}`, handler(out, outStr));
          }
          insert(outStr, sel.pos);
          currentHandler = handler(out);
        }
      };
    
      toolbar.append(
        elem("button", { className: "toolbar-button", title: "Run", onclick: () => myrun(ta.value) }, "▶"),
        elem(
          "button", {
            className: "toolbar-button",
            title: "Clear output",
            onclick: () => {
              out.replaceChildren(elem("pre", { className: "output" }));
            }
          },
          "⎚")
        );
    } else {
      ta.readOnly = true;
    }
  };

  window.addEventListener("load", (e) => {
    initWasmModule(ModuleConfig).then((aModule) => {
      Module = aModule;
      Module.ccall("run_lua", "number", ["string", "string"], [luaplain, `
      local send = webSend
      webSend = nil
      web = {
        run = function(thunk)
          coroutine.wrap(
            function()
              local _, res = pcall(thunk)
              if res ~= nil then send("return", tostring(res)) end
            end
          )()
        end,
        resume = function(thunk)
          local prev = web.co
          web.co = nil
          coroutine.resume(prev, thunk);
        end,
        read = function(str)
          web.co = coroutine.running()
          send("read", str)
          local thunk = coroutine.yield()
          local res = thunk()
          return res
        end
      }
      local Web = {}
      setmetatable(web, Web)
      function Web:__index(code)
        return function(payload) send(code, payload) end
      end
      function show(o)
        if type(o) == "table" then
          local is = {}
          for i, v in ipairs(o) do
            is[i] = true
          end
          local res = { "{", "" }
          for k, v in pairs(o) do
            if not is[k] then
              table.insert(res, " " .. tostring(k) .. " = " .. tostring(v))
              table.insert(res, ",")
            end
          end
          for i, v in ipairs(o) do
            table.insert(res, " " .. tostring(v))
            table.insert(res, ",")
          end
          res[#res] = " }"
          return table.concat(res)
        else return tostring(o)
        end
      end
      `]);
      for (const el of document.querySelectorAll(".lua.prelude")) {
        create(el)
      };
      for (const el of document.querySelectorAll(".lua:not(.prelude)")) {
        create(el)
      };
    });
  });
  return run;
})();
