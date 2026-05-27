#!/bin/bash

# tests/test_status_script.sh
# 职责与边界：验证 `.tmux/status.sh` 在 macOS 场景下的内存统计和 IPv4 分类输出；不验证真实 tmux 状态栏渲染。
# 关键副作用：创建并删除临时 fake 命令目录，并通过测试专用 `USER` 写入 `/tmp/tmux_ip_index_*` 轮播状态文件。
# 关键依赖与约束：依赖 bash、mktemp、grep、sed；必须从仓库根目录执行，fake 命令只覆盖本测试需要的 macOS 命令输出。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
TEST_USER="stmux_status_test_$$"
STATE_FILE="/tmp/tmux_ip_index_${TEST_USER}"

trap 'rm -rf "$TMP_DIR"; rm -f "$STATE_FILE"' EXIT

cat >"$TMP_DIR/uname" <<'FAKE_UNAME'
#!/bin/bash
echo Darwin
FAKE_UNAME

cat >"$TMP_DIR/top" <<'FAKE_TOP'
#!/bin/bash
echo "CPU usage: 10.0% user, 20.0% sys, 70.0% idle"
FAKE_TOP

cat >"$TMP_DIR/bc" <<'FAKE_BC'
#!/bin/bash
input="$(cat)"
if [ "$input" = "100 - 70.0" ]; then
    echo "30.0"
else
    echo "0"
fi
FAKE_BC

cat >"$TMP_DIR/sysctl" <<'FAKE_SYSCTL'
#!/bin/bash
if [ "$1" = "-n" ] && [ "$2" = "hw.memsize" ]; then
    echo 17179869184
else
    exit 1
fi
FAKE_SYSCTL

cat >"$TMP_DIR/vm_stat" <<'FAKE_VM_STAT'
#!/bin/bash
cat <<'VMSTAT'
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                    688128.
Pages active:                                  131072.
Pages inactive:                                131072.
Pages speculative:                                 0.
Pages wired down:                               65536.
File-backed pages:                              98304.
Anonymous pages:                                98304.
Pages occupied by compressor:                   32768.
VMSTAT
FAKE_VM_STAT

cat >"$TMP_DIR/ifconfig" <<'FAKE_IFCONFIG'
#!/bin/bash
case "${1:-}" in
    -l)
        echo "lo0 en0 feth1793 utun9"
        ;;
    en0)
        echo "en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST>"
        echo "    inet 192.168.1.212 netmask 0xfffffe00 broadcast 192.168.1.255"
        ;;
    feth1793)
        echo "feth1793: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST>"
        echo "    inet 172.28.153.222 netmask 0xffff0000 broadcast 172.28.255.255"
        ;;
    utun9)
        echo "utun9: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST>"
        echo "    inet 100.104.140.75 --> 100.104.140.75 netmask 0xffffffff"
        ;;
    *)
        exit 1
        ;;
esac
FAKE_IFCONFIG

cat >"$TMP_DIR/tailscale" <<'FAKE_TAILSCALE'
#!/bin/bash
if [ "$1" = "ip" ] && [ "$2" = "-4" ]; then
    echo "100.104.140.75"
else
    exit 1
fi
FAKE_TAILSCALE

chmod +x "$TMP_DIR"/uname "$TMP_DIR"/top "$TMP_DIR"/bc "$TMP_DIR"/sysctl "$TMP_DIR"/vm_stat "$TMP_DIR"/ifconfig "$TMP_DIR"/tailscale

PATH="$TMP_DIR:$PATH" USER="$TEST_USER" bash "$ROOT_DIR/.tmux/status.sh" >"$TMP_DIR/run1.txt"
PATH="$TMP_DIR:$PATH" USER="$TEST_USER" bash "$ROOT_DIR/.tmux/status.sh" >"$TMP_DIR/run2.txt"
PATH="$TMP_DIR:$PATH" USER="$TEST_USER" bash "$ROOT_DIR/.tmux/status.sh" >"$TMP_DIR/run3.txt"

if ! grep -q 'MEM: 3072/16384MB' "$TMP_DIR/run1.txt"; then
    echo "expected macOS memory to exclude reclaimable file cache" >&2
    cat "$TMP_DIR/run1.txt" >&2
    exit 1
fi

combined_output="$(cat "$TMP_DIR/run1.txt" "$TMP_DIR/run2.txt" "$TMP_DIR/run3.txt")"

if ! printf '%s\n' "$combined_output" | grep -q 'IP: \[LAN\]192.168.1.212'; then
    echo "expected macOS LAN address to be included in IP rotation" >&2
    printf '%s\n' "$combined_output" >&2
    exit 1
fi

if ! printf '%s\n' "$combined_output" | grep -q 'IP: \[ZT\]172.28.153.222'; then
    echo "expected macOS ZeroTier address to be labeled separately" >&2
    printf '%s\n' "$combined_output" >&2
    exit 1
fi

if ! printf '%s\n' "$combined_output" | grep -q 'IP: \[TS\]100.104.140.75'; then
    echo "expected macOS Tailscale address to be labeled separately" >&2
    printf '%s\n' "$combined_output" >&2
    exit 1
fi
