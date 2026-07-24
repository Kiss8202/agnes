# ==================== sing-box 协议配置模块 ====================
# ==================== Reality 配置 ====================
setup_reality() {
    echo ""
    read_port_with_check 443
    
    echo -e "${YELLOW}请输入SNI域名（建议使用常见HTTPS网站域名）${NC}"
    echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
    while true; do
        read -p "SNI域名 [${DEFAULT_SNI}]: " SNI
        SNI=${SNI:-${DEFAULT_SNI}}
        if validate_sni "$SNI"; then
            break
        fi
        print_warning "请重新输入有效的域名格式"
    done

    # 询问回落目标（handshake destination）
    local handshake_server="${SNI}"
    local handshake_port=443
    echo ""
    echo -e "${YELLOW}是否自定义回落目标？(回车默认 ${SNI}:443)${NC}"
    echo -e "${CYAN}说明: 回落目标决定主动探测时返回的内容，默认转发到 SNI 站点${NC}"
    echo -e "${CYAN}自定义可指向本地 Web 服务，如 127.0.0.1:8085${NC}"
    read -p "回落目标 [回车默认]: " custom_dest
    if [[ -n "$custom_dest" ]]; then
        if [[ "$custom_dest" == *:* ]]; then
            handshake_server="${custom_dest%%:*}"
            handshake_port="${custom_dest##*:}"
        else
            handshake_server="$custom_dest"
        fi
        if ! [[ "$handshake_port" =~ ^[0-9]+$ ]] || (( handshake_port < 1 || handshake_port > 65535 )); then
            print_warning "端口无效，使用默认 443"
            handshake_port=443
        fi
        print_info "回落目标: ${handshake_server}:${handshake_port}"
    fi

    # 每个节点使用独立UUID
    local NODE_UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [[ -z "$NODE_UUID" ]]; then
        print_error "UUID 生成失败，请检查系统环境"
        return 1
    fi
    print_info "节点 UUID: ${NODE_UUID}"
    
    print_info "生成配置文件..."
    
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"vless\",
  \"tag\": \"vless-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"uuid\": \"${NODE_UUID}\", \"flow\": \"xtls-rprx-vision\"}],
  \"tls\": {
    \"enabled\": true,
    \"server_name\": \"${SNI}\",
    \"min_version\": \"1.3\",
    \"reality\": {
      \"enabled\": true,
      \"handshake\": {\"server\": \"${handshake_server}\", \"server_port\": ${handshake_port}},
      \"private_key\": \"${REALITY_PRIVATE}\",
      \"short_id\": [\"${SHORT_ID}\"]
    }
  }
}"
    
    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi
    
    # 生成 Reality 链接 - 同时支持 IPv4 和 IPv6
    PROTO="Reality"
    EXTRA_INFO="UUID: ${NODE_UUID}\nPublic Key: ${REALITY_PUBLIC}\nShort ID: ${SHORT_ID}\nSNI: ${SNI}"
    
    # 保存新添加节点的链接（只用于显示）
    CURRENT_NEW_LINKS=""
    
    # IPv4 链接
    local link_ipv4=$(generate_proto_link "reality" "${SERVER_IP}" "${PORT}" "uuid=${NODE_UUID}" "sni=${SNI}" "pbk=${REALITY_PUBLIC}" "sid=${SHORT_ID}")
    add_link "$link_ipv4" "Reality" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${SNI}"
    LINK="$link_ipv4"  # 默认链接

    # 添加到新链接显示
    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[Reality] ${SERVER_IP}:${PORT} (SNI: ${SNI})\n${link_ipv4}\n----------------------------------------\n\n"

    # IPv6 链接（如果有）
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "reality" "[${SERVER_IPV6}]" "${PORT}" "uuid=${NODE_UUID}" "sni=${SNI}" "pbk=${REALITY_PUBLIC}" "sid=${SHORT_ID}")
        add_link "$link_ipv6" "Reality" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[Reality] [${SERVER_IPV6}]:${PORT} (SNI: ${SNI})\n${link_ipv6}\n----------------------------------------\n\n"
    fi
    
    INBOUND_TAGS+=("vless-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${SNI}")
    INBOUND_RELAY_TAGS+=("direct")
    
    print_success "Reality 配置完成 (SNI: ${SNI})"
    save_links_to_files
}

