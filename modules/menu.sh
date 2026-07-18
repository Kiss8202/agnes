# ==================== sing-box 菜单系统模块 ====================
# ==================== 协议选择菜单 ====================
show_menu() {
    show_banner
    echo -e "${YELLOW}请选择要添加的协议节点:${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC} VlessReality ${CYAN}→ 抗审查最强，伪装真实TLS，无需证书${NC} ${YELLOW}(⭐ 强烈推荐)${NC}"
    echo ""
    echo -e "${GREEN}[2]${NC} Hysteria2 ${CYAN}→ 基于QUIC，速度快，垃圾线路专用${NC}"
    echo ""
    echo -e "${GREEN}[3]${NC} SOCKS5 ${CYAN}→ 适合中转的代理协议${NC}"
    echo ""
    echo -e "${GREEN}[4]${NC} ShadowTLS v3 ${CYAN}→ TLS流量伪装${NC}"
    echo ""
    echo -e "${GREEN}[5]${NC} HTTPS ${CYAN}→ 标准HTTPS，可过CDN${NC}"
    echo ""
    echo -e "${GREEN}[6]${NC} AnyTLS ${CYAN}→ 通用 TLS 协议，可启用 REALITY 伪装${NC}"
    echo ""
    read -p "选择 [1-6]: " choice
    
    case $choice in
        1)
            setup_reality
            ;;
        2)
            setup_hysteria2
            ;;
        3)
            setup_socks5
            ;;
        4)
            setup_shadowtls
            ;;
        5)
            setup_https
            ;;
        6)
            setup_anytls
            ;;
        *)
            print_error "无效选项"
            return 1
            ;;
    esac
    
    if [[ -n "$INBOUNDS_JSON" ]]; then
        generate_config || return 1
        start_svc || return 1
        show_result
    fi
}
# ==================== 主菜单 ====================
show_main_menu() {
    show_banner
    menu_header "Sing-Box 一键管理面板"
    
    # 显示出入站配置
    echo -e "${YELLOW}当前出入站配置:${NC}"
    if [[ -n "$SERVER_IP" ]]; then
        echo -e "  IPv4 地址: ${GREEN}${SERVER_IP}${NC}"
    fi
    if [[ -n "$SERVER_IPV6" ]]; then
        echo -e "  IPv6 地址: ${GREEN}${SERVER_IPV6}${NC}"
    fi
    echo -e "  ${CYAN}└─${NC} 入站模式: ${GREEN}${INBOUND_IP_MODE}${NC}     出站模式: ${GREEN}${OUTBOUND_IP_MODE}${NC}"
    echo ""
    
    # 统计中转使用情况
    local relay_count=0
    local direct_count=0
    
    # 统计每个中转被使用的次数
    declare -A relay_usage
    
    for relay_tag in "${INBOUND_RELAY_TAGS[@]}"; do
        if [[ "$relay_tag" == "direct" ]]; then
            ((direct_count++))
        else
            ((relay_count++))
            if [[ -n "${relay_usage[$relay_tag]}" ]]; then
                relay_usage[$relay_tag]=$((${relay_usage[$relay_tag]} + 1))
            else
                relay_usage[$relay_tag]=1
            fi
        fi
    done
    
    # 显示出站状态
    local outbound_desc
    if [[ $relay_count -gt 0 ]]; then
        declare -A relay_proto_count
        for relay_tag in "${!relay_usage[@]}"; do
            for i in "${!RELAY_TAGS[@]}"; do
                if [[ "${RELAY_TAGS[$i]}" == "$relay_tag" ]]; then
                    local proto=$(echo "${RELAY_DESCS[$i]}" | cut -d' ' -f1)
                    if [[ -n "${relay_proto_count[$proto]}" ]]; then
                        relay_proto_count[$proto]=$((${relay_proto_count[$proto]} + ${relay_usage[$relay_tag]}))
                    else
                        relay_proto_count[$proto]=${relay_usage[$relay_tag]}
                    fi
                    break
                fi
            done
        done
        
        local proto_list=""
        for proto in "${!relay_proto_count[@]}"; do
            [[ -n "$proto_list" ]] && proto_list+=", "
            proto_list+="${proto}:${relay_proto_count[$proto]}"
        done
        
        outbound_desc="中转 (直连:${direct_count} 中转:${relay_count} [${proto_list}])"
    else
        outbound_desc="直连"
    fi
    
    echo -e "  ${YELLOW}当前出站: ${GREEN}${outbound_desc}${NC}"
    
    # 显示中转列表详情
    if [[ ${#RELAY_TAGS[@]} -gt 0 ]]; then
        declare -A relay_type_count
        for desc in "${RELAY_DESCS[@]}"; do
            local proto=$(echo "$desc" | cut -d' ' -f1)
            if [[ -n "${relay_type_count[$proto]}" ]]; then
                relay_type_count[$proto]=$((${relay_type_count[$proto]} + 1))
            else
                relay_type_count[$proto]=1
            fi
        done
        
        local relay_list=""
        for proto in "${!relay_type_count[@]}"; do
            [[ -n "$relay_list" ]] && relay_list+=", "
            relay_list+="${proto}:${relay_type_count[$proto]}"
        done
        
        echo -e "  ${YELLOW}中转列表: ${GREEN}${#RELAY_TAGS[@]} 个 [${relay_list}]${NC}"
        
        if [[ $relay_count -gt 0 ]]; then
            local relay_nodes=""
            for i in "${!INBOUND_RELAY_TAGS[@]}"; do
                if [[ "${INBOUND_RELAY_TAGS[$i]}" != "direct" ]]; then
                    [[ -n "$relay_nodes" ]] && relay_nodes+=", "
                    relay_nodes+="${INBOUND_PROTOS[$i]}:${INBOUND_PORTS[$i]}"
                fi
            done
            echo -e "  ${CYAN}  └─ 使用中转: ${relay_nodes}${NC}"
        fi
    fi
    
    # 统计各协议节点数
    local reality_count=0
    local hysteria2_count=0
    local socks5_count=0
    local shadowtls_count=0
    local https_count=0
    local anytls_count=0
    
    for proto in "${INBOUND_PROTOS[@]}"; do
        case "$proto" in
            "Reality") ((reality_count++)) ;;
            "Hysteria2") ((hysteria2_count++)) ;;
            "SOCKS5") ((socks5_count++)) ;;
            "ShadowTLS v3") ((shadowtls_count++)) ;;
            "HTTPS") ((https_count++)) ;;
            "AnyTLS") ((anytls_count++)) ;;
            "AnyTLS+REALITY") ((anytls_count++)) ;;
        esac
    done
    
    echo -e "  ${YELLOW}当前节点数: ${GREEN}${#INBOUND_TAGS[@]}${NC}"
    
    if [[ ${#INBOUND_TAGS[@]} -gt 0 ]]; then
        local node_details=""
        [[ $reality_count -gt 0 ]] && node_details="${node_details}Reality:${reality_count} "
        [[ $hysteria2_count -gt 0 ]] && node_details="${node_details}Hysteria2:${hysteria2_count} "
        [[ $socks5_count -gt 0 ]] && node_details="${node_details}SOCKS5:${socks5_count} "
        [[ $shadowtls_count -gt 0 ]] && node_details="${node_details}ShadowTLS:${shadowtls_count} "
        [[ $https_count -gt 0 ]] && node_details="${node_details}HTTPS:${https_count} "
        [[ $anytls_count -gt 0 ]] && node_details="${node_details}AnyTLS:${anytls_count} "
        
        if [[ -n "$node_details" ]]; then
            echo -e "  ${CYAN}  └─ ${node_details}${NC}"
        fi
    fi
    echo ""
        echo -e "  ${GREEN}[1]${NC} 添加/继续添加节点"
        echo ""
        echo -e "  ${GREEN}[2]${NC} 中转配置 (添加/配置/删除/域名分流)"
        echo ""
        echo -e "  ${GREEN}[3]${NC} 出入站配置 (IPv4/IPv6)"
        echo ""
        echo -e "  ${GREEN}[4]${NC} 配置/查看节点"
        echo ""
        echo -e "  ${GREEN}[5]${NC} 重新生成链接文件"
        echo ""
        echo -e "  ${GREEN}[6]${NC} 一键删除脚本并退出"
        echo ""
        echo -e "  ${GREEN}[7]${NC} DNS 配置"
        echo ""
        echo -e "  ${GREEN}[8]${NC} 网络调优 (BBR/缓冲区)"
        echo ""
        echo -e "  ${GREEN}[0]${NC} 退出脚本"
        echo ""
}

# ==================== 修改节点菜单 ====================
modify_node_menu() {
    if [[ ${#INBOUND_TAGS[@]} -eq 0 ]]; then
        print_warning "当前没有可修改的节点"
        return 1
    fi

    # 直接列出所有节点，让用户选择
    echo ""
    echo -e "${CYAN}当前所有节点:${NC}"
    for i in "${!INBOUND_TAGS[@]}"; do
        local idx=$((i+1))
        local proto="${INBOUND_PROTOS[$i]}"
        local port="${INBOUND_PORTS[$i]}"
        local sni="${INBOUND_SNIS[$i]}"
        local tag="${INBOUND_TAGS[$i]}"
        if [[ -n "$sni" && "$sni" != "-" ]]; then
            echo -e "  ${GREEN}[${idx}]${NC} ${proto} | 端口: ${port} | SNI: ${sni} | TAG: ${tag}"
        else
            echo -e "  ${GREEN}[${idx}]${NC} ${proto} | 端口: ${port} | TAG: ${tag}"
        fi
    done
    echo ""
    echo -e "  ${GREEN}[0]${NC} 返回"
    echo ""
    read -p "请选择要修改的节点序号: " node_choice

    [[ "$node_choice" == "0" ]] && return 0
    if ! [[ "$node_choice" =~ ^[0-9]+$ ]] || (( node_choice < 1 || node_choice > ${#INBOUND_TAGS[@]} )); then
        print_error "序号无效"
        return 1
    fi

    local array_idx=$((node_choice-1))
    local proto="${INBOUND_PROTOS[$array_idx]}"
    local tag="${INBOUND_TAGS[$array_idx]}"
    local port="${INBOUND_PORTS[$array_idx]}"
    local current_sni="${INBOUND_SNIS[$array_idx]}"

    # 根据协议类型跳转到对应的修改子菜单
    _MODIFY_CONFIG_CHANGED=0
    case "$proto" in
        Reality)        _modify_menu_Reality "$array_idx" "$tag" "$port" "$current_sni" "$proto" ;;
        Hysteria2)      _modify_menu_Hysteria2 "$array_idx" "$tag" "$port" "$current_sni" "$proto" ;;
        SOCKS5)         _modify_menu_SOCKS5 "$array_idx" "$tag" "$port" "$current_sni" "$proto" ;;
        "ShadowTLS v3") _modify_menu_ShadowTLS "$array_idx" "$tag" "$port" "$current_sni" "$proto" ;;
        HTTPS)          _modify_menu_HTTPS "$array_idx" "$tag" "$port" "$current_sni" "$proto" ;;
        AnyTLS|AnyTLS+REALITY) _modify_menu_AnyTLS "$array_idx" "$tag" "$port" "$current_sni" "$proto" ;;
        *)              print_warning "不支持的协议类型: ${proto}" ;;
    esac

    # 修改完成后统一处理
    if [[ ${_MODIFY_CONFIG_CHANGED:-0} -eq 1 ]]; then
        load_inbounds_from_config
        generate_config && start_svc
        regenerate_links_from_config
    fi
}

# ==================== 配置查看菜单 ====================
config_and_view_menu() {
    while true; do
        show_banner
        menu_header "配置 / 查看节点菜单"
        echo -e "  ${GREEN}[1]${NC} 重新加载配置并启动服务"
        echo ""
        echo -e "  ${GREEN}[2]${NC} 查看全部节点链接"
        echo ""
        echo -e "  ${GREEN}[3]${NC} 查看 Reality 节点"
        echo ""
        echo -e "  ${GREEN}[4]${NC} 查看 Hysteria2 节点"
        echo ""
        echo -e "  ${GREEN}[5]${NC} 查看 SOCKS5 节点"
        echo ""
        echo -e "  ${GREEN}[6]${NC} 查看 ShadowTLS 节点"
        echo ""
        echo -e "  ${GREEN}[7]${NC} 查看 HTTPS 节点"
        echo ""
        echo -e "  ${GREEN}[8]${NC} 查看 AnyTLS 节点"
        echo ""
        echo -e "  ${GREEN}[9]${NC} 修改节点配置"
        echo ""
        echo -e "  ${GREEN}[10]${NC} 删除单个节点"
        echo ""
        echo -e "  ${GREEN}[11]${NC} 删除全部节点"
        echo ""
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        
        read -p "请选择 [0-11]: " cv_choice
        
        case $cv_choice in
            1)
                if [[ -f "${CONFIG_FILE}" ]]; then
                    if generate_config && start_svc; then
                        print_success "配置已重新加载并启动服务"
                    fi
                else
                    print_error "配置文件不存在，请先添加节点"
                fi
                pause "按回车返回..."
                ;;
            2)
                clear
                echo -e "${YELLOW}全部节点链接:${NC}"
                echo ""
                if [[ -z "$ALL_LINKS_TEXT" ]]; then
                    echo "(暂无节点)"
                else
                    echo -e "$ALL_LINKS_TEXT"
                fi
                echo ""
                pause "按回车返回..."
                ;;
            3)
                clear
                show_protocol_links "Reality 节点" "$REALITY_LINKS" "$YELLOW"
                [[ -z "$REALITY_LINKS" ]] && echo "(暂无 Reality 节点)"
                pause "按回车返回..."
                ;;
            4)
                clear
                show_protocol_links "Hysteria2 节点" "$HYSTERIA2_LINKS" "$YELLOW"
                [[ -z "$HYSTERIA2_LINKS" ]] && echo "(暂无 Hysteria2 节点)"
                pause "按回车返回..."
                ;;
            5)
                clear
                show_protocol_links "SOCKS5 节点" "$SOCKS5_LINKS" "$YELLOW"
                [[ -z "$SOCKS5_LINKS" ]] && echo "(暂无 SOCKS5 节点)"
                pause "按回车返回..."
                ;;
            6)
                clear
                show_protocol_links "ShadowTLS 节点" "$SHADOWTLS_LINKS" "$YELLOW"
                [[ -z "$SHADOWTLS_LINKS" ]] && echo "(暂无 ShadowTLS 节点)"
                [[ -n "$SHADOWTLS_LINKS" ]] && echo -e "${CYAN}提示: 可直接复制上方 ss:// 链接导入客户端 (Shadowrocket/NekoBox/v2rayN)${NC}"
                pause "按回车返回..."
                ;;
            7)
                clear
                show_protocol_links "HTTPS 节点" "$HTTPS_LINKS" "$YELLOW"
                [[ -z "$HTTPS_LINKS" ]] && echo "(暂无 HTTPS 节点)"
                pause "按回车返回..."
                ;;
            8)
                clear
                show_protocol_links "AnyTLS 节点" "$ANYTLS_LINKS" "$YELLOW"
                [[ -z "$ANYTLS_LINKS" ]] && echo "(暂无 AnyTLS 节点)"
                pause "按回车返回..."
                ;;
            9)
                modify_node_menu
                ;;
            10)
                delete_single_node
                pause "按回车返回..."
                ;;
            11)
                delete_all_nodes
                pause "按回车返回..."
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

