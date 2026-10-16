# Python 规则

**基线**：工程 `requires-python = ">=3.8"`，目标版本 `py38`；格式与机械检查交给 `ruff`（工程已配 `line-length = 88`，选中 `B`/`C`/`E`/`F`/`I`/`UP` 等）。数据模型既有 `@dataclass` 也有 Pydantic `BaseModel`，按既有用法选。

**优先级**：公司共享库的 `python-patterns` 技能与 `language-python.md` 在本文件之上——可读性、EAFP、命名、注释、异常处理、上下文管理器、推导式、装饰器、包组织、工具链那些内容都在那边，本文件不重复。这里只写准入规则在 Python 的落地手段、并发、版本语法边界与重构手法。

准入标准、触发条件、坏味道清单、手法目录与定级口径见 `../SKILL.md`（各语言共用）。规则作用于本次改动新增或修改的行。

## 设计模式落地手段

| 模式 | Python 做法 |
| --- | --- |
| 单例 | 模块级对象即可（模块本身只导入一次）；不要手写 `__new__` / 元类单例 |
| 工厂 | 普通函数，或注册表装饰器（`_REGISTRY[key] = cls`）；不要造 Factory 类层级 |
| 策略 | `dict` 映射到函数/对象，或 `functools.singledispatch`；枚举自带行为用 `enum.Enum` 上挂方法 |
| 模板方法 | 优先把差异作为 **callable 参数**传入（高阶函数），不造继承层级；确需固定骨架时用 `abc.ABC` + 抽象方法 |
| 建造者 | **不用**。`dataclass` / Pydantic 模型 + 关键字参数即可；`**kwargs` 只用在外部边界（解析外部输入），不用于内部构造 |
| 装饰器 | 只承载横切关注点（日志、重试、计时、权限）。业务分支不要藏在装饰器里 |

版本红线：**`py38` 下没有结构性模式匹配 `match`**（3.10+），条件分派用 `dict` 映射或 `if / elif`，不要写成 `match`。

## 并发

现状：本仓库目前 **没有** `async` / 线程池用法（全仓 0 处）。以下是**新引入并发时**的约束，不是对现有代码的指控。

- **GIL 决定选型**：CPU 密集用 `concurrent.futures.ProcessPoolExecutor`；IO 密集用 `ThreadPoolExecutor`。选错不会报错，只是白等 → `P2`。
- **不用裸 `threading.Thread`**（除短命守护线程）；用池并给 `thread_name_prefix`，事故才能定位。`P2`
- **`asyncio` 里禁止阻塞调用**：`requests`、`time.sleep`、同步数据库驱动、同步文件大读写都会卡住整个事件循环。用异步库，或 `loop.run_in_executor`（`py38` 没有 `asyncio.to_thread`，那是 3.9+）。`P2`
- **`asyncio.create_task` 必须保存引用并 `await`**（或放进集合并等待）：任务对象没有强引用会被 GC 静默取消，表现为「偶发没执行」。`P2`
- 跨线程/跨进程共享可变状态要么加锁，要么不共享。进程间状态用 `multiprocessing` 原语或外部存储（Redis），**不要用模块级全局变量**（多进程下各有一份副本，改了看不见）。`P2`
- 锁、连接、session 用 `with` 管理，保证异常路径也释放。
- 队列、worker、任务名要可诊断（公司共享库的既有要求）。

## 版本语法边界（py38）

用仓库已经在用的写法，别引入跑不起来的语法：

- **不可用**：`match`（3.10）、`X | Y` 联合类型（3.10）、内建泛型注解 `dict[str, str]` / `list[int]`（3.9）、`str.removeprefix` / `removesuffix`（3.9）、`asyncio.to_thread`（3.9）、`functools.cache`（3.9）。
- 需要泛型注解时用 `typing.List` / `Dict` / `Optional`，或在文件顶部加 `from __future__ import annotations`——**它只让注解不求值，Pydantic 模型字段、`dataclass` 运行时校验仍可能求值**，改前确认。
- 顺带一提：`tmp/` 下有历史脚本用了 `dict[str, str]` 注解且无 future import（如 `tmp/migrate_msgid.py`）。属存量脚本，记账不阻断；重跑到 3.8 环境会 ImportError，别照抄。

可用且应当用的：

- **f-string** 优于 `%` 与 `str.format`；`pathlib.Path` 优于字符串拼路径。
- **推导式**用于简单转换；逻辑一复杂就改生成器函数（公司 `python-patterns` 已有此条）。
- 用 `enumerate` / `zip` / `any` / `all` / `sorted(key=...)` 替代手工计数与标志位。
- 用 `with` 管理文件、锁、连接、session，别手写 `try/finally`。
- **数据模型**：有稳定 schema 就用 `dataclass` 或 Pydantic 模型，不要用无类型 `dict` 传递结构化数据（公司共享库同样要求）。
- 集合统计用 `collections` 的 `defaultdict` / `Counter`，别手写「取值、判空、初始化」。
- **`print` 只用于 CLI 脚本的正常输出**，诊断信息走工程 logger——公司共享库的阻断项。存量示例：`common/retry_utils.py` 在生产重试工具里用 `print` 打重试信息，属存量，记账不阻断，但改动该文件时顺手换成 logger。

## 重构落地手段

准入、坏味道、手法目录与完成标准见 `../SKILL.md`。Python 侧：

| 手法 | Python 做法 |
| --- | --- |
| 格式化 / 机械修复 | 交给 `ruff format` 与 `ruff check --fix`，不要手工调格式 |
| 重命名 / 搬移 | 用 IDE 或 rope 重构，不要全仓 `sed`——会误改字符串、注释与配置 |
| 以映射替换条件分派 | 长 `if / elif` 链换成 `dict` 分派或 `functools.singledispatch` |
| 提取方法 | 抽出函数，签名用类型提示与关键字参数；不要靠 `**kwargs` 兜 |
| 引入参数对象 | 多参数合成 `dataclass`（`frozen=True` 更好）或 Pydantic 模型 |
| 重复样板消除 | 重复的 `try/except`、重试、计时逻辑抽成上下文管理器或装饰器 |
| 删除死代码 | 注释掉的代码块、无引用函数、`if False:` 分支直接删 |
| 合并多余抽象层 | 只有一个实现的基类/接口直接合回具体类；一个方法的「工厂函数」直接内联 |

- 改结构不要顺手改模块 docstring 的作者或历史信息，与 Java 侧同一原则。
- 重构后跑 `ruff check` 加受影响范围的 `pytest` 目标；纯结构调整也跑一次。

## 自查

```bash
CHANGED=$(git diff --name-only origin/test... -- '*.py')
ruff check $CHANGED
rg -n -- 'print\(|except:|time\.sleep|create_task|match [^=]*:$|: *(list|dict)\[' $CHANGED
```

命中后逐个判定：是否落在改动行上、是否命中上面某条规则。
