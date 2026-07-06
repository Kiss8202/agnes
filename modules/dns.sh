# ==================== sing-box DNS配置模块 ====================
# ==================== DNS 配置管理 ====================
DNS_MODE="udp"
DNS_SERVER="8.8.8.8"
DNS_SERVER_NAME="Google"

save_dns_config() {
    mkdir -p "$(dirname "${DNS_CONFIG_FILE}")"
    cat > "${DNS_CONFIG_FILE}" << EOF
# Sing-box DNS 配置
DNS_MODE="${DNS_MODE}"
DNS_SERVER="${DNS_SERVER}"
DNS_SERVER_NAME="${DNS_SERVER_NAME}"
EOF
}

load_dns_config() {
    if [[ -f "${DNS_CONFIG_FILE}" ]] && [[ -r "${DNS_CONFIG_FILE}" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value="${value#\"}"
            value="${value%\"}"
            case "$key" in
                DNS_MODE) DNS_MODE="$value" ;;
                DNS_SERVER) DNS_SERVER="$value" ;;
                DNS_SERVER_NAME) DNS_SERVER_NAME="$value" ;;
            esac
        done < "${DNS_CONFIG_FILE}"
    fi
}

# 根据当前 DNS 配置生成 sing-box DNS server JSON
build_dns_remote_server() {
    case "${DNS_MODE}" in
        "doh")
            if [[ $SB_GE_1_12 -eq 1 ]]; then
                echo "{\"tag\": \"remote\", \"type\": \"https\", \"server\": \"${DNS_SERVER}\", \"server_port\": 443, \"domain_resolver\": \"local\"}"
            else
                echo "{\"tag\": \"remote\", \"type\": \"https\", \"server\": \"${DNS_SERVER}\", \"server_port\": 443, \"address_resolver\": \"local\"}"
            fi
            ;;
        "dot")
            if [[ $SB_GE_1_12 -eq 1 ]]; then
                echo "{\"tag\": \"remote\", \"type\": \"tls\", \"server\": \"${DNS_SERVER}\", \"server_port\": 853, \"domain_resolver\": \"local\"}"
            else
                echo "{\"tag\": \"remote\", \"type\": \"tls\", \"server\": \"${DNS_SERVER}\", \"server_port\": 853, \"address_resolver\": \"local\"}"
            fi
            ;;
        "udp"|*)
            echo "{\"tag\": \"remote\", \"type\": \"udp\", \"server\": \"${DNS_SERVER}\"}"
            ;;
    esac
}