# ==================== 完整卸载 ====================
delete_self() {
    echo -e "${YELLOW}此操作将卸载 sing-box、删除所有节点配置、证书、快捷命令 sb 和当前脚本，且无法恢复。${NC}"
    echo -e "${RED}警告：这将永久删除所有数据！${NC}"
    echo ""
    echo -e "${CYAN}注意:${NC}"
    echo -e "  1. 此操作与'删除全部节点'不同"
    echo -e "  2. '删除全部节点'只会清空配置，保留服务和脚本"
    echo -e "  3. 此操作会完全卸载 sing-box 和脚本"
    echo ""
    
    read -p "确认完全卸载？(y/N): " CONFIRM_DELETE
    CONFIRM_DELETE=${CONFIRM_DELETE:-N}
    
    if [[ ! "$CONFIRM_DELETE" =~ ^[Yy]$ ]]; then
        print_info "已取消卸载操作"
        return 0
    fi
    
    print_info "停止 sing-box 服务..."
    svc_stop
    svc_disable
    
    if [[ $ALPINE -eq 1 ]]; then
        if [[ -f /etc/init.d/sing-box ]]; then
            print_info "删除 OpenRC 服务..."
            rm -f /etc/init.d/sing-box
        fi
    else
        if [[ -f /etc/systemd/system/sing-box.service ]]; then
            print_info "删除 systemd 服务文件..."
            rm -f /etc/systemd/system/sing-box.service
            systemctl daemon-reload 2>/dev/null
        fi
    fi
    
    if [[ -d /run/sing-box ]]; then
        print_info "删除 sing-box 运行时文件..."
        rm -rf /run/sing-box 2>/dev/null
    fi
    
    if command -v sing-box &>/dev/null; then
        local sb_bin=$(command -v sing-box)
        print_info "删除 sing-box 二进制: ${sb_bin}"
        rm -f "${sb_bin}" 2>/dev/null
    else
        if [[ -f ${INSTALL_DIR}/sing-box ]]; then
            print_info "删除 sing-box 二进制: ${INSTALL_DIR}/sing-box"
            rm -f "${INSTALL_DIR}/sing-box" 2>/dev/null
        fi
    fi
    
    if [[ -d /etc/sing-box ]]; then
        print_info "删除 /etc/sing-box 配置目录..."
        rm -rf /etc/sing-box 2>/dev/null
    fi
    
    # 清理 logrotate 配置（Alpine）
    if [[ -f /etc/logrotate.d/sing-box ]]; then
        print_info "删除 logrotate 配置..."
        rm -f /etc/logrotate.d/sing-box 2>/dev/null
    fi
    
    if [[ -d ${CERT_DIR} ]]; then
        print_info "删除证书目录: ${CERT_DIR}"
        rm -rf "${CERT_DIR}" 2>/dev/null
    fi
    
    if [[ -d "${LINK_DIR}" ]]; then
        print_info "删除链接文件目录: ${LINK_DIR}"
        rm -rf "${LINK_DIR}" 2>/dev/null
    fi
    
    if [[ -f "${KEY_FILE}" ]]; then
        print_info "删除密钥文件: ${KEY_FILE}"
        rm -f "${KEY_FILE}" 2>/dev/null
    fi
    
    if [[ -d /var/log/sing-box ]]; then
        print_info "删除 sing-box 日志目录..."
        rm -rf /var/log/sing-box 2>/dev/null
    fi
    
    # 清理 journal 日志 (仅 systemd)
    if [[ $ALPINE -eq 0 ]] && command -v journalctl &>/dev/null; then
        print_info "清理 systemd journal 日志..."
        journalctl --vacuum-time=1s --quiet 2>/dev/null || true
    fi
    
    print_info "清理临时文件..."
    rm -f /tmp/sb.tar.gz 2>/dev/null
    rm -rf /tmp/sing-box-* 2>/dev/null
    
    print_info "删除快捷命令 sb..."
    for cmd in /usr/local/bin/sb /usr/bin/sb /usr/local/sbin/sb /usr/sbin/sb; do
        if [[ -f "$cmd" ]]; then
            print_info "删除快捷命令: $cmd"
            rm -f "$cmd" 2>/dev/null
        fi
    done
    
    print_info "删除当前脚本文件: ${SCRIPT_PATH}"
    rm -f "${SCRIPT_PATH}" 2>/dev/null
    
    print_success "已完成 sing-box 完整卸载和脚本清理，准备退出。"
    echo ""
    echo -e "${GREEN}✔ 所有文件已清理完成${NC}"
    echo -e "${YELLOW}注意:${NC}"
    echo -e "  1. 如果之前添加了防火墙规则，可能需要手动清理"
    echo -e "  2. 系统日志中可能还有历史记录"
    echo -e "  3. 如需重新安装，请重新下载脚本运行"
    echo ""
    
    exit 0
}

