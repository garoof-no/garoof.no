(() => {
  window.onload = () => {
    
    const elem = (tagName, props, ...children) => {
      const el = Object.assign(document.createElement(tagName), props);
      el.replaceChildren(...children);
      return el;
    };
  
    const editor = document.getElementById("editor");
    const result = document.getElementById("result");
    const autorun = document.getElementById("autorun");
    const forlink = document.getElementById("forlink");
    const url = window.location.href.split('?')[0];
    let link = null;

    let Module;
    let timer;

    const luarun = str => `return web.run(function() ${str} end)`;
    const luaresume = str => `return web.resume(function() ${str} end)`;
    const luastr = str => `[[${str.replace("]]", "__")}]]`;
    let modified = true;

    const runLua = () => {
      result.replaceChildren(elem("pre", { className: "output" }));
      const str = editor.value;
      Module.ccall("run_lua", "number", ["string"], [luarun(str)]);
      link = elem("a", { href: `${url}?code=${LZString144.compressToEncodedURIComponent(str)}` }, "link");
      forlink.replaceChildren(link);
    };
    
    const printelem = () => elem("pre", { className: "output" });
    
    const print = (str) => {
      result.lastElementChild.append(elem("samp", {}, str), "\n");
    };

    const html = (el) => {
      const last = result.lastElementChild;
      if (last.childNodes.length === 0) {
        last.remove();
      }
      result.append(el, elem("pre", { className: "output" }));
    };

    const ModuleConfig = {
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
        print(text);
      },
      send: (code, payload) => {
        if (code === "return") {
          if (payload !== "") {
            print("return: " + payload);
          }
        } else if (code === "html") {
          const div = elem("div");
          div.innerHTML = payload;
          html(div)
        } else if (code === "title") {
          document.title = payload;
        } else if (code === "log") {
          console.log(payload);
        } else if (code === "require") {
          const xmlHttp = new XMLHttpRequest();
          xmlHttp.onreadystatechange = () => {
            if (xmlHttp.readyState === 4) {
              let code;
              if (xmlHttp.status === 200) {
                code = xmlHttp.responseText;
              } else {
                const err = `${xmlHttp.status}: ${xmlHttp.statusText} (${payload})`;
                code = `error(${luastr(err)})`;
              }
              Module.ccall("run_lua", "number", ["string"], [luaresume(code)]);
            }
          };
          xmlHttp.open("GET", payload, true);
          xmlHttp.send(null);
        } else {
          console.error(`unkown code sent from Lua. code: "%o". payload: %o`, code, payload);
        }
      }
    };

    const encoded = new URLSearchParams(location.search).get("code");
    if (encoded !== null) {
      const decoded = LZString144.decompressFromEncodedURIComponent(encoded);
      if (decoded !== null) {
        editor.value = decoded;
      }
    }

    const prelude = `
    local send = webSend
    webSend = nil
    web = {
      send = send,
      require = function(name, path)
        local loaded = package.loaded[name]
        if loaded then return loaded end
        web.co = coroutine.running()
        send("require", path)
        local thunk = coroutine.yield()
        local res = thunk()
        package.loaded[name] = res
        return res
      end,
      run = function(thunk)
        coroutine.wrap(
          function()
            local _, res = pcall(thunk)
            send("return", tostring(res))
          end
        )()
      end,
      resume = function(thunk)
        local prev = web.co
        web.co = nil
        coroutine.resume(prev, thunk);
      end
    }
    local Web = {}
    setmetatable(web, Web)
    function Web:__index(code)
      return function(payload) send(code, payload) end
    end
    `;

    initWasmModule(ModuleConfig).then((aModule) => {
      Module = aModule;
      Module.ccall("run_lua", "number", ["string"], [prelude]);
      runLua();
      editor.oninput = () => {
        if (link !== null) {
          link.remove();
          link = null;
        }
        modified = true;
        clearTimeout(timer);
        if (autorun.checked) {
          timer = setTimeout(runLua, 500);
        }
      };
      autorun.onchange = () => {
        if (!autorun.checked) {
          clearTimeout(timer);
        } else if (modified) {
          runLua();
        }
      };
      run.onclick = runLua;
    });
  }
})();
