#!/bin/bash

# tests/test_tmux_conf_mouse.sh
# 职责与边界：静态验证共享 tmux 配置的触控板/鼠标复制策略；不启动真实 tmux 服务、不验证终端模拟器行为。
# 关键副作用：只读取仓库根目录 `.tmux.conf`，失败时向 stderr 输出诊断信息，不修改文件系统。
# 关键依赖与约束：依赖 bash、grep；必须从仓库根目录或测试脚本所在路径可定位仓库根目录的环境执行。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONF="$ROOT_DIR/.tmux.conf"

# expect_line
# 语义与边界：断言 `.tmux.conf` 中包含某个固定字符串；只做字面匹配，不解析 tmux 语法。
# 入参：`pattern` 是必须出现的固定字符串，`message` 是失败时输出给 stderr 的诊断信息。
# 返回值：匹配成功返回 0；缺失时输出诊断并以 1 终止测试。
# 错误处理与副作用：依赖 grep 读取配置文件，失败时写 stderr 并 exit，不修改任何文件。
expect_line() {
    local pattern=$1
    local message=$2

    if ! grep -Fq "$pattern" "$TMUX_CONF"; then
        echo "$message" >&2
        echo "missing pattern: $pattern" >&2
        exit 1
    fi
}

# reject_line
# 语义与边界：断言 `.tmux.conf` 中不包含某个固定字符串；只用于防止旧鼠标复制策略回归。
# 入参：`pattern` 是禁止出现的固定字符串，`message` 是失败时输出给 stderr 的诊断信息。
# 返回值：未匹配返回 0；发现禁用字符串时输出诊断并以 1 终止测试。
# 错误处理与副作用：依赖 grep 读取配置文件，失败时写 stderr 并 exit，不修改任何文件。
reject_line() {
    local pattern=$1
    local message=$2

    if grep -Fq "$pattern" "$TMUX_CONF"; then
        echo "$message" >&2
        echo "rejected pattern: $pattern" >&2
        exit 1
    fi
}

expect_line 'set -g mouse on' "expected tmux mouse support to remain enabled for trackpad scrolling and pane interactions"
expect_line 'set -g history-limit 50000' "expected larger tmux history for copying long remote output"
expect_line 'setw -g mode-keys vi' "expected vi copy-mode keys to make long-output selection predictable"
expect_line 'bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-selection-and-cancel' "expected emacs copy-mode mouse drag to copy and exit selection"
expect_line 'bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel' "expected vi copy-mode mouse drag to copy and exit selection"
expect_line 'bind-key M if -F "#{mouse}"' "expected Prefix+M mouse toggle for recovering from stuck mouse reporting"
reject_line 'copy-selection-no-clear' "expected mouse drag copy to clear the selection highlight instead of leaving large selected regions visible"