# ==================== 域名分流配置菜单 ====================
domain_route_menu() {
    while true; do
        # 加载最新的分流规则、中转和入站配置
        load_domain_routes_from_file
        load_relays_from_file
        
        show_banner
        menu_header "域名分流配置菜单"
        
        # 显示当前的分流规则（按入站节点分组）
        echo -e "${YELLOW}当前分流规则 (共 ${#DOMAIN_ROUTES[@]} 条):${NC}"
        if [[ ${#DOMAIN_ROUTES[@]} -eq 0 ]]; then
            echo "  (暂无分流规则)"
        else
            # 先按入站节点分组
            unset inbound_rules 2>/dev/null
            declare -A inbound_rules
            for route in "${DOMAIN_ROUTES[@]}"; do
                IFS='|' read -r inbound_tag match_type match_value relay_tag desc <<< "$route"
                inbound_rules["$inbound_tag"]+="$route;"
            done
            
            # 显示每个入站节点的分组
            local global_idx=1
            for inbound_tag in "${!inbound_rules[@]}"; do
                # 获取该入站节点的详细信息
                local inbound_proto=""
                local inbound_port=""
                local inbound_relay_tag=""
                local inbound_relay_info=""
                
                for i in "${!INBOUND_TAGS[@]}"; do
                    if [[ "${INBOUND_TAGS[$i]}" == "$inbound_tag" ]]; then
                        inbound_proto="${INBOUND_PROTOS[$i]}"
                        inbound_port="${INBOUND_PORTS[$i]}"
                        inbound_relay_tag="${INBOUND_RELAY_TAGS[$i]}"
                        break
                    fi
                done
                
                # 获取入站节点的连接状态信息
                if [[ "$inbound_relay_tag" == "direct" || -z "$inbound_relay_tag" ]]; then
                    # 直连状态
                    inbound_relay_info="📡 直连"
                elif [[ -n "$inbound_relay_tag" ]]; then
                    # 从 RELAY_JSONS 中提取中转配置信息
                    for j in "${!RELAY_TAGS[@]}"; do
                        if [[ "${RELAY_TAGS[$j]}" == "$inbound_relay_tag" ]]; then
                            local relay_json="${RELAY_JSONS[$j]}"
                            # 提取中转协议类型
                            local relay_type=$(echo "$relay_json" | grep -o '"type": "[^"]*"' | cut -d'"' -f4 | tr '[:lower:]' '[:upper:]')
                            # 提取服务器地址
                            local relay_server=$(echo "$relay_json" | grep -o '"server": "[^"]*"' | cut -d'"' -f4)
                            # 提取端口
                            local relay_port=$(echo "$relay_json" | grep -o '"server_port": [0-9]*' | grep -o '[0-9]*')
                            
                            if [[ -n "$relay_type" && -n "$relay_server" && -n "$relay_port" ]]; then
                                inbound_relay_info="📍 中转: ${relay_type} ${relay_server}:${relay_port}"
                            fi
                            break
                        fi
                    done
                fi
                
                # 显示入站节点和连接状态
                echo ""
                echo -e "  ${CYAN}▶ ${inbound_proto}:${inbound_port}${NC}"
                echo -e "  ${CYAN}   ${inbound_relay_info}${NC}"
                
                # 显示分流规则
                IFS=';' read -ra routes_array <<< "${inbound_rules[$inbound_tag]}"
                
                for route in "${routes_array[@]}"; do
                    [[ -z "$route" ]] && continue
                    
                    IFS='|' read -r tag mtype mval rtag rdesc <<< "$route"
                    if [[ -n "$mval" ]]; then
                        # 获取中转节点的描述
                        local relay_node_desc="$rtag"
                        for j in "${!RELAY_TAGS[@]}"; do
                            if [[ "${RELAY_TAGS[$j]}" == "$rtag" ]]; then
                                relay_node_desc="${RELAY_DESCS[$j]}"
                                break
                            fi
                        done
                        
                        local match_display=""
                        case "$mtype" in
                            domain_suffix) match_display="域名后缀" ;;
                            domain) match_display="完整域名" ;;
                            domain_keyword) match_display="关键词" ;;
                            ip_cidr) match_display="IP/CIDR" ;;
                            *) match_display="$mtype" ;;
                        esac
                        
                        echo -e "    ${GREEN}[${global_idx}]${NC} ${match_display}: ${mval} -> ${relay_node_desc}"
                        ((global_idx++))
                    fi
                done
            done
        fi
        echo ""
        
        echo -e "  ${GREEN}[1]${NC} 添加分流规则"
        echo ""
        echo -e "  ${GREEN}[2]${NC} 删除单个分流规则"
        echo ""
        echo -e "  ${GREEN}[3]${NC} 清空所有分流规则"
        echo ""
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        
        read -p "请选择 [0-3]: " dr_choice
        
        case $dr_choice in
            1)
                add_domain_route
                ;;
            2)
                delete_domain_route
                ;;
            3)
                echo ""
                echo -e "${YELLOW}此操作将删除所有分流规则！${NC}"
                if confirm "确认清空？(y/N): "; then
                    DOMAIN_ROUTES=()
                    save_domain_routes_to_file
                    print_success "已清空所有分流规则"
                    # 重新生成配置
                    if [[ -n "$INBOUNDS_JSON" ]]; then
                        generate_config && start_svc
                    fi
                fi
                ;;
            0)
                break
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
        echo ""
        pause
    done
}

