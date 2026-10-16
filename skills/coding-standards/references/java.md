# Java 规则

目标 Java 8。准入标准、触发条件、矩阵与定级口径在 `../SKILL.md` 的「通用：设计模式准入」一节，各语言共用；本文件只写 Java 的落地手段、并发规则、Java 8 语法与该语言的既有写法。

规则作用于本次改动新增或修改的行；存量边界见 `../SKILL.md`。

## 设计模式落地手段

**优先级：公司共享技能库 > 工程既有写法 > 本节建议。** 本节是推荐手段，冲突时以高者为准并说明冲突点。

结构形态参考 Spring Framework 源码（本机克隆：`/Volumes/liuyl/coding/java/opensource/framework/spring/spring-framework`）——**只借形态，不借复杂度**。

### 变化点分派：按选择依据挑形态，用最小可用版本

**参考 Spring 的形态，不照搬它的复杂度。** Spring 那些缓存、谓词兜底、多匹配取最优、运行时注册与注销，是「面向不特定第三方扩展 + 框架生命周期」才付的成本；业务工程没有这个约束，写这些属于凭空复杂度。

**先按需求写最小可用版本，等第二个真实需求出现再优化。** 判据是「现在有没有第二个冲突的需求」，不是「以后可能要用」。

| 选择依据 | 最小实现 | 明确不做（除非需求已经要求） | 形态参考 |
| --- | --- | --- | --- |
| 外部稳定编码（供应商码、渠道码、类型码） | 构造注入 `List<Strategy>`，按显式 key 建不可变 `Map`，重复 key 启动期抛错，未命中抛业务 error code | 谓词兜底、多重匹配取最优、查询缓存、运行时注册/注销、懒加载 | `AbstractHandlerMethodMapping` |
| 能力谓词，条件可能重叠、顺序有意义 | `List<Resolver>` 顺序遍历，`supportsXxx()` 首个命中即返回 | 结果缓存、权重体系、动态排序 | `HandlerMethodArgumentResolverComposite` |
| 骨架固定、仅某一两步不同 | 把变化的那步作为回调/函数参数传入（`TransactionCallback` 式） | 抽象基类 + 多个钩子方法 + 模板里再套模板 | `TransactionTemplate#execute`、`JdbcTemplate` |

参考路径（本机 Spring 克隆，可核对）：`spring-webmvc/.../AbstractHandlerMethodMapping.java`、`spring-messaging/.../HandlerMethodArgumentResolverComposite.java`、`spring-tx/.../TransactionTemplate.java`。

其余要求：

- **不用裸 `Map<String, X>` 注入**（key 取 bean 名，与业务编码不天然一致，key 错要到运行时缺 bean 才暴露）。要么按显式 key 建索引并做重复检测，要么走谓词链。
- **分派结构要有失败语义**：未命中抛 typed error code，或明确兜底，不能静默返回 `null`。
- 新增分派结构在设计说明里点明选了哪种形态、为什么这么小就够用。
- **接口只有一个实现不必然是过度抽象**：该点已确认会有第二、第三个实现（多供应商、多渠道、多品类这类明确扩展点）时，建立分派结构是设计决策，不是 `P3`。判据是「第二实现是否已确认」——crm-16 的 `DataSourcePackageStrategy`（当前仅 `SouKeBao` 一个实现，供应商扩展点明确）属此类，不要当过度抽象打回。
- **升级路径写清楚**：如果这次刻意留了简化（没做缓存、没做谓词兜底），在设计说明里写一句「当前为最小实现，触发条件 X 时再补」——留痕，避免后来者以为是遗漏。

### 状态流转：用 State 形态

对象行为随状态转移而变，且**状态数 ≥ 3、转移带业务分支**时，用状态类而不是在业务方法里堆 `switch (status)`。审批流、工单流这类场景的推荐形态：

```java
public interface State {
    void init(Context context);
    void preReview(Context context);   // 预审
    void approve(Context context);     // 审批
    void execute(Context context);     // 执行
}
```

配各状态实现（初始 / 预审通过 / 预审失败 / 已审批 / 审批驳回 / 执行成功 / 执行失败）+ 一个 `Context` 持有当前状态并转发调用。

边界（简易版即可）：**不引入状态机框架、不做 DSL、不做状态图配置**。状态转移表就是各状态类里的方法实现，谁允许转移到谁写在代码里。状态需要持久化时只存状态枚举值，恢复时按值构造对应状态类。

状态数只有 1–2 个，或转移没有业务分支（纯改字段）时，用一个状态枚举 + 少量 `if` 就够，不要建状态类。

### 其它模式

