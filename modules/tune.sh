# ==================== 系统网络调优模块 ====================
# 安全第一：所有操作仅修改 sysctl 参数或创建 swap 文件，不安装任何第三方软件
# 适用 Alpine / Debian / Ubuntu，所有改动可一键恢复

# 调优配置文件路径
TUNE_CONF="/etc/sysctl.d/99-sing-box-tuning.conf"
TUNE_FLAG="/etc/sing-box/.tune_applied"

# 调优前备份原配置（仅首次）
TUNE_BACKUP="/etc/sing-box/sysctl.backup"

# 自建 swap 文件路径
TUNE_SWAP_FILE="/swapfile-singbox"

# 统一的调优参数列表（备份/恢复/状态显示共用）
TUNE_PARAMS=(
    "net.ipv4.tcp_congestion_control"
    "net.core.default_qdisc"
    "net.core.rmem_max"
    "net.core.wmem_max"
    "net.ipv4.tcp_rmem"
    "net.ipv4.tcp_wmem"
    "net.ipv4.tcp_notsent_lowat"
    "net.ipv4.tcp_slow_start_after_idle"
    "net.ipv4.tcp_no_metrics_save"
    "net.ipv4.tcp_mtu_probing"
    # --- 宽带缓存 / backlog ---
    "net.core.netdev_max_backlog"
    "net.core.somaxconn"
    "net.ipv4.tcp_max_syn_backlog"
    "net.ipv4.tcp_max_tw_buckets"
    "net.ipv4.tcp_tw_reuse"
    "net.ipv4.tcp_fin_timeout"
    "net.ipv4.ip_local_port_range"
    "net.ipv4.tcp_keepalive_time"
    "net.ipv4.tcp_fastopen"
    # --- SWAP / 虚拟内存 ---
    "vm.swappiness"
    "vm.vfs_cache_pressure"
    "vm.dirty_ratio"
    "vm.dirty_background_ratio"
    "vm.overcommit_memory"
)

# ==================== 检测内核版本 ====================
check_kernel_version() {
    local kernel_ver=$(uname -r | cut -d'-' -f1)
    local major=$(echo "$kernel_ver" | cut -d'.' -f1)
    local minor=$(echo "$kernel_ver" | cut -d'.' -f2)

    # BBR 需要 4.9+
    if [[ $major -lt 4 ]] || { [[ $major -eq 4 ]] && [[ $minor -lt 9 ]]; }; then
        echo "old"
        return
    fi
    echo "ok"
}

# 检测 BBR 模块是否可用
check_bbr_available() {
    # 先看已加载的算法
    local available=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    if echo "$available" | grep -qw bbr; then
        echo "yes"
        return
    fi

    # 尝试加载模块
    if modprobe tcp_bbr 2>/dev/null; then
        available=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
        if echo "$available" | grep -qw bbr; then
            echo "yes"
            return
        fi
    fi

    echo "no"
}

# ==================== 备份原配置 ====================
backup_sysctl() {
    if [[ ! -f "$TUNE_BACKUP" ]]; then
        mkdir -p /etc/sing-box
        # 记录调优前所有相关参数的原始值
        {
            echo "# sysctl 备份 - $(date)"
            echo "# 调优前的原始值"
            for key in "${TUNE_PARAMS[@]}"; do
                local val=$(sysctl -n "$key" 2>/dev/null)
                [[ -z "$val" ]] && continue
                # 包含空格的值用引号包裹
                if [[ "$val" == *" "* ]]; then
                    echo "${key}=\"${val}\""
                else
                    echo "${key}=${val}"
                fi
            done
        } > "$TUNE_BACKUP" 2>/dev/null
        print_info "原 sysctl 配置已备份到 ${TUNE_BACKUP}"
    fi
}