# ==================== Hysteria2 配置（已升级，含混淆） ====================
setup_hysteria2() {
    echo ""
    read_port_with_check 443
    
    echo -e "${YELLOW}请输入SNI域名（建议使用常见HTTPS网站域名）${NC}"
    echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
    while true; do
        read -p "SNI域名 [${DEFAULT_SNI}]: " HY2_SNI
        HY2_SNI=${HY2_SNI:-${DEFAULT_SNI}}
        if validate_sni "$HY2_SNI"; then
            break
        fi
        print_warning "请重新输入有效的域名格式"
    done
    
    # 是否启用 Salamander 混淆
    read -p "是否启用 Salamander 混淆？(y/N): " ENABLE_OBFS
    ENABLE_OBFS=${ENABLE_OBFS:-N}
    OBFS_PASSWORD=""
    if [[ "$ENABLE_OBFS" =~ ^[Yy]$ ]]; then
        read -p "混淆密码 (留空随机生成16位hex): " OBFS_PASSWORD
        if [[ -z "$OBFS_PASSWORD" ]]; then
            OBFS_PASSWORD=$(openssl rand -hex 16)
        fi
        print_info "混淆密码: ${OBFS_PASSWORD}"
    fi

    # 带宽配置（Brutal 拥塞控制）
    echo -e "${YELLOW}是否配置带宽限制？(y/N)${NC}"
    echo -e "${CYAN}提示: Hysteria2 使用 Brutal 拥塞控制，配置带宽可获得更好性能${NC}"
    read -p "配置带宽? [y/N]: " ENABLE_BW
    ENABLE_BW=${ENABLE_BW:-N}
    local BW_CONFIG=""
    local IGNORE_CLIENT_BW=""
    if [[ "$ENABLE_BW" =~ ^[Yy]$ ]]; then
        read -p "上传带宽 (Mbps, 留空不限制): " UP_MBPS
        read -p "下载带宽 (Mbps, 留空不限制): " DOWN_MBPS
        local bw_parts=""
        if [[ -n "$UP_MBPS" && "$UP_MBPS" =~ ^[0-9]+$ ]]; then
            bw_parts+="\"up_mbps\": ${UP_MBPS}"
        fi
        if [[ -n "$DOWN_MBPS" && "$DOWN_MBPS" =~ ^[0-9]+$ ]]; then
            [[ -n "$bw_parts" ]] && bw_parts+=","
            bw_parts+="\"down_mbps\": ${DOWN_MBPS}"
        fi
        if [[ -n "$bw_parts" ]]; then
            BW_CONFIG=",${bw_parts}"
        else
            # 用户选择配置带宽但都留空，等同于不配置带宽
            IGNORE_CLIENT_BW=",
  \"ignore_client_bandwidth\": true"
        fi
    else
        # 不配置带宽时，强制客户端使用 BBR CC，避免 Brutal CC 无带宽限制导致无法传输数据
        IGNORE_CLIENT_BW=",
  \"ignore_client_bandwidth\": true"
    fi

    print_info "为 ${HY2_SNI} 生成自签证书..."
    gen_cert_for_sni "${HY2_SNI}"
    
    print_info "生成配置文件..."
    
    # 每个节点使用独立密码
    local NODE_HY2_PASSWORD=$(openssl rand -hex 16)
    print_info "节点密码: ${NODE_HY2_PASSWORD}"
    
    # 构建 obfs 配置
    local obfs_config=""
    if [[ "$ENABLE_OBFS" =~ ^[Yy]$ ]]; then
        obfs_config=",
    \"obfs\": {
      \"type\": \"salamander\",
      \"password\": \"${OBFS_PASSWORD}\"
    }"
    fi
    
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"hysteria2\",
  \"tag\": \"hy2-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"password\": \"${NODE_HY2_PASSWORD}\"}]${BW_CONFIG}${IGNORE_CLIENT_BW},
  \"tls\": {
    \"enabled\": true,
    \"alpn\": [\"h3\"],
    \"min_version\": \"1.3\",
    \"server_name\": \"${HY2_SNI}\",
    \"certificate_path\": \"${CERT_DIR}/${HY2_SNI}/cert.pem\",
    \"key_path\": \"${CERT_DIR}/${HY2_SNI}/private.key\"
  }${obfs_config},
  \"masquerade\": {
    \"type\": \"proxy\",
    \"url\": \"https://www.bing.com\",
    \"rewrite_host\": true
  }
}"
    
    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi
    
    PROTO="Hysteria2"
    EXTRA_INFO="密码: ${NODE_HY2_PASSWORD}\n证书: 自签证书(${HY2_SNI})\nSNI: ${HY2_SNI}"
    if [[ "$ENABLE_OBFS" =~ ^[Yy]$ ]]; then
        EXTRA_INFO="${EXTRA_INFO}\nSalamander混淆: 已启用 (密码: ${OBFS_PASSWORD})"
    fi
    
    # 保存新添加节点的链接（只用于显示）
    CURRENT_NEW_LINKS=""
    
    # IPv4 链接
    local obfs_type_val=""
    local obfs_password_val=""
    if [[ "$ENABLE_OBFS" =~ ^[Yy]$ ]]; then
        obfs_type_val="salamander"
        obfs_password_val="${OBFS_PASSWORD}"
    fi
    local link_ipv4=$(generate_proto_link "hysteria2" "${SERVER_IP}" "${PORT}" "password=${NODE_HY2_PASSWORD}" "sni=${HY2_SNI}" "obfs_type=${obfs_type_val}" "obfs_password=${obfs_password_val}")
    add_link "$link_ipv4" "Hysteria2" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${HY2_SNI}"
    LINK="$link_ipv4"  # 默认链接

    # 添加到新链接显示
    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[Hysteria2] ${SERVER_IP}:${PORT} (SNI: ${HY2_SNI})\n${link_ipv4}\n----------------------------------------\n\n"

    # IPv6 链接（如果有）
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "hysteria2" "[${SERVER_IPV6}]" "${PORT}" "password=${NODE_HY2_PASSWORD}" "sni=${HY2_SNI}" "obfs_type=${obfs_type_val}" "obfs_password=${obfs_password_val}")
        add_link "$link_ipv6" "Hysteria2" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${HY2_SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[Hysteria2] [${SERVER_IPV6}]:${PORT} (SNI: ${HY2_SNI})\n${link_ipv6}\n----------------------------------------\n\n"
    fi
    
    INBOUND_TAGS+=("hy2-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${HY2_SNI}")
    INBOUND_RELAY_TAGS+=("direct")
    
    print_success "Hysteria2 配置完成 (SNI: ${HY2_SNI})"
    save_links_to_files
}

# ==================== SOCKS5 配置 ====================
setup_socks5() {
    echo ""
    read_port_with_check 1080
    read -p "是否启用认证? [Y/n]: " ENABLE_AUTH
    ENABLE_AUTH=${ENABLE_AUTH:-Y}
    
    print_info "生成配置文件..."
    
    # 每个节点使用独立凭据
    local NODE_SOCKS_USER="user_$(openssl rand -hex 4)"
    local NODE_SOCKS_PASS=$(openssl rand -hex 16)
    
    local listen_addr=$(get_listen_address)
    
    if [[ "$ENABLE_AUTH" =~ ^[Yy]$ ]]; then
        local inbound="{
  \"type\": \"socks\",
  \"tag\": \"socks-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"username\": \"${NODE_SOCKS_USER}\", \"password\": \"${NODE_SOCKS_PASS}\"}]
}"
        EXTRA_INFO="用户名: ${NODE_SOCKS_USER}\n密码: ${NODE_SOCKS_PASS}"
    else
        local inbound="{
  \"type\": \"socks\",
  \"tag\": \"socks-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT}
}"
        EXTRA_INFO="无认证"
    fi
    
    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi
    
    PROTO="SOCKS5"
    
    # 保存新添加节点的链接（只用于显示）
    CURRENT_NEW_LINKS=""
    
    # IPv4 链接
    local link_ipv4=""
    if [[ "$ENABLE_AUTH" =~ ^[Yy]$ ]]; then
        link_ipv4="socks5://${NODE_SOCKS_USER}:${NODE_SOCKS_PASS}@${SERVER_IP}:${PORT}#SOCKS5-${SERVER_IP}"
    else
        link_ipv4="socks5://${SERVER_IP}:${PORT}#SOCKS5-${SERVER_IP}"
    fi
    add_link "$link_ipv4" "SOCKS5" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" ""
    LINK="$link_ipv4"  # 默认链接
    
    # 添加到新链接显示
    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[SOCKS5] ${SERVER_IP}:${PORT}\n${link_ipv4}\n----------------------------------------\n\n"
    
    # IPv6 链接（如果有）
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=""
        if [[ "$ENABLE_AUTH" =~ ^[Yy]$ ]]; then
            link_ipv6="socks5://${NODE_SOCKS_USER}:${NODE_SOCKS_PASS}@[${SERVER_IPV6}]:${PORT}#SOCKS5-[${SERVER_IPV6}]"
        else
            link_ipv6="socks5://[${SERVER_IPV6}]:${PORT}#SOCKS5-[${SERVER_IPV6}]"
        fi
        add_link "$link_ipv6" "SOCKS5" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" ""
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[SOCKS5] [${SERVER_IPV6}]:${PORT}\n${link_ipv6}\n----------------------------------------\n\n"
    fi
    
    INBOUND_TAGS+=("socks-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("")
    INBOUND_RELAY_TAGS+=("direct")
    
    print_success "SOCKS5 配置完成"
    save_links_to_files
}

