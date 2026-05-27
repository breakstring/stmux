#!/bin/bash

# .tmux/status.sh
# 职责与边界：为 tmux 状态栏输出当前机器的 CPU、内存和轮播 IPv4 摘要；不负责持久监控、告警或网络连通性检测。
# 关键副作用：读取系统状态命令，并在 `/tmp/tmux_ip_index_${USER}` 写入下一次 IP 轮播索引。
# 关键依赖与约束：macOS 依赖 `top`、`vm_stat`、`sysctl`、`ifconfig`，可选 `tailscale`；Linux 依赖 `top`、`free`、`ip` 和 `/sys/class/net`。

# --- 1. 系统检测 ---
OS=$(uname -s)

Tailscale_IPV4S=""

# 读取 macOS 物理内存用量，输出 used/total MB。
#
# 参数：无。
# 返回值：通过 stdout 输出 `<used>/<total>MB`；used 排除 file-backed/inactive 等可回收文件缓存。
# 错误处理：`vm_stat` 必要字段缺失时输出 `Unknown`，避免给出误导性内存值。
# 副作用：读取 `sysctl -n hw.memsize` 和 `vm_stat`，不写入系统状态。
get_darwin_memory_usage() {
    local total_bytes page_size total_mb used_mb

    total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    if ! [[ "$total_bytes" =~ ^[0-9]+$ ]] || [ "$total_bytes" -le 0 ]; then
        echo "Unknown"
        return
    fi

    total_mb=$((total_bytes / 1024 / 1024))
    used_mb=$(vm_stat 2>/dev/null | awk -v total_mb="$total_mb" '
        /page size of/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+$/) {
                    page_size = $i
                    break
                }
            }
        }
        /Pages wired down:/ { wired = $4 + 0; wired_seen = 1 }
        /Anonymous pages:/ { anonymous = $3 + 0; anonymous_seen = 1 }
        /Pages occupied by compressor:/ { compressor = $5 + 0; compressor_seen = 1 }
        END {
            if (!page_size || !wired_seen || !anonymous_seen || !compressor_seen) {
                print "Unknown"
                exit
            }
            used = (wired + anonymous + compressor) * page_size / 1024 / 1024
            if (used < 0) used = 0
            if (used > total_mb) used = total_mb
            printf "%d", used
        }
    ')

    if ! [[ "$used_mb" =~ ^[0-9]+$ ]]; then
        echo "Unknown"
        return
    fi

    echo "${used_mb}/${total_mb}MB"
}

# 将网卡名和 IPv4 映射为状态栏短标签。
#
# 参数：
#   $1：网卡名，例如 `en0`、`eth0`、`feth1793`、`utun9`。
#   $2：IPv4 地址，不包含 CIDR 后缀。
# 返回值：通过 stdout 输出短标签，当前包括 LAN、ETH、ZT、TS、NET。
# 错误处理：未知网卡或无法识别的地址回退为 `NET`。
# 副作用：无；只读取全局 `Tailscale_IPV4S`。
label_ipv4() {
    local iface="$1"
    local ip_addr="$2"

    case "$iface" in
        zt*|feth*) echo "ZT"; return ;;
        enp*|eth*) echo "ETH"; return ;;
        en*) echo "LAN"; return ;;
    esac

    if printf '%s\n' "$Tailscale_IPV4S" | grep -qx "$ip_addr"; then
        echo "TS"
        return
    fi

    case "$ip_addr" in
        100.*) echo "TS" ;;
        172.28.*) echo "ZT" ;;
        *) echo "NET" ;;
    esac
}

# 收集 macOS 上可展示的 IPv4 地址。
#
# 参数：无。
# 返回值：每行输出一个 `[标签]IPv4` 项；调用方可按行读入轮播数组。
# 错误处理：`ifconfig` 或单个网卡读取失败时跳过对应项。
# 副作用：会尝试执行可选的 `tailscale ip -4` 来提升 Tailscale 网卡识别准确性。
collect_darwin_ipv4s() {
    local iface ip_addr label

    Tailscale_IPV4S=$(tailscale ip -4 2>/dev/null || true)

    for iface in $(ifconfig -l 2>/dev/null); do
        case "$iface" in
            lo*|gif*|stf*|awdl*|llw*|bridge*|anpi*|ap*) continue ;;
        esac

        ip_addr=$(ifconfig "$iface" 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" { print $2; exit }')
        if [ -n "$ip_addr" ]; then
            label=$(label_ipv4 "$iface" "$ip_addr")
            printf '[%s]%s\n' "$label" "$ip_addr"
        fi
    done
}

# 收集 Linux 上可展示的 IPv4 地址。
#
# 参数：无。
# 返回值：每行输出一个 `[标签]IPv4` 项；调用方可按行读入轮播数组。
# 错误处理：`/sys/class/net` 或 `ip` 不可用时输出空集合，由调用方显示 `No IP`。
# 副作用：无。
collect_linux_ipv4s() {
    local iface ip_addr label

    [ -d /sys/class/net ] || return

    for iface in $(ls /sys/class/net | grep -vE "lo|docker|br-|veth"); do
        ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
        if [ -n "$ip_addr" ]; then
            label=$(label_ipv4 "$iface" "$ip_addr")
            printf '[%s]%s\n' "$label" "$ip_addr"
        fi
    done
}

# --- 2. CPU 计算 (兼容 Mac/Linux) ---
if [ "$OS" = "Darwin" ]; then
    CPU_IDLE=$(top -l 1 | grep "CPU usage" | awk '{print $7}' | sed 's/%//')
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc 2>/dev/null || echo "0")
else
    # Linux 逻辑，如果没有 bc 则取整数部分
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}' | cut -d. -f1)
fi

# --- 3. 内存计算 ---
if [ "$OS" = "Darwin" ]; then
    MEM_USAGE=$(get_darwin_memory_usage)
else
    MEM_USAGE=$(free -m | awk 'NR==2{printf "%d/%dMB", $3,$2}')
fi

# --- 4. IPv4 轮播 ---
IPS=()

if [ "$OS" = "Darwin" ]; then
    while IFS= read -r item; do
        [ -n "$item" ] && IPS+=("$item")
    done < <(collect_darwin_ipv4s)
else
    while IFS= read -r item; do
        [ -n "$item" ] && IPS+=("$item")
    done < <(collect_linux_ipv4s)
fi

IP_COUNT=${#IPS[@]}

if [ $IP_COUNT -eq 0 ]; then
    CURRENT_IP="No IP"
else
    STATE_FILE="/tmp/tmux_ip_index_${USER}"
    INDEX=$(cat "$STATE_FILE" 2>/dev/null)
    [[ -z "$INDEX" ]] && INDEX=0
    (( INDEX >= IP_COUNT )) && INDEX=0
    
    CURRENT_IP="${IPS[$INDEX]}"
    
    NEXT_INDEX=$(( (INDEX + 1) % IP_COUNT ))
    echo "$NEXT_INDEX" > "$STATE_FILE"
fi

# --- 5. 最终输出 ---
echo "CPU: ${CPU_USAGE}% | MEM: ${MEM_USAGE} | IP: ${CURRENT_IP}"
