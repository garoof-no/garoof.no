"use strict";

const outElement = (() => {
  const elem = (tagName, props, ...children) => {
    const el = Object.assign(document.createElement(tagName), props);
    el.replaceChildren(...children);
    return el;
  };
  const params = new URLSearchParams(window.location.search);
  const wait = params.has("wait") && params.get("wait") !== "false";
  let currentOut = null;
  window.addEventListener("error", (event) => {
    if (currentOut !== null) {
      currentOut.append(
        elem("span", { className: "error" }, event.message),
        elem("br")
      );
    }
  });

  const outElement = elem("div");

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
    const out = elem("pre", { className: "output" });
    const run = (e) => {
      currentOut = out;
      toolbar.after(outElement);
      const script = elem("script", {}, ta.value);
      document.head.appendChild(script);
      script.remove();
      currentOut = null;
    };
    element.after(ta, toolbar, out);
    element.remove();
    resizeta(ta);

    if (element.classList.contains("run")) {
      run();
    }
    if (element.classList.contains("repl")) {
      ta.oninput = () => resizeta(ta);
      toolbar.append(
        elem("button", { className: "toolbar-button", title: "Run", onclick: run }, "▶"),
        elem("button", { className: "toolbar-button", title: "Clear output", onclick: (e) => { out.replaceChildren(); } }, "⎚"));
    } else {
      ta.readOnly = true;
    }
  };

  const thingToString = (level) => (thing) => {
    const keyString = (str) =>
      /^\p{L}[\p{Nd}\p{L}]*$/u.test(str) ? str : JSON.stringify(str);

    if (level > 2) {
      return `${thing}`;
    }
    if (Array.isArray(thing)) {
      const list = thing.map(thingToString(level + 1));
      if (level === 0 && list.length > 3) {
        return `[\n  ${list.join(",\n  ")}\n]`;
      } else {
        return `[${list.join(", ")}]`;
      }
    }
    if (typeof thing === "object" && thing.toString === ({}).toString) {
      const list = Object.keys(thing).map(
        (key) => `${keyString(key)}: ${thingToString(level + 1)(thing[key])}`
      );
      if (level === 0 && list.length > 3) {
        return `{ \n  ${list.join(",\n  ")}\n}`;
      } else {
        return `{ ${list.join(", ")} }`;
      }
    }
    if (typeof thing === "string" && level > 0) {
      return JSON.stringify(thing);
    }
    return `${thing}`;
  };

  window.addEventListener("load", (e) => {
    const log = console.log;
    console.log = (...args) => {
      log.apply(console, args);
      if (currentOut !== null) {
        currentOut.append(
          elem("samp", {}, args.map(thingToString(0)).join(" ")),
          "\n"
        );
      }
    };

    for (const el of document.querySelectorAll(".js.prelude")) {
      create(el)
    };
    for (const el of document.querySelectorAll(".js:not(.prelude)")) {
      create(el)
    };
  });
  return outElement;
})();