# ==================== ShadowTLS 配置 ====================
setup_shadowtls() {
    echo ""
    read_port_with_check 443
    
    echo -e "${YELLOW}请输入SNI域名（建议使用常见HTTPS网站域名）${NC}"
    echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
    while true; do
        read -p "SNI域名 [${DEFAULT_SNI}]: " SHADOWTLS_SNI
        SHADOWTLS_SNI=${SHADOWTLS_SNI:-${DEFAULT_SNI}}
        if validate_sni "$SHADOWTLS_SNI"; then
            break
        fi
        print_warning "请重新输入有效的域名格式"
    done
    
    print_info "生成配置文件..."
    print_warning "ShadowTLS 通过伪装真实域名的TLS握手工作"
    
    # 每个节点使用独立密码
    local NODE_SHADOWTLS_PASSWORD=$(openssl rand -hex 16)
    local NODE_SS_PASSWORD=$(openssl rand -base64 16)
    print_info "ShadowTLS密码: ${NODE_SHADOWTLS_PASSWORD}"
    print_info "Shadowsocks密码: ${NODE_SS_PASSWORD}"
    
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"shadowtls\",
  \"tag\": \"shadowtls-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"version\": 3,
  \"users\": [{\"password\": \"${NODE_SHADOWTLS_PASSWORD}\"}],
  \"handshake\": {
    \"server\": \"${SHADOWTLS_SNI}\",
    \"server_port\": 443
  },
  \"strict_mode\": true,
  \"detour\": \"shadowsocks-in-${PORT}\"
},
{
  \"type\": \"shadowsocks\",
  \"tag\": \"shadowsocks-in-${PORT}\",
  \"listen\": \"127.0.0.1\",
  \"network\": \"tcp\",
  \"method\": \"2022-blake3-aes-128-gcm\",
  \"password\": \"${NODE_SS_PASSWORD}\"
}"
    
    local ss_userinfo=$(echo -n "2022-blake3-aes-128-gcm:${NODE_SS_PASSWORD}" | base64 -w0 | sed 's/+/-/g; s/\//_/g; s/=//g')
    
    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi
    
    PROTO="ShadowTLS v3"
    EXTRA_INFO="Shadowsocks方法: 2022-blake3-aes-128-gcm\nShadowsocks密码: ${NODE_SS_PASSWORD}\nShadowTLS密码: ${NODE_SHADOWTLS_PASSWORD}\n伪装域名: ${SHADOWTLS_SNI}\n\n${YELLOW}提示: 请使用支持 shadow-tls 插件的客户端${NC}\n${CYAN}(如 sing-box / Shadowrocket / NekoBox / v2rayN)${NC}"
    
    # 保存新添加节点的链接（只用于显示）
    CURRENT_NEW_LINKS=""
    
    # IPv4 链接
    local plugin_json_ipv4="{\"version\":\"3\",\"password\":\"${NODE_SHADOWTLS_PASSWORD}\",\"host\":\"${SHADOWTLS_SNI}\",\"port\":\"${PORT}\",\"address\":\"${SERVER_IP}\"}"
    local plugin_base64_ipv4=$(echo -n "$plugin_json_ipv4" | base64 -w0 | sed 's/+/-/g; s/\//_/g; s/=//g')
    local link_ipv4="ss://${ss_userinfo}@${SERVER_IP}:${PORT}?shadow-tls=${plugin_base64_ipv4}#ShadowTLS-${SERVER_IP}"
    add_link "$link_ipv4" "ShadowTLS v3" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${SHADOWTLS_SNI}"
    LINK="$link_ipv4"  # 默认链接
    
    # 添加到新链接显示
    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[ShadowTLS v3] ${SERVER_IP}:${PORT} (SNI: ${SHADOWTLS_SNI})\n${link_ipv4}\n----------------------------------------\n\n"
    
    # 生成 IPv4 客户端配置文件
    local client_config_file_ipv4="${LINK_DIR}/shadowtls_client_${PORT}_ipv4.json"
    generate_shadowtls_client_config "${client_config_file_ipv4}" "${SERVER_IP}" "${PORT}" "${SHADOWTLS_SNI}" "${NODE_SHADOWTLS_PASSWORD}" "2022-blake3-aes-128-gcm" "${NODE_SS_PASSWORD}"
    
    # IPv6 链接（如果有）
    if [[ -n "${SERVER_IPV6}" ]]; then
        local plugin_json_ipv6="{\"version\":\"3\",\"password\":\"${NODE_SHADOWTLS_PASSWORD}\",\"host\":\"${SHADOWTLS_SNI}\",\"port\":\"${PORT}\",\"address\":\"${SERVER_IPV6}\"}"
        local plugin_base64_ipv6=$(echo -n "$plugin_json_ipv6" | base64 -w0 | sed 's/+/-/g; s/\//_/g; s/=//g')
        local link_ipv6="ss://${ss_userinfo}@[${SERVER_IPV6}]:${PORT}?shadow-tls=${plugin_base64_ipv6}#ShadowTLS-[${SERVER_IPV6}]"
        add_link "$link_ipv6" "ShadowTLS v3" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${SHADOWTLS_SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[ShadowTLS v3] [${SERVER_IPV6}]:${PORT} (SNI: ${SHADOWTLS_SNI})\n${link_ipv6}\n----------------------------------------\n\n"
        
        # 生成 IPv6 客户端配置文件
        local client_config_file_ipv6="${LINK_DIR}/shadowtls_client_${PORT}_ipv6.json"
        generate_shadowtls_client_config "${client_config_file_ipv6}" "${SERVER_IPV6}" "${PORT}" "${SHADOWTLS_SNI}" "${NODE_SHADOWTLS_PASSWORD}" "2022-blake3-aes-128-gcm" "${NODE_SS_PASSWORD}"
    fi
    
    INBOUND_TAGS+=("shadowtls-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${SHADOWTLS_SNI}")
    INBOUND_RELAY_TAGS+=("direct")
    
    print_success "ShadowTLS v3 配置完成 (SNI: ${SHADOWTLS_SNI})"
    print_info "IPv4 客户端配置文件已保存: ${client_config_file_ipv4}"
    if [[ -n "${SERVER_IPV6}" ]]; then
        print_info "IPv6 客户端配置文件已保存: ${client_config_file_ipv6}"
    fi
    save_links_to_files
}

