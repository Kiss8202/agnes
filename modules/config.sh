# ==================== sing-box 配置生成模块 ====================
# ==================== 出入站 IP 配置菜单 ====================
ip_config_menu() {
    while true; do
        clear
        menu_header "出入站 IP 配置"
        echo -e "${YELLOW}当前配置:${NC}"
        echo -e "  IPv4 地址: ${GREEN}${SERVER_IP}${NC}"
        [[ -n "$SERVER_IPV6" ]] && echo -e "  IPv6 地址: ${GREEN}${SERVER_IPV6}${NC}"
        echo -e "  入站模式: ${GREEN}${INBOUND_IP_MODE}${NC}"
        echo -e "  出站模式: ${GREEN}${OUTBOUND_IP_MODE}${NC}"
        echo ""
        echo -e "${CYAN}说明:${NC}"
        echo -e "  ${YELLOW}入站${NC}: 控制节点监听的 IP 版本（客户端连接到哪个 IP）"
        echo -e "  ${YELLOW}出站${NC}: 控制服务器对外连接的 IP 版本（访问网站用哪个 IP）"
        echo ""
        echo -e "  ${GREEN}[1]${NC} 设置入站为 IPv4"
        echo -e "  ${GREEN}[2]${NC} 设置入站为 IPv6"
        echo -e "  ${GREEN}[3]${NC} 设置入站为双栈 (IPv4+IPv6)"
        echo -e "  ${GREEN}[4]${NC} 设置出站为 IPv4"
        echo -e "  ${GREEN}[5]${NC} 设置出站为 IPv6 (优先)"
        echo -e "  ${GREEN}[6]${NC} 设置出站为仅 IPv6 (IPv4不出站)"
        echo -e "  ${GREEN}[7]${NC} 设置出站为双栈 (IPv4+IPv6)"
        echo -e "  ${GREEN}[8]${NC} 手动修改 IPv4 地址"
        echo -e "  ${GREEN}[9]${NC} 手动修改 IPv6 地址"
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        read -p "请选择 [0-9]: " ip_choice
        
        case $ip_choice in
            1)
                INBOUND_IP_MODE="ipv4"
                save_ip_config
                print_success "入站已设置为 IPv4"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            2)
                if [[ -z "$SERVER_IPV6" ]]; then
                    print_error "未检测到 IPv6 地址，请先手动设置"
                    pause
                    continue
                fi
                INBOUND_IP_MODE="ipv6"
                save_ip_config
                print_success "入站已设置为 IPv6"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            3)
                INBOUND_IP_MODE="dual"
                save_ip_config
                print_success "入站已设置为双栈 (IPv4+IPv6)"
                echo -e "${YELLOW}提示: 双栈模式将同时监听 IPv4 和 IPv6${NC}"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            4)
                OUTBOUND_IP_MODE="ipv4"
                save_ip_config
                print_success "出站已设置为 IPv4"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            5)
                if [[ -z "$SERVER_IPV6" ]]; then
                    print_error "未检测到 IPv6 地址，请先手动设置"
                    pause
                    continue
                fi
                OUTBOUND_IP_MODE="ipv6"
                save_ip_config
                print_success "出站已设置为 IPv6 优先"
                echo -e "${YELLOW}提示: IPv6 优先出站，IPv6 不可用时回退到 IPv4${NC}"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            6)
                if [[ -z "$SERVER_IPV6" ]]; then
                    print_error "未检测到 IPv6 地址，请先手动设置"
                    pause
                    continue
                fi
                OUTBOUND_IP_MODE="ipv6_only"
                save_ip_config
                print_success "出站已设置为仅 IPv6"
                echo -e "${YELLOW}提示: 仅使用 IPv6 出站，IPv4 将无法出站${NC}"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            7)
                OUTBOUND_IP_MODE="dual"
                save_ip_config
                print_success "出站已设置为双栈 (IPv4+IPv6)"
                echo -e "${YELLOW}提示: 双栈模式将同时使用 IPv4 和 IPv6，由系统自动选择${NC}"
                echo -e "${YELLOW}提示: 需要重新生成配置才能生效${NC}"
                read -p "是否立即重新生成配置? (y/N): " regen
                if [[ "$regen" =~ ^[Yy]$ ]] && [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            8)
                read -p "请输入 IPv4 地址: " new_ipv4
                if [[ -n "$new_ipv4" ]]; then
                    SERVER_IP="$new_ipv4"
                    save_ip_config
                    print_success "IPv4 地址已更新: ${SERVER_IP}"
                    echo -e "${YELLOW}提示: 需要重新生成链接文件${NC}"
                fi
                ;;
            9)
                read -p "请输入 IPv6 地址: " new_ipv6
                if [[ -n "$new_ipv6" ]]; then
                    SERVER_IPV6="$new_ipv6"
                    save_ip_config
                    print_success "IPv6 地址已更新: ${SERVER_IPV6}"
                    echo -e "${YELLOW}提示: 需要重新生成链接文件${NC}"
                fi
                ;;
            0)
                break
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
        
        [[ "$ip_choice" != "0" ]] && pause
    done
}

# ==================== 通用节点修改框架 ====================

# 通用端口修改逻辑
# 参数: array_idx tag port tag_prefix
# 通过 echo 返回 "new_tag new_port"，失败返回空
_modify_port_common() {
    local array_idx="$1"
    local tag="$2"
    local port="$3"
    local tag_prefix="$4"

    echo -e "${YELLOW}新端口 (留空随机分配)${NC}" >&2
    read -p "端口: " new_port
    if [[ -z "$new_port" ]]; then
        new_port=$(get_random_free_port)
        [[ -z "$new_port" ]] && { print_error "无法获取随机端口" >&2; return 1; }
    fi
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        print_error "端口无效" >&2; return 1
    fi
    if check_port_in_use "$new_port" && [[ "$new_port" != "$port" ]]; then
        print_warning "端口 ${new_port} 已被占用" >&2; return 1
    fi
    local new_tag=$(modify_port "$tag" "$tag_prefix" "$new_port")
    INBOUND_TAGS[$array_idx]="$new_tag"
    INBOUND_PORTS[$array_idx]="$new_port"
    print_success "端口已修改为 ${new_port}" >&2
    echo "${new_tag} ${new_port}"
    return 0
}

