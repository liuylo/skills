# Java 规则

目标 Java 8。以下规则应用于本次改动新增或修改的行；存量边界与定级口径见 `../SKILL.md`。

## 设计模式

- 按**变化维度**选模式，不按「看起来像」选。先答「什么会变」，再答「哪个模式吸收这个变化」。
- 需要两个以上真实实现或分支才做抽象；只有一个实现、且同一迭代内没有确认的第二个，不做抽象层。
- 复用工程既有的抽象、工厂、注册表，别为同一类变化再造一套并行机制。
- **定级**：
  - 接口/抽象类只有一个实现且无确认的第二实现 → `P3`
  - 靠反复修改稳定核心类来加业务分支 → `P2`
  - 绕过工程既有抽象、另造重复机制 → `P2`

## 并发

- 线程池一律用工程既有命名池（如 `ThreadPoolUtil` 及其等价物）；**生产代码禁止 `Executors.new*`**，测试代码除外。`P2`
- `CompletableFuture` 必须显式传 executor，不依赖 `ForkJoinPool.commonPool`；失败用 `exceptionally` / `handle` / `whenComplete` 处理；不留「发出去就不管」且无失败日志的异步任务。`P2`
- **事务方法内禁止起异步或并行**：事务、`ThreadLocal`、MDC、租户/安全上下文都不会传播到工作线程。`P2`
- 并发路径用线程安全类型（`ConcurrentHashMap`、`Atomic*`、按线程持有的 formatter）；跨线程共享 `HashMap`、`ArrayList`、`SimpleDateFormat`、非原子计数器 → `P2`
- 跨线程可达的共享可变状态，要么有明确同步，要么不可变，并把决定写下来。`P2`

## Java 8 语法

用仓库已经在用的写法，不要手写标准惯用法能表达的逻辑。

- 集合转换、过滤、分组、拼接、聚合用 Stream。
- 以下场景**保留 `for` 更清楚**，不要为风格硬转 Stream：顺序副作用、按业务条件提前退出、循环内处理受检异常、依赖下标、循环体写出来会变成多语句 lambda。
- Stream 管道内不做副作用：写库、发 MQ、调远程、改共享可变状态。`P2`
- `Collectors.toMap` 未给 merge 函数、而源数据可能重复键 → 抛 `IllegalStateException`。`P2`
- **`parallelStream` 禁止**用于：IO / 远程调用 / 数据库访问、事务内、集合小或规模不可控。它跑在共享的 `ForkJoinPool.commonPool`，事务上下文、`ThreadLocal`、MDC 都不会传到工作线程。需要真并行时用工程命名池 + `CompletableFuture`。`P2`
- `Optional` 只做返回值。不做字段类型、方法参数、集合元素、序列化 DTO 字段。不做未判存在的 `get()`——用 `orElse` / `orElseGet` / `orElseThrow` / `ifPresent` / `map`。`P2`
- lambda 保持短小单一职责；需要多语句或嵌套控制流的 lambda 体抽成具名方法。`P3`
- 能用方法引用代替等价 lambda 就用。`P3`
- map 的「取值判空再放回」改用 `getOrDefault` / `computeIfAbsent` / `putIfAbsent` / `merge`。`P3`

## 自查

```bash
git diff origin/test... -- '*.java' | grep -n "parallelStream\|Executors\.new\|Optional\.get()\|SimpleDateFormat\|new HashMap\|\.stream()"
```

命中后逐个判定：是否落在改动行上、是否命中上面某条规则。设计阶段没写三项决策的，先补结论再继续。