# 生成调优配置文件内容（统一函数，确保 apply_bbr_tuning 和 auto_tune 一致）
write_tune_conf() {
    cat > "$TUNE_CONF" << 'EOF'
# ===== sing-box 网络调优 =====
# 注意：所有参数针对代理服务器场景优化
# 适用于高延迟、国际线路的代理流量
# 安全说明：仅修改 sysctl 参数，不安装任何第三方软件

# ============ 拥塞控制 ============
# BBR: 基于带宽和RTT模型，比CUBIC在高延迟/丢包线路上表现更好
net.ipv4.tcp_congestion_control = bbr

# fq: 公平队列，配合BBR使用效果最佳
net.core.default_qdisc = fq

# ============ TCP 缓冲区（针对高BDP国际线路）============
# 16MB 上限足够覆盖 250ms RTT × 500Mbps
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 262144 16777216
net.ipv4.tcp_wmem = 4096 262144 16777216

# 16KB: 减少内核缓冲的小包数量，降低延迟
net.ipv4.tcp_notsent_lowat = 16384

# 长连接空闲后不重置拥塞窗口，代理长连接友好
net.ipv4.tcp_slow_start_after_idle = 0

# 避免使用历史路由缓存，防止错误判断
net.ipv4.tcp_no_metrics_save = 1

# 自动探测路径MTU，避免分片
net.ipv4.tcp_mtu_probing = 1

# ============ 宽带缓存 / backlog（提升突发流量处理）============
# 网卡接收队列最大长度（默认1000，提到16384应对突发）
net.core.netdev_max_backlog = 16384

# socket 监听队列上限（代理服务高并发友好）
net.core.somaxconn = 8192

# SYN 队列上限（防 SYN flood，同时支持高并发握手）
net.ipv4.tcp_max_syn_backlog = 8192

# TIME_WAIT 套接字数量上限（默认约4000，代理流量大时容易耗尽）
net.ipv4.tcp_max_tw_buckets = 55000

# 允许复用 TIME_WAIT 端口（代理短连接场景显著减少端口耗尽）
net.ipv4.tcp_tw_reuse = 1

# FIN-WAIT-2 状态超时（默认60s，缩短到15s释放更快）
net.ipv4.tcp_fin_timeout = 15

# 本地端口范围（默认32768-60999，扩展到1024-65535）
net.ipv4.ip_local_port_range = 1024 65535

# keepalive 探测间隔（默认7200s，缩短到600s更快释放死连接）
net.ipv4.tcp_keepalive_time = 600

# TCP Fast Open（3=客户端+服务端都启用）
net.ipv4.tcp_fastopen = 3

# ============ SWAP / 虚拟内存 ============
# 降低 swap 倾向（默认60，代理服务器优先用物理内存）
vm.swappiness = 10

# 减少 inode/dentry cache 回收压力（默认100，调到50保留更多文件缓存）
vm.vfs_cache_pressure = 50

# 脏页比例上限（默认20%，降到10%减少突发IO造成的延迟）
vm.dirty_ratio = 10

# 后台异步写脏页比例（默认10%，降到5%更平滑）
vm.dirty_background_ratio = 5

# 允许内存超分（代理服务长连接多，1=总是允许）
vm.overcommit_memory = 1
EOF
}

# ==================== 应用 BBR 调优 ====================
apply_bbr_tuning() {
    local kernel_status=$(check_kernel_version)
    if [[ "$kernel_status" == "old" ]]; then
        print_error "内核版本过低（需要 4.9+），当前: $(uname -r)"
        print_warning "Alpine 请运行: apk add linux-lts；Debian 请升级内核"
        return 1
    fi

    local bbr_status=$(check_bbr_available)
    if [[ "$bbr_status" == "no" ]]; then
        print_error "BBR 模块不可用"
        if [[ $ALPINE -eq 1 ]]; then
            print_warning "Alpine 需要: apk add linux-lts（BBR 内置于内核模块）"
        else
            print_warning "尝试: modprobe tcp_bbr，或更新内核"
        fi
        return 1
    fi

    # 备份
    backup_sysctl

    print_info "应用 BBR + 缓冲区 + 宽带缓存 + SWAP 调优..."

    # 写入配置文件（幂等：直接覆盖）
    write_tune_conf

    # 应用配置
    if sysctl --system >/dev/null 2>&1; then
        touch "$TUNE_FLAG"
        print_success "网络调优已应用（BBR/缓冲区/宽带缓存/SWAP）"
        show_tune_status
    else
        print_error "sysctl 应用失败，请检查配置"
        return 1
    fi
}