# ==================== Reality 修改菜单 ====================
_modify_menu_Reality() {
    local array_idx="$1" tag="$2" port="$3" current_sni="$4" proto="$5"

    # 读取当前回落目标
    local current_hs_server=$(jq -r --arg tag "$tag" '(.inbounds[] | select(.tag == $tag)).tls.reality.handshake.server // ""' "${CONFIG_FILE}" 2>/dev/null)
    local current_hs_port=$(jq -r --arg tag "$tag" '(.inbounds[] | select(.tag == $tag)).tls.reality.handshake.server_port // 443' "${CONFIG_FILE}" 2>/dev/null)
    local current_handshake
    if [[ -n "$current_hs_server" && "$current_hs_server" != "$current_sni" ]]; then
        current_handshake="${current_hs_server}:${current_hs_port}"
    else
        current_handshake="默认 (${current_sni}:443)"
    fi

    while true; do
        echo ""
        printf "${CYAN}修改 Reality 节点 %s:${NC}\n" "$tag"
        printf "  ${GREEN}[1]${NC} 修改端口 (当前: %s)\n" "$port"
        printf "  ${GREEN}[2]${NC} 修改 SNI (当前: %s)\n" "$current_sni"
        printf "  ${GREEN}[3]${NC} 重新生成 UUID\n"
        printf "  ${GREEN}[4]${NC} 重新生成 Short ID\n"
        printf "  ${GREEN}[5]${NC} 修改回落目标 (当前: %s)\n" "$current_handshake"
        printf "  ${GREEN}[0]${NC} 返回\n"
        read -p "请选择: " mod_choice

        case $mod_choice in
            1)
                local port_result
                port_result=$(_modify_port_common "$array_idx" "$tag" "$port" "vless-in-")
                if [[ -n "$port_result" ]]; then
                    read -r tag port <<< "$port_result"
                    _MODIFY_CONFIG_CHANGED=1
                fi
                ;;
            2)
                echo -e "${YELLOW}新 SNI (留空随机)${NC}"
                echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
                read -p "SNI: " new_sni
                if [[ -z "$new_sni" ]]; then
                    new_sni=$(get_random_sni)
                fi
                # 回落目标为默认时同步更新，自定义时只更新 server_name
                if [[ "$current_hs_server" == "$current_sni" || -z "$current_hs_server" ]]; then
                    jq_update_config --arg tag "$tag" --arg sni "$new_sni" \
                        '(.inbounds[] | select(.tag == $tag)) |= (.tls.server_name = $sni | .tls.reality.handshake.server = $sni)'
                    current_hs_server="$new_sni"
                else
                    jq_update_config --arg tag "$tag" --arg sni "$new_sni" \
                        '(.inbounds[] | select(.tag == $tag)) |= (.tls.server_name = $sni)'
                fi
                INBOUND_SNIS[$array_idx]="$new_sni"
                current_sni="$new_sni"
                # 更新回落目标显示
                if [[ "$current_hs_server" == "$current_sni" || -z "$current_hs_server" ]]; then
                    current_handshake="默认 (${current_sni}:443)"
                else
                    current_handshake="${current_hs_server}:${current_hs_port}"
                fi
                _MODIFY_CONFIG_CHANGED=1
                print_success "SNI 已修改为 ${new_sni}"
                ;;
            3)
                regenerate_secret uuid "$tag" || continue
                _MODIFY_CONFIG_CHANGED=1
                ;;
            4)
                regenerate_secret sid "$tag"
                _MODIFY_CONFIG_CHANGED=1
                ;;
            5)
                echo -e "${YELLOW}新回落目标 (回车恢复默认 ${current_sni}:443)${NC}"
                echo -e "${CYAN}格式: server:port 或 server (默认端口443)${NC}"
                echo -e "${CYAN}例如: 127.0.0.1:8085${NC}"
                read -p "回落目标: " new_dest
                if [[ -z "$new_dest" ]]; then
                    # 恢复默认
                    jq_update_config --arg tag "$tag" --arg server "$current_sni" --argjson port 443 \
                        '(.inbounds[] | select(.tag == $tag)) |= (.tls.reality.handshake.server = $server | .tls.reality.handshake.server_port = $port)'
                    current_hs_server="$current_sni"
                    current_hs_port=443
                    current_handshake="默认 (${current_sni}:443)"
                    _MODIFY_CONFIG_CHANGED=1
                    print_success "回落目标已恢复默认: ${current_sni}:443"
                else
                    local new_hs_server="${new_dest%%:*}"
                    local new_hs_port="${new_dest##*:}"
                    if [[ "$new_dest" != *:* ]]; then
                        new_hs_server="$new_dest"
                        new_hs_port=443
                    fi
                    if ! [[ "$new_hs_port" =~ ^[0-9]+$ ]] || (( new_hs_port < 1 || new_hs_port > 65535 )); then
                        print_error "端口无效"; continue
                    fi
                    jq_update_config --arg tag "$tag" --arg server "$new_hs_server" --argjson port "$new_hs_port" \
                        '(.inbounds[] | select(.tag == $tag)) |= (.tls.reality.handshake.server = $server | .tls.reality.handshake.server_port = $port)'
                    current_hs_server="$new_hs_server"
                    current_hs_port="$new_hs_port"
                    current_handshake="${new_hs_server}:${new_hs_port}"
                    _MODIFY_CONFIG_CHANGED=1
                    print_success "回落目标已修改为: ${new_hs_server}:${new_hs_port}"
                fi
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

