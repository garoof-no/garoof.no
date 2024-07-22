"use strict";
(() => {
  const elem = (tagName, props, ...children) => {
    const el = Object.assign(document.createElement(tagName), props);
    el.replaceChildren(...children);
    return el;
  };
  let currentOut = null;
  const print = (str) => {
    if (currentOut !== null) {
      currentOut.console.append(elem("samp", {}, str), "\n");
    } else {
      console.log(str);
    }
  };
  const html = (str) => {
    if (currentOut !== null) {
      const el = elem("div", {});
      el.innerHTML = str;
      currentOut.append(el);
    } else {
      console.log("html: " + str);
    }
  };
  let Module;
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
        currentOut.console.append(
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
      } else if (code == "html") {
          html(payload);
      } else {
        console.error(`unkown code sent from Lua. code: "%o". payload: %o`, code, payload);
      }
    }
  };

  const resizeta = ta => {
    ta.setAttribute("style", "height: 0;");
    const height = ta.scrollHeight;
    ta.setAttribute("style", `height: ${height}px;`);
    const extra = ta.offsetHeight - ta.clientHeight;
    ta.setAttribute("style", `height: ${height + extra}px;`);
  };

  const create = (element) => {
    const ta = elem("textarea", {
      value: element.innerText,
    });
    const toolbar = elem("div", { className: "toolbar" });
    const consoleout = elem("pre", { className: "output" });
    const out = elem("div", { }, consoleout);
    out.console = consoleout;
    const run = (e) => {
      currentOut = out;
      Module.ccall("run_lua", "number", ["string"], [ta.value]);
      currentOut = null;
    };
    element.after(ta, toolbar, out);
    element.remove();
    resizeta(ta);

    if (element.classList.contains("prelude")) {
      run();
      ta.readOnly = true;
    } else {
      ta.oninput = () => resizeta(ta);
      toolbar.append(
        elem("button", { className: "toolbar-button", title: "Run", onclick: run }, "▶"),
        elem(
          "button", {
            className: "toolbar-button",
            title: "Clear output",
            onclick: (e) => {
              consoleout.replaceChildren();
              out.replaceChildren(consoleout);
            }
          },
          "⎚")
        );
    }
  };

  window.addEventListener("load", (e) => {
    initWasmModule(ModuleConfig).then((aModule) => {
      Module = aModule;
      Module.ccall("run_lua", "number", ["string"], [`
      local send = webSend
      webSend = nil
      web = {}
      local Web = {}
      setmetatable(web, Web)
      function Web:__index(code)
        return function(payload) send(code, payload) end
      end
      `]);
      for (const el of document.querySelectorAll(".lua")) {
        create(el)
      };
    });
  });
})();
