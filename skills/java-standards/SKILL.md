---
name: java-standards
description: >
  Java 后端编码口径：设计模式选择、并发与线程池、Java 8 语法（lambda/Stream/Optional）。
  技术设计与编码前加载；写 Java 代码、做技术设计、或 review Java 改动时使用。
  Use when asked to 实现 Java 代码、写技术设计、review Java 改动、检查设计模式/并发/Java 8 用法。
---

# Java Standards

Java 后端的三条硬口径：**设计模式选择**、**并发处理**、**Java 8 语法**。设计阶段与编码阶段都要按这里判定，review 也用同一份口径定级。

不替代工程既有约定。仓库已有 spec / `duyan-backend-standards` 优先，本技能只补它们没写清的部分；冲突时以工程 spec 为准并说明。

## 设计强制点

**技术设计与编码前，先明确三件事，写进设计文档或产出说明里。三项都要有结论，"没有"也要显式写出来。**

1. **设计模式**：本需求的变化维度是什么（哪个点会随业务分支增多而变化），用哪个模式吸收（策略 / 模板方法 / 工厂 / 责任链 / 建造者 / 状态），**否掉了哪些替代方案及原因**，复用了工程里哪个既有抽象而不是新造一套。
   - 没有第二个实现或第二个业务分支时，不引入抽象层，显式写「无需新模式」。
   - 禁止为加业务分支反复改稳定的核心抽象，改为扩展。
2. **并发模型**：谁在跑这段逻辑（请求线程 / 哪个线程池），哪些部分并行或异步，是否落在事务内，失败与超时怎么处理，上下文（事务、`ThreadLocal`、MDC、租户）怎么传到工作线程。
   - 无线程、无异步就写「无并发」。
3. **Java 8 用法**：Stream / `Optional` / 方法引用用在哪，哪里的显式 `for` 是刻意保留的（提前退出、顺序副作用、循环内受检异常等），为什么。

三项缺任一项，视为设计未完成，先把结论补出来再动代码。

## 规则一：设计模式

- 按**变化维度**选模式，不按「看起来像」选。先答「什么会变」，再答「哪个模式吸收这个变化」。
- 需要两个以上真实实现或分支才做抽象；只有一个实现、且同一迭代内没有确认的第二个，不做抽象层。
- 复用工程既有的抽象、工厂、注册表，别为同一类变化再造一套并行机制。
- **定级**：
  - 接口/抽象类只有一个实现且无确认的第二实现 → `P3`
  - 靠反复修改稳定核心类来加业务分支 → `P2`
  - 绕过工程既有抽象、另造重复机制 → `P2`

## 规则二：并发

- 线程池一律用工程既有命名池（`duyan-common` 的 `ThreadPoolUtil` 及其等价物）；**生产代码禁止 `Executors.new*`**，测试代码除外。`P2`
- `CompletableFuture` 必须显式传 executor，不依赖 `ForkJoinPool.commonPool`；失败用 `exceptionally` / `handle` / `whenComplete` 处理；不留「发出去就不管」且无失败日志的异步任务。`P2`
- **事务方法内禁止起异步或并行**：事务、`ThreadLocal`、MDC、租户/安全上下文都不会传播到工作线程。`P2`
- 并发路径用线程安全类型（`ConcurrentHashMap`、`Atomic*`、按线程持有的 formatter）；跨线程共享 `HashMap`、`ArrayList`、`SimpleDateFormat`、非原子计数器 → `P2`
- 跨线程可达的共享可变状态，要么有明确同步，要么不可变，并把决定写下来。`P2`

## 规则三：Java 8 语法

工程目标是 Java 8，用仓库已经在用的写法，不要手写标准惯用法能表达的逻辑。

- 集合转换、过滤、分组、拼接、聚合用 Stream。
- 以下场景**保留 `for` 更清楚**，不要为风格硬转 Stream：顺序副作用、按业务条件提前退出、循环内处理受检异常、依赖下标、循环体写出来会变成多语句 lambda。
- Stream 管道内不做副作用：写库、发 MQ、调远程、改共享可变状态。`P2`
- `Collectors.toMap` 未给 merge 函数、而源数据可能重复键 → 抛 `IllegalStateException`。`P2`
- **`parallelStream` 禁止**用于：IO / 远程调用 / 数据库访问、事务内、集合小或规模不可控。它跑在共享的 `ForkJoinPool.commonPool`，事务上下文、`ThreadLocal`、MDC 都不会传到工作线程。需要真并行时用工程命名池 + `CompletableFuture`。`P2`
- `Optional` 只做返回值。不做字段类型、方法参数、集合元素、序列化 DTO 字段。不做未判存在的 `get()`——用 `orElse` / `orElseGet` / `orElseThrow` / `ifPresent` / `map`。`P2`
- lambda 保持短小单一职责；需要多语句或嵌套控制流的 lambda 体抽成具名方法。`P3`
- 能用方法引用代替等价 lambda 就用。`P3`
- map 的「取值判空再放回」改用 `getOrDefault` / `computeIfAbsent` / `putIfAbsent` / `merge`。`P3`

## 新代码强制，存量记账不阻断

- 以上规则的作用面是**本次改动新增或修改的行**。这是可执行、可判定的边界。
- 改动没碰到的既有代码属存量欠账：**不得报 `P0`/`P1`/`P2`，也不要求本 MR 修**；最多记一条 `P3`，前缀 `存量`，让欠账可见但不阻断合并。
- 例外是「顺着存量继续错」：往不安全的 `parallelStream` 里加新调用方、新增 executor、新增未判存在的 `Optional.get()`、在事务内新增异步——这些落在改动行上，按正常严重度报。

## 自查清单

动手前或提 MR 前，按改动范围过一遍（`grep` 可查）：

```bash
git diff origin/test... -- '*.java' | grep -n "parallelStream\|Executors\.new\|Optional\.get()\|SimpleDateFormat\|\.stream()" 
```

命中后逐个判定：是否落在改动行上、是否命中上面某条规则。设计阶段没写三项决策的，先补结论再继续。