# ==================== HTTPS 配置 ====================
setup_https() {
    echo ""
    read_port_with_check 443
    
    echo -e "${YELLOW}请输入SNI域名（建议使用常见HTTPS网站域名）${NC}"
    echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
    while true; do
        read -p "SNI域名 [${DEFAULT_SNI}]: " HTTPS_SNI
        HTTPS_SNI=${HTTPS_SNI:-${DEFAULT_SNI}}
        if validate_sni "$HTTPS_SNI"; then
            break
        fi
        print_warning "请重新输入有效的域名格式"
    done
    
    print_info "为 ${HTTPS_SNI} 生成自签证书..."
    gen_cert_for_sni "${HTTPS_SNI}"
    
    # 每个节点使用独立UUID
    local NODE_UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [[ -z "$NODE_UUID" ]]; then
        print_error "UUID 生成失败，请检查系统环境"
        return 1
    fi
    print_info "节点 UUID: ${NODE_UUID}"
    
    print_info "生成配置文件..."
    
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"vless\",
  \"tag\": \"vless-tls-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"uuid\": \"${NODE_UUID}\"}],
  \"tls\": {
    \"enabled\": true,
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"server_name\": \"${HTTPS_SNI}\",
    \"certificate_path\": \"${CERT_DIR}/${HTTPS_SNI}/cert.pem\",
    \"key_path\": \"${CERT_DIR}/${HTTPS_SNI}/private.key\"
  }
}"
    
    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi
    
    PROTO="HTTPS"
    EXTRA_INFO="UUID: ${NODE_UUID}\n证书: 自签证书(${HTTPS_SNI})\nSNI: ${HTTPS_SNI}"
    
    # 保存新添加节点的链接（只用于显示）
    CURRENT_NEW_LINKS=""
    
    # IPv4 链接
    local link_ipv4=$(generate_proto_link "https" "${SERVER_IP}" "${PORT}" "uuid=${NODE_UUID}" "sni=${HTTPS_SNI}")
    add_link "$link_ipv4" "HTTPS" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${HTTPS_SNI}"
    LINK="$link_ipv4"  # 默认链接

    # 添加到新链接显示
    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[HTTPS] ${SERVER_IP}:${PORT} (SNI: ${HTTPS_SNI})\n${link_ipv4}\n----------------------------------------\n\n"

    # IPv6 链接（如果有）
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "https" "[${SERVER_IPV6}]" "${PORT}" "uuid=${NODE_UUID}" "sni=${HTTPS_SNI}")
        add_link "$link_ipv6" "HTTPS" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${HTTPS_SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[HTTPS] [${SERVER_IPV6}]:${PORT} (SNI: ${HTTPS_SNI})\n${link_ipv6}\n----------------------------------------\n\n"
    fi
    
    INBOUND_TAGS+=("vless-tls-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${HTTPS_SNI}")
    INBOUND_RELAY_TAGS+=("direct")
    
    print_success "HTTPS 配置完成 (SNI: ${HTTPS_SNI})"
    save_links_to_files
}