# ==================== 自建 swap 文件（安全方式）====================
# 创建 swap 文件（如果当前没有 swap 且用户确认）
setup_swap_file() {
    # 检查当前 swap 状态
    local current_swap=$(swapon --show 2>/dev/null | wc -l)
    if [[ $current_swap -gt 0 ]]; then
        print_info "当前已存在 swap 分区/文件："
        swapon --show 2>/dev/null
        if ! confirm "是否仍要创建额外的 swap 文件？(y/N): "; then
            return 0
        fi
    fi

    # 检测物理内存大小，建议 swap = 内存大小（上限 4GB）
    local mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    if [[ -z "$mem_mb" || "$mem_mb" -eq 0 ]]; then
        mem_mb=1024
    fi
    local suggested_swap=2048
    if [[ $mem_mb -lt 1024 ]]; then
        suggested_swap=1024
    elif [[ $mem_mb -gt 4096 ]]; then
        suggested_swap=4096
    else
        suggested_swap=$mem_mb
    fi

    echo ""
    echo -e "${CYAN}建议 swap 大小: ${suggested_swap}MB${NC}"
    echo -e "${CYAN}swap 文件路径: ${TUNE_SWAP_FILE}${NC}"
    echo ""
    read -p "请输入 swap 大小(MB，默认 ${suggested_swap}): " swap_size
    swap_size="${swap_size:-$suggested_swap}"

    if ! [[ "$swap_size" =~ ^[0-9]+$ ]] || (( swap_size < 64 || swap_size > 8192 )); then
        print_error "swap 大小无效（允许范围 64-8192 MB）"
        return 1
    fi

    # 检查磁盘剩余空间（至少需要 swap_size + 1GB）
    local free_mb=$(df -m / 2>/dev/null | awk 'NR==2{print $4}')
    if [[ -n "$free_mb" ]] && (( free_mb < swap_size + 1024 )); then
        print_error "磁盘剩余空间不足（需要至少 $((swap_size + 1024))MB，当前 ${free_mb}MB）"
        return 1
    fi

    if [[ -f "$TUNE_SWAP_FILE" ]]; then
        print_warning "swap 文件已存在，将先关闭并删除"
        swapoff "$TUNE_SWAP_FILE" 2>/dev/null
        rm -f "$TUNE_SWAP_FILE"
    fi

    print_info "创建 ${swap_size}MB swap 文件..."
    # 使用 fallocate 快速创建（如果失败回退到 dd）
    if ! fallocate -l "${swap_size}M" "$TUNE_SWAP_FILE" 2>/dev/null; then
        print_info "fallocate 不可用，使用 dd 创建（可能较慢）..."
        if ! dd if=/dev/zero of="$TUNE_SWAP_FILE" bs=1M count="$swap_size" status=none 2>/dev/null; then
            print_error "swap 文件创建失败"
            rm -f "$TUNE_SWAP_FILE"
            return 1
        fi
    fi

    # 设置权限（仅 root 可读写）
    chmod 600 "$TUNE_SWAP_FILE"

    # 格式化为 swap
    if ! mkswap "$TUNE_SWAP_FILE" >/dev/null 2>&1; then
        print_error "mkswap 失败"
        rm -f "$TUNE_SWAP_FILE"
        return 1
    fi

    # 启用 swap
    if ! swapon "$TUNE_SWAP_FILE" 2>/dev/null; then
        print_error "swapon 失败"
        rm -f "$TUNE_SWAP_FILE"
        return 1
    fi

    # 持久化到 fstab（幂等：先检查是否已存在）
    if ! grep -q "^${TUNE_SWAP_FILE} " /etc/fstab 2>/dev/null; then
        echo "${TUNE_SWAP_FILE} none swap sw 0 0" >> /etc/fstab
        print_info "已添加到 /etc/fstab（开机自动挂载）"
    fi

    print_success "swap 文件已创建并启用"
    echo ""
    swapon --show 2>/dev/null
    echo ""
    free -h 2>/dev/null
}