# ==================== Hysteria2 修改菜单 ====================
_modify_menu_Hysteria2() {
    local array_idx="$1" tag="$2" port="$3" current_sni="$4" proto="$5"

    while true; do
        echo ""
        printf "${CYAN}修改 Hysteria2 节点 %s:${NC}\n" "$tag"
        printf "  ${GREEN}[1]${NC} 修改端口 (当前: %s)\n" "$port"
        printf "  ${GREEN}[2]${NC} 修改 SNI (当前: %s)\n" "$current_sni"
        printf "  ${GREEN}[3]${NC} 重新生成密码\n"
        printf "  ${GREEN}[4]${NC} 重新生成混淆密码\n"
        printf "  ${GREEN}[0]${NC} 返回\n"
        read -p "请选择: " mod_choice

        case $mod_choice in
            1)
                local port_result
                port_result=$(_modify_port_common "$array_idx" "$tag" "$port" "hy2-in-")
                if [[ -n "$port_result" ]]; then
                    read -r tag port <<< "$port_result"
                    _MODIFY_CONFIG_CHANGED=1
                fi
                ;;
            2)
                echo -e "${YELLOW}新 SNI (留空随机)${NC}"
                echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
                read -p "SNI: " new_sni
                if [[ -z "$new_sni" ]]; then
                    new_sni=$(get_random_sni)
                fi
                jq_update_config --arg tag "$tag" --arg sni "$new_sni" --arg certdir "$CERT_DIR" \
                    '(.inbounds[] | select(.tag == $tag)) |= (.tls.server_name = $sni | .tls.certificate_path = ($sni | $certdir + "/" + . + "/cert.pem") | .tls.key_path = ($sni | $certdir + "/" + . + "/private.key"))'
                gen_cert_for_sni "${new_sni}"
                INBOUND_SNIS[$array_idx]="$new_sni"
                current_sni="$new_sni"
                _MODIFY_CONFIG_CHANGED=1
                print_success "SNI 已修改为 ${new_sni}，证书已重新生成"
                ;;
            3)
                regenerate_secret password "$tag"
                _MODIFY_CONFIG_CHANGED=1
                ;;
            4)
                regenerate_secret obfs_password "$tag"
                _MODIFY_CONFIG_CHANGED=1
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

# ==================== SOCKS5 修改菜单 ====================
_modify_menu_SOCKS5() {
    local array_idx="$1" tag="$2" port="$3" current_sni="$4" proto="$5"

    # 读取当前用户名
    local current_user=$(jq -r --arg tag "$tag" '(.inbounds[] | select(.tag == $tag)).users[0].username // ""' "${CONFIG_FILE}")

    while true; do
        echo ""
        printf "${CYAN}修改 SOCKS5 节点 %s:${NC}\n" "$tag"
        printf "  ${GREEN}[1]${NC} 修改端口 (当前: %s)\n" "$port"
        printf "  ${GREEN}[2]${NC} 修改用户名 (当前: %s)\n" "${current_user:-无}"
        printf "  ${GREEN}[3]${NC} 重新生成密码\n"
        printf "  ${GREEN}[0]${NC} 返回\n"
        read -p "请选择: " mod_choice

        case $mod_choice in
            1)
                local port_result
                port_result=$(_modify_port_common "$array_idx" "$tag" "$port" "socks-in-")
                if [[ -n "$port_result" ]]; then
                    read -r tag port <<< "$port_result"
                    _MODIFY_CONFIG_CHANGED=1
                fi
                ;;
            2)
                echo -e "${YELLOW}新用户名 (留空随机生成)${NC}"
                read -p "用户名: " new_user
                if [[ -z "$new_user" ]]; then
                    new_user="user_$(openssl rand -hex 4)"
                fi
                jq_update_config --arg tag "$tag" --arg user "$new_user" \
                    '(.inbounds[] | select(.tag == $tag)) |= (.users[0].username = $user)'
                current_user="$new_user"
                _MODIFY_CONFIG_CHANGED=1
                print_success "用户名已修改为 ${new_user}"
                ;;
            3)
                regenerate_secret socks_password "$tag"
                _MODIFY_CONFIG_CHANGED=1
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

# ==================== ShadowTLS 修改菜单 ====================
_modify_menu_ShadowTLS() {
    local array_idx="$1" tag="$2" port="$3" current_sni="$4" proto="$5"

    while true; do
        echo ""
        printf "${CYAN}修改 ShadowTLS 节点 %s:${NC}\n" "$tag"
        printf "  ${GREEN}[1]${NC} 修改端口 (当前: %s)\n" "$port"
        printf "  ${GREEN}[2]${NC} 修改 SNI (当前: %s)\n" "$current_sni"
        printf "  ${GREEN}[3]${NC} 重新生成 ShadowTLS 密码\n"
        printf "  ${GREEN}[4]${NC} 重新生成 SS 密码\n"
        printf "  ${GREEN}[0]${NC} 返回\n"
        read -p "请选择: " mod_choice

        case $mod_choice in
            1)
                # ShadowTLS 端口修改特殊：需要同时修改 shadowsocks tag
                echo -e "${YELLOW}新端口 (留空随机分配)${NC}"
                read -p "端口: " new_port
                if [[ -z "$new_port" ]]; then
                    new_port=$(get_random_free_port)
                    [[ -z "$new_port" ]] && { print_error "无法获取随机端口"; continue; }
                fi
                if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
                    print_error "端口无效"; continue
                fi
                if check_port_in_use "$new_port" && [[ "$new_port" != "$port" ]]; then
                    print_warning "端口 ${new_port} 已被占用"; continue
                fi
                local new_stls_tag="shadowtls-in-${new_port}"
                local new_ss_tag="shadowsocks-in-${new_port}"
                local old_ss_tag="shadowsocks-in-${port}"
                # Update shadowtls inbound tag, port, and detour
                jq_update_config --arg old_tag "$tag" --arg new_tag "$new_stls_tag" --argjson new_port "$new_port" --arg new_ss_tag "$new_ss_tag" \
                    '(.inbounds[] | select(.tag == $old_tag)) |= (.tag = $new_tag | .listen_port = $new_port | .detour = $new_ss_tag)'
                # Update shadowsocks inbound tag and detour reference
                jq_update_config --arg old_ss_tag "$old_ss_tag" --arg new_ss_tag "$new_ss_tag" \
                    '(.inbounds[] | select(.tag == $old_ss_tag)) |= (.tag = $new_ss_tag)'
                # Update route rules
                if jq -e '.route.rules' "${CONFIG_FILE}" >/dev/null 2>&1; then
                    jq_update_config --arg old_tag "$tag" --arg new_tag "$new_stls_tag" \
                        '(.route.rules[] | select(.inbound[]? == $old_tag)) |= (.inbound = [.inbound[] | if . == $old_tag then $new_tag else . end])'
                fi
                INBOUND_TAGS[$array_idx]="$new_stls_tag"
                INBOUND_PORTS[$array_idx]="$new_port"
                tag="$new_stls_tag"
                port="$new_port"
                _MODIFY_CONFIG_CHANGED=1
                print_success "端口已修改为 ${new_port}，SS 标签和 detour 已同步更新"
                ;;
            2)
                echo -e "${YELLOW}新 SNI (留空随机)${NC}"
                echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
                read -p "SNI: " new_sni
                if [[ -z "$new_sni" ]]; then
                    new_sni=$(get_random_sni)
                fi
                jq_update_config --arg tag "$tag" --arg sni "$new_sni" \
                    '(.inbounds[] | select(.tag == $tag)) |= (.handshake.server = $sni)'
                INBOUND_SNIS[$array_idx]="$new_sni"
                current_sni="$new_sni"
                _MODIFY_CONFIG_CHANGED=1
                print_success "SNI 已修改为 ${new_sni}，handshake.server 已同步更新"
                ;;
            3)
                regenerate_secret stls_password "$tag"
                _MODIFY_CONFIG_CHANGED=1
                print_success "ShadowTLS 密码已重新生成"
                ;;
            4)
                local ss_tag="shadowsocks-in-${port}"
                regenerate_secret ss_password "$ss_tag"
                _MODIFY_CONFIG_CHANGED=1
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

