---
name: mr
description: >
  创建 GitLab 合并请求（MR）：缺 mr 命令就安装，已有则直接用，再对当前分支发起
  MR。Use when asked to 提交 MR, 创建合并请求, 发起 MR, 提 MR, 推 test 分支,
  "create a merge request", or /mr.
---

# MR

为当前分支创建 GitLab 合并请求。`mr` 命令的实现随本技能一起分发。

## Step 1 — 确认在 git 仓库里

```bash
git rev-parse --show-toplevel
git status --short
git branch --show-current
```

不在仓库里就停下，说明需要先进入目标仓库。工作区有未提交改动时先告知用户——`mr` 只推送已提交的内容，未提交的改动不会进 MR。

## Step 2 — 确认 mr 可用

默认只做一次检测，一条 shell 内建，不装、不验证：

```bash
command -v mr
```

**有 → 直接进 Step 3。** 不跑验证脚本：每次都做 `bash -n` + grep + sha256 + 依赖探测是四个进程的开销，只为确认一个本该在 PATH 里的命令，不值当。

**缺 → 安装**，然后继续：

```bash
bash <skill-dir>/scripts/install-mr.sh
```

`<skill-dir>` 是本技能所在目录（如 `~/.claude/skills/mr`、`~/.agents/skills/mr`）。安装行为：macOS / Linux 装到 `/usr/local/bin/mr`；无写权限且是交互终端时用 `sudo`，两者都不行则回退 `~/.local/bin`。Windows（Git Bash / MSYS / Cygwin）装到 `~/.local/bin/mr`，并在同目录生成 `mr.cmd`（`@echo off` + `bash "%~dp0mr" %*`）供 PowerShell / cmd 调用，同时把 PATH 写入 `~/.bashrc`。装完校验 `command -v mr`，目录不在 PATH 就报错并给出临时与永久生效的写法。

### 只在两种情况跑完整验证

```bash
bash <skill-dir>/scripts/install-mr.sh --check
```

1. 用户问「`mr` 装了吗 / 能用吗」这类问题时
2. `mr` 执行失败、需要定位原因时

验证是**静态**的——**绝不为了验证去真实执行**，跑一次就真的建出一个 MR 了。检查项：执行位、`bash -n` 语法、脚本内含 `merge_requests` 调用、`git`/`curl` 依赖、token 与项目 ID 是否配置、指纹。

验证要看清一项：脚本是否带 `--fail-with-body`。不带时 `curl` 遇到 4xx/5xx 仍返回 0，**MR 被拒也会看起来像成功**。这条不影响是否验证的判断，但影响成败判定——见 Step 4。

明确要替换机器上已有版本时（会先备份为 `mr.bak-<时间戳>`）：

```bash
bash <skill-dir>/scripts/install-mr.sh --force
```

**不要覆盖用户已有的 `mr`**——能跑就留着，除非用户明确要求替换。**也不要在未告知用户的情况下跑 `sudo`**，提权会改动系统目录。

Windows 上 `~/.bashrc` 的 PATH 变更自动完成，但**用户级环境变量只打印命令、不代跑**（要改注册表）。把打印出的 PowerShell / cmd 命令原样转给用户。

## Step 3 — 确认必填配置

```bash
[ -n "${GITLAB_PRIVATE_TOKEN:-}" ] && echo "token 已配置" || echo "缺少 GITLAB_PRIVATE_TOKEN"
git config --get duyan.gitlabProjectId || echo "缺少项目 ID"
```

缺 token 或项目 ID 就不要执行——`mr` 会失败。分别提示：

- `GITLAB_PRIVATE_TOKEN`：GitLab 个人访问令牌，需要 `api` 权限，写进 `~/.zshrc` 或 `~/.bashrc`
- 项目 ID：`git config duyan.gitlabProjectId <id>`（仓库级），或走环境变量 `GITLAB_PROJECT_ID`

不要把 token 值打印到输出里，只报告「已配置 / 未配置」。

## Step 4 — 执行

```bash
mr [目标分支] [标题]
```

- 目标分支默认 `test`，用户指定了就以用户为准（`master`、`release` 等）
- 标题默认 `Merge <源分支> into <目标分支>`，用户给了就传用户给的
- 源分支取当前分支；`mr` 内部会先 `git push -u origin <源分支>`

命令成功时返回 GitLab 的 MR JSON。**以响应体里的 `web_url` 为准**判断是否真的建成了，把该链接报给用户，其余字段（id、iid、sha）不必展开。没有 `web_url` 就是没建成，即使退出码是 0——`curl` 在这里对 4xx/5xx 不报错。

按失败表现定位：401/403 是 token 问题，404 多半是项目 ID 不对，`git push` 失败则是远端权限或分支保护，提示「源分支与目标分支相同」这类校验错误则说明参数选错。

## 输出

用中文汇报：MR 链接、源分支 → 目标分支、标题。创建失败时给出失败原因与下一步要补的配置，不要复述整段 JSON。

## 边界

- 不代替用户做代码审查，不判断分支是否该合。
- 用户说「创建 MR」时直接执行 `mr`；只问「mr 装了吗」这类问题时只跑验证，不装、不建 MR。
- 不覆盖已有的 `mr`，`--force` 只在用户明确要求替换时用。
- 不自动改用户级环境变量，不代跑 `sudo`（先问）。
- 不 force push。
