# ai-skills

个人 agent 技能仓库。`skills/` 下每个目录一个技能，各自独立，可单独安装。

```
skills/
  <skill-name>/
    SKILL.md    # frontmatter: name（与目录同名）+ description 触发条件，后接指令正文
scripts/
  install.sh    # 把技能软链到 ~/.agents/skills 与 ~/.claude/skills
```

## 技能

| 技能 | 用途 |
| --- | --- |
| `git-commit` | 分析 git 改动生成提交信息：Conventional Commits、简体中文、聚焦高层功能变化。 |

## 安装

```bash
bash scripts/install.sh              # 全部
bash scripts/install.sh git-commit   # 单个
bash scripts/install.sh --uninstall git-commit
```

软链安装，不拷贝——改本仓库的文件立即生效，无需重装。重复执行安全；目标路径若是真目录（非软链）会跳过并提示，不覆盖。卸载只删指向本仓库的软链。

## npx 安装

```bash
npx github:liuylo/skills install              # 全部技能
npx github:liuylo/skills install git-commit   # 指定技能
npx github:liuylo/skills list                 # 查看安装了哪些
npx github:liuylo/skills uninstall git-commit
```

npx 路径下技能是**拷贝**，不是软链——npx 把包解到临时缓存目录，缓存清理后软链会悬空。内容落在 `~/.agents/skills/<name>`，`~/.claude/skills/<name>` 为指向它的相对软链。拷贝目录带 `.installed-by-liuylo-skills` 标记，卸载只删带标记的目录；目标位置若是手工放的真目录会跳过，加 `--force` 才覆盖。

上面的 `scripts/install.sh` 是本地开发用（软链，改完即生效），两者互不影响。

## 新增技能

1. `mkdir skills/<name>`，写 `skills/<name>/SKILL.md`，`name` 与目录同名
2. `bash scripts/install.sh <name>`