# ==================== AnyTLS 配置（支持内嵌 REALITY，修正版） ====================
setup_anytls() {
    echo ""
    read_port_with_check 443

    echo -e "${YELLOW}是否启用 REALITY 伪装？(y/N)${NC}"
    echo -e "${CYAN}启用后，服务端使用 AnyTLS+REALITY，客户端需使用 sing-box 并导入 JSON 配置${NC}"
    read -p "启用 REALITY? [y/N]: " ENABLE_REALITY
    ENABLE_REALITY=${ENABLE_REALITY:-N}

    echo -e "${YELLOW}请输入 SNI 域名（用于 TLS 及 REALITY handshake）${NC}"
    echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
    while true; do
        read -p "SNI 域名 [${DEFAULT_SNI}]: " ANYTLS_SNI
        ANYTLS_SNI=${ANYTLS_SNI:-${DEFAULT_SNI}}
        if validate_sni "$ANYTLS_SNI"; then
            break
        fi
        print_warning "请重新输入有效的域名格式"
    done

    # 每个节点使用独立密码
    local NODE_ANYTLS_PASSWORD=$(openssl rand -hex 16)
    print_info "节点密码: ${NODE_ANYTLS_PASSWORD}"

    # 如果启用 REALITY，确保 REALITY 密钥对存在
    if [[ "$ENABLE_REALITY" =~ ^[Yy]$ ]]; then
        if [[ -z "$REALITY_PRIVATE" ]]; then
            KEYS=$(${INSTALL_DIR}/sing-box generate reality-keypair 2>/dev/null)
            REALITY_PRIVATE=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
            REALITY_PUBLIC=$(echo "$KEYS" | grep "PublicKey" | awk '{print $2}')
            SHORT_ID=$(openssl rand -hex 8)
            save_keys_to_file
        fi
        print_info "REALITY 公钥: ${REALITY_PUBLIC}"
        print_info "Short ID: ${SHORT_ID}"
    else
        # 纯 AnyTLS 需要自签证书
        gen_cert_for_sni "${ANYTLS_SNI}"
    fi

    # 询问 uTLS 指纹（可选）
    echo -e "${YELLOW}请输入 uTLS 指纹（默认 chrome，可选: firefox, safari, ios, android）${NC}"
    read -p "指纹 [chrome]: " UTLS_FINGERPRINT
    UTLS_FINGERPRINT=${UTLS_FINGERPRINT:-chrome}

    # 构建 padding_scheme（增强版填充方案，覆盖更多数据包，增大随机范围）
    local padding_config="[
    \"stop=12\",
    \"0=50-80\",
    \"1=150-600\",
    \"2=300-600,c,500-1200,c,500-1200,c,500-1200\",
    \"3=9-9,600-1200\",
    \"4=500-1200\",
    \"5=500-1200,c,500-1200\",
    \"6=400-1000\",
    \"7=400-1000\",
    \"8=300-800,c,500-1000\",
    \"9=300-800\",
    \"10=200-600\",
    \"11=200-600\"
  ]"

    local listen_addr=$(get_listen_address)
    local inbound=""
    local PROTO=""
    local EXTRA_INFO=""
    local LINK=""
    local CLIENT_JSON_PATH=""

    if [[ "$ENABLE_REALITY" =~ ^[Yy]$ ]]; then
        # AnyTLS + REALITY 入站（无需证书）
        inbound="{
  \"type\": \"anytls\",
  \"tag\": \"anytls-reality-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"password\": \"${NODE_ANYTLS_PASSWORD}\"}],
  \"padding_scheme\": ${padding_config},
  \"tls\": {
    \"enabled\": true,
    \"server_name\": \"${ANYTLS_SNI}\",
    \"min_version\": \"1.3\",
    \"reality\": {
      \"enabled\": true,
      \"handshake\": {
        \"server\": \"${ANYTLS_SNI}\",
        \"server_port\": 443
      },
      \"private_key\": \"${REALITY_PRIVATE}\",
      \"short_id\": [\"${SHORT_ID}\"]
    }
  }
}"
        PROTO="AnyTLS+REALITY"
        EXTRA_INFO="密码: ${NODE_ANYTLS_PASSWORD}\nREALITY 公钥: ${REALITY_PUBLIC}\nShort ID: ${SHORT_ID}\nSNI: ${ANYTLS_SNI}"

        # 生成客户端 JSON 配置文件（sing-box 格式）
        # 注意: TUN stack 默认使用 system，客户端可根据自身系统修改为 gvisor
        CLIENT_JSON_PATH="${LINK_DIR}/anytls_reality_client_${PORT}.json"
        cat > "${CLIENT_JSON_PATH}" << EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "sing-box0",
      "address": ["172.19.0.1/30", "fd00::1/126"],
      "auto_route": true,
      "stack": "system"
    }
  ],
  "outbounds": [
    {
      "type": "anytls",
      "tag": "AnyTLS+REALITY",
      "server": "${SERVER_IP}",
      "server_port": ${PORT},
      "password": "${NODE_ANYTLS_PASSWORD}",
      "idle_session_check_interval": "30s",
      "idle_session_timeout": "30s",
      "min_idle_session": 5,
      "tls": {
        "enabled": true,
        "server_name": "${ANYTLS_SNI}",
        "min_version": "1.3",
        "utls": { "enabled": true, "fingerprint": "${UTLS_FINGERPRINT}" },
        "reality": {
          "enabled": true,
          "public_key": "${REALITY_PUBLIC}",
          "short_id": "${SHORT_ID}"
        }
      }
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "final": "AnyTLS+REALITY",
    "auto_detect_interface": true,
    "rules": [
      {"action":"sniff","sniffer":["http","tls","quic"]}
    ]
  }
}
EOF
        chmod 644 "${CLIENT_JSON_PATH}"
        LINK="请使用 sing-box 客户端，配置文件已保存到: ${CLIENT_JSON_PATH}"

        # 生成 IPv6 客户端配置文件
        if [[ -n "${SERVER_IPV6}" ]]; then
            local client_config_file_ipv6="${LINK_DIR}/anytls_reality_client_${PORT}_ipv6.json"
            cat > "${client_config_file_ipv6}" << EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "sing-box0",
      "address": ["172.19.0.1/30", "fd00::1/126"],
      "auto_route": true,
      "stack": "system"
    }
  ],
  "outbounds": [
    {
      "type": "anytls",
      "tag": "AnyTLS+REALITY",
      "server": "${SERVER_IPV6}",
      "server_port": ${PORT},
      "password": "${NODE_ANYTLS_PASSWORD}",
      "idle_session_check_interval": "30s",
      "idle_session_timeout": "30s",
      "min_idle_session": 5,
      "tls": {
        "enabled": true,
        "server_name": "${ANYTLS_SNI}",
        "min_version": "1.3",
        "utls": { "enabled": true, "fingerprint": "${UTLS_FINGERPRINT}" },
        "reality": {
          "enabled": true,
          "public_key": "${REALITY_PUBLIC}",
          "short_id": "${SHORT_ID}"
        }
      }
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "final": "AnyTLS+REALITY",
    "auto_detect_interface": true,
    "rules": [
      {"action":"sniff","sniffer":["http","tls","quic"]}
    ]
  }
}
EOF
            chmod 644 "${client_config_file_ipv6}"
        fi
    else
        # 纯 AnyTLS 入站（需要证书）
        inbound="{
  \"type\": \"anytls\",
  \"tag\": \"anytls-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"password\": \"${NODE_ANYTLS_PASSWORD}\"}],
  \"padding_scheme\": ${padding_config},
  \"tls\": {
    \"enabled\": true,
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"server_name\": \"${ANYTLS_SNI}\",
    \"certificate_path\": \"${CERT_DIR}/${ANYTLS_SNI}/cert.pem\",
    \"key_path\": \"${CERT_DIR}/${ANYTLS_SNI}/private.key\"
  }
}"
        PROTO="AnyTLS"
        EXTRA_INFO="密码: ${NODE_ANYTLS_PASSWORD}\n证书: 自签证书 (${ANYTLS_SNI})"
        # 生成客户端 JSON 配置文件
        CLIENT_JSON_PATH="${LINK_DIR}/anytls_client_${PORT}.json"
        cat > "${CLIENT_JSON_PATH}" << EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "sing-box0",
      "address": ["172.19.0.1/30", "fd00::1/126"],
      "auto_route": true,
      "stack": "system"
    }
  ],
  "outbounds": [
    {
      "type": "anytls",
      "tag": "AnyTLS",
      "server": "${SERVER_IP}",
      "server_port": ${PORT},
      "password": "${NODE_ANYTLS_PASSWORD}",
      "idle_session_check_interval": "30s",
      "idle_session_timeout": "30s",
      "min_idle_session": 5,
      "tls": {
        "enabled": true,
        "server_name": "${ANYTLS_SNI}",
        "alpn": ["h2", "http/1.1"],
        "min_version": "1.3",
        "insecure": true,
        "utls": { "enabled": true, "fingerprint": "${UTLS_FINGERPRINT}" }
      }
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "final": "AnyTLS",
    "auto_detect_interface": true,
    "rules": [
      {"action":"sniff","sniffer":["http","tls","quic"]}
    ]
  }
}
EOF
        chmod 644 "${CLIENT_JSON_PATH}"
        # 同时生成 anytls:// 链接（自签证书默认 insecure=true）
        LINK=$(generate_proto_link "anytls" "${SERVER_IP}" "${PORT}" "password=${NODE_ANYTLS_PASSWORD}" "sni=${ANYTLS_SNI}" "fp=${UTLS_FINGERPRINT}" "insecure=true")
        add_link "$LINK" "${PROTO}" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${ANYTLS_SNI}"

        # 生成 IPv6 链接和客户端配置
        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "anytls" "[${SERVER_IPV6}]" "${PORT}" "password=${NODE_ANYTLS_PASSWORD}" "sni=${ANYTLS_SNI}" "fp=${UTLS_FINGERPRINT}" "insecure=true")
            add_link "$link_ipv6" "${PROTO}" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${ANYTLS_SNI}"

            local client_config_file_ipv6="${LINK_DIR}/anytls_client_${PORT}_ipv6.json"
            cat > "${client_config_file_ipv6}" << EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "sing-box0",
      "address": ["172.19.0.1/30", "fd00::1/126"],
      "auto_route": true,
      "stack": "system"
    }
  ],
  "outbounds": [
    {
      "type": "anytls",
      "tag": "AnyTLS",
      "server": "${SERVER_IPV6}",
      "server_port": ${PORT},
      "password": "${NODE_ANYTLS_PASSWORD}",
      "idle_session_check_interval": "30s",
      "idle_session_timeout": "30s",
      "min_idle_session": 5,
      "tls": {
        "enabled": true,
        "server_name": "${ANYTLS_SNI}",
        "alpn": ["h2", "http/1.1"],
        "min_version": "1.3",
        "insecure": true,
        "utls": { "enabled": true, "fingerprint": "${UTLS_FINGERPRINT}" }
      }
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "final": "AnyTLS",
    "auto_detect_interface": true,
    "rules": [
      {"action":"sniff","sniffer":["http","tls","quic"]}
    ]
  }
}
EOF
            chmod 644 "${client_config_file_ipv6}"
        fi
    fi

    # 并入全局 inbound JSON
    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi

    # 记录节点信息
    if [[ "$ENABLE_REALITY" =~ ^[Yy]$ ]]; then
        INBOUND_TAGS+=("anytls-reality-${PORT}")
    else
        INBOUND_TAGS+=("anytls-in-${PORT}")
    fi
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${ANYTLS_SNI}")
    INBOUND_RELAY_TAGS+=("direct")

    # 显示新添加节点的信息
    CURRENT_NEW_LINKS=""
    if [[ "$ENABLE_REALITY" =~ ^[Yy]$ ]]; then
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] ${SERVER_IP}:${PORT} (SNI: ${ANYTLS_SNI})\n客户端配置文件: ${CLIENT_JSON_PATH}\n----------------------------------------\n\n"
        if [[ -n "${SERVER_IPV6}" ]]; then
            CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] [${SERVER_IPV6}]:${PORT} (SNI: ${ANYTLS_SNI})\n客户端配置文件: ${LINK_DIR}/anytls_reality_client_${PORT}_ipv6.json\n----------------------------------------\n\n"
        fi
    else
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] ${SERVER_IP}:${PORT} (SNI: ${ANYTLS_SNI})\n${LINK}\n客户端配置文件: ${CLIENT_JSON_PATH}\n----------------------------------------\n\n"
        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "anytls" "[${SERVER_IPV6}]" "${PORT}" "password=${NODE_ANYTLS_PASSWORD}" "sni=${ANYTLS_SNI}" "fp=${UTLS_FINGERPRINT}" "insecure=true")
            CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] [${SERVER_IPV6}]:${PORT} (SNI: ${ANYTLS_SNI})\n${link_ipv6}\n客户端配置文件: ${LINK_DIR}/anytls_client_${PORT}_ipv6.json\n----------------------------------------\n\n"
        fi
    fi

    print_success "AnyTLS 节点添加完成 (REALITY: ${ENABLE_REALITY})"
    echo -e "${CYAN}客户端配置 JSON 已保存到: ${CLIENT_JSON_PATH}${NC}"
    echo -e "${CYAN}请使用 sing-box 客户端运行: sing-box run -c ${CLIENT_JSON_PATH}${NC}"
    save_links_to_files
}