1. **单例与 IoC**：Spring 环境下用 `@Component` / `@Service` 的默认 singleton 作用域，禁止手写饿汉式/懒汉式单例类。
2. **建造者**：分场景——**框架/公共库**用静态工厂 + 链式 builder（`BeanDefinitionBuilder.genericBeanDefinition(...)`、`WebClient.builder()` 式）；**业务 DTO** 若工程已用 Lombok 则用 `@Builder`。**不用 Lombok 的工程不要为单处引入**（是否引入是团队决定，不是顺手）。两种场景都不手写 `static class Builder`，除非有链式强校验逻辑。
3. **枚举承载行为**：状态/类型枚举自带方法（枚举常量实现抽象方法）优于在业务类里写 `switch` 判枚举再分派。本仓库现有 49 个枚举均为纯数据枚举，首次这样用属允许的改进，不是偏离既有风格。
4. **桥接（Bridge）**：仅适用于**两个维度各自独立变化**的场景（例：消息渠道 × 紧急程度、报表类型 × 导出格式）。业务里出现频率低，两个维度只有一个会变时不要用。
5. **谁先谁后**：以上都属于「为变化点建结构」。**没有变化点就不建**——单实现、单分支、单次使用的抽象层一律是净负担（见 `../SKILL.md` 的准入矩阵）。

### 不要这样写（反例）

以下写法在学习型示例代码里常见，落到生产就是缺陷。都定义在**改动行**上，按括号内严重度报。

```java
// 反例 1：自引用谓词——适配器判断「自己是不是自己」，恒真，没有决策价值
if (adapter.support(adapter)) { return adapter.login(id, adapter); }
```

谓词必须拿**外部输入**做判断（`supports(targetType)`、`supports(providerCode)`）。`support(this)` 这种没有信息量的判断只是摆设，删掉或改成真正的条件。（`P2`）

```java
// 反例 2：吞异常 + 打印堆栈 + 静默返回 null
try { ... } catch (Exception e) { e.printStackTrace(); }
return null;
```

分派失败必须有语义：抛业务 error code，或返回带失败原因的结果对象；生产代码禁止 `printStackTrace`（走工程日志器，且要带业务 key）。返回 `null` 让调用方无从判断是「没匹配」还是「出错了」。（`P2`）

```java
// 反例 3：在分派入口里直接 new 出实现
return processLogin(openId, new LoginForQQAdapter());
```

分派器内 `new` 使实现无法注入、无法 mock、新增实现要改入口。按上面表格选形态：注册表用构造注入 `List<Strategy>` 建索引，谓词链注入 `List<Resolver>`。（`P2`）

另外两类顺带记：实现类命名拼错（`AbstraceAdapter`、`AbastractMessage`、`NomalMessage` 这类原书笔误）不照抄（`P3`）；占位方法体 `return null` / `return 空集合` 而不写 TODO 或抛未实现异常，会让人误以为可用（`P3`）。

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

## 重构落地手段

准入、坏味道清单、手法目录与完成标准见 `../SKILL.md` 的「通用：重构准入」与「通用：重构手法目录」。Java 侧映射：

| 手法 | Java 做法 |
| --- | --- |
| 提取方法 / 内联 / 搬移 | 用 IDE 的 Extract Method / Inline / Move（IntelliJ），不手工拷贝——手抄会漏调用点、泛型签名、Javadoc |
| 以多态替换条件分派 | 枚举自带行为（枚举里写抽象方法 + 各常量实现），或策略 + 显式注册表；用 Spring `Map<String, X>` 注入时注意 key 取 bean 名 |
| 以管道替换循环 | 换成 Stream；`collect` 前先想清楚目标集合类型，避免为收集而收集 |
| 引入参数对象 | 多参数合成 DTO——本工程 DTO 惯例是 `@Data`（`@Builder` 目前零使用，见上文） |
| 以对象替换数据值 | 金额用 `BigDecimal`（不用 `double`），时间用工程既有的时间类型，状态用枚举而非裸 `int` |
| 合并重复分支 | 分支体一致时合并；仅骨架一致、子步骤不同才考虑模板方法，且先评估函数式接口传参 |
| 删除死代码 | 注释掉的代码块、无调用方的方法、不再使用的私有方法与常量直接删 |
| 合并多余抽象层 | 接口或抽象类只有一条实现且无第二实现时，合回具体类 |

其它：

- 动公共方法签名、DTO 字段或枚举值时，兼容性判断按公司共享库的既有口径走，不自行放宽。
- 改结构不要顺手改历史注释头：`@author` / `@since` 有归属规则，重构不重新归属。
- 重构后跑受影响模块的最小验证命令（目标测试类或模块级 `mvn test`）；纯结构调整也跑一次，确认行为未变。

## 自查

```bash
git diff origin/test... -- '*.java' | grep -n "parallelStream\|Executors\.new\|Optional\.get()\|SimpleDateFormat\|new HashMap\|\.stream()"
```

命中后逐个判定：是否落在改动行上、是否命中上面某条规则。设计阶段没写「模式 / 并发 / Java 8」三项结论的，先补结论再继续。