# ==================== HTTPS 修改菜单 ====================
_modify_menu_HTTPS() {
    local array_idx="$1" tag="$2" port="$3" current_sni="$4" proto="$5"

    while true; do
        echo ""
        printf "${CYAN}修改 HTTPS 节点 %s:${NC}\n" "$tag"
        printf "  ${GREEN}[1]${NC} 修改端口 (当前: %s)\n" "$port"
        printf "  ${GREEN}[2]${NC} 修改 SNI (当前: %s)\n" "$current_sni"
        printf "  ${GREEN}[3]${NC} 重新生成 UUID\n"
        printf "  ${GREEN}[0]${NC} 返回\n"
        read -p "请选择: " mod_choice

        case $mod_choice in
            1)
                local port_result
                port_result=$(_modify_port_common "$array_idx" "$tag" "$port" "vless-tls-in-")
                if [[ -n "$port_result" ]]; then
                    read -r tag port <<< "$port_result"
                    _MODIFY_CONFIG_CHANGED=1
                fi
                ;;
            2)
                echo -e "${YELLOW}新 SNI (留空随机)${NC}"
                echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
                read -p "SNI: " new_sni
                if [[ -z "$new_sni" ]]; then
                    new_sni=$(get_random_sni)
                fi
                jq_update_config --arg tag "$tag" --arg sni "$new_sni" --arg certdir "$CERT_DIR" \
                    '(.inbounds[] | select(.tag == $tag)) |= (.tls.server_name = $sni | .tls.certificate_path = ($sni | $certdir + "/" + . + "/cert.pem") | .tls.key_path = ($sni | $certdir + "/" + . + "/private.key"))'
                gen_cert_for_sni "${new_sni}"
                INBOUND_SNIS[$array_idx]="$new_sni"
                current_sni="$new_sni"
                _MODIFY_CONFIG_CHANGED=1
                print_success "SNI 已修改为 ${new_sni}，证书已重新生成"
                ;;
            3)
                regenerate_secret uuid "$tag" || continue
                _MODIFY_CONFIG_CHANGED=1
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

# ==================== AnyTLS 修改菜单 ====================
_modify_menu_AnyTLS() {
    local array_idx="$1" tag="$2" port="$3" current_sni="$4" proto="$5"

    # 判断是否为 AnyTLS+REALITY 模式
    local is_reality=0
    if [[ "$proto" == "AnyTLS+REALITY" ]]; then
        is_reality=1
    fi

    while true; do
        echo ""
        printf "${CYAN}修改 %s 节点 %s:${NC}\n" "$proto" "$tag"
        printf "  ${GREEN}[1]${NC} 修改端口 (当前: %s)\n" "$port"
        printf "  ${GREEN}[2]${NC} 修改 SNI (当前: %s)\n" "$current_sni"
        printf "  ${GREEN}[3]${NC} 重新生成密码\n"
        printf "  ${GREEN}[0]${NC} 返回\n"
        read -p "请选择: " mod_choice

        case $mod_choice in
            1)
                # AnyTLS 端口修改：根据 is_reality 选择前缀
                local new_tag_prefix
                if [[ $is_reality -eq 1 ]]; then
                    new_tag_prefix="anytls-reality-"
                else
                    new_tag_prefix="anytls-in-"
                fi
                local port_result
                port_result=$(_modify_port_common "$array_idx" "$tag" "$port" "$new_tag_prefix")
                if [[ -n "$port_result" ]]; then
                    read -r tag port <<< "$port_result"
                    _MODIFY_CONFIG_CHANGED=1
                fi
                ;;
            2)
                echo -e "${YELLOW}新 SNI (留空随机)${NC}"
                echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
                read -p "SNI: " new_sni
                if [[ -z "$new_sni" ]]; then
                    new_sni=$(get_random_sni)
                fi
                if [[ $is_reality -eq 1 ]]; then
                    jq_update_config --arg tag "$tag" --arg sni "$new_sni" \
                        '(.inbounds[] | select(.tag == $tag)) |= (.tls.server_name = $sni | .tls.reality.handshake.server = $sni)'
                else
                    jq_update_config --arg tag "$tag" --arg sni "$new_sni" \
                        '(.inbounds[] | select(.tag == $tag)) |= (.tls.server_name = $sni | .tls.certificate_path = ($sni | "/etc/sing-box/certs/\(.)" + "/cert.pem") | .tls.key_path = ($sni | "/etc/sing-box/certs/\(.)" + "/private.key"))'
                    gen_cert_for_sni "${new_sni}"
                fi
                INBOUND_SNIS[$array_idx]="$new_sni"
                current_sni="$new_sni"
                _MODIFY_CONFIG_CHANGED=1
                if [[ $is_reality -eq 1 ]]; then
                    print_success "SNI 已修改为 ${new_sni}，handshake.server 已同步更新"
                else
                    print_success "SNI 已修改为 ${new_sni}，证书已重新生成"
                fi
                ;;
            3)
                regenerate_secret password "$tag"
                _MODIFY_CONFIG_CHANGED=1
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

# ==================== 节点删除功能 ====================