add_domain_route() {
    # 检查是否有入站节点和中转节点
    if [[ ${#INBOUND_TAGS[@]} -eq 0 ]]; then
        print_error "没有可用的入站节点，请先添加节点"
        return 1
    fi
    if [[ ${#RELAY_TAGS[@]} -eq 0 ]]; then
        print_error "没有可用的中转节点，请先添加中转"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}选择要配置分流的入站节点:${NC}"
    local idx=1
    for i in "${!INBOUND_TAGS[@]}"; do
        echo -e "  ${GREEN}[${idx}]${NC} ${INBOUND_PROTOS[$i]}:${INBOUND_PORTS[$i]} (${INBOUND_TAGS[$i]})"
        ((idx++))
    done
    echo ""
    
    read -p "请选择 [1-$((idx-1))]: " inbound_idx
    if ! [[ "$inbound_idx" =~ ^[0-9]+$ ]] || [[ "$inbound_idx" -lt 1 ]] || [[ "$inbound_idx" -ge "$idx" ]]; then
        print_error "无效选项"
        return 1
    fi
    ((inbound_idx--))
    local selected_inbound="${INBOUND_TAGS[$inbound_idx]}"
    
    echo ""
    echo -e "${CYAN}选择匹配类型:${NC}"
    echo -e "  ${GREEN}[1]${NC} domain_suffix - 域名后缀匹配 (推荐，如 time.is 匹配 time.is, a.time.is)"
    echo -e "  ${GREEN}[2]${NC} domain - 完整域名匹配 (如 www.time.is 只匹配该域名)"
    echo -e "  ${GREEN}[3]${NC} domain_keyword - 关键词匹配 (如 time 匹配所有含 time 的域名)"
    echo -e "  ${GREEN}[4]${NC} ip_cidr - IP/CIDR 匹配 (如 1.2.3.4 或 1.2.3.0/24)"
    echo ""
    
    read -p "请选择 [1-4]: " type_idx
    local match_type=""
    case "$type_idx" in
        1) match_type="domain_suffix" ;;
        2) match_type="domain" ;;
        3) match_type="domain_keyword" ;;
        4) match_type="ip_cidr" ;;
        *)
            print_error "无效选项"
            return 1
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}输入要分流的域名或IP (支持多个，用英文逗号分隔):${NC}"
    echo -e "${YELLOW}示例: time.is, ip.sb, youtube.com${NC}"
    echo -e "${YELLOW}       1.2.3.4, 5.6.7.0/24${NC}"
    echo ""
    read -p "请输入: " match_input
    
    # 预处理输入：替换中文逗号为英文逗号，并去除空格
    match_input=$(echo "$match_input" | sed 's/，/,/g' | tr -d ' ')
    
    if [[ -z "$match_input" ]]; then
        print_error "输入不能为空"
        return 1
    fi
    
    # 检查是否包含逗号，决定是单个还是批量
    local is_batch=0
    if [[ "$match_input" == *,* ]]; then
        is_batch=1
    fi
    
    echo ""
    echo -e "${CYAN}选择要使用的中转节点:${NC}"
    idx=1
    for i in "${!RELAY_TAGS[@]}"; do
        echo -e "  ${GREEN}[${idx}]${NC} ${RELAY_DESCS[$i]}"
        ((idx++))
    done
    echo ""
    
    read -p "请选择 [1-$((idx-1))]: " relay_idx
    if ! [[ "$relay_idx" =~ ^[0-9]+$ ]] || [[ "$relay_idx" -lt 1 ]] || [[ "$relay_idx" -ge "$idx" ]]; then
        print_error "无效选项"
        return 1
    fi
    ((relay_idx--))
    local selected_relay="${RELAY_TAGS[$relay_idx]}"
    local selected_relay_desc="${RELAY_DESCS[$relay_idx]}"
    
    echo ""
    read -p "请输入描述 (可选): " desc
    if [[ -z "$desc" ]]; then
        if [[ $is_batch -eq 1 ]]; then
            desc="批量分流规则"
        else
            desc="分流规则"
        fi
    fi
    
    # 批量添加分流规则
    if [[ $is_batch -eq 1 ]]; then
        # 使用 IFS 分割字符串
        IFS=',' read -ra MATCH_VALUES <<< "$match_input"
        local added_count=0
        local base_idx=${#DOMAIN_ROUTES[@]}
        
        for match_value in "${MATCH_VALUES[@]}"; do
            # 去除首尾空格
            match_value=$(echo "$match_value" | xargs)
            if [[ -n "$match_value" ]]; then
                local route_str="${selected_inbound}|${match_type}|${match_value}|${selected_relay}|${desc}"
                DOMAIN_ROUTES+=("$route_str")
                ((added_count++))
            fi
        done
        
        if [[ $added_count -gt 0 ]]; then
            save_domain_routes_to_file
            print_success "已添加 ${added_count} 条分流规则到入站 ${selected_inbound}，全部走 ${selected_relay_desc}"
            echo ""
            echo -e "${CYAN}添加的域名/IP:${NC}"
            for match_value in "${MATCH_VALUES[@]}"; do
                match_value=$(echo "$match_value" | xargs)
                if [[ -n "$match_value" ]]; then
                    echo -e "  ${GREEN}✓${NC} ${match_value}"
                fi
            done
        fi
    else
        # 单个添加
        local route_str="${selected_inbound}|${match_type}|${match_input}|${selected_relay}|${desc}"
        DOMAIN_ROUTES+=("$route_str")
        save_domain_routes_to_file
        print_success "分流规则已添加: ${match_input} -> ${selected_relay_desc}"
    fi
    
    # 重新生成配置
    if [[ -n "$INBOUNDS_JSON" ]]; then
        echo ""
        if confirm "是否立即重新生成配置并生效？(y/N): "; then
            generate_config && start_svc
        fi
    fi
}

