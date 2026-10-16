# React 规则

**适用**：`package.json` 依赖 `react`、`*.jsx` / `*.tsx`。

注意：本机没有团队自有的 React 工程可作基准（本地仅有第三方开源项目，版本跨度从 React 16 到 19）。以下按现代 React（18+ 函数组件 + hooks）写，**落地时以目标工程的实况与既有 lint 配置为准**（若工程仍在 React 16/17，class 组件与旧 API 属既有风格，跟随工程而不是强行升级）。

类型质量看 `typescript.md`，纯 JS 基线看 `javascript.md`。准入标准与定级见 `../SKILL.md`。

## 组件与渲染

- 新组件用**函数组件 + hooks**；同一工程不要 class 组件与新写法混杂。
- **渲染必须纯粹**：渲染期间不发请求、不写外部状态、不改 DOM、不读可变全局。副作用进 `useEffect` 或事件处理。`P2`。
- **不用 effect 做派生**：能从 props / state 直接算出来的值就地算或用 `useMemo`，不要 `useEffect` 里 `setState`（多一轮渲染，且易出现中间态闪烁）。
- `setState` 用函数式更新（`setCount(c => c + 1)`）避免闭包读到过期值。
- state 最小化、单一数据源：能推导的不存；同一份数据不要在两处 state 里各存一份。`P2`。
- 受控与非受控不混用：给了 `value` 就必须给 `onChange`。

## hooks

- **`useEffect` 依赖数组要完整**，不要用禁用 lint 注释糊过去；依赖多了通常说明该拆 effect 或该改设计。`P2`。
- **每个 effect 都要有清理**：订阅、事件监听、定时器、进行中的请求（取消或标记忽略），否则出现内存泄漏与卸载后 setState。
- effect 只做「同步到外部系统」的事（订阅、DOM、日志上报）。纯粹的数据转换不该进 effect。
- 自定义 hook 以 `use` 开头，一个 hook 一个关注点；不在 hook 里隐藏全局副作用。
- `useMemo` / `useCallback` / `React.memo` **只用于真实性能问题**：列表项、昂贵计算、需要稳定引用才能正确工作的依赖（如传给 memo 化子组件的回调）。为「防重渲染」默认加一层属过度优化 → `P3`。
- 依赖引用稳定时用 `useRef` 存不需要触发渲染的值，不要用 state 当可变容器。

## 列表、key 与组件边界

- `key` 用稳定业务 id；**不用数组下标**（除完全静态、不重排的列表）。
- 大列表（几百条以上）虚拟滚动。
- Context 按用途拆分，把数据与 dispatch 分开，避免整棵子树重渲染；跨层共享优先用工程既有的 store 方案。
- 避免 props drilling 超过两层：用组合（`children` / slot 式 props）或 Context，而不是层层透传。
- 用错误边界兜住子树渲染异常；异步错误在数据层处理，不靠边界捕获。
- 昂贵的非紧急更新用 `useTransition` / `useDeferredValue`，不要靠 debounce 到处绕。

## 检查命令

按工程既有脚本（`eslint` 含 `react-hooks` 插件、`tsc --noEmit` / `vue-tsc` 之外的 `tsc`、工程 test runner）。没有 lint 配置的工程，先确认要不要引入，而不是自行新建一套规则。

## 自查

```bash
CHANGED=$(git diff --name-only origin/test... -- '*.tsx' '*.jsx')
rg -n -- 'useEffect\(.*\[\]|eslint-disable.*exhaustive-deps|key=\{(index|i)\}|useMemo|useCallback' $CHANGED
```

重点看：依赖数组为空的 effect 是否真的只跑一次且带清理；每条 `eslint-disable` 是否真的必要（要写理由）。
