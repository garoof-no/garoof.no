(() => {
  window.onload = () => {
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
      result.replaceChildren();
      const str = editor.value;
      Module.ccall("run_lua", "number", ["string"], [luarun(str)]);
      link = document.createElement("a");
      link.href = `${url}?code=${LZString144.compressToEncodedURIComponent(str)}`;
      link.innerText = "link";
      forlink.replaceChildren(link);
    };

    let ModuleConfig = {
      print: (function () {
        return (text) => {
          if (arguments.length > 1) {
            text = arguments.join(" ");
          }
          if (text != "emsc") {
            const p = document.createElement("p");
            p.innerText = text;
            result.append(p, document.createElement("br"));
          }
        };
      })(),
      printErr: function (text) {
        if (arguments.length > 1) {
          text = arguments.join(" ");
        }
        const p = document.createElement("p");
        p.className = "error";
        p.innerText = text;
        result.append(p, document.createElement("br"));
        console.error(text);
      },
      send: (code, payload) => {
        if (code === "return") {
          if (payload === "") {
            return;
          }
          const el = document.createElement("p");
          el.innerText = "return: " + payload;
          result.appendChild(el);
        } else if (code === "html") {
          const div = document.createElement("div");
          div.innerHTML = payload;
          result.append(div);
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
      require = function(name, path)
            local loaded = package.loaded[name]
            if loaded then return loaded end
            web.co = coroutine.running()
            send("require", path)
            local res = coroutine.yield()
            package.loaded[name] = res
           return res
        end,
      run = function(thunk)
          local co = coroutine.create(thunk)
          local status, res = coroutine.resume(co)
          assert(status, res)
          return res
      end,
      resume = function(thunk)
          local prev = web.co
          web.co = nil
          local co = coroutine.create(thunk)
          local status, res = coroutine.resume(co)
          assert(status, res)
          local prevStatus, prevRes = coroutine.resume(prev, res);
          assert(status, res)
          return prevRes
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
