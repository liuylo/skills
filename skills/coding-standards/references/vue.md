# Vue 规则

**适用**：`.vue`、Vite / Nuxt 配置。类型质量看 `typescript.md`，纯 JS 基线看 `javascript.md`。

准入标准、重构口径、定级与存量政策见 `../SKILL.md`（各语言共用）。规则作用于本次改动新增或修改的行。

基准：Vue 3 + `<script setup lang="ts">` + Pinia + VueUse；检查命令按工程既有脚本（`vue-tsc --noEmit` 做类型、`oxlint --vue-plugin` 或工程 eslint 做 lint、`oxfmt` / prettier 做格式）。

## 组件写法

- **一律 `<script setup lang="ts">`**，新组件不写 Options API、不写 `defineComponent` 包装（除需要显式控制 `name` 等少数场景）。
- **props 类型化**：`defineProps<Props>()`，默认值用 `withDefaults`；不用运行时对象式 props 声明（类型和实现会漂移）。
- **emits 类型化**：`defineEmits<{ change: [value: string] }>()`。
- **不直接改 prop**：需要本地可变时先 `ref(props.x)` 或 `toRef` 建立副本，并明确同步策略；直接赋值 prop 属 `P2`。
- 组合式函数以 `use` 开头的独立文件存放，不把可复用逻辑写死在单个组件里。

## 响应式选择

- **`ref` 优先**；需要整体替换的容器用 `ref`，只在固定结构的表单/对象聚合上用 `reactive`（`reactive` 解构会丢响应性，除非用 `toRefs`）。
- **大对象、第三方实例、只读外部数据用 `shallowRef`**，避免深层代理带来的开销与不可预期触发。
- **派生状态用 `computed`**，不在模板里现算、不用 `watch` 往另一个 ref 里写。
- `computed` 内**不写副作用**：不发请求、不改 store、不写 DOM。`P2`。
- `watch` 要明确 source（用 getter 或 `toRef`），只在有副作用（请求、存储、上报）时使用；`deep: true` 需要说明理由。
- **优先 `watch`，不用 `watchEffect`**：后者依赖收集隐式，改动时容易漏。仅当副作用完全依赖同一批响应式数据且无需控制触发时机时才用。
- 组件卸载要清理：`watch` / 事件监听 / 定时器 / 未完成的请求，用 `onScopeDispose` 或对应的 stop 句柄。

## 模板

- `v-for` **必须带 `key`**，用稳定业务 id，不用数组下标（列表会重排/插入时下标 key 会导致状态串位）。
- `v-if` 与 `v-for` 不同元素上，避免优先级歧义与无谓渲染。
- 模板里不堆复杂表达式：条件链、格式化、多步推导抽成 `computed`；纯展示映射可抽工具函数。
- 事件处理只做分发，业务逻辑落在 script 里的具名函数。

## 状态与数据流

- props 向下、emits 向上；跨层共享走 Pinia 或 `provide / inject`，不用事件总线。
- **Pinia store 按领域拆**，一个 store 一个职责；组件内不散落全局可变模块级状态。
- store 不直接依赖组件（不在 store 里读组件实例或 DOM）；异步动作放 store 的 action 里，错误处理与 loading 状态也随之定义。
- 异步结果写状态前确认组件仍存活（或直接落到 store），避免卸载后写已销毁组件的状态。

## 性能

- 大列表（几百条以上）用虚拟滚动，不硬渲染。
- 深层大对象不要 `deep: true` watch；按需 `shallowRef` + 手动触发。
- 组件拆分按可复用性与渲染边界拆，不为「文件小」把每个 `<div>` 抽成组件。
- 路由级懒加载（`() => import(...)`），首屏不打包非必要模块。

## 样式

- 组件样式 `<style scoped>`；全局样式集中管理，不在组件里写影响全局的选择器。
- 深度选择器（`:deep()`）只用于确实需要穿透第三方组件的场景，并就近注释原因。

## 自查

```bash
CHANGED=$(git diff --name-only origin/test... -- '*.vue')
rg -n -- 'v-for="[^"]*"[^>]*v-if|v-if="[^"]*"[^>]*v-for|<script(?! setup)|watchEffect|deep: *true|:key="(index|i)\b|\w+ *= *props\.' $CHANGED
```