# DNS 配置菜单
dns_config_menu() {
    while true; do
        echo ""
        menu_header "DNS 配置"
        echo -e "${YELLOW}当前 DNS 模式:${NC} ${GREEN}${DNS_MODE^^}${NC}"
        echo -e "${YELLOW}当前 DNS 服务器:${NC} ${GREEN}${DNS_SERVER_NAME} (${DNS_SERVER})${NC}"
        echo -e "${YELLOW}自定义 DNS 服务器:${NC} ${GREEN}${#DNS_SERVERS[@]} 个${NC}"
        echo -e "${YELLOW}DNS 分流规则:${NC} ${GREEN}${#DNS_ROUTES[@]} 条${NC}"
        echo ""
        echo -e "  ${GREEN}[1]${NC} UDP 模式 (默认，兼容性最好)"
        echo -e "  ${GREEN}[2]${NC} DNS-over-HTTPS (DoH，加密DNS查询)"
        echo -e "  ${GREEN}[3]${NC} DNS-over-TLS (DoT，加密DNS查询)"
        echo -e "  ${GREEN}[4]${NC} 自定义 DNS 服务器"
        echo -e "  ${GREEN}[5]${NC} 预设 DNS 服务器列表"
        echo -e "  ${GREEN}[6]${NC} DNS 分流配置"
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        read -p "请选择 [0-6]: " dns_choice

        case $dns_choice in
            1)
                DNS_MODE="udp"
                save_dns_config
                print_success "DNS 模式已设置为 UDP"
                ;;
            2)
                DNS_MODE="doh"
                save_dns_config
                print_success "DNS 模式已设置为 DoH"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                ;;
            3)
                DNS_MODE="dot"
                save_dns_config
                print_success "DNS 模式已设置为 DoT"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                ;;
            4)
                read -p "请输入 DNS 服务器地址 (域名，如 dns.google): " custom_dns
                if [[ -n "$custom_dns" ]]; then
                    DNS_SERVER="$custom_dns"
                    DNS_SERVER_NAME="Custom"
                    save_dns_config
                    print_success "DNS 服务器已设置为: ${DNS_SERVER}"
                fi
                ;;
            5)
                echo ""
                echo -e "${CYAN}预设 DNS 服务器:${NC}"
                echo -e "  ${GREEN}[1]${NC} Google (8.8.8.8 / dns.google)"
                echo -e "  ${GREEN}[2]${NC} Cloudflare (1.1.1.1 / cloudflare-dns.com)"
                echo -e "  ${GREEN}[3]${NC} Alibaba (223.5.5.5 / dns.alidns.com)"
                echo -e "  ${GREEN}[4]${NC} Tencent (119.29.29.29 / doh.pub)"
                echo -e "  ${GREEN}[0]${NC} 取消"
                echo ""
                read -p "请选择: " preset_choice
                case $preset_choice in
                    1) DNS_SERVER="8.8.8.8"; DNS_SERVER_NAME="Google"; DNS_MODE="udp"; save_dns_config; print_success "已设置为 Google DNS" ;;
                    2) DNS_SERVER="cloudflare-dns.com"; DNS_SERVER_NAME="Cloudflare"; DNS_MODE="doh"; save_dns_config; print_success "已设置为 Cloudflare DoH" ;;
                    3) DNS_SERVER="dns.alidns.com"; DNS_SERVER_NAME="Alibaba"; DNS_MODE="doh"; save_dns_config; print_success "已设置为 Alibaba DoH" ;;
                    4) DNS_SERVER="doh.pub"; DNS_SERVER_NAME="Tencent"; DNS_MODE="doh"; save_dns_config; print_success "已设置为 Tencent DoH" ;;
                    *) continue ;;
                esac
                ;;
            6)
                dns_route_menu
                continue
                ;;
            0)
                break
                ;;
            *)
                print_error "无效选项"
                ;;
        esac

        # 询问是否立即应用
        if [[ "$dns_choice" =~ ^[1-5]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
            read -p "是否立即重新生成配置? (y/N): " regen
            if [[ "$regen" =~ ^[Yy]$ ]]; then
                generate_config && start_svc
            fi
        fi
    done
}

# ==================== DNS 分流配置 ====================

# 保存自定义 DNS 服务器到文件
save_dns_servers_to_file() {
    mkdir -p "$(dirname "${DNS_SERVERS_FILE}")"
    cat > "${DNS_SERVERS_FILE}" << EOF
# Sing-box 自定义 DNS 服务器
# 格式: TAG|TYPE|SERVER|DESCRIPTION
EOF
    for entry in "${DNS_SERVERS[@]}"; do
        echo "$entry" >> "${DNS_SERVERS_FILE}"
    done
}

# 从文件加载自定义 DNS 服务器
load_dns_servers_from_file() {
    DNS_SERVERS=()
    if [[ -f "${DNS_SERVERS_FILE}" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            DNS_SERVERS+=("$line")
        done < "${DNS_SERVERS_FILE}"
    fi
}

# 保存 DNS 分流规则到文件
save_dns_routes_to_file() {
    mkdir -p "$(dirname "${DNS_ROUTES_FILE}")"
    cat > "${DNS_ROUTES_FILE}" << EOF
# Sing-box DNS 分流规则
# 格式: MATCH_TYPE|MATCH_VALUE|DNS_TAG|DESCRIPTION
EOF
    for entry in "${DNS_ROUTES[@]}"; do
        echo "$entry" >> "${DNS_ROUTES_FILE}"
    done
}

# 从文件加载 DNS 分流规则
load_dns_routes_from_file() {
    DNS_ROUTES=()
    if [[ -f "${DNS_ROUTES_FILE}" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            DNS_ROUTES+=("$line")
        done < "${DNS_ROUTES_FILE}"
    fi
}

# 添加自定义 DNS 服务器
add_custom_dns_server() {
    echo ""
    echo -e "${CYAN}添加自定义 DNS 服务器${NC}"
    echo -e "${YELLOW}用于流媒体解锁、特定域名解析等场景${NC}"
    echo ""

    # 预设解锁 DNS
    echo -e "${CYAN}预设解锁 DNS:${NC}"
    echo -e "  ${GREEN}[1]${NC} Zouter HK (151.243.229.229)"
    echo -e "  ${GREEN}[2]${NC} 自定义输入"
    echo -e "  ${GREEN}[0]${NC} 取消"
    echo ""
    read -p "请选择: " dns_preset

    case $dns_preset in
        1)
            local tag="unlock-hk"
            local type="udp"
            local server="151.243.229.229"
            local desc="Zouter HK 流媒体解锁"
            ;;
        2)
            read -p "DNS 标签 (如 unlock-jp，留空自动生成): " tag
            if [[ -z "$tag" ]]; then
                tag="dns-custom-$(( ${#DNS_SERVERS[@]} + 1 ))"
            fi
            read -p "DNS 类型 (udp/doh/dot) [udp]: " type
            type=${type:-udp}
            read -p "DNS 服务器地址: " server
            if [[ -z "$server" ]]; then
                print_error "服务器地址不能为空"
                return 1
            fi
            read -p "描述 (如 JP 流媒体解锁): " desc
            desc=${desc:-"自定义 DNS ${server}"}
            ;;
        0|*)
            return 0
            ;;
    esac

    # 检查 tag 是否重复
    for entry in "${DNS_SERVERS[@]}"; do
        local existing_tag=$(echo "$entry" | cut -d'|' -f1)
        if [[ "$existing_tag" == "$tag" ]]; then
            print_error "DNS 标签 '${tag}' 已存在"
            return 1
        fi
    done

    DNS_SERVERS+=("${tag}|${type}|${server}|${desc}")
    save_dns_servers_to_file
    print_success "DNS 服务器已添加: ${desc} (${server})"
}

# 删除自定义 DNS 服务器
delete_custom_dns_server() {
    if [[ ${#DNS_SERVERS[@]} -eq 0 ]]; then
        print_warning "当前没有自定义 DNS 服务器"
        return 0
    fi

    echo ""
    echo -e "${CYAN}自定义 DNS 服务器:${NC}"
    echo -e "  ${GREEN}[0]${NC} 删除全部 (恢复系统预设)"
    for i in "${!DNS_SERVERS[@]}"; do
        local idx=$((i+1))
        IFS='|' read -r tag type server desc <<< "${DNS_SERVERS[$i]}"
        echo -e "  ${GREEN}[${idx}]${NC} ${desc} (${type}:${server}) [${tag}]"
    done
    echo ""
    read -p "请选择要删除的序号 (输入 -1 取消): " del_idx

    if [[ "$del_idx" == "-1" ]]; then
        return 0
    elif [[ "$del_idx" == "0" ]]; then
        if confirm "确认删除全部自定义 DNS 服务器和关联的分流规则? (y/N): "; then
            # 获取所有要删除的 tag
            local del_tags=()
            for entry in "${DNS_SERVERS[@]}"; do
                del_tags+=("$(echo "$entry" | cut -d'|' -f1)")
            done
            # 删除引用这些 tag 的分流规则
            local new_routes=()
            for route in "${DNS_ROUTES[@]}"; do
                local route_tag=$(echo "$route" | cut -d'|' -f3)
                local tag_found=0
                for dt in "${del_tags[@]}"; do
                    [[ "$route_tag" == "$dt" ]] && tag_found=1 && break
                done
                [[ $tag_found -eq 0 ]] && new_routes+=("$route")
            done
            DNS_ROUTES=("${new_routes[@]}")
            save_dns_routes_to_file
            DNS_SERVERS=()
            save_dns_servers_to_file
            print_success "已删除全部自定义 DNS 服务器和关联规则"
        fi
    elif [[ "$del_idx" =~ ^[0-9]+$ ]] && (( del_idx >= 1 && del_idx <= ${#DNS_SERVERS[@]} )); then
        local d=$((del_idx-1))
        local del_tag=$(echo "${DNS_SERVERS[$d]}" | cut -d'|' -f1)
        local del_desc=$(echo "${DNS_SERVERS[$d]}" | cut -d'|' -f4)

        # 检查是否有规则引用该 DNS
        local ref_count=0
        for route in "${DNS_ROUTES[@]}"; do
            local route_tag=$(echo "$route" | cut -d'|' -f3)
            [[ "$route_tag" == "$del_tag" ]] && ((ref_count++))
        done

        if [[ $ref_count -gt 0 ]]; then
            print_warning "DNS 服务器 '${del_desc}' 被 ${ref_count} 条分流规则引用"
            if ! confirm "删除服务器同时删除关联规则? (y/N): "; then
                return 0
            fi
            local new_routes=()
            for route in "${DNS_ROUTES[@]}"; do
                local route_tag=$(echo "$route" | cut -d'|' -f3)
                [[ "$route_tag" != "$del_tag" ]] && new_routes+=("$route")
            done
            DNS_ROUTES=("${new_routes[@]}")
            save_dns_routes_to_file
        fi

        unset 'DNS_SERVERS[$d]'
        DNS_SERVERS=("${DNS_SERVERS[@]}")
        save_dns_servers_to_file
        print_success "已删除 DNS 服务器: ${del_desc}"
    else
        print_error "无效选择"
    fi
}

# 添加 DNS 分流规则（域名 → DNS）
add_dns_domain_route() {
    if [[ ${#DNS_SERVERS[@]} -eq 0 ]]; then
        print_warning "请先添加自定义 DNS 服务器"
        return 1
    fi

    echo ""
    echo -e "${CYAN}添加 DNS 分流规则（域名 → DNS）${NC}"
    echo -e "${YELLOW}匹配的域名将使用指定的 DNS 服务器解析${NC}"
    echo ""

    # 选择匹配类型
    echo -e "${CYAN}匹配类型:${NC}"
    echo -e "  ${GREEN}[1]${NC} 域名后缀 (如 .netflix.com)"
    echo -e "  ${GREEN}[2]${NC} 完整域名 (如 www.netflix.com)"
    echo -e "  ${GREEN}[3]${NC} 域名关键词 (如 netflix)"
    echo ""
    read -p "请选择 [1-3]: " match_choice

    local match_type=""
    case $match_choice in
        1) match_type="domain_suffix" ;;
        2) match_type="domain" ;;
        3) match_type="domain_keyword" ;;
        *) print_error "无效选择"; return 1 ;;
    esac

    # 输入匹配值（支持逗号分隔多个）
    echo -e "${YELLOW}请输入域名 (多个用英文逗号分隔，如 netflix.com,disneyplus.com)${NC}"
    read -p "域名: " match_value
    if [[ -z "$match_value" ]]; then
        print_error "域名不能为空"
        return 1
    fi

    # 选择 DNS 服务器
    echo ""
    echo -e "${CYAN}选择 DNS 服务器:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do
        local idx=$((i+1))
        IFS='|' read -r tag type server desc <<< "${DNS_SERVERS[$i]}"
        echo -e "  ${GREEN}[${idx}]${NC} ${desc} (${server}) [${tag}]"
    done
    echo ""
    read -p "请选择: " dns_idx

    if ! [[ "$dns_idx" =~ ^[0-9]+$ ]] || (( dns_idx < 1 || dns_idx > ${#DNS_SERVERS[@]} )); then
        print_error "无效选择"
        return 1
    fi

    local dns_tag=$(echo "${DNS_SERVERS[$((dns_idx-1))]}" | cut -d'|' -f1)
    local dns_desc=$(echo "${DNS_SERVERS[$((dns_idx-1))]}" | cut -d'|' -f4)

    # 输入描述
    read -p "描述 (留空自动生成): " route_desc
    if [[ -z "$route_desc" ]]; then
        route_desc="${match_value} -> ${dns_desc}"
    fi

    DNS_ROUTES+=("${match_type}|${match_value}|${dns_tag}|${route_desc}")
    save_dns_routes_to_file
    print_success "DNS 分流规则已添加: ${route_desc}"
}

# 添加 DNS 分流规则（节点 → DNS）
add_dns_inbound_route() {
    if [[ ${#DNS_SERVERS[@]} -eq 0 ]]; then
        print_warning "请先添加自定义 DNS 服务器"
        return 1
    fi

    if [[ ${#INBOUND_TAGS[@]} -eq 0 ]]; then
        print_warning "当前没有入站节点"
        return 1
    fi

    echo ""
    echo -e "${CYAN}添加 DNS 分流规则（节点 → DNS）${NC}"
    echo -e "${YELLOW}指定节点的所有流量使用指定 DNS 解析${NC}"
    echo ""

    # 选择节点
    echo -e "${CYAN}选择节点:${NC}"
    for i in "${!INBOUND_TAGS[@]}"; do
        local idx=$((i+1))
        echo -e "  ${GREEN}[${idx}]${NC} ${INBOUND_PROTOS[$i]}:${INBOUND_PORTS[$i]} [${INBOUND_TAGS[$i]}]"
    done
    echo ""
    read -p "请选择: " node_idx

    if ! [[ "$node_idx" =~ ^[0-9]+$ ]] || (( node_idx < 1 || node_idx > ${#INBOUND_TAGS[@]} )); then
        print_error "无效选择"
        return 1
    fi

    local inbound_tag="${INBOUND_TAGS[$((node_idx-1))]}"
    local inbound_proto="${INBOUND_PROTOS[$((node_idx-1))]}"
    local inbound_port="${INBOUND_PORTS[$((node_idx-1))]}"

    # 选择 DNS 服务器
    echo ""
    echo -e "${CYAN}选择 DNS 服务器:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do
        local idx=$((i+1))
        IFS='|' read -r tag type server desc <<< "${DNS_SERVERS[$i]}"
        echo -e "  ${GREEN}[${idx}]${NC} ${desc} (${server}) [${tag}]"
    done
    echo ""
    read -p "请选择: " dns_idx

    if ! [[ "$dns_idx" =~ ^[0-9]+$ ]] || (( dns_idx < 1 || dns_idx > ${#DNS_SERVERS[@]} )); then
        print_error "无效选择"
        return 1
    fi

    local dns_tag=$(echo "${DNS_SERVERS[$((dns_idx-1))]}" | cut -d'|' -f1)
    local dns_desc=$(echo "${DNS_SERVERS[$((dns_idx-1))]}" | cut -d'|' -f4)

    # 输入描述
    local route_desc="${inbound_proto}:${inbound_port} -> ${dns_desc}"
    read -p "描述 [${route_desc}]: " custom_desc
    [[ -n "$custom_desc" ]] && route_desc="$custom_desc"

    DNS_ROUTES+=("inbound|${inbound_tag}|${dns_tag}|${route_desc}")
    save_dns_routes_to_file
    print_success "DNS 分流规则已添加: ${route_desc}"
}

# 删除 DNS 分流规则
delete_dns_route() {
    if [[ ${#DNS_ROUTES[@]} -eq 0 ]]; then
        print_warning "当前没有 DNS 分流规则"
        return 0
    fi

    echo ""
    echo -e "${CYAN}DNS 分流规则:${NC}"
    echo -e "  ${GREEN}[0]${NC} 删除全部"
    for i in "${!DNS_ROUTES[@]}"; do
        local idx=$((i+1))
        IFS='|' read -r match_type match_value dns_tag desc <<< "${DNS_ROUTES[$i]}"
        local match_display=""
        case "$match_type" in
            domain_suffix) match_display="域名后缀" ;;
            domain) match_display="完整域名" ;;
            domain_keyword) match_display="关键词" ;;
            inbound) match_display="节点" ;;
            *) match_display="$match_type" ;;
        esac
        echo -e "  ${GREEN}[${idx}]${NC} [${match_display}] ${match_value} -> ${dns_tag} (${desc})"
    done
    echo ""
    read -p "请选择要删除的序号 (输入 -1 取消): " del_idx

    if [[ "$del_idx" == "-1" ]]; then
        return 0
    elif [[ "$del_idx" == "0" ]]; then
        if confirm "确认删除全部 DNS 分流规则? (y/N): "; then
            DNS_ROUTES=()
            save_dns_routes_to_file
            print_success "已删除全部 DNS 分流规则"
        fi
    elif [[ "$del_idx" =~ ^[0-9]+$ ]] && (( del_idx >= 1 && del_idx <= ${#DNS_ROUTES[@]} )); then
        local d=$((del_idx-1))
        IFS='|' read -r _ _ _ del_desc <<< "${DNS_ROUTES[$d]}"
        unset 'DNS_ROUTES[$d]'
        DNS_ROUTES=("${DNS_ROUTES[@]}")
        save_dns_routes_to_file
        print_success "已删除规则: ${del_desc}"
    else
        print_error "无效选择"
    fi
}

# DNS 分流配置菜单
dns_route_menu() {
    # 加载最新配置
    load_dns_servers_from_file
    load_dns_routes_from_file

    while true; do
        echo ""
        menu_header "DNS 分流配置"
        echo -e "${YELLOW}全局 DNS:${NC} ${GREEN}${DNS_SERVER_NAME} (${DNS_SERVER})${NC}"
        echo -e "${YELLOW}自定义 DNS 服务器:${NC} ${GREEN}${#DNS_SERVERS[@]} 个${NC}"
        echo -e "${YELLOW}DNS 分流规则:${NC} ${GREEN}${#DNS_ROUTES[@]} 条${NC}"

        # 显示自定义 DNS 服务器
        if [[ ${#DNS_SERVERS[@]} -gt 0 ]]; then
            echo ""
            echo -e "${CYAN}自定义 DNS 服务器:${NC}"
            for entry in "${DNS_SERVERS[@]}"; do
                IFS='|' read -r tag type server desc <<< "$entry"
                echo -e "  ${GREEN}*${NC} ${desc} (${type}:${server}) [${tag}]"
            done
        fi

        # 显示分流规则
        if [[ ${#DNS_ROUTES[@]} -gt 0 ]]; then
            echo ""
            echo -e "${CYAN}DNS 分流规则:${NC}"
            for route in "${DNS_ROUTES[@]}"; do
                IFS='|' read -r match_type match_value dns_tag desc <<< "$route"
                local match_display=""
                case "$match_type" in
                    domain_suffix) match_display="后缀" ;;
                    domain) match_display="域名" ;;
                    domain_keyword) match_display="关键词" ;;
                    inbound) match_display="节点" ;;
                    *) match_display="$match_type" ;;
                esac
                echo -e "  ${GREEN}*${NC} [${match_display}] ${match_value} -> ${dns_tag}"
            done
        fi

        echo ""
        echo -e "  ${GREEN}[1]${NC} 添加自定义 DNS 服务器"
        echo -e "  ${GREEN}[2]${NC} 删除自定义 DNS 服务器"
        echo -e "  ${GREEN}[3]${NC} 添加 DNS 分流规则（域名 → DNS）"
        echo -e "  ${GREEN}[4]${NC} 添加 DNS 分流规则（节点 → DNS）"
        echo -e "  ${GREEN}[5]${NC} 删除 DNS 分流规则"
        echo -e "  ${GREEN}[0]${NC} 返回"
        echo ""
        read -p "请选择 [0-5]: " route_choice

        case $route_choice in
            1) add_custom_dns_server ;;
            2) delete_custom_dns_server ;;
            3) add_dns_domain_route ;;
            4) add_dns_inbound_route ;;
            5) delete_dns_route ;;
            0) break ;;
            *) print_error "无效选项" ;;
        esac

        # 操作后询问是否应用
        if [[ "$route_choice" =~ ^[1-5]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
            read -p "是否立即重新生成配置? (y/N): " regen
            if [[ "$regen" =~ ^[Yy]$ ]]; then
                generate_config && start_svc
            fi
        fi
    done
}

# ==================== IP 配置管理 ====================
save_ip_config() {
    mkdir -p "$(dirname "${IP_CONFIG_FILE}")"
    cat > "${IP_CONFIG_FILE}" << EOF
# Sing-box IP 配置
SERVER_IP="${SERVER_IP}"
SERVER_IPV6="${SERVER_IPV6}"
INBOUND_IP_MODE="${INBOUND_IP_MODE}"
OUTBOUND_IP_MODE="${OUTBOUND_IP_MODE}"
GH_MIRROR="${GH_MIRROR}"
EOF
}

load_ip_config() {
    if [[ -f "${IP_CONFIG_FILE}" ]] && [[ -r "${IP_CONFIG_FILE}" ]]; then
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            # 去除值两端的引号
            value="${value#\"}"
            value="${value%\"}"
            case "$key" in
                SERVER_IP) SERVER_IP="$value" ;;
                SERVER_IPV6) SERVER_IPV6="$value" ;;
                INBOUND_IP_MODE) INBOUND_IP_MODE="$value" ;;
                OUTBOUND_IP_MODE) OUTBOUND_IP_MODE="$value" ;;
                GH_MIRROR) GH_MIRROR="$value" ;;
            esac
        done < "${IP_CONFIG_FILE}"
    fi
}
