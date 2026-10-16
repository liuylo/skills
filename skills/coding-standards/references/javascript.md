# JavaScript 规则

**适用**：`.js` / `.mjs` / `.cjs`。工程里存在 `tsconfig.json` 时，`.js` 也按 `typescript.md` 的类型要求走（新文件优先写 TS）。框架层规则看 `vue.md` / `react.md`。

准入标准、重构口径、定级与存量政策见 `../SKILL.md`（各语言共用）。规则作用于本次改动新增或修改的行。

## 语言基线

- **`const` 优先**，需要重新赋值才用 `let`；新代码不用 `var`。
- **`===` / `!==`**，不用 `==`（除 `x == null` 这一种同时判 `null` 与 `undefined` 的惯用法）。
- **可选链与空值合并**（`?.`、`??`）替代层层判空；注意 `??` 与 `||` 语义差异——`0`、`''`、`false` 是有效值时必须用 `??`。
- **不就地修改入参**：函数不修改传进来的对象或数组，用展开或返回新值。
- **字符串与数组处理用现成方法**（`includes`、`startsWith`、`at`、`flatMap`），不手写下标循环。

## 数据处理

- 转换、过滤、分组、聚合用 `map` / `filter` / `reduce` / `Object.groupBy` 之类的声明式写法；链条超过三步或回调超过几行，抽成具名函数。
- `sort` 是就地修改，对入参排序前先复制（`[...arr].sort(...)` 或 `toSorted`）。
- 集合按 id 索引时用 `Map`，不要用对象或数组里反复 `find`（O(n²)）。
- 浅拷贝、深拷贝要分清：深拷贝优先 `structuredClone`；`JSON.parse(JSON.stringify(x))` 会丢 `Date`、`undefined`、`Map`、`Set`，只在纯 JSON 数据上用。

## 异步

- **`async / await` 优先于 promise 链**；`.then` 里抛错容易被吞。
- **每个 await 都要有失败路径**：`try / catch` 或由调用方明确接管。空 `catch {}` 属 `P2`——错误静默是线上最难查的一类问题。
- 互不依赖的异步用 `Promise.all` 并发，不要串行 `await`（除非确实要求顺序）；需要「部分失败也要结果」用 `Promise.allSettled`。
- 抛错要抛 `Error` 实例并带上下文（`new Error('拉取用户失败', { cause: e })`），不要抛字符串。
- 循环里 `await` 会串行：确认是刻意顺序执行，否则改成并发。

## 数值与时间

- **金额不用浮点**：用整数（分为单位）或 decimal 库。`0.1 + 0.2 !== 0.3` 在金额场景是缺陷，不是趣味题。
- 时间统一用 ISO 字符串或工程既有日期库传递，避免 `new Date('2026/01/02')` 这类依赖实现的解析；比较用时间戳。
- 时区显式：跨时区数据不要在展示层随手 `toLocaleString` 拼字符串。

## 日志与调试

- `console.log` 只用于本地调试，提交前删除；生产诊断走工程日志器（如已有）。`P3`，若在热路径或输出敏感信息则 `P2`。
- 不打日志输出凭据、token、用户隐私字段。

## 模块与命名

- 用 ESM `import` / `export`；同一工程不要混 `require`。
- 避免循环依赖：模块间依赖单向，共享常量与类型下沉到独立模块。
- 命名跟随工程既有风格；文件与导出保持可检索（组件 PascalCase，工具函数文件与主导出同名）。

## 自查

```bash
CHANGED=$(git diff --name-only origin/test... -- '*.js' '*.mjs' '*.cts' '*.cjs' '*.ts' '*.tsx' '*.vue')
rg -n -- '\bvar \b|==[^=]|catch *\{\s*\}|console\.(log|debug)|parseInt\(|new Date\(["'\'']' $CHANGED
```

`parseInt` 命中要确认是否给了基数或用 `Number()`；`new Date('…')` 命中要确认不是依赖实现的字符串解析。
