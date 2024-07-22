"use strict";

(() => {
  const match = (tag, value, args, cases) => {
    if (cases.hasOwnProperty(tag)) {
      return cases[tag](...args);
    } else if (cases.hasOwnProperty("default")) {
      return cases["default"](value);
    } else {
      throw {
        message: "match failed",
        tag: tag,
        value: value,
        cases: cases,
      };
    }
  };
  const matchf = (cases) => (x) => x.match(cases);

  const [Just, Nope] = (() => {
    class Just {
      constructor(value) {
        this.value = value;
      }
      match(cases) {
        return match("Just", this, [this.value], cases);
      }
      isEmpty() {
        return false;
      }
      map(f) {
        return new Just(f(this.value));
      }
      flatMap(f) {
        return f(this.value);
      }
      forEach(f) {
        f(this.value);
      }
      or(other) {
        return this.value;
      }
      either(f, g) {
        return f(this.value);
      }
    }

    class Nope {
      constructor() { }
      match(cases) {
        return match("Nope", this, [], cases);
      }
      isEmpty() {
        return true;
      }
      map(f) {
        return this;
      }
      flatMap(f) {
        return this;
      }
      forEach(f) { }
      or(other) {
        return other();
      }
      either(f, g) {
        return g();
      }
    }
    return [(x) => new Just(x), new Nope()];
  })();

  class Var {
    constructor(name) {
      this.name = name;
    }
    match(cases) {
      return match("Var", this, [this.name], cases);
    }
  }

  class Lam {
    constructor(parameter, body) {
      this.parameter = parameter;
      this.body = body;
    }
    match(cases) {
      return match("Lam", this, [this.parameter, this.body], cases);
    }
  }
  class App {
    constructor(fun, arg) {
      this.function = fun;
      this.argument = arg;
    }
    match(cases) {
      return match("App", this, [this.function, this.argument], cases);
    }
  }

  class Found {
    constructor(path, value) {
      this.path = path;
      this.value = value;
    }
  }

  const assemble = (path, replacement) =>
    path.match({
      LamStep: (p, rest) => assemble(rest, new Lam(p, replacement)),
      AppFunStep: (a, rest) => assemble(rest, new App(replacement, a)),
      AppArgStep: (f, rest) => assemble(rest, new App(f, replacement)),
      Stop: () => replacement,
    });

  class LamStep {
    constructor(parameter, rest) {
      this.parameter = parameter;
      this.rest = rest;
    }
    match(cases) {
      return match("LamStep", this, [this.parameter, this.rest], cases);
    }
  }

  class AppFunStep {
    constructor(argument, rest) {
      this.argument = argument;
      this.rest = rest;
    }
    match(cases) {
      return match("AppFunStep", this, [this.argument, this.rest], cases);
    }
  }

  class AppArgStep {
    constructor(fun, rest) {
      this.function = fun;
      this.rest = rest;
    }
    match(cases) {
      return match("AppArgStep", this, [this.function, this.rest], cases);
    }
  }

  const Stop = (() => {
    class Stop {
      match(cases) {
        return match("Stop", this, [], cases);
      }
    }
    return new Stop();
  })();

  const findExp = (pred, exp) => {
    const halp = (exp, path) =>
      pred(exp).either(
        (x) => Just(new Found(path, x)),
        () =>
          exp.match({
            Var: () => Nope,
            Lam: (p, b) => halp(b, new LamStep(p, path)),
            App: (f, a) =>
              halp(f, new AppFunStep(a, path)).either(
                (x) => Just(x),
                () => halp(a, new AppArgStep(f, path))
              ),
          })
      );
    return halp(exp, Stop);
  };

  class Conflict {
    constructor(parameter, body) {
      this.parameter = parameter;
      this.body = body;
    }
  }

  class Redex {
    constructor(argument, parameter, body) {
      this.argument = argument;
      this.parameter = parameter;
      this.body = body;
    }

    findConflict() {
      const freeIds = (exp) => {
        const halp = (used, x) => {
          const res = x.match({
            Var: (s) => (used.has(s) ? new Set() : new Set([s])),
            Lam: (p, b) => halp(new Set([p, ...used]), b),
            App: (f, a) => new Set([...halp(used, f), ...halp(used, a)]),
          });

          return res;
        };
        return halp(new Set(), exp);
      };

      const conflict = (param, bad, exp) =>
        exp.match({
          Lam: (p, b) =>
            p !== param && bad.has(p) && freeIds(b).has(param)
              ? Just(new Conflict(p, b))
              : Nope,
          default: (u) => Nope,
        });

      const freeInArg = freeIds(this.argument);
      const find = (path, exp) => {
        const next = matchf({
          Var: (v) => Nope,
          Lam: (p, b) =>
            p === b ? Nope : find(new LamStep(p, path), b),
          App: (a, f) =>
            find(new AppFunStep(a, path), f).or(() =>
              find(new AppArgStep(f, path), a)
            ),
        });

        return conflict(this.parameter, freeInArg, exp).either(
          (c) => Just(new Found(path, c)),
          () => next(exp)
        );
      };
      return find(Stop, this.body);
    }

    subst() {
      const halp = matchf({
        Var: (v) => (this.parameter === v ? this.argument : new Var(v)),
        Lam: (p, b) =>
          this.parameter === p ? new Lam(p, b) : new Lam(p, halp(b)),
        App: (f, a) => new App(halp(f), halp(a)),
      });
      return halp(this.body);
    }
  }

  const redex = matchf({
    App: (f, a) =>
      f.match({
        Lam: (p, b) => Just(new Redex(a, p, b)),
        default: (u) => Nope,
      }),
    default: (u) => Nope,
  });

  const step = (() => {
    class Reduce {
      constructor(from, to) {
        this.from = from;
        this.to = to;
      }
      match(cases) {
        return match("Reduce", this, [this.from, this.to], cases);
      }
    }

    class Rename {
      constructor(fromVar, from, toVar, to) {
        this.fromVar = fromVar;
        this.from = from;
        this.toVar = toVar;
        this.to = to;
      }
      match(cases) {
        return match(
          "Rename",
          this,
          [this.fromVar, this.from, this.toVar, this.to],
          cases
        );
      }
    }

    class Normal {
      constructor(exp) {
        this.exp = exp;
      }
      match(cases) {
        return match("Normal", this, [this.exp], cases);
      }
    }

    const allIds = matchf({
      Var: (s) => new Set([s]),
      Lam: (p, b) => new Set([p, ...allIds(b)]),
      App: (f, a) => new Set([...allIds(f), ...allIds(a)]),
    });

    const uniqueId = (s, used) => {
      const idNum = /^([a-zA-Z0-9]*?)([0-9]+)$/.exec(s);
      var id;
      var num;
      if (idNum) {
        id = idNum[1];
        num = parseInt(idNum[2]);
      } else {
        id = s;
        num = 1;
      }

      while (true) {
        num = num + 1;
        const res = id + num;
        if (!used.has(res)) {
          return res;
        }
      }
    };

    const renameStuff = (foundRedex, foundConflict, from) => {
      const newParam = uniqueId(foundConflict.value.parameter, allIds(from));
      const renamed = new Lam(
        newParam,
        new Redex(
          new Var(newParam),
          foundConflict.value.parameter,
          foundConflict.value.body
        ).subst()
      );
      return new Rename(
        foundConflict.value.parameter,
        from,
        newParam,
        assemble(
          foundRedex.path,
          new App(
            new Lam(
              foundRedex.value.parameter,
              assemble(foundConflict.path, renamed)
            ),
            foundRedex.value.argument
          )
        )
      );
    };

    return (exp) => {
      const x = findExp(redex, exp);
      return x.either(
        (foundRedex) => {
          return foundRedex.value.findConflict().either(
            (foundConflict) => renameStuff(foundRedex, foundConflict, exp),
            () =>
              new Reduce(
                exp,
                assemble(foundRedex.path, foundRedex.value.subst())
              )
          );
        },
        () => new Normal(exp)
      );
    };
  })();

  const parse = (() => {
    class ParseError {
      constructor(message, index) {
        this.message = message;
        this.index = index;
      }
      match(cases) {
        return match("ParseError", this, [this.message, this.index], cases);
      }
      isError() {
        return true;
      }
      flatMap(f) {
        return this;
      }
      either(f, g) {
        return g();
      }
    }
    class ParseResult {
      constructor(value, index) {
        this.value = value;
        this.index = index;
      }
      isError() {
        return false;
      }
      flatMap(f) {
        return f(this.value, this.index);
      }
      either(f, g) {
        return f(this.value, this.index);
      }
    }

    class Define {
      constructor(name, expression) {
        this.name = name;
        this.expression = expression;
      }
      match(cases) {
        return match("Define", this, [this.name, this.expression], cases);
      }
    }

    class Undefine {
      constructor(name) {
        this.name = name;
      }
      match(cases) {
        return match("Undefine", this, [this.name], cases);
      }
    }
    class Expression {
      constructor(expression) {
        this.expression = expression;
      }
      match(cases) {
        return match("Expression", this, [this.expression], cases);
      }
    }
    class Empty {
      match(cases) {
        return match("Empty", this, [], cases);
      }
    }

    const isLambda = (code) => code === 92 || code === 955;
    const isWhite = (code) =>
      code === 32 || code === 9 || code === 10 || code === 13;
    const isDot = (code) => code === 46;

    const isDef = (code) => code === 8796;
    const isColon = (code) => code === 58;
    const isEquals = (code) => code === 61;

    const isId = (code) =>
      !(
        isLambda(code) ||
        isWhite(code) ||
        isDot(code) ||
        isOpen(code) ||
        isClose(code) ||
        isDef(code) ||
        isColon(code) ||
        isEquals(code)
      );

    const isOpen = (code) => code === 40;
    const isClose = (code) => code === 41;

    const isBar = (code) => code === 124;

    const strCode = (s, i) => s.charCodeAt(i);
    const strAtEnd = (s, i) => i >= s.length || isBar(strCode(s, i));

    const skipChars = (pred) => (s, i) => {
      var idx;
      for (idx = i; idx < s.length; idx++) {
        if (!pred(s.charCodeAt(idx))) {
          break;
        }
      }
      return idx;
    };

    const skipWhites = skipChars(isWhite);

    const parseIdentifier = (s, startI) => {
      const stopI = skipChars(isId)(s, startI);
      return stopI === startI
        ? new ParseError("expected identifier", stopI)
        : new ParseResult(s.substr(startI, stopI - startI), stopI);
    };

    const parseLambda = (s, lamI) => {
      if (!isLambda(strCode(s, lamI))) {
        return new ParseError("expected lambda", lamI);
      }

      const paramStartI = skipWhites(s, lamI + 1);
      return parseIdentifier(s, paramStartI).flatMap((param, paramStopI) => {
        const dotI = skipWhites(s, paramStopI);

        if (!isDot(strCode(s, dotI))) {
          return new ParseError("expected dot", dotI);
        }

        return parseApps(s, dotI + 1).flatMap(
          (body, nextI) => new ParseResult(new Lam(param, body), nextI)
        );
      });
    };

    const parseOne = (s, startI) => {
      const code = strCode(s, startI);
      if (isId(code)) {
        return parseIdentifier(s, startI).flatMap(
          (v, i) => new ParseResult(new Var(v), i)
        );
      }
      if (isLambda(code)) {
        return parseLambda(s, startI);
      }
      if (isOpen(code)) {
        return parseApps(s, startI + 1).flatMap((exp, closeI) => {
          if (!isClose(strCode(s, closeI))) {
            return new ParseError("expected close paren", closeI);
          }
          return new ParseResult(exp, closeI + 1);
        });
      }
    };

    const parseApps = (s, beforeI) => {
      const exps = [];
      var currentI = beforeI;
      while (true) {
        currentI = skipWhites(s, currentI);
        if (strAtEnd(s, currentI)) {
          break;
        }
        const code = strCode(s, currentI);
        if (!(isId(code) || isLambda(code) || isOpen(code))) {
          break;
        }
        const res = parseOne(s, currentI);
        if (res.isError()) {
          return res;
        }
        exps.push(res.value);
        currentI = res.index;
      }

      if (exps.length === 0) {
        return new ParseError("expected _something_", currentI);
      }
      return new ParseResult(makeApps(exps), currentI);
    };

    const makeApps = (exps) => {
      var res = exps[0];
      for (var i = 1; i < exps.length; i++) {
        res = new App(res, exps[i]);
      }
      return res;
    };

    const parseExpression = (s, startI) => {
      const res = parseApps(s, startI);
      if (res.isError()) {
        return res;
      }
      if (!strAtEnd(s, res.index)) {
        return new ParseError("expected _not that_", res.index);
      }
      return res;
    };

    const parseDef = (name, s, i) =>
      isDef(strCode(s, i))
        ? new ParseResult(name, i + 1)
        : isColon(strCode(s, i)) && isEquals(strCode(s, i + 1))
          ? new ParseResult(name, i + 2)
          : new ParseError("expected ≜ or :=", i);

    const parse = (s) => {
      const startI = skipWhites(s, 0);
      if (strAtEnd(s, startI)) {
        return new Empty();
      }
      const defRes = parseIdentifier(s, startI).flatMap((name, afterIdI) =>
        parseDef(name, s, skipWhites(s, afterIdI))
      );

      return defRes.either(
        (name, afterDefId) =>
          strAtEnd(s, skipWhites(s, afterDefId))
            ? new Undefine(name)
            : parseExpression(s, afterDefId).flatMap(
              (exp, u) => new Define(name, exp)
            ),
        () => parseExpression(s, 0).flatMap((exp, ui) => new Expression(exp))
      );
    };

    return parse;
  })();

  const unparse = (() => {
    const pstring = (s) => `(${s})`;

    const argstring = matchf({
      Var: (n) => `${n}`,
      BadVar: (n) => `?${n}`,
      Missing: () => "_",
      default: (x) => pstring(unparse(x)),
    });

    const fstring = (x) =>
      x.match({
        Lam: (p, b) => pstring(unparse(x)),
        default: (u) => unparse(x),
      });

    const unparse = matchf({
      BadVar: (n) => `?${n}`,
      Missing: () => "_",
      Bad: (x) => `${x}`,
      Var: (x) => `${x}`,
      Lam: (p, b) => `λ${p}.${unparse(b)}`,
      App: (f, a) => `${fstring(f)} ${argstring(a)}`,
    });

    return unparse;
  })();

  class Repl {
    #defs = [];
    #nextExp = Nope;
    execute(str) {
      this.#nextExp = Nope;

      const res = parse(str);
      return res.match({
        Expression: (x) => this.#eval(x),
        Define: (name, exp) => {
          const resstr = `\n${name} is defined :)`;
          for (let i = 0; i < this.#defs.length; i++) {
            if (name === this.#defs[i].name) {
              this.#defs[i] = res;
              return resstr;
            }
          }
          this.#defs.push(res);
          return resstr;
        },

        Undefine: (name) => {
          this.#defs = this.#defs.filter(x => x.name !== name);
          return `\n${name} is undefined :|`;
        },
        ParseError: (msg, i) =>
          `\n${new Array(i + 1).join(" ")}^\noh no: ${msg}`,
        Empty: () => "",
      });
    }
    #eval(exp) {
      return step(exp).match({
        Normal: (exp) => {
          this.#nextExp = Nope;
          return `\n${unparse(exp)}`;
        },
        Reduce: (a, b) => {
          this.#nextExp = Just(b);
          return `\n${unparse(b)}`;
        },
        Rename: (oldV, oldExp, v, exp) => {
          this.#nextExp = Just(exp);
          return ` | [${v}/${oldV}]\n${unparse(exp)}`;
        },
      });
    }
    next() {
      const res = this.#nextExp.map((x) => this.#eval(x));
      return this.#nextExp.flatMap(x => res);
    }

    replaceDefs(str) {
      return parse(str).match({
        Expression: (x) => {
          let res = x;
          for (let i = this.#defs.length - 1; i >= 0; i--) {
            const d = this.#defs[i];
            res = new Redex(d.expression, d.name, res).subst();
          }
          return `\n${unparse(res)}`;
        },
        ParseError: (msg, i) =>
          `\n ${new Array(i).join(" ")}^\noh no: ${msg}`,
        Empty: () => "",
        default: (u) => "\nplox replacestuff on normal expressions only?",
      });
    }
  }

  window.onload = () => {
    const repl = new Repl();
    const readline = (editor) => {
      const str = editor.value;
      let start = str.lastIndexOf("\n", editor.selectionStart - 1) + 1;
      if (start < 0) { start = 0; }
      let end = str.indexOf("\n", editor.selectionStart);
      if (end < 0) { end = str.length; }
      const line = str.substring(start, end);
      editor.setSelectionRange(end, end);
      return line;
    };

    const resizeta = ta => {
      ta.setAttribute("style", "height: 0;");
      const height = ta.scrollHeight;
      ta.setAttribute("style", `height: ${height}px;`);
      const extra = ta.offsetHeight - ta.clientHeight;
      ta.setAttribute("style", `height: ${height + extra}px;`);
    };

    const print = (editor, str) => {
      const start = editor.selectionStart;
      const end = editor.selectionEnd;
      editor.setRangeText(str, start, end, "end");
      resizeta(editor);
    }

    const onkey = e => {
      const editor = e.target;
      if ((e.ctrlKey || e.metaKey || e.shiftKey) && e.key === "Enter") {
        e.preventDefault();
        print(editor, repl.execute(readline(editor)));
        if (e.shiftKey) {
          for (let i = 0; i < 1000; i++) {
            const res = repl.next();
            if (res.isEmpty()) {
              return;
            }
            print(editor, res.value);
          }
        }
      } else if ((e.ctrlKey || e.metaKey) && (e.key === "\\") || e.key.toLowerCase() === "l") {
        e.preventDefault();
        print(editor, "λ");
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "d") {
        e.preventDefault();
        print(editor, "≜");
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "r") {
        e.preventDefault();
        print(editor, repl.replaceDefs(readline(editor)));
      }
    };

    const create = elem => {
      const ta = document.createElement("textarea");
      ta.className = elem.className;
      if (elem.classList.contains("prelude")) {
        let str = "";
        for (const line of elem.innerText.split(/\r?\n/)) {
          if (str !== "") {
            str = str + "\n";
          }
          if (line.trim().length > 0) {
            str += line + repl.execute(line);
          }
          ta.value = str;
          ta.readOnly = true;
        }
      } else {
        ta.value = elem.innerText;
        ta.onkeydown = onkey;
        ta.oninput = () => resizeta(ta);
      }
      elem.parentElement.replaceChild(ta, elem);
      resizeta(ta);
    }

    for (const element of document.querySelectorAll(".lambs")) {
      create(element);
    }
  };
})();