# 移除自建的 swap 文件
remove_swap_file() {
    if [[ ! -f "$TUNE_SWAP_FILE" ]]; then
        print_warning "未找到自建 swap 文件: ${TUNE_SWAP_FILE}"
        return 0
    fi

    if ! confirm "确认移除 swap 文件 ${TUNE_SWAP_FILE}？(y/N): "; then
        return 0
    fi

    print_info "关闭 swap..."
    swapoff "$TUNE_SWAP_FILE" 2>/dev/null

    # 从 fstab 移除
    if grep -q "^${TUNE_SWAP_FILE} " /etc/fstab 2>/dev/null; then
        sed -i "\|^${TUNE_SWAP_FILE} |d" /etc/fstab
        print_info "已从 /etc/fstab 移除"
    fi

    rm -f "$TUNE_SWAP_FILE"
    print_success "swap 文件已移除"
}

# ==================== 恢复默认配置 ====================
restore_default_tuning() {
    if [[ ! -f "$TUNE_CONF" ]] && [[ ! -f "$TUNE_BACKUP" ]]; then
        print_warning "未找到调优配置，无需恢复"
        return 0
    fi

    if ! confirm "确认恢复默认 sysctl 配置？(y/N): "; then
        return 0
    fi

    print_info "恢复默认配置..."

    rm -f "$TUNE_CONF"
    rm -f "$TUNE_FLAG"

    # 重新加载 sysctl
    sysctl --system >/dev/null 2>&1

    # 恢复备份的值
    if [[ -f "$TUNE_BACKUP" ]]; then
        print_info "从备份恢复原始值..."
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value="${value#\"}"
            value="${value%\"}"
            sysctl -w "$key=$value" >/dev/null 2>&1
        done < "$TUNE_BACKUP"
        print_success "已从备份恢复 sysctl 值"
    else
        print_success "已删除调优配置，系统使用默认值"
    fi

    # 询问是否同时移除 swap 文件
    if [[ -f "$TUNE_SWAP_FILE" ]]; then
        echo ""
        if confirm "是否同时移除自建 swap 文件 ${TUNE_SWAP_FILE}？(y/N): "; then
            remove_swap_file
        fi
    fi
}

