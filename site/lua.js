"use strict";
(() => {
  const elem = (tagName, props, ...children) => {
    const el = Object.assign(document.createElement(tagName), props);
    el.replaceChildren(...children);
    return el;
  };
  let currentOut = null;
  let outStr = null;
  const print = (str) => {
    if (currentOut !== null) {
      currentOut.lastElementChild.append(elem("samp", {}, str), "\n");
    } else {
      console.log(str);
    }
  };
  const err = (str) => {
    if (outStr !== null) {
      outStr += ` ${str}`;
      return;
    }
    if (currentOut !== null) {
      currentOut.lastElementChild.append(
        elem("span", { className: "error" }, str),
        "\n"
      );
    } else {
      console.log(str);
    }
  };
  const show = (str) => {
    if (outStr !== null) {
      outStr += ` ${str}`;
    } else {
      console.log(str);
    }
  };
  const html = (str) => {
    if (currentOut !== null) {
      const el = elem("div", {});
      el.innerHTML = str;
      currentOut.append(el, elem("pre", { className: "output" }));
    } else {
      console.log("html: " + str);
    }
  };


  const luaplain = `return function(f) return f() end`;
  const luarun = `return web.run`;
  const luashow = `return function(f) web.show(show(f())) end`;
  const luaresume = `return web.resume`;
  
  
  let Module;

  let resume = [];

  const run = (runner, code) => {
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

  const read = (str) => {
    if (currentOut === null) {
      console.log("read: " + str);
    }
    const inp = elem("input");
    const myrun = () => run(luaresume, `return ${luastr(inp.value)}`);
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
  };
  
  let ModuleConfig = {
    print: (function () {
      return (text) => {
        if (arguments.length > 1) {
          text = arguments.join(" ");
        }
        if (text != "emsc") {
          print(text);
        }
      };
    })(),
    printErr: function (text) {
      if (arguments.length > 1) {
        text = arguments.join(" ");
      }
      if (currentOut !== null) {
        currentOut.lastElementChild.append(
          elem("span", { className: "error" }, text),
          elem("br")
        );
      } else {
        console.error(text);
      }
    },
    send: (code, payload) => {
      if (code === "return") {
        if (payload === "") {
          return;
        }
        print("return: " + payload);
      } else if (code === "error") {
        err(payload);
      } else if (code === "show") {
        show(payload);
      } else if (code === "html") {
          html(payload);
      } else if (code === "read") {
        read(payload);
      } else {
        console.error(`unkown code sent from Lua. code: "%o". payload: %o`, code, payload);
      }
    }
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
      currentOut = out;
      run(luarun, str);
    };

    if (element.classList.contains("run")) {
      myrun(ta.value)
    }
    if (element.classList.contains("repl")) {
      ta.onkeyup = e => {
        if ((e.ctrlKey || e.metaKey || e.shiftKey) && e.key === "Enter") {
          e.preventDefault();
          const sel = selected();
          currentOut = out;
          outStr = "";
          let code;
          let runner;
          if (e.shiftKey) {
            run(luarun, sel.str);
          } else {
            run(luashow, `return ${sel.str}`);
          }
          insert(outStr, sel.pos);
          outStr = null;
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
      show = tostring
      `]);
      for (const el of document.querySelectorAll(".lua.prelude")) {
        create(el)
      };
      for (const el of document.querySelectorAll(".lua:not(.prelude)")) {
        create(el)
      };
    });
  });
})();