# ==================== CDN 协议（VLESS/VMess/Trojan + WS/gRPC/HTTPUpgrade + TLS）====================
# 适用 Cloudflare/Gcore/雨盾 等 CDN，端口走 443 系或 80 系，客户端 address 可填优选 IP

# 公共函数：交互式收集 CDN 协议通用参数
# 输出全局变量：CDN_TRANSPORT / CDN_SNI / CDN_WS_PATH / CDN_WS_HOST / CDN_GRPC_SERVICE
# PORT 由 read_port_with_check 设置
_cdn_collect_common_params() {
    local default_port="${1:-443}"

    echo -e "${CYAN}支持的 CDN 端口:${NC}"
    echo -e "  ${GREEN}HTTPS (推荐)${NC}: 443 / 8443 / 2053 / 2083 / 2087 / 2096"
    echo -e "  ${YELLOW}HTTP  (不推荐,明文)${NC}: 80 / 8080 / 8880 / 2052 / 2082 / 2086 / 2095"
    echo ""

    # 1. 端口输入（交互式，不强制限制范围，但提示推荐值）
    while true; do
        read -p "端口 [默认 ${default_port}]: " input_port
        PORT="${input_port:-$default_port}"
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
            print_error "端口无效，请输入 1-65535"; continue
        fi
        if check_port_in_use "$PORT"; then
            print_warning "端口 ${PORT} 已被占用"; continue
        fi
        # 提示非标准端口
        case "$PORT" in
            443|8443|2053|2083|2087|2096|80|8080|8880|2052|2082|2086|2095) ;;
            *)
                print_warning "端口 ${PORT} 非 CDN 标准端口，请确认 CDN 控制台支持该端口"
                ;;
        esac
        break
    done

    # 2. 传输方式
    echo ""
    echo -e "${CYAN}传输方式:${NC}"
    echo -e "  ${GREEN}[1]${NC} ws           ${YELLOW}(WebSocket, CDN 全支持, 推荐)${NC}"
    echo -e "  ${GREEN}[2]${NC} grpc         ${YELLOW}(gRPC, Cloudflare 需在面板开启 gRPC 开关)${NC}"
    echo -e "  ${GREEN}[3]${NC} httpupgrade ${YELLOW}(HTTP Upgrade, 较新)${NC}"
    read -p "选择 [1-3, 默认 1]: " transport_choice
    transport_choice="${transport_choice:-1}"
    CDN_TRANSPORT="ws"
    case "$transport_choice" in
        1) CDN_TRANSPORT="ws" ;;
        2) CDN_TRANSPORT="grpc" ;;
        3) CDN_TRANSPORT="httpupgrade" ;;
        *) print_warning "无效选择，使用默认 ws"; CDN_TRANSPORT="ws" ;;
    esac

    # 3. SNI 域名
    echo ""
    echo -e "${YELLOW}请输入 SNI 域名（需与 CDN 控制台绑定的域名一致）${NC}"
    echo -e "${CYAN}例如: ${DEFAULT_SNI1}${NC}"
    while true; do
        read -p "SNI 域名 [${DEFAULT_SNI}]: " CDN_SNI
        CDN_SNI=${CDN_SNI:-${DEFAULT_SNI}}
        if validate_sni "$CDN_SNI"; then
            break
        fi
        print_warning "请重新输入有效的域名格式"
    done

    # 4. transport 相关参数
    CDN_WS_PATH="/ws"
    CDN_WS_HOST="$CDN_SNI"
    CDN_GRPC_SERVICE="grpc"
    if [[ "$CDN_TRANSPORT" == "ws" || "$CDN_TRANSPORT" == "httpupgrade" ]]; then
        read -p "WebSocket 路径 [${CDN_WS_PATH}]: " input_path
        [[ -n "$input_path" ]] && CDN_WS_PATH="$input_path"
        read -p "Host 头 [${CDN_WS_HOST}]: " input_host
        [[ -n "$input_host" ]] && CDN_WS_HOST="$input_host"
    elif [[ "$CDN_TRANSPORT" == "grpc" ]]; then
        read -p "gRPC service name [${CDN_GRPC_SERVICE}]: " input_grpc
        [[ -n "$input_grpc" ]] && CDN_GRPC_SERVICE="$input_grpc"
    fi

    # 5. CDN 配置提示
    echo ""
    echo -e "${CYAN}===== CDN 配置提示 =====${NC}"
    echo -e "  ${YELLOW}CDN 控制台需将 ${CDN_SNI} 的回源指向本机 ${SERVER_IP:-IP}:${PORT}${NC}"
    echo -e "  ${YELLOW}CDN SSL 模式建议设为 Full (HTTPS 回源)${NC}"
    echo -e "  ${YELLOW}客户端 address 可填 CDN 优选 IP/域名, SNI 必须为 ${CDN_SNI}${NC}"
    echo ""
}