# ==================== 显示当前调优状态 ====================
show_tune_status() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  当前网络调优状态${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    local rmem_max=$(sysctl -n net.core.rmem_max 2>/dev/null)
    local wmem_max=$(sysctl -n net.core.wmem_max 2>/dev/null)
    local tcp_rmem=$(sysctl -n net.ipv4.tcp_rmem 2>/dev/null)
    local tcp_wmem=$(sysctl -n net.ipv4.tcp_wmem 2>/dev/null)
    local notsent=$(sysctl -n net.ipv4.tcp_notsent_lowat 2>/dev/null)
    local slow_start=$(sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null)

    # 宽带缓存
    local netdev_backlog=$(sysctl -n net.core.netdev_max_backlog 2>/dev/null)
    local somaxconn=$(sysctl -n net.core.somaxconn 2>/dev/null)
    local syn_backlog=$(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null)
    local tw_buckets=$(sysctl -n net.ipv4.tcp_max_tw_buckets 2>/dev/null)
    local tw_reuse=$(sysctl -n net.ipv4.tcp_tw_reuse 2>/dev/null)
    local fin_timeout=$(sysctl -n net.ipv4.tcp_fin_timeout 2>/dev/null)
    local port_range=$(sysctl -n net.ipv4.ip_local_port_range 2>/dev/null)
    local keepalive=$(sysctl -n net.ipv4.tcp_keepalive_time 2>/dev/null)
    local fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null)

    # SWAP / 虚拟内存
    local swappiness=$(sysctl -n vm.swappiness 2>/dev/null)
    local vfs_cache=$(sysctl -n vm.vfs_cache_pressure 2>/dev/null)
    local dirty_ratio=$(sysctl -n vm.dirty_ratio 2>/dev/null)
    local dirty_bg=$(sysctl -n vm.dirty_background_ratio 2>/dev/null)
    local overcommit=$(sysctl -n vm.overcommit_memory 2>/dev/null)

    echo -e "  ${YELLOW}内核版本:${NC}     $(uname -r)"
    echo ""

    # BBR 状态
    if [[ "$cc" == "bbr" ]]; then
        echo -e "  ${YELLOW}拥塞控制:${NC}     ${GREEN}BBR ✓${NC}"
    else
        echo -e "  ${YELLOW}拥塞控制:${NC}     ${RED}${cc}${NC} ${YELLOW}(建议 BBR)${NC}"
    fi

    # 队列规则
    if [[ "$qdisc" == "fq" ]]; then
        echo -e "  ${YELLOW}队列规则:${NC}     ${GREEN}fq ✓${NC}"
    else
        echo -e "  ${YELLOW}队列规则:${NC}     ${RED}${qdisc}${NC} ${YELLOW}(建议 fq)${NC}"
    fi

    echo ""
    echo -e "  ${YELLOW}TCP 缓冲区:${NC}"
    echo -e "    rmem_max:    ${rmem_max}"
    echo -e "    wmem_max:    ${wmem_max}"
    echo -e "    tcp_rmem:    ${tcp_rmem}"
    echo -e "    tcp_wmem:    ${tcp_wmem}"
    echo -e "    notsent_lowat:           ${notsent}"
    echo -e "    slow_start_after_idle:   ${slow_start} ${YELLOW}(0=禁用,建议)${NC}"

    echo ""
    echo -e "  ${YELLOW}宽带缓存 / backlog:${NC}"
    echo -e "    netdev_max_backlog:   ${netdev_backlog} ${YELLOW}(建议 16384)${NC}"
    echo -e "    somaxconn:            ${somaxconn} ${YELLOW}(建议 8192)${NC}"
    echo -e "    tcp_max_syn_backlog:  ${syn_backlog}"
    echo -e "    tcp_max_tw_buckets:   ${tw_buckets}"
    echo -e "    tcp_tw_reuse:         ${tw_reuse} ${YELLOW}(1=启用,建议)${NC}"
    echo -e "    tcp_fin_timeout:      ${fin_timeout}s"
    echo -e "    ip_local_port_range: ${port_range}"
    echo -e "    tcp_keepalive_time:  ${keepalive}s"
    echo -e "    tcp_fastopen:         ${fastopen} ${YELLOW}(3=双向启用)${NC}"

    echo ""
    echo -e "  ${YELLOW}SWAP / 虚拟内存:${NC}"
    echo -e "    vm.swappiness:              ${swappiness} ${YELLOW}(建议 10)${NC}"
    echo -e "    vm.vfs_cache_pressure:      ${vfs_cache} ${YELLOW}(建议 50)${NC}"
    echo -e "    vm.dirty_ratio:             ${dirty_ratio}%"
    echo -e "    vm.dirty_background_ratio:  ${dirty_bg}%"
    echo -e "    vm.overcommit_memory:       ${overcommit}"
    echo ""

    # SWAP 文件状态
    echo -e "  ${YELLOW}SWAP 状态:${NC}"
    if swapon --show 2>/dev/null | tail -n +2 | grep -q .; then
        swapon --show 2>/dev/null | sed 's/^/    /'
    else
        echo -e "    ${RED}(未启用 swap)${NC}"
    fi

    echo ""
    # 配置文件状态
    if [[ -f "$TUNE_CONF" ]]; then
        echo -e "  ${GREEN}调优配置文件: ${TUNE_CONF} (已启用)${NC}"
    else
        echo -e "  ${YELLOW}调优配置文件: 未启用${NC}"
    fi
    if [[ -f "$TUNE_SWAP_FILE" ]]; then
        echo -e "  ${GREEN}自建 swap 文件: ${TUNE_SWAP_FILE}${NC}"
    fi

    # 实时连接信息（仅统计 bbr/cubic/reno 三种拥塞算法）
    # 用 ss -tiH 强制单行 + head -n1 兜底，避免 grep -c 异常输出破坏 $(( ))
    local ss_out
    ss_out=$(ss -tiH 2>/dev/null || true)
    local bbr_conns=$(echo "$ss_out" | grep -c 'bbr' || true)
    local cubic_conns=$(echo "$ss_out" | grep -c 'cubic' || true)
    local reno_conns=$(echo "$ss_out" | grep -c 'reno' || true)
    # 强制只取第一行（防御性：grep -c 正常只输出一行数字）
    bbr_conns=$(echo "$bbr_conns" | head -n1 | tr -cd '0-9')
    cubic_conns=$(echo "$cubic_conns" | head -n1 | tr -cd '0-9')
    reno_conns=$(echo "$reno_conns" | head -n1 | tr -cd '0-9')
    bbr_conns=${bbr_conns:-0}
    cubic_conns=${cubic_conns:-0}
    reno_conns=${reno_conns:-0}
    local total_conns=$((bbr_conns + cubic_conns + reno_conns))

    echo ""
    if [[ $total_conns -gt 0 ]]; then
        echo -e "  ${YELLOW}实时 TCP 连接:${NC}"
        echo -e "    BBR 连接:   ${GREEN}${bbr_conns}${NC}"
        [[ $cubic_conns -gt 0 ]] && echo -e "    CUBIC 连接: ${cubic_conns}"
        [[ $reno_conns -gt 0 ]] && echo -e "    Reno 连接:  ${reno_conns}"
    fi
    echo ""
}