# 从全局数组中移除指定索引的节点
remove_inbound_by_index() {
    local idx="$1"
    unset INBOUND_TAGS[$idx]
    unset INBOUND_PORTS[$idx]
    unset INBOUND_PROTOS[$idx]
    unset INBOUND_SNIS[$idx]
    unset INBOUND_RELAY_TAGS[$idx]
    # 重建数组（移除空元素）
    INBOUND_TAGS=("${INBOUND_TAGS[@]}")
    INBOUND_PORTS=("${INBOUND_PORTS[@]}")
    INBOUND_PROTOS=("${INBOUND_PROTOS[@]}")
    INBOUND_SNIS=("${INBOUND_SNIS[@]}")
    INBOUND_RELAY_TAGS=("${INBOUND_RELAY_TAGS[@]}")
}

delete_single_node() {
    if [[ ${#INBOUND_TAGS[@]} -eq 0 ]]; then
        print_warning "当前没有可删除的节点"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}当前节点列表:${NC}"
    for i in "${!INBOUND_TAGS[@]}"; do
        idx=$((i+1))
        echo -e "  ${GREEN}[${idx}]${NC} 协议: ${INBOUND_PROTOS[$i]}, 端口: ${INBOUND_PORTS[$i]}, SNI: ${INBOUND_SNIS[$i]}, TAG: ${INBOUND_TAGS[$i]}"
    done
    echo ""
    echo -e "${RED}警告: 删除节点后无法恢复！${NC}"
    read -p "请输入要删除的节点序号 (输入 0 取消): " node_idx
    
    if [[ "$node_idx" == "0" ]]; then
        print_info "取消删除操作"
        return 0
    fi
    
    if ! [[ "$node_idx" =~ ^[0-9]+$ ]] || (( node_idx < 1 || node_idx > ${#INBOUND_TAGS[@]} )); then
        print_error "序号无效"
        return 1
    fi
    
    local index=$((node_idx-1))
    local tag="${INBOUND_TAGS[$index]}"
    local port="${INBOUND_PORTS[$index]}"
    local proto="${INBOUND_PROTOS[$index]}"
    local sni="${INBOUND_SNIS[$index]}"
    
    echo ""
    echo -e "${YELLOW}确认删除以下节点:${NC}"
    echo -e "  协议: ${proto}"
    echo -e "  端口: ${port}"
    echo -e "  SNI: ${sni}"
    echo -e "  TAG: ${tag}"
    echo ""

    if ! confirm "确认删除? (y/N): "; then
        print_info "取消删除操作"
        return 0
    fi
    
    # 从配置文件中删除节点
    if [[ -f "${CONFIG_FILE}" ]] && command -v jq &>/dev/null; then
        print_info "从配置文件删除节点..."

        # 使用 jq 原子更新（jq_update_config 会校验非空 + 原子替换）
        # 如果是 ShadowTLS，需要同时删除对应的 shadowsocks-in 节点
        if [[ "$proto" == "ShadowTLS v3" ]]; then
            local ss_tag="shadowsocks-in-${port}"
            jq_update_config --arg tag "$tag" --arg ss_tag "$ss_tag" \
                '.inbounds |= map(select(.tag != $tag and .tag != $ss_tag))' \
                || { print_error "删除节点失败"; return 1; }
        else
            jq_update_config --arg tag "$tag" \
                '.inbounds |= map(select(.tag != $tag))' \
                || { print_error "删除节点失败"; return 1; }
        fi

        # 从数组中删除
        remove_inbound_by_index "$index"

        # 重新加载配置
        load_inbounds_from_config
        
        # 重新生成链接文件
        print_info "重新生成链接文件..."
        regenerate_links_from_config
        
        # 重启服务
        print_info "重启服务..."
        svc_restart
        sleep 2
        
        if svc_is_active; then
            print_success "节点已删除: ${proto}:${port} (SNI: ${sni})"
            print_success "服务已重启"
        else
            print_error "服务重启失败"
            if [[ $ALPINE -eq 1 ]]; then
                tail -n 10 /var/log/messages | grep sing-box || cat /var/log/sing-box.log 2>/dev/null
            else
                journalctl -u sing-box -n 10 --no-pager
            fi
        fi
    else
        print_error "无法删除节点：配置文件不存在或 jq 未安装"
        return 1
    fi
}

delete_all_nodes() {
    echo ""
    echo -e "${RED}⚠️  警告: 此操作将删除所有节点配置！${NC}"
    echo -e "${YELLOW}当前共有 ${#INBOUND_TAGS[@]} 个节点${NC}"
    echo ""
    echo -e "删除后:"
    echo -e "  1. 所有节点配置将被清空"
    echo -e "  2. 配置文件将只保留基础结构"
    echo -e "  3. 需要重新添加节点"
    echo ""
    
    if ! confirm "确认删除所有节点? (y/N): "; then
        print_info "取消删除操作"
        return 0
    fi
    
    INBOUNDS_JSON=""
    INBOUND_TAGS=()
    INBOUND_PORTS=()
    INBOUND_PROTOS=()
    INBOUND_SNIS=()
    INBOUND_RELAY_TAGS=()

    # 使用 build_dns_config 生成完整 DNS 配置（包含自定义 DNS 和分流规则）
    local dns_json
    dns_json=$(build_dns_config)

    # 1.12.0+ 支持 default_domain_resolver
    # 1.14.0+ 强制要求：所有使用域名的 outbound 必须有 domain_resolver
    # 设为 "remote" 确保能解析外部域名，同时根据出站模式设置 strategy
    local route_domain_resolver=""
    if [[ $SB_GE_1_12 -eq 1 ]]; then
        case "$OUTBOUND_IP_MODE" in
            ipv4)
                route_domain_resolver=",
    \"default_domain_resolver\": {\"server\": \"remote\", \"strategy\": \"ipv4_only\"}"
                ;;
            ipv6_only)
                route_domain_resolver=",
    \"default_domain_resolver\": {\"server\": \"remote\", \"strategy\": \"ipv6_only\"}"
                ;;
            ipv6)
                route_domain_resolver=",
    \"default_domain_resolver\": {\"server\": \"remote\", \"strategy\": \"prefer_ipv6\"}"
                ;;
            *)
                route_domain_resolver=",
    \"default_domain_resolver\": \"remote\""
                ;;
        esac
    fi

    cat > ${CONFIG_FILE} << EOFCONFIG
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": ${dns_json},
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "direct"${route_domain_resolver}
  }
}
EOFCONFIG
    
    print_info "停止 sing-box 服务..."
    svc_stop
    
    cleanup_links
    
    print_success "所有节点已删除，配置文件已重置"
    
    read -p "是否启动空配置的 sing-box 服务? (y/N): " restart_service
    restart_service=${restart_service:-N}
    
    if [[ "$restart_service" =~ ^[Yy]$ ]]; then
        svc_start
        sleep 2
        if svc_is_active; then
            print_success "服务已启动 (空配置)"
        else
            print_error "服务启动失败"
        fi
    fi
}
# ==================== 配置生成子函数 ====================

