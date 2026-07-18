# ==================== 系统网络调优模块 ====================
# 安全第一：所有操作仅修改 sysctl 参数，不安装任何第三方软件
# 适用 Alpine / Debian / Ubuntu，所有改动可一键恢复

# 调优配置文件路径
TUNE_CONF="/etc/sysctl.d/99-sing-box-tuning.conf"
TUNE_FLAG="/etc/sing-box/.tune_applied"

# 调优前备份原配置（仅首次）
TUNE_BACKUP="/etc/sing-box/sysctl.backup"

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
        # 记录当前拥塞控制和队列规则
        {
            echo "# sysctl 备份 - $(date)"
            echo "# 调优前的原始值"
            echo "net.ipv4.tcp_congestion_control=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
            echo "net.core.default_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)"
            echo "net.core.rmem_max=$(sysctl -n net.core.rmem_max 2>/dev/null)"
            echo "net.core.wmem_max=$(sysctl -n net.core.wmem_max 2>/dev/null)"
            echo "net.ipv4.tcp_rmem=\"$(sysctl -n net.ipv4.tcp_rmem 2>/dev/null)\""
            echo "net.ipv4.tcp_wmem=\"$(sysctl -n net.ipv4.tcp_wmem 2>/dev/null)\""
            echo "net.ipv4.tcp_notsent_lowat=$(sysctl -n net.ipv4.tcp_notsent_lowat 2>/dev/null)"
            echo "net.ipv4.tcp_slow_start_after_idle=$(sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null)"
            echo "net.ipv4.tcp_no_metrics_save=$(sysctl -n net.ipv4.tcp_no_metrics_save 2>/dev/null)"
            echo "net.ipv4.tcp_mtu_probing=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)"
        } > "$TUNE_BACKUP" 2>/dev/null
        print_info "原 sysctl 配置已备份到 ${TUNE_BACKUP}"
    fi
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

    print_info "应用 BBR + 缓冲区调优..."

    # 写入配置文件（幂等：直接覆盖）
    cat > "$TUNE_CONF" << 'EOF'
# ===== sing-box 网络调优 =====
# 注意：所有参数针对代理服务器场景优化
# 适用于高延迟、国际线路的代理流量

# --- 拥塞控制 ---
# BBR: 基于带宽和RTT模型，比CUBIC在高延迟/丢包线路上表现更好
net.ipv4.tcp_congestion_control = bbr

# --- 队列规则 ---
# fq: 公平队列，配合BBR使用效果最佳
net.core.default_qdisc = fq

# --- TCP 缓冲区（针对高BDP国际线路）---
# 16MB 上限足够覆盖 250ms RTT × 500Mbps
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 262144 16777216
net.ipv4.tcp_wmem = 4096 262144 16777216

# --- 减少小包积压 ---
# 16KB: 减少内核缓冲的小包数量，降低延迟
net.ipv4.tcp_notsent_lowat = 16384

# --- 禁用慢启动重启 ---
# 长连接空闲后不重置拥塞窗口，代理长连接友好
net.ipv4.tcp_slow_start_after_idle = 0

# --- 不缓存路由指标 ---
# 避免使用历史路由缓存，防止错误判断
net.ipv4.tcp_no_metrics_save = 1

# --- MTU 探测 ---
# 自动探测路径MTU，避免分片
net.ipv4.tcp_mtu_probing = 1
EOF

    # 应用配置
    if sysctl --system >/dev/null 2>&1; then
        touch "$TUNE_FLAG"
        print_success "BBR 调优已应用"
        show_tune_status
    else
        print_error "sysctl 应用失败，请检查配置"
        return 1
    fi
}

# ==================== 恢复默认配置 ====================
restore_default_tuning() {
    if [[ ! -f "$TUNE_CONF" ]]; then
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
        print_success "已从备份恢复"
    else
        print_success "已删除调优配置，系统使用默认值"
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
    echo -e "  ${YELLOW}缓冲区上限:${NC}"
    echo -e "    rmem_max:    ${rmem_max}"
    echo -e "    wmem_max:    ${wmem_max}"
    echo -e "    tcp_rmem:    ${tcp_rmem}"
    echo -e "    tcp_wmem:    ${tcp_wmem}"
    echo ""
    echo -e "  ${YELLOW}其他参数:${NC}"
    echo -e "    notsent_lowat:           ${notsent}"
    echo -e "    slow_start_after_idle:   ${slow_start} ${YELLOW}(0=禁用,建议)${NC}"
    echo ""

    # 配置文件状态
    if [[ -f "$TUNE_CONF" ]]; then
        echo -e "  ${GREEN}调优配置文件: ${TUNE_CONF} (已启用)${NC}"
    else
        echo -e "  ${YELLOW}调优配置文件: 未启用${NC}"
    fi

    # 实时连接信息
    local bbr_conns=$(ss -tin 2>/dev/null | grep -c bbr 2>/dev/null || echo 0)
    local cubic_conns=$(ss -tin 2>/dev/null | grep -c cubic 2>/dev/null || echo 0)
    local reno_conns=$(ss -tin 2>/dev/null | grep -c reno 2>/dev/null || echo 0)
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

    cat > "$TUNE_CONF" << 'EOF'
# ===== sing-box 网络调优（自动应用）=====
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 262144 16777216
net.ipv4.tcp_wmem = 4096 262144 16777216
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_mtu_probing = 1
EOF

    sysctl --system >/dev/null 2>&1
    touch "$TUNE_FLAG"
    print_success "BBR 网络调优已自动应用"
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
        echo -e "  拥塞控制: ${cc}"
        echo ""
        echo -e "  ${GREEN}[1]${NC} 一键应用 BBR 调优（推荐）"
        echo ""
        echo -e "  ${GREEN}[2]${NC} 查看详细调优状态"
        echo ""
        echo -e "  ${GREEN}[3]${NC} 恢复默认配置"
        echo ""
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        read -p "请选择 [0-3]: " t_choice

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