delete_domain_route() {
    if [[ ${#DOMAIN_ROUTES[@]} -eq 0 ]]; then
        print_warning "没有可删除的分流规则"
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}选择要删除的分流规则 (按入站节点分组):${NC}"
    echo ""
    
    # 为每条规则创建带有原始索引的结构，同时按入站分组
    declare -A inbound_groups
    local -A index_map
    local display_idx=1
    
    for orig_idx in "${!DOMAIN_ROUTES[@]}"; do
        local route="${DOMAIN_ROUTES[$orig_idx]}"
        IFS='|' read -r inbound_tag match_type match_value relay_tag desc <<< "$route"
        
        # 存储分组信息
        if [[ -z "${inbound_groups[$inbound_tag]}" ]]; then
            inbound_groups[$inbound_tag]="$orig_idx|$route"
        else
            inbound_groups[$inbound_tag]="${inbound_groups[$inbound_tag]}
$orig_idx|$route"
        fi
    done
    
    # 显示规则并记录显示索引到原始索引的映射
    for inbound_tag in "${!inbound_groups[@]}"; do
        # 获取该入站节点的详细信息
        local inbound_proto=""
        local inbound_port=""
        local inbound_relay_tag=""
        local inbound_relay_info=""
        
        for i in "${!INBOUND_TAGS[@]}"; do
            if [[ "${INBOUND_TAGS[$i]}" == "$inbound_tag" ]]; then
                inbound_proto="${INBOUND_PROTOS[$i]}"
                inbound_port="${INBOUND_PORTS[$i]}"
                inbound_relay_tag="${INBOUND_RELAY_TAGS[$i]}"
                break
            fi
        done
        
        # 获取入站节点的连接状态信息
        if [[ "$inbound_relay_tag" == "direct" || -z "$inbound_relay_tag" ]]; then
            # 直连状态
            inbound_relay_info="📡 直连"
        elif [[ -n "$inbound_relay_tag" ]]; then
            # 从 RELAY_JSONS 中提取中转配置信息
            for j in "${!RELAY_TAGS[@]}"; do
                if [[ "${RELAY_TAGS[$j]}" == "$inbound_relay_tag" ]]; then
                    local relay_json="${RELAY_JSONS[$j]}"
                    # 提取中转协议类型
                    local relay_type=$(echo "$relay_json" | grep -o '"type": "[^"]*"' | cut -d'"' -f4 | tr '[:lower:]' '[:upper:]')
                    # 提取服务器地址
                    local relay_server=$(echo "$relay_json" | grep -o '"server": "[^"]*"' | cut -d'"' -f4)
                    # 提取端口
                    local relay_port=$(echo "$relay_json" | grep -o '"server_port": [0-9]*' | grep -o '[0-9]*')
                    
                    if [[ -n "$relay_type" && -n "$relay_server" && -n "$relay_port" ]]; then
                        inbound_relay_info="📍 中转: ${relay_type} ${relay_server}:${relay_port}"
                    fi
                    break
                fi
            done
        fi
        
        echo -e "  ${CYAN}▶ ${inbound_proto}:${inbound_port}${NC}"
        echo -e "  ${CYAN}   ${inbound_relay_info}${NC}"
        
        local grouped_str="${inbound_groups[$inbound_tag]}"
        local grouped_array=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && grouped_array+=("$line")
        done <<< "$grouped_str"
        
        for item in "${grouped_array[@]}"; do
            IFS='|' read -r orig_idx tag mtype mval rtag rdesc <<< "$item"
            
            # 记录显示索引到原始索引的映射
            index_map[$display_idx]="$orig_idx"
            
            # 获取中转节点的描述
            local relay_node_desc="$rtag"
            for j in "${!RELAY_TAGS[@]}"; do
                if [[ "${RELAY_TAGS[$j]}" == "$rtag" ]]; then
                    relay_node_desc="${RELAY_DESCS[$j]}"
                    break
                fi
            done
            
            local match_display=""
            case "$mtype" in
                domain_suffix) match_display="域名后缀" ;;
                domain) match_display="完整域名" ;;
                domain_keyword) match_display="关键词" ;;
                ip_cidr) match_display="IP/CIDR" ;;
                *) match_display="$mtype" ;;
            esac
            
            echo -e "    ${GREEN}[${display_idx}]${NC} ${match_display}: ${mval} -> ${relay_node_desc}"
            ((display_idx++))
        done
        echo ""
    done
    
    local max_idx=$((display_idx - 1))
    read -p "请选择要删除的规则编号 [1-$max_idx]: " delete_idx
    if ! [[ "$delete_idx" =~ ^[0-9]+$ ]] || [[ "$delete_idx" -lt 1 ]] || [[ "$delete_idx" -gt "$max_idx" ]]; then
        print_error "无效选项"
        return 1
    fi
    
    # 获取对应的原始索引
    local orig_idx_to_delete="${index_map[$delete_idx]}"
    local to_delete="${DOMAIN_ROUTES[$orig_idx_to_delete]}"
    IFS='|' read -r del_inbound del_type del_value del_relay del_desc <<< "$to_delete"
    
    # 构建新数组，排除要删除的元素（使用原始索引）
    local new_routes=()
    for i in "${!DOMAIN_ROUTES[@]}"; do
        if [[ "$i" -ne "$orig_idx_to_delete" ]]; then
            new_routes+=("${DOMAIN_ROUTES[$i]}")
        fi
    done
    DOMAIN_ROUTES=("${new_routes[@]}")
    
    save_domain_routes_to_file
    
    echo ""
    print_success "已删除分流规则: ${del_type}:${del_value}"
    echo -e "  ${CYAN}入站节点: ${del_inbound}${NC}"
    
    # 重新生成配置
    if [[ -n "$INBOUNDS_JSON" ]]; then
        echo ""
        if confirm "是否立即重新生成配置并生效？(y/N): "; then
            generate_config && start_svc
        fi
    fi
}

