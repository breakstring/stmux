#!/bin/bash

# tests/test_stmux_remote_command.sh
# 职责与边界：验证 `stmux` 生成的远端 SSH 命令包含必要的 tmux 启动兜底；不真实连接远端主机。
# 关键副作用：创建并删除临时目录中的 fake `ssh`/`rsync`/`scp` 可执行文件，读取本仓库 `stmux` 脚本。
# 关键依赖与约束：依赖 bash、mktemp、grep；必须从仓库根目录执行，且 fake `ssh` 只捕获命令不模拟远端 shell 行为。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CAPTURE_FILE="$TMP_DIR/ssh-command.txt"

cat >"$TMP_DIR/ssh" <<'FAKE_SSH'
#!/bin/bash

# fake ssh
# 职责与边界：捕获 `stmux` 传给 SSH 的主机与远端命令；不建立网络连接、不执行远端命令。
# 关键副作用：把收到的参数写入 `STMUX_TEST_CAPTURE_FILE` 指定文件。
# 关键依赖与约束：调用方必须提供 `STMUX_TEST_CAPTURE_FILE`，并且本测试只关心最后一次 ssh 调用。

set -euo pipefail

printf '%s\n' "$*" >"$STMUX_TEST_CAPTURE_FILE"
exit 0
FAKE_SSH
chmod +x "$TMP_DIR/ssh"

PATH="$TMP_DIR:$PATH" STMUX_TEST_CAPTURE_FILE="$CAPTURE_FILE" \
    bash "$ROOT_DIR/stmux" minibox.zhiyu.ts >/dev/null

if ! grep -q 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"' "$CAPTURE_FILE"; then
    echo "expected remote command to prepend common Homebrew tmux paths" >&2
    cat "$CAPTURE_FILE" >&2
    exit 1
fi

if ! grep -q 'command -v tmux >/dev/null 2>&1' "$CAPTURE_FILE"; then
    echo "expected remote command to check tmux availability before attach/new-session" >&2
    cat "$CAPTURE_FILE" >&2
    exit 1
fi

if ! grep -q 'Remote tmux was not found' "$CAPTURE_FILE"; then
    echo "expected remote command to print actionable tmux-not-found diagnostics" >&2
    cat "$CAPTURE_FILE" >&2
    exit 1
fi
