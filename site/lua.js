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
      currentOut.append(elem("samp", {}, str), "\n");
    } else {
      console.log(str);
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
        currentOut.append(
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
    const run = (e) => {
      currentOut = out;
      Module.ccall("run_lua", "number", ["string"], [ta.value]);
      currentOut = null;
    };
    const toolbar = elem("div", { className: "toolbar" });
    const out = elem("pre", { className: "output" });
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
        elem("button", { className: "toolbar-button", title: "Clear output", onclick: (e) => { out.replaceChildren(); } }, "⎚"));
    }
  };

  window.addEventListener("load", (e) => {
    initWasmModule(ModuleConfig).then((aModule) => {
      Module = aModule;
      for (const el of document.querySelectorAll(".lua")) {
        create(el)
      };
    });
  });
})();