# ==================== 自动调优（安装时调用）====================
auto_tune() {
    # 如果已经调优过，跳过
    if [[ -f "$TUNE_FLAG" ]]; then
        return 0
    fi

    # 检测内核
    local kernel_status=$(check_kernel_version)
    if [[ "$kernel_status" == "old" ]]; then
        return 0
    fi

    # 检测 BBR
    local bbr_status=$(check_bbr_available)
    if [[ "$bbr_status" == "no" ]]; then
        return 0
    fi

    # 静默应用调优
    backup_sysctl
    write_tune_conf

    if sysctl --system >/dev/null 2>&1; then
        touch "$TUNE_FLAG"
        print_success "网络调优已自动应用（BBR/缓冲区/宽带缓存/SWAP）"
    fi

    # 自动创建 swap：仅当物理内存 < 2GB 且当前无 swap 时
    # 大内存机器不需要，避免无谓占用磁盘
    local current_swap=$(swapon --show 2>/dev/null | wc -l)
    if [[ $current_swap -eq 0 ]]; then
        local mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
        if [[ -n "$mem_mb" ]] && (( mem_mb < 2048 )); then
            # 静默创建 1024MB swap（小内存机器兜底）
            if fallocate -l 1024M "$TUNE_SWAP_FILE" 2>/dev/null || \
               dd if=/dev/zero of="$TUNE_SWAP_FILE" bs=1M count=1024 status=none 2>/dev/null; then
                chmod 600 "$TUNE_SWAP_FILE" 2>/dev/null
                mkswap "$TUNE_SWAP_FILE" >/dev/null 2>&1
                swapon "$TUNE_SWAP_FILE" 2>/dev/null && {
                    grep -q "^${TUNE_SWAP_FILE} " /etc/fstab 2>/dev/null || \
                        echo "${TUNE_SWAP_FILE} none swap sw 0 0" >> /etc/fstab
                    print_success "检测到小内存 (${mem_mb}MB) 无 swap，已自动创建 1024MB swap"
                }
            fi
        fi
    fi
}