# 构建 outbounds 数组
build_outbounds() {
    local outbounds_array=()

    # 根据出站模式确定中转 outbound 的 domain_strategy 和绑定地址
    local relay_domain_strategy=""
    local relay_bind_fields=""
    case "$OUTBOUND_IP_MODE" in
        ipv6)
            relay_domain_strategy="prefer_ipv6"
            [[ -n "${SERVER_IPV6}" ]] && relay_bind_fields="\"inet6_bind_address\":\"${SERVER_IPV6}\",\"fallback_delay\":\"300ms\""
            ;;
        ipv6_only)
            relay_domain_strategy="ipv6_only"
            [[ -n "${SERVER_IPV6}" ]] && relay_bind_fields="\"inet6_bind_address\":\"${SERVER_IPV6}\""
            ;;
        ipv4)
            relay_domain_strategy="ipv4_only"
            # 不绑定 inet4_bind_address，仅用 domain_resolver strategy 控制出站
            # 绑定地址在某些网络配置下会导致连接失败 (sing-box issue #3440)
            ;;
        dual|"")
            # dual 模式：同时支持 IPv4/IPv6，不绑定特定地址
            relay_domain_strategy="prefer_ipv4"
            relay_bind_fields="\"fallback_delay\":\"300ms\""
            ;;
    esac

    # 添加所有中转 outbound（注入域名解析策略和绑定地址）
    for relay_json in "${RELAY_JSONS[@]}"; do
        # 域名解析策略：1.11.x 用 domain_strategy，1.12.0+ 用 domain_resolver
        if [[ -n "$relay_domain_strategy" ]]; then
            if [[ $SB_GE_1_12 -eq 1 ]]; then
                relay_json=$(echo "$relay_json" | jq --arg ds "$relay_domain_strategy" \
                    '. + {"domain_resolver": {"server": "remote", "strategy": $ds}}' 2>/dev/null || echo "$relay_json")
            else
                relay_json=$(echo "$relay_json" | jq --arg ds "$relay_domain_strategy" \
                    '. + {"domain_strategy": $ds}' 2>/dev/null || echo "$relay_json")
            fi
        fi
        if [[ -n "$relay_bind_fields" ]]; then
            local bind_json
            bind_json=$(echo "{$relay_bind_fields}" | jq . 2>/dev/null)
            if [[ -n "$bind_json" ]]; then
                relay_json=$(echo "$relay_json" | jq --argjson bind "$bind_json" '. + $bind' 2>/dev/null || echo "$relay_json")
            fi
        fi
        outbounds_array+=("$relay_json")
    done

    # 添加 direct outbound（根据出站模式设置绑定地址和域名解析策略）
    local bind_field="" resolver_strategy=""
    case "$OUTBOUND_IP_MODE" in
        ipv6)
            [[ -n "${SERVER_IPV6}" ]] && bind_field=",\"inet6_bind_address\":\"${SERVER_IPV6}\",\"fallback_delay\":\"300ms\""
            resolver_strategy="prefer_ipv6"
            ;;
        ipv6_only)
            [[ -n "${SERVER_IPV6}" ]] && bind_field=",\"inet6_bind_address\":\"${SERVER_IPV6}\""
            resolver_strategy="ipv6_only"
            ;;
        ipv4)
            # 不绑定 inet4_bind_address，仅用 domain_resolver strategy 控制出站
            # 绑定地址在某些网络配置下会导致连接失败 (sing-box issue #3440)
            resolver_strategy="ipv4_only"
            ;;
    esac

    local direct_outbound
    if [[ -n "$resolver_strategy" ]]; then
        if [[ $SB_GE_1_12 -eq 1 ]]; then
            # 1.12.0+ 使用 domain_resolver
            direct_outbound="{\"type\":\"direct\",\"tag\":\"direct\",\"tcp_fast_open\":false${bind_field},\"domain_resolver\":{\"server\":\"remote\",\"strategy\":\"${resolver_strategy}\"}}"
        else
            # 1.11.x 使用 domain_strategy
            direct_outbound="{\"type\":\"direct\",\"tag\":\"direct\",\"tcp_fast_open\":false${bind_field},\"domain_strategy\":\"${resolver_strategy}\"}"
        fi
    else
        direct_outbound='{"type":"direct","tag":"direct","tcp_fast_open":false}'
    fi
    outbounds_array+=("$direct_outbound")

    # ipv6_only 模式下阻断 IPv4 出站
    if [[ "$OUTBOUND_IP_MODE" == "ipv6_only" ]]; then
        if [[ $SB_GE_1_11 -eq 1 ]]; then
            : # 1.11.0+ 使用 route rule action reject，不需要 block outbound
        else
            local block_outbound='{"type": "block", "tag": "block-ipv4"}'
            outbounds_array+=("$block_outbound")
        fi
    fi

    # 组合 outbounds JSON 数组
    local outbounds="["
    for i in "${!outbounds_array[@]}"; do
        [[ $i -gt 0 ]] && outbounds+=", "
        outbounds+="${outbounds_array[$i]}"
    done
    outbounds+="]"

    echo "$outbounds"
}

