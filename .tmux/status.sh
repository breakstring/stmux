#!/bin/bash

# --- 1. 系统检测 ---
OS=$(uname -s)

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
    # Mac 简化版：由于 vm_stat 较慢，这里取大概
    MEM_USAGE=$(vm_stat | perl -ne '/page size of (\d+)/ and $s=$1; /Pages free:\s+(\d+)/ and $f=$1; /Pages active:\s+(\d+)/ and $a=$1; END { printf "%dMB", ($a*$s/1024/1024) }')
else
    MEM_USAGE=$(free -m | awk 'NR==2{printf "%d/%dMB", $3,$2}')
fi

# --- 4. IPv4 轮播 (稳健版) ---
IPS=()

# 我们只遍历 /sys/class/net 下存在的网卡
# 过滤掉 docker, br-, veth, lo 等
for iface in $(ls /sys/class/net | grep -vE "lo|docker|br-|veth"); do
    # 获取该网卡的 IPv4 地址
    ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
    if [ -n "$ip_addr" ]; then
        # 为不同网卡加个小标签，方便识别
        case "$iface" in
            enp*)  label="LAN" ;;
            eth*)  label="ETH" ;;
            zt*)   label="ZT"  ;; # ZeroTier
            *)     label="NET" ;;
        esac
        IPS+=("[$label]$ip_addr")
    fi
done

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

