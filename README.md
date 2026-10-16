# ai-skills

个人 agent 技能仓库。`skills/` 下每个目录一个技能，各自独立，可单独安装。

```
skills/
  <skill-name>/
    SKILL.md    # frontmatter: name（与目录同名）+ description 触发条件，后接指令正文
    scripts/    # 可选：技能调用的脚本
```

## 技能

| 技能 | 用途 |
| --- | --- |
| `git-commit` | 分析 git 改动生成提交信息：Conventional Commits、简体中文、聚焦高层功能变化。 |
| `mr` | 创建 GitLab 合并请求：先检测并验证 `mr` 命令（已有则不改动），缺失才安装，再对当前分支发起 MR。 |
| `coding-standards` | 编码口径规则库，按语言拆 `references/`：Java 已有，Python / TypeScript / Vue 待补。含设计模式准入矩阵与阈值、重构准入与拆分要求、并发、语言惯用法，以及「新代码强制、存量记账不阻断」判定。优先级低于公司共享技能库与工程 spec。 |

## 安装

```bash
npx -y github:liuylo/skills install              # 全部技能
npx -y github:liuylo/skills install git-commit   # 指定技能
npx -y github:liuylo/skills list                 # 查看安装了哪些
npx -y github:liuylo/skills uninstall git-commit
```

技能以**拷贝**方式安装——npx 把包解到临时缓存目录，缓存清理后软链会悬空。内容落在 `~/.agents/skills/<name>`，`~/.claude/skills/<name>` 为指向它的相对软链。拷贝目录带 `.installed-by-liuylo-skills` 标记，卸载只删带标记的目录；目标位置若是手工放的真目录会跳过，加 `--force` 才覆盖。

改了仓库里的技能后，重跑一次 `install` 即可同步。

## 新增技能

1. `mkdir skills/<name>`，写 `skills/<name>/SKILL.md`，`name` 与目录同名
2. 需要外部脚本就放 `skills/<name>/scripts/`，长规则放 `skills/<name>/references/`
3. 提交推送后 `npx -y github:liuylo/skills install <name>`

## 补语言规则

`coding-standards` 按语言拆文件。加一门语言：

1. 写 `skills/coding-standards/references/<language>.md`，末尾带该语言的 grep 自查清单
2. 在 `SKILL.md` 的「选文件」表里加一行：语言、文件路径、识别依据（构建文件或后缀）
3. 提交推送后重跑 `npx -y github:liuylo/skills install coding-standards`

没写对应语言文件时，技能会明说缺少该语言规则，不凭印象造规则——所以表里的行必须与文件同时存在。
