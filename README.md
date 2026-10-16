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

## 新增技能

1. `mkdir skills/<name>`，写 `skills/<name>/SKILL.md`，`name` 与目录同名
2. `bash scripts/install.sh <name>`
