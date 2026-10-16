#!/usr/bin/env bash
# Make the `mr` command callable from any directory, or verify the copy that
# is already there.
#
#   bash install-mr.sh                 verify an existing mr, else install
#   bash install-mr.sh --check         verify only, never install
#   bash install-mr.sh --force         install even when mr already exists
#   bash install-mr.sh --prefix DIR    install into DIR instead of the default
#
# Existing installations are never overwritten without --force: a working mr on
# the machine is the thing we want, not our copy of it.
#
# Default prefix: /usr/local/bin on macOS/Linux, ~/.local/bin on Windows
# (Git Bash / MSYS / Cygwin), where /usr/local/bin is not a shared bin dir.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/mr"

[ -f "$SRC" ] || { echo "找不到 mr 脚本：${SRC}" >&2; exit 1; }

case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin*) OS_FAMILY="macos" ;;
  Linux*) OS_FAMILY="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS_FAMILY="windows" ;;
  *) OS_FAMILY="unknown" ;;
esac

PREFIX=""
CHECK_ONLY=0
FORCE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix 需要目录参数}"; shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    --force) FORCE=1; shift ;;
    *) echo "未知参数：$1" >&2; exit 1 ;;
  esac
done

if [ -z "$PREFIX" ]; then
  if [ "$OS_FAMILY" = "windows" ]; then
    PREFIX="${HOME}/.local/bin"
  else
    PREFIX="/usr/local/bin"
  fi
fi

# The copy to verify: whatever `mr` resolves to on PATH, else the default path.
EXISTING=""
if command -v mr >/dev/null 2>&1; then
  EXISTING="$(command -v mr)"
elif [ -f "${PREFIX}/mr" ]; then
  EXISTING="${PREFIX}/mr"
fi

# Check that mr can actually run. It is never invoked for real here — running it
# would create a merge request — so this is a static check plus a dependency
# probe, and it reports what it could not confirm.
verify() {
  local path="$1" problems=0

  echo "位置：${path}"

  if [ -x "$path" ]; then
    echo "  可执行：是"
  else
    echo "  可执行：否（缺少执行位）"
    problems=$((problems + 1))
  fi

  if bash -n "$path" 2>/dev/null; then
    echo "  语法：通过"
  else
    echo "  语法：失败"
    bash -n "$path" || true
    problems=$((problems + 1))
  fi

  if grep -q 'merge_requests' "$path" 2>/dev/null; then
    echo "  内容：含 merge_requests 调用"
  else
    echo "  内容：不像 MR 脚本（没有 merge_requests 调用）"
    problems=$((problems + 1))
  fi

  local dep
  for dep in git curl; do
    if command -v "$dep" >/dev/null 2>&1; then
      echo "  依赖 ${dep}：$(command -v "$dep")"
    else
      echo "  依赖 ${dep}：缺失"
      problems=$((problems + 1))
    fi
  done

  if [ -n "${GITLAB_PRIVATE_TOKEN:-}" ]; then
    echo "  GITLAB_PRIVATE_TOKEN：已配置"
  else
    echo "  GITLAB_PRIVATE_TOKEN：未配置（执行时会报错）"
  fi

  if [ -n "$(git config --get duyan.gitlabProjectId 2>/dev/null || true)" ]; then
    echo "  项目 ID：已配置（$(pwd)）"
  else
    echo "  项目 ID：当前目录未取到（仓库级配置需在目标仓库内检查）"
  fi

  # Known weakness of the original script, worth saying out loud because it
  # changes how a failure looks: curl exits 0 on HTTP errors here, so a
  # rejected MR can still look like a success.
  if grep -q -- '--fail-with-body\|--fail' "$path" 2>/dev/null; then
    echo "  HTTP 错误处理：curl 会因 4xx/5xx 非零退出"
  else
    echo "  HTTP 错误处理：curl 对 4xx/5xx 仍返回 0，失败可能被当成成功"
  fi

  echo "  指纹：$( (shasum -a 256 "$path" 2>/dev/null || sha256sum "$path" 2>/dev/null) | cut -c1-12)"

  return "$problems"
}