# 构建路由规则
build_route_rules() {
    local route_rules=()

    # 添加协议嗅探规则（1.11.0+ 使用 route rule action）
    if [[ $SB_GE_1_11 -eq 1 ]]; then
        route_rules+=('{"action":"sniff","sniffer":["http","tls","quic"]}')
    fi

    # ipv6_only 模式下，添加规则阻断所有 IPv4 出站流量
    if [[ "$OUTBOUND_IP_MODE" == "ipv6_only" ]]; then
        if [[ $SB_GE_1_11 -eq 1 ]]; then
            route_rules+=('{"ip_cidr":["0.0.0.0/0"],"action":"reject"}')
        else
            route_rules+=('{"ip_cidr":["0.0.0.0/0"],"outbound":"block-ipv4"}')
        fi
    fi

    # 1. 添加所有分流域名规则
    for route in "${DOMAIN_ROUTES[@]}"; do
        IFS='|' read -r inbound_tag match_type match_value relay_tag desc <<< "$route"
        [[ -z "$inbound_tag" || -z "$match_type" || -z "$match_value" || -z "$relay_tag" ]] && continue

        # 检查中转是否存在
        local relay_exists=0
        for rt in "${RELAY_TAGS[@]}"; do
            [[ "$rt" == "$relay_tag" ]] && relay_exists=1 && break
        done
        if [[ $relay_exists -eq 0 ]]; then
            print_warning "分流规则引用的中转 ${relay_tag} 不存在，跳过规则: ${match_type}=${match_value}"
            continue
        fi

        # 根据匹配类型生成对应的 sing-box 规则
        local rule_part=""
        case "$match_type" in
            domain_suffix)  rule_part="\"domain_suffix\":[\"${match_value}\"]" ;;
            domain)         rule_part="\"domain\":[\"${match_value}\"]" ;;
            domain_keyword) rule_part="\"domain_keyword\":[\"${match_value}\"]" ;;
            ip_cidr)        rule_part="\"ip_cidr\":[\"${match_value}\"]" ;;
            *)              continue ;;
        esac

        route_rules+=("{\"inbound\":[\"${inbound_tag}\"],${rule_part},\"outbound\":\"${relay_tag}\"}")
    done

    # 2. 为每个节点添加默认路由（仅当节点配置了中转且不是 direct）
    for i in "${!INBOUND_TAGS[@]}"; do
        local inbound_tag="${INBOUND_TAGS[$i]}"
        local relay_tag="${INBOUND_RELAY_TAGS[$i]}"

        if [[ "$relay_tag" != "direct" ]]; then
            local relay_exists=0
            for rt in "${RELAY_TAGS[@]}"; do
                [[ "$rt" == "$relay_tag" ]] && relay_exists=1 && break
            done
            if [[ $relay_exists -eq 0 ]]; then
                print_warning "节点 ${inbound_tag} 配置的中转 ${relay_tag} 不存在，将改为直连"
                INBOUND_RELAY_TAGS[$i]="direct"
                continue
            fi
            route_rules+=("{\"inbound\":[\"${inbound_tag}\"],\"outbound\":\"${relay_tag}\"}")
        fi
    done

    # 组合路由 JSON（根据 route_rules 是否非空决定是否包含 rules 数组）
    # 1.14.0+ 强制要求 default_domain_resolver
    # default_domain_resolver 需要包含 strategy，否则内部解析可能返回 AAAA 记录
    local route_domain_resolver=""
    if [[ $SB_GE_1_12 -eq 1 ]]; then
        case "$OUTBOUND_IP_MODE" in
            ipv4)
                route_domain_resolver=",\"default_domain_resolver\":{\"server\":\"remote\",\"strategy\":\"ipv4_only\"}"
                ;;
            ipv6_only)
                route_domain_resolver=",\"default_domain_resolver\":{\"server\":\"remote\",\"strategy\":\"ipv6_only\"}"
                ;;
            ipv6)
                route_domain_resolver=",\"default_domain_resolver\":{\"server\":\"remote\",\"strategy\":\"prefer_ipv6\"}"
                ;;
            *)
                route_domain_resolver=",\"default_domain_resolver\":\"remote\""
                ;;
        esac
    fi
    local route_json
    if [[ ${#route_rules[@]} -gt 0 ]]; then
        route_json="{\"rules\":["
        for i in "${!route_rules[@]}"; do
            [[ $i -gt 0 ]] && route_json+=","
            route_json+="${route_rules[$i]}"
        done
        route_json+="],\"final\":\"direct\"${route_domain_resolver}}"
    else
        route_json="{\"final\":\"direct\"${route_domain_resolver}}"
    fi

    echo "$route_json"
}

# 构建 DNS 配置
build_dns_config() {
    local dns_strategy="prefer_ipv4"
    [[ "$OUTBOUND_IP_MODE" == "ipv4" ]] && dns_strategy="ipv4_only"
    [[ "$OUTBOUND_IP_MODE" == "ipv6" ]] && dns_strategy="prefer_ipv6"
    [[ "$OUTBOUND_IP_MODE" == "ipv6_only" ]] && dns_strategy="ipv6_only"

    local dns_remote_server
    dns_remote_server=$(build_dns_remote_server)

    # 加载自定义 DNS 服务器和分流规则
    load_dns_servers_from_file
    load_dns_routes_from_file

    # 构建自定义 DNS 服务器 JSON
    local custom_dns_servers=""
    for entry in "${DNS_SERVERS[@]}"; do
        IFS='|' read -r tag type server desc <<< "$entry"
        local dns_server_json=""
        case "$type" in
            "doh")
                if [[ $SB_GE_1_12 -eq 1 ]]; then
                    dns_server_json="{\"tag\": \"${tag}\", \"type\": \"https\", \"server\": \"${server}\", \"server_port\": 443, \"domain_resolver\": \"local\"}"
                else
                    dns_server_json="{\"tag\": \"${tag}\", \"type\": \"https\", \"server\": \"${server}\", \"server_port\": 443, \"address_resolver\": \"local\"}"
                fi
                ;;
            "dot")
                if [[ $SB_GE_1_12 -eq 1 ]]; then
                    dns_server_json="{\"tag\": \"${tag}\", \"type\": \"tls\", \"server\": \"${server}\", \"server_port\": 853, \"domain_resolver\": \"local\"}"
                else
                    dns_server_json="{\"tag\": \"${tag}\", \"type\": \"tls\", \"server\": \"${server}\", \"server_port\": 853, \"address_resolver\": \"local\"}"
                fi
                ;;
            "udp"|*)
                dns_server_json="{\"tag\": \"${tag}\", \"type\": \"udp\", \"server\": \"${server}\"}"
                ;;
        esac
        if [[ -n "$custom_dns_servers" ]]; then
            custom_dns_servers+="
      ,${dns_server_json}"
        else
            custom_dns_servers="
      ${dns_server_json}"
        fi
    done

    # 构建 DNS 分流规则 JSON
    local dns_rules=""
    for route in "${DNS_ROUTES[@]}"; do
        IFS='|' read -r match_type match_value dns_tag desc <<< "$route"
        local rule_json=""

        if [[ "$match_type" == "inbound" ]]; then
            # 节点级 DNS 分流
            rule_json="{\"inbound\": [\"${match_value}\"], \"server\": \"${dns_tag}\"}"
        else
            # 域名级 DNS 分流（支持逗号分隔多个域名）
            local rule_field=""
            case "$match_type" in
                domain_suffix)  rule_field="domain_suffix" ;;
                domain)         rule_field="domain" ;;
                domain_keyword) rule_field="domain_keyword" ;;
                *)              continue ;;
            esac

            # 将逗号分隔的域名转为 JSON 数组
            local domains_json=$(echo "$match_value" | awk -F',' '{for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i);printf "\"%s\"", $i; if(i<NF) printf ","}}')
            rule_json="{\"${rule_field}\": [${domains_json}], \"server\": \"${dns_tag}\"}"
        fi

        if [[ -n "$dns_rules" ]]; then
            dns_rules+="
      ,${rule_json}"
        else
            dns_rules="
      ${rule_json}"
        fi
    done

    # 1.14.0+ 支持 optimistic DNS 缓存，降低 DNS 延迟
    local dns_optimistic=""
    if [[ $SB_GE_1_14 -eq 1 ]]; then
        dns_optimistic=",
    \"optimistic\": true"
    fi

    # 构建 DNS rules 部分
    local dns_rules_section=""
    if [[ -n "$dns_rules" ]]; then
        dns_rules_section="
    \"rules\": [${dns_rules}
    ],"
    fi

    # 拼接 DNS servers 列表：remote 后面加逗号，再接自定义 DNS
    local dns_servers_list="${dns_remote_server}"
    if [[ -n "$custom_dns_servers" ]]; then
        dns_servers_list+=",${custom_dns_servers}"
    fi

    local dns_json="{
    \"servers\": [
      {
        \"tag\": \"local\",
        \"type\": \"local\"
      },
      ${dns_servers_list}
    ],
    ${dns_rules_section}\"final\": \"remote\",
    \"strategy\": \"${dns_strategy}\"${dns_optimistic}
  }"

    echo "$dns_json"
}

