# TypeScript 规则

**适用**：`.ts` / `.tsx`，以及有 `tsconfig.json` 的工程里的 `.js`。框架层规则看 `vue.md` / `react.md`。

准入标准、重构口径、定级与存量政策见 `../SKILL.md`（各语言共用）。规则作用于本次改动新增或修改的行。

基准（本地 Vue3 工程的现役配置，落地时先看目标工程的 tsconfig）：`strict: true`、`noUnusedLocals` / `noUnusedParameters: true`、`target: ES2021`、`moduleResolution: bundler`；检查命令 `vue-tsc --noEmit` 或 `tsc --noEmit`。

## 类型逃逸

- **`any` 不用**。外部输入用 `unknown`，收窄后再用。新代码引入 `any` → `P2`。
- **双重断言 `as unknown as T` 不用**（存量工程里常见，属欠账）→ `P2`。它说明类型链已经断开，正确做法是补类型定义或写校验。
- `as T` 单层断言只在**你比编译器知道更多且能说明理由**时用，并在紧邻处写一行注释说明依据；能改成类型守卫就不断言。
- 非空断言 `!` 只用于确实不可为空的场景（例如紧邻已判空），否则改成判空收窄。
- 外部数据（HTTP 响应、本地存储、IPC、配置文件）**先校验再断言**：用工程的运行时校验（zod 之类）或手写类型守卫，不要靠 `as` 把 `unknown` 变成业务类型。
- 类型守卫写 `function isFoo(x: unknown): x is Foo`，让收窄在调用处生效。

## 类型表达

- **联合类型要穷尽**：`switch` 或 `if / else` 覆盖所有分支，末尾用 `never` 兜底，新增成员时编译期报错，而不是运行时静默走到 else。
- **枚举用 `as const` 对象 + `keyof typeof`**，不用 TS `enum`（数值 enum 有反查对象、tree-shaking 与字面量收窄的坑）。工程既有 `enum` 时跟随既有写法，不混用两套。
- **类型从来源推导**：`typeof`、`ReturnType`、`Parameters`、`satisfies`、`Awaited` 复用既有定义，不手抄一遍（手抄的定义一定会和来源漂移）。
- 对象契约用 `interface`，联合、映射、条件类型等工具类型用 `type`；同一仓库保持一致，不因个人偏好来回换。
- 属性可选（`a?: T`）与「可能是 undefined」（`a: T | undefined`）语义不同，别混用；`exactOptionalPropertyTypes` 未开时尤其要注意它们的差别不被编译器拦住。
- 泛型要有约束（`<T extends X>`）；无约束的万能泛型函数通常意味着类型已经失效。
- 导入类型用 `import type`，避免把类型导入带进运行时。

## 生成类型与协议

工程有从后端协议生成类型的脚本时（例如 `generate:*types` 配 `check:*types`）：

- 改了接口定义、协议文件或连接类型，**必须重新生成并跑一致性检查**，不手改生成产物。
- 生成产物不手写补丁；需要扩展时在生成层之外做包装类型。

## 与框架的边界

- 组件 props / emits、store 状态、路由参数的类型定义属于框架文件（`vue.md` / `react.md`），这里只管类型本身的质量。
- 模板或 JSX 里不要用断言绕过类型错误：类型报错先修类型，再改实现。

## 自查

```bash
CHANGED=$(git diff --name-only origin/test... -- '*.ts' '*.tsx' '*.vue')
npx tsc --noEmit 2>&1 | head -30      # 或无 tsc 时用工程的 vue-tsc / typecheck 脚本
rg -n -- ': *any\b|<any>|as unknown as| as [A-Z][A-Za-z]*(\[\])?[;,) ]|\w+!' $CHANGED
```

`as` 与 `!` 的命中逐个看：是否落在改动行、是否属于上面禁止的逃逸用法、是否有紧邻的判空或理由注释。