if [ -n "$EXISTING" ] && [ "$FORCE" -eq 0 ]; then
  echo "检测到已有 mr，不改动（要替换用 --force）。"
  verify "$EXISTING"
  status=$?
  if [ "$status" -eq 0 ]; then
    echo "结论：可用。"
  else
    echo "结论：存在 ${status} 处问题，见上。需要替换时用 --force。" >&2
  fi
  exit "$status"
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "未检测到 mr（PATH 与 ${PREFIX} 都没有）。"
  exit 1
fi

# Nothing installed yet.
install_into() {
  local prefix="$1" target="$1/mr"
  mkdir -p "$prefix"

  if [ -w "$prefix" ]; then
    install -m 0755 "$SRC" "$target"
    return 0
  fi

  if [ "$OS_FAMILY" != "windows" ] && [ -t 0 ] && command -v sudo >/dev/null 2>&1; then
    echo "无写权限，使用 sudo 安装到 ${target}"
    sudo install -m 0755 "$SRC" "$target"
    return 0
  fi

  return 1
}

if [ "$FORCE" -eq 1 ] && [ -f "${PREFIX}/mr" ] && [ -w "${PREFIX}/mr" ]; then
  cp "${PREFIX}/mr" "${PREFIX}/mr.bak-$(date +%Y%m%d%H%M%S)"
  echo "已备份原文件：${PREFIX}/mr.bak-$(date +%Y%m%d%H%M%S)"
fi

if install_into "$PREFIX"; then
  echo "已安装：${PREFIX}/mr"
else
  FALLBACK="${HOME}/.local/bin"
  echo "无权写入 ${PREFIX}，回退到 ${FALLBACK}" >&2
  PREFIX="$FALLBACK"
  install_into "$PREFIX" || { echo "安装失败：${PREFIX} 亦不可写" >&2; exit 1; }
  echo "已安装：${PREFIX}/mr"
fi

# Windows: cmd and PowerShell cannot run a bash script directly, so ship a
# .cmd shim next to it, and make sure Git Bash picks the directory up.
if [ "$OS_FAMILY" = "windows" ]; then
  SHIM="${PREFIX}/mr.cmd"
  printf '@echo off\r\nbash "%%~dp0mr" %%*\r\n' > "$SHIM"
  echo "已安装 cmd 转发：${SHIM}"

  BASHRC="${HOME}/.bashrc"
  if ! grep -qs 'local/bin' "$BASHRC" 2>/dev/null; then
    printf '\n# added by mr installer\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$BASHRC"
    echo "已把 ${PREFIX} 写入 ${BASHRC}（Git Bash 重启后生效）"
  fi

  echo
  echo "PowerShell / cmd 还需把目录加进用户 PATH（只打印，不自动改注册表）："
  echo "  PowerShell: [Environment]::SetEnvironmentVariable('Path', \"\$env:USERPROFILE\\.local\\bin;\" + [Environment]::GetEnvironmentVariable('Path','User'), 'User')"
  echo "  cmd:        setx PATH \"%USERPROFILE%\\.local\\bin;%PATH%\""
fi

# A copy that is not on PATH is the failure mode users actually hit.
if command -v mr >/dev/null 2>&1; then
  echo "PATH 可用：$(command -v mr)"
else
  echo "警告：${PREFIX} 不在当前 PATH 中，本 shell 里仍无法直接调用 mr" >&2
  echo "  临时生效：export PATH=\"${PREFIX}:\$PATH\"" >&2
  if [ "$OS_FAMILY" != "windows" ]; then
    echo "  永久生效：把该行加进 ~/.zshrc 或 ~/.bashrc" >&2
  fi
  exit 1
fi