# 构建 CDN 协议的 transport JSON 片段
_cdn_build_transport_json() {
    case "$CDN_TRANSPORT" in
        ws)
            echo "\"transport\": {\"type\": \"ws\", \"path\": \"${CDN_WS_PATH}\", \"headers\": {\"Host\": \"${CDN_WS_HOST}\"}}"
            ;;
        grpc)
            echo "\"transport\": {\"type\": \"grpc\", \"service_name\": \"${CDN_GRPC_SERVICE}\"}"
            ;;
        httpupgrade)
            echo "\"transport\": {\"type\": \"httpupgrade\", \"path\": \"${CDN_WS_PATH}\", \"headers\": {\"Host\": \"${CDN_WS_HOST}\"}}"
            ;;
    esac
}

# ==================== VLESS + WS/gRPC/HTTPUpgrade + TLS (CDN) ====================
setup_cdn_vless() {
    echo ""
    menu_header "VLESS + WS/gRPC + TLS (CDN 适用)"
    _cdn_collect_common_params 443

    # UUID
    local NODE_UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [[ -z "$NODE_UUID" ]]; then
        print_error "UUID 生成失败，请检查系统环境"
        return 1
    fi
    print_info "节点 UUID: ${NODE_UUID}"

    # 自签证书（CDN Full 模式回源会校验证书存在）
    print_info "为 ${CDN_SNI} 生成自签证书..."
    gen_cert_for_sni "${CDN_SNI}"

    print_info "生成配置文件..."

    local transport_json=$(_cdn_build_transport_json)
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"vless\",
  \"tag\": \"vless-cdn-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"uuid\": \"${NODE_UUID}\"}],
  \"tls\": {
    \"enabled\": true,
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"server_name\": \"${CDN_SNI}\",
    \"certificate_path\": \"${CERT_DIR}/${CDN_SNI}/cert.pem\",
    \"key_path\": \"${CERT_DIR}/${CDN_SNI}/private.key\"
  },
  ${transport_json}
}"

    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi

    PROTO="VLESS-CDN-${CDN_TRANSPORT}"
    EXTRA_INFO="UUID: ${NODE_UUID}\nSNI: ${CDN_SNI}\n传输: ${CDN_TRANSPORT}\n路径: ${CDN_WS_PATH}"

    CURRENT_NEW_LINKS=""

    # IPv4 链接
    local link_ipv4=$(generate_proto_link "vless-ws" "${SERVER_IP}" "${PORT}" \
        "uuid=${NODE_UUID}" "sni=${CDN_SNI}" "transport=${CDN_TRANSPORT}" \
        "path=${CDN_WS_PATH}" "host=${CDN_WS_HOST}" "grpc_service=${CDN_GRPC_SERVICE}")
    add_link "$link_ipv4" "${PROTO}" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${CDN_SNI}"
    LINK="$link_ipv4"

    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] ${SERVER_IP}:${PORT} (SNI: ${CDN_SNI}, ${CDN_TRANSPORT})\n${link_ipv4}\n----------------------------------------\n\n"

    # IPv6 链接
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "vless-ws" "[${SERVER_IPV6}]" "${PORT}" \
            "uuid=${NODE_UUID}" "sni=${CDN_SNI}" "transport=${CDN_TRANSPORT}" \
            "path=${CDN_WS_PATH}" "host=${CDN_WS_HOST}" "grpc_service=${CDN_GRPC_SERVICE}")
        add_link "$link_ipv6" "${PROTO}" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${CDN_SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] [${SERVER_IPV6}]:${PORT} (SNI: ${CDN_SNI}, ${CDN_TRANSPORT})\n${link_ipv6}\n----------------------------------------\n\n"
    fi

    INBOUND_TAGS+=("vless-cdn-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${CDN_SNI}")
    INBOUND_RELAY_TAGS+=("direct")

    print_success "${PROTO} 配置完成 (SNI: ${CDN_SNI})"
    save_links_to_files
}