# ==================== 调优菜单 ====================
tune_menu() {
    while true; do
        echo ""
        menu_header "网络调优配置"
        echo ""

        # 显示当前状态摘要
        local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
        local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
        local swappiness=$(sysctl -n vm.swappiness 2>/dev/null)
        local has_swap=$(swapon --show 2>/dev/null | wc -l)
        local status_icon

        if [[ "$cc" == "bbr" && "$qdisc" == "fq" ]]; then
            status_icon="${GREEN}已启用${NC}"
        elif [[ -f "$TUNE_CONF" ]]; then
            status_icon="${YELLOW}部分启用${NC}"
        else
            status_icon="${RED}未启用${NC}"
        fi

        echo -e "  当前状态: ${status_icon}"
        echo -e "  内核版本: $(uname -r)"
        echo -e "  拥塞控制: ${cc}    swappiness: ${swappiness}"
        if [[ $has_swap -gt 0 ]]; then
            echo -e "  SWAP: ${GREEN}已启用${NC}"
        else
            echo -e "  SWAP: ${YELLOW}未启用${NC}"
        fi
        echo ""
        echo -e "  ${GREEN}[1]${NC} 一键应用全套调优（BBR+缓冲区+宽带缓存+SWAP参数）"
        echo ""
        echo -e "  ${GREEN}[2]${NC} 查看详细调优状态"
        echo ""
        echo -e "  ${GREEN}[3]${NC} 恢复默认配置"
        echo ""
        echo -e "  ${GREEN}[4]${NC} 创建/管理自建 swap 文件"
        echo ""
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        read -p "请选择 [0-4]: " t_choice

        case $t_choice in
            1)
                apply_bbr_tuning
                ;;
            2)
                show_tune_status
                ;;
            3)
                restore_default_tuning
                ;;
            4)
                swap_file_menu
                ;;
            0)
                break
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
        echo ""
        pause "按回车继续..."
    done
}

# ==================== swap 文件子菜单 ====================
swap_file_menu() {
    while true; do
        echo ""
        menu_header "自建 Swap 文件管理"
        echo ""

        if swapon --show 2>/dev/null | tail -n +2 | grep -q .; then
            echo -e "${YELLOW}当前 SWAP 状态:${NC}"
            swapon --show 2>/dev/null | sed 's/^/  /'
        else
            echo -e "${YELLOW}当前 SWAP 状态: ${RED}未启用${NC}"
        fi
        echo ""
        if [[ -f "$TUNE_SWAP_FILE" ]]; then
            echo -e "  自建文件: ${GREEN}${TUNE_SWAP_FILE}${NC}"
            local swap_size=$(du -m "$TUNE_SWAP_FILE" 2>/dev/null | cut -f1)
            [[ -n "$swap_size" ]] && echo -e "  文件大小: ${swap_size}MB"
        else
            echo -e "  自建文件: ${YELLOW}未创建${NC}"
        fi
        echo ""
        echo -e "  ${GREEN}[1]${NC} 创建/重建 swap 文件"
        echo ""
        echo -e "  ${GREEN}[2]${NC} 移除自建 swap 文件"
        echo ""
        echo -e "  ${GREEN}[0]${NC} 返回调优菜单"
        echo ""
        read -p "请选择 [0-2]: " s_choice

        case $s_choice in
            1)
                setup_swap_file
                ;;
            2)
                remove_swap_file
                ;;
            0)
                break
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
    done
}