# ==================== 配置生成（主函数） ====================
generate_config() {
    print_info "生成最终配置文件..."

    if [[ -f "${CONFIG_FILE}" ]]; then
        local backup_file="${CONFIG_FILE}.bak"
        cp "${CONFIG_FILE}" "${backup_file}" 2>/dev/null
        print_info "已备份配置到: ${backup_file}"
    fi

    if [[ -z "$INBOUNDS_JSON" ]]; then
        print_error "未找到任何入站节点，请先添加节点"
        return 1
    fi

    # 加载中转配置
    load_relays_from_file

    # 构建各部分配置
    local outbounds
    outbounds=$(build_outbounds)

    # 加载分流规则
    load_domain_routes_from_file

    local route_json
    route_json=$(build_route_rules)

    local dns_json
    dns_json=$(build_dns_config)

    cat > ${CONFIG_FILE} << EOFCONFIG
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": ${dns_json},
  "inbounds": [${INBOUNDS_JSON}],
  "outbounds": ${outbounds},
  "route": ${route_json}
}
EOFCONFIG

    print_success "配置文件生成完成"
}

start_svc() {
    # 检查 sing-box 二进制是否存在
    if [[ ! -x "${INSTALL_DIR}/sing-box" ]]; then
        print_error "sing-box 未安装或不可执行 (${INSTALL_DIR}/sing-box)"
        print_info "请先执行安装或重启脚本以完成安装"
        return 1
    fi

    print_info "验证配置文件..."

    local check_output
    check_output=$("${INSTALL_DIR}/sing-box" check -c "${CONFIG_FILE}" 2>&1)
    local check_exit_code=$?

    if [[ $check_exit_code -ne 0 ]]; then
        print_error "配置验证失败 (退出码: ${check_exit_code})"
        print_warning "错误详情:"
        echo "$check_output"
        echo ""
        # 自动回滚到备份配置
        if [[ -f "${CONFIG_FILE}.bak" ]]; then
            print_warning "正在自动回滚到备份配置..."
            cp "${CONFIG_FILE}.bak" "${CONFIG_FILE}"
            print_success "已回滚到备份配置"
            # 尝试用备份配置重启
            if "${INSTALL_DIR}/sing-box" check -c "${CONFIG_FILE}" >/dev/null 2>&1; then
                print_info "使用备份配置重启服务..."
                svc_restart
                sleep 2
                if svc_is_active; then
                    print_success "服务已使用备份配置恢复运行"
                fi
            fi
        fi
        return 1
    fi
    
    if echo "$check_output" | grep -q "WARN"; then
        print_warning "配置验证通过，但有警告："
        echo "$check_output" | grep "WARN"
        echo ""
    else
        print_success "配置验证通过"
    fi
    
    print_info "启动 sing-box 服务..."
    svc_restart
    sleep 2
    
    if svc_is_active; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败，查看日志："
        if [[ $ALPINE -eq 1 ]]; then
            tail -n 10 /var/log/messages | grep sing-box || cat /var/log/sing-box.log 2>/dev/null
        else
            journalctl -u sing-box -n 10 --no-pager
        fi
        return 1
    fi
}
# ==================== 结果显示 ====================
show_result() {
    clear
    echo ""
    menu_header "配置完成！"
    echo -e "${YELLOW}服务器信息:${NC}"
    echo -e "  协议: ${GREEN}${PROTO}${NC}"
    echo -e "  IP: ${GREEN}${SERVER_IP}${NC}"
    echo -e "  端口: ${GREEN}${PORT}${NC}"
    echo ""
    
    if [[ -n "$EXTRA_INFO" ]]; then
        echo -e "${YELLOW}协议详情:${NC}"
        echo -e "$EXTRA_INFO" | sed 's/^/  /'
        echo ""
    fi
    
    echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}📋 新添加的节点链接:${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
    echo ""
    # 只显示新添加的节点链接
    if [[ -n "$CURRENT_NEW_LINKS" ]]; then
        echo -e "${YELLOW}${CURRENT_NEW_LINKS}${NC}"
    else
        echo -e "${YELLOW}${LINK}${NC}"
    fi
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}💡 提示: 去菜单的 [配置与查看] 可以查看全部节点链接${NC}"
}