# ==================== 主循环 ====================
main_menu() {
    local config_mtime=0
    while true; do
        # 只在配置文件变化时重新加载，避免每次循环都解析 JSON
        if [[ -f "${CONFIG_FILE}" ]]; then
            local current_mtime=$(stat -c %Y "${CONFIG_FILE}" 2>/dev/null || stat -f %m "${CONFIG_FILE}" 2>/dev/null || echo 0)
            if [[ $current_mtime -ne $config_mtime ]]; then
                load_inbounds_from_config
                config_mtime=$current_mtime
            fi
        fi
        load_relays_from_file
        load_ip_config
        
        show_main_menu
        read -p "请选择 [0-8]: " m_choice
        
        case $m_choice in
            1)
                show_menu
                ;;
            2)
                setup_relay
                ;;
            3)
                ip_config_menu
                ;;
            4)
                config_and_view_menu
                ;;
            5)
                regenerate_all_links
                ;;
            6)
                delete_self
                ;;
            7)
                dns_config_menu
                ;;
            8)
                tune_menu
                ;;
            0)
                print_info "已退出"
                exit 0
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
        echo ""
        pause "按回车返回主菜单..."
    done
}

setup_sb_shortcut() {
    print_info "创建快捷命令 sb..."

    local sb_target="/etc/sing-box/install.sh"

    # 确保脚本在标准位置
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        print_warning "脚本不在磁盘上，跳过创建 sb"
        return
    fi

    # 如果脚本不在标准位置，复制一份到 /etc/sing-box/
    if [[ "${SCRIPT_PATH}" != "${sb_target}" ]]; then
        cp "${SCRIPT_PATH}" "${sb_target}" 2>/dev/null && chmod +x "${sb_target}"
        SCRIPT_PATH="${sb_target}"
    fi

    # 确保模块目录存在且有文件（防止旧版本升级后模块缺失）
    if [[ ! -d "/etc/sing-box/modules" ]] || [[ -z "$(ls -A /etc/sing-box/modules/ 2>/dev/null)" ]]; then
        print_info "模块目录缺失，从 GitHub 下载..."
        mkdir -p /etc/sing-box/modules
        local modules_url="https://raw.githubusercontent.com/Kiss8202/Trae/main/modules"
        for module in core install links dns relay protocols config tune menu; do
            curl -sfL --connect-timeout 10 --max-time 30 "${modules_url}/${module}.sh" -o "/etc/sing-box/modules/${module}.sh" 2>/dev/null || true
        done
    fi

    cat > /usr/local/bin/sb << EOSB
#!/bin/bash
"${SCRIPT_PATH}" "\$@"
EOSB

    chmod +x /usr/local/bin/sb
    print_success "已创建快捷命令: sb (任意位置输入 sb 即可重新进入脚本)"
}
# ==================== 主函数 ====================
main() {
    if [[ $EUID -ne 0 ]]; then
        print_error "需要 root 权限"
        exit 1
    fi
    
    # DEBUG 模式支持: DEBUG=1 ./install.sh
    if [[ "${DEBUG:-0}" -eq 1 ]]; then
        set -x
        print_warning "DEBUG 模式已启用，所有命令将被追踪"
    fi
    
    # 如果脚本不在磁盘上（如 bash <(curl ...) 方式运行），保存到磁盘
    # 不再 exec 重新执行，避免新进程需要重新 source 模块导致函数丢失
    local sb_script="/etc/sing-box/install.sh"
    if [[ ! -f "${SCRIPT_PATH}" ]] || [[ "$0" == /dev/fd/* ]]; then
        mkdir -p /etc/sing-box
        # 尝试从 BASH_SOURCE 获取
        local script_src="${BASH_SOURCE[0]:-$0}"
        if [[ -f "${script_src}" ]]; then
            cp "${script_src}" "${sb_script}" 2>/dev/null
        fi
        # 如果 BASH_SOURCE 也不可用，从 GitHub 重新下载
        if [[ ! -f "${sb_script}" ]]; then
            print_info "脚本不在磁盘上，从 GitHub 下载到 ${sb_script} ..."
            # 自动检测仓库 URL
            _repo_raw=""
            _script_url="${BASH_SOURCE[0]:-$0}"
            if [[ "$_script_url" =~ ^https?:// ]]; then
                _repo_raw="$_script_url"
            else
                _pp_cmdline=$(cat /proc/$PPID/cmdline 2>/dev/null | tr '\0' ' ')
                for _word in $_pp_cmdline; do
                    if [[ "$_word" =~ ^https://raw\.githubusercontent\.com/.*install\.sh$ ]]; then
                        _repo_raw="$_word"
                        break
                    fi
                done
            fi
            [[ -z "$_repo_raw" ]] && _repo_raw="https://raw.githubusercontent.com/Kiss8202/Trae/main/install.sh"
            wget -q -O "${sb_script}" "$_repo_raw" 2>/dev/null || curl -sL -o "${sb_script}" "$_repo_raw" 2>/dev/null || true
            unset _repo_raw _script_url _pp_cmdline _word
        fi
        if [[ -f "${sb_script}" ]]; then
            chmod +x "${sb_script}"
            SCRIPT_PATH="${sb_script}"
            print_success "脚本已保存到 ${sb_script}"
        fi
    fi
    
    detect_system
    if ! install_singbox; then
        print_error "sing-box 安装失败，请检查网络或系统环境后重试"
        print_info "按回车键退出..."
        read -r
        exit 1
    fi
    detect_singbox_version
    mkdir -p /etc/sing-box
    gen_keys
    
    # 先加载 IP 配置（如果存在）
    load_ip_config
    load_dns_config
    
    get_ip
    
    setup_sb_shortcut

    # 安装完成后自动应用网络调优（安全第一：仅修改 sysctl，不安装任何软件）
    auto_tune
    
    # 从配置文件加载节点信息
    if [[ -f "${CONFIG_FILE}" ]]; then
        load_inbounds_from_config
    fi
    
    # 加载中转配置
    load_relays_from_file
    
    # 从配置文件重新生成链接（避免加载旧链接文件）
    if [[ -f "${CONFIG_FILE}" ]]; then
        cleanup_links
        regenerate_links_from_config
    fi
    
    # 如果配置文件存在但链接文件为空，自动重新生成链接
    if [[ -f "${CONFIG_FILE}" ]] && [[ -z "$ALL_LINKS_TEXT" ]]; then
        print_info "检测到链接文件缺失，正在重新生成..."
        regenerate_links_from_config
    fi
    
    main_menu
}

main "$@"