# ==================== VMess + WS/gRPC/HTTPUpgrade + TLS (CDN) ====================
setup_cdn_vmess() {
    echo ""
    menu_header "VMess + WS/gRPC + TLS (CDN 适用)"
    _cdn_collect_common_params 443

    # UUID
    local NODE_UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [[ -z "$NODE_UUID" ]]; then
        print_error "UUID 生成失败，请检查系统环境"
        return 1
    fi
    print_info "节点 UUID: ${NODE_UUID}"

    # 自签证书
    print_info "为 ${CDN_SNI} 生成自签证书..."
    gen_cert_for_sni "${CDN_SNI}"

    print_info "生成配置文件..."

    local transport_json=$(_cdn_build_transport_json)
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"vmess\",
  \"tag\": \"vmess-cdn-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"uuid\": \"${NODE_UUID}\", \"alterId\": 0}],
  \"tls\": {
    \"enabled\": true,
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"server_name\": \"${CDN_SNI}\",
    \"certificate_path\": \"${CERT_DIR}/${CDN_SNI}/cert.pem\",
    \"key_path\": \"${CERT_DIR}/${CDN_SNI}/private.key\"
  },
  ${transport_json}
}"

    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi

    PROTO="VMess-CDN-${CDN_TRANSPORT}"
    EXTRA_INFO="UUID: ${NODE_UUID}\nalterId: 0\nSNI: ${CDN_SNI}\n传输: ${CDN_TRANSPORT}\n路径: ${CDN_WS_PATH}"

    CURRENT_NEW_LINKS=""

    # IPv4 链接
    local link_ipv4=$(generate_proto_link "vmess-ws" "${SERVER_IP}" "${PORT}" \
        "uuid=${NODE_UUID}" "sni=${CDN_SNI}" "transport=${CDN_TRANSPORT}" \
        "path=${CDN_WS_PATH}" "host=${CDN_WS_HOST}" "grpc_service=${CDN_GRPC_SERVICE}")
    add_link "$link_ipv4" "${PROTO}" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${CDN_SNI}"
    LINK="$link_ipv4"

    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] ${SERVER_IP}:${PORT} (SNI: ${CDN_SNI}, ${CDN_TRANSPORT})\n${link_ipv4}\n----------------------------------------\n\n"

    # IPv6 链接
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "vmess-ws" "[${SERVER_IPV6}]" "${PORT}" \
            "uuid=${NODE_UUID}" "sni=${CDN_SNI}" "transport=${CDN_TRANSPORT}" \
            "path=${CDN_WS_PATH}" "host=${CDN_WS_HOST}" "grpc_service=${CDN_GRPC_SERVICE}")
        add_link "$link_ipv6" "${PROTO}" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${CDN_SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] [${SERVER_IPV6}]:${PORT} (SNI: ${CDN_SNI}, ${CDN_TRANSPORT})\n${link_ipv6}\n----------------------------------------\n\n"
    fi

    INBOUND_TAGS+=("vmess-cdn-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${CDN_SNI}")
    INBOUND_RELAY_TAGS+=("direct")

    print_success "${PROTO} 配置完成 (SNI: ${CDN_SNI})"
    save_links_to_files
}

# ==================== Trojan + WS/gRPC/HTTPUpgrade + TLS (CDN) ====================
setup_cdn_trojan() {
    echo ""
    menu_header "Trojan + WS/gRPC + TLS (CDN 适用)"
    _cdn_collect_common_params 443

    # Trojan 密码
    local NODE_TROJAN_PASSWORD=$(openssl rand -hex 16)
    print_info "节点密码: ${NODE_TROJAN_PASSWORD}"

    # 自签证书
    print_info "为 ${CDN_SNI} 生成自签证书..."
    gen_cert_for_sni "${CDN_SNI}"

    print_info "生成配置文件..."

    local transport_json=$(_cdn_build_transport_json)
    local listen_addr=$(get_listen_address)
    local inbound="{
  \"type\": \"trojan\",
  \"tag\": \"trojan-cdn-in-${PORT}\",
  \"listen\": \"${listen_addr}\",
  \"listen_port\": ${PORT},
  \"users\": [{\"password\": \"${NODE_TROJAN_PASSWORD}\"}],
  \"tls\": {
    \"enabled\": true,
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"server_name\": \"${CDN_SNI}\",
    \"certificate_path\": \"${CERT_DIR}/${CDN_SNI}/cert.pem\",
    \"key_path\": \"${CERT_DIR}/${CDN_SNI}/private.key\"
  },
  ${transport_json}
}"

    if [[ -z "$INBOUNDS_JSON" ]]; then
        INBOUNDS_JSON="$inbound"
    else
        INBOUNDS_JSON="${INBOUNDS_JSON},${inbound}"
    fi

    PROTO="Trojan-CDN-${CDN_TRANSPORT}"
    EXTRA_INFO="密码: ${NODE_TROJAN_PASSWORD}\nSNI: ${CDN_SNI}\n传输: ${CDN_TRANSPORT}\n路径: ${CDN_WS_PATH}"

    CURRENT_NEW_LINKS=""

    # IPv4 链接
    local link_ipv4=$(generate_proto_link "trojan-ws" "${SERVER_IP}" "${PORT}" \
        "password=${NODE_TROJAN_PASSWORD}" "sni=${CDN_SNI}" "transport=${CDN_TRANSPORT}" \
        "path=${CDN_WS_PATH}" "host=${CDN_WS_HOST}" "grpc_service=${CDN_GRPC_SERVICE}")
    add_link "$link_ipv4" "${PROTO}" "$EXTRA_INFO" "${SERVER_IP}" "${PORT}" "${CDN_SNI}"
    LINK="$link_ipv4"

    CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] ${SERVER_IP}:${PORT} (SNI: ${CDN_SNI}, ${CDN_TRANSPORT})\n${link_ipv4}\n----------------------------------------\n\n"

    # IPv6 链接
    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "trojan-ws" "[${SERVER_IPV6}]" "${PORT}" \
            "password=${NODE_TROJAN_PASSWORD}" "sni=${CDN_SNI}" "transport=${CDN_TRANSPORT}" \
            "path=${CDN_WS_PATH}" "host=${CDN_WS_HOST}" "grpc_service=${CDN_GRPC_SERVICE}")
        add_link "$link_ipv6" "${PROTO}" "$EXTRA_INFO" "[${SERVER_IPV6}]" "${PORT}" "${CDN_SNI}"
        CURRENT_NEW_LINKS="${CURRENT_NEW_LINKS}[${PROTO}] [${SERVER_IPV6}]:${PORT} (SNI: ${CDN_SNI}, ${CDN_TRANSPORT})\n${link_ipv6}\n----------------------------------------\n\n"
    fi

    INBOUND_TAGS+=("trojan-cdn-in-${PORT}")
    INBOUND_PORTS+=("${PORT}")
    INBOUND_PROTOS+=("${PROTO}")
    INBOUND_SNIS+=("${CDN_SNI}")
    INBOUND_RELAY_TAGS+=("direct")

    print_success "${PROTO} 配置完成 (SNI: ${CDN_SNI})"
    save_links_to_files
}
