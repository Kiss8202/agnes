# ==================== sing-box 链接管理模块 ====================
# ==================== 链接文件管理 ====================
save_links_to_files() {
    mkdir -p "${LINK_DIR}"

    echo -en "${ALL_LINKS_TEXT}" > "${ALL_LINKS_FILE}"
    echo -en "${REALITY_LINKS}" > "${REALITY_LINKS_FILE}"
    echo -en "${HYSTERIA2_LINKS}" > "${HYSTERIA2_LINKS_FILE}"
    echo -en "${SOCKS5_LINKS}" > "${SOCKS5_LINKS_FILE}"
    echo -en "${SHADOWTLS_LINKS}" > "${SHADOWTLS_LINKS_FILE}"
    echo -en "${HTTPS_LINKS}" > "${HTTPS_LINKS_FILE}"
    echo -en "${ANYTLS_LINKS}" > "${ANYTLS_LINKS_FILE}"
    echo -en "${VLESS_CDN_LINKS}" > "${VLESS_CDN_LINKS_FILE}"
    echo -en "${VMESS_CDN_LINKS}" > "${VMESS_CDN_LINKS_FILE}"
    echo -en "${TROJAN_CDN_LINKS}" > "${TROJAN_CDN_LINKS_FILE}"

    chmod 600 "${LINK_DIR}"/*.txt 2>/dev/null || true
    chmod 700 "${LINK_DIR}" 2>/dev/null || true
    print_success "链接已保存到 ${LINK_DIR}"
}

# ==================== 从配置文件加载节点信息 ====================
load_inbounds_from_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        return 1
    fi
    
    if ! command -v jq &>/dev/null; then
        return 1
    fi
    
    # 清空数组
    INBOUND_TAGS=()
    INBOUND_PORTS=()
    INBOUND_PROTOS=()
    INBOUND_SNIS=()
    INBOUND_RELAY_TAGS=()
    INBOUNDS_JSON=""
    
    local inbounds_count=$(jq '.inbounds | length' "${CONFIG_FILE}" 2>/dev/null || echo "0")
    
    if [[ "$inbounds_count" -eq 0 ]]; then
        return 1
    fi
    
    local inbound_list=""
    
    for ((i=0; i<inbounds_count; i++)); do
        local inbound=$(jq -c ".inbounds[${i}]" "${CONFIG_FILE}" 2>/dev/null)
        
        if [[ -z "$inbound" ]]; then
            continue
        fi
        
        # 添加到 INBOUNDS_JSON
        if [[ -z "$inbound_list" ]]; then
            inbound_list="$inbound"
        else
            inbound_list="${inbound_list},${inbound}"
        fi
        
        # 提取信息
        local tag=$(echo "$inbound" | jq -r '.tag' 2>/dev/null || echo "unknown")
        local port=$(echo "$inbound" | jq -r '.listen_port' 2>/dev/null || echo "0")
        local type=$(echo "$inbound" | jq -r '.type' 2>/dev/null || echo "unknown")
        
        # 跳过 shadowsocks-in-* (ShadowTLS 的内部组件)
        if [[ "$tag" == "shadowsocks-in-"* ]]; then
            continue
        fi

        # 判断协议类型
        local proto="unknown"
        local sni=""

        if [[ "$tag" == *"vless-in-"* ]]; then
            proto="Reality"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"vless-cdn-in-"* ]]; then
            local transport=$(echo "$inbound" | jq -r '.transport.type // "ws"' 2>/dev/null)
            proto="VLESS-CDN-${transport}"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"vmess-cdn-in-"* ]]; then
            local transport=$(echo "$inbound" | jq -r '.transport.type // "ws"' 2>/dev/null)
            proto="VMess-CDN-${transport}"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"trojan-cdn-in-"* ]]; then
            local transport=$(echo "$inbound" | jq -r '.transport.type // "ws"' 2>/dev/null)
            proto="Trojan-CDN-${transport}"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"hy2-in-"* ]]; then
            proto="Hysteria2"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"shadowtls-in-"* ]]; then
            proto="ShadowTLS v3"
            sni=$(echo "$inbound" | jq -r '.handshake.server // ""' 2>/dev/null)
        elif [[ "$tag" == *"socks-in"* ]]; then
            proto="SOCKS5"
        elif [[ "$tag" == *"vless-tls-in-"* ]]; then
            proto="HTTPS"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"anytls-in-"* ]]; then
            proto="AnyTLS"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        elif [[ "$tag" == *"anytls-reality-"* ]]; then
            proto="AnyTLS+REALITY"
            sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
        fi
        
        [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"
        
        INBOUND_TAGS+=("$tag")
        INBOUND_PORTS+=("$port")
        INBOUND_PROTOS+=("$proto")
        INBOUND_SNIS+=("$sni")
        INBOUND_RELAY_TAGS+=("direct")  # 默认直连，稍后从路由规则更新
    done
    
    INBOUNDS_JSON="$inbound_list"
    
    # 从路由规则中恢复每个节点的默认中转（查找针对该入站且没有域名/IP条件的规则）
    # 注意：路由规则中可能有多个匹配该入站，需要找到最后一条没有域名/IP的规则作为默认
    local route_rules=$(jq -c '.route.rules[]? // empty' "${CONFIG_FILE}" 2>/dev/null)
    if [[ -n "$route_rules" ]]; then
        # 先收集所有入站对应的默认中转（无域名/IP条件）
        declare -A default_relay
        while IFS= read -r rule; do
            # 检查是否包含 inbound 字段
            local has_inbound=$(echo "$rule" | jq -e '.inbound // empty' 2>/dev/null)
            if [[ -z "$has_inbound" ]]; then
                continue
            fi
            # 检查是否包含域名或IP条件（如果包含，则是分流规则，跳过）
            local has_domain=$(echo "$rule" | jq -e '.domain // .domain_suffix // .domain_keyword // .domain_regex // empty' 2>/dev/null)
            local has_ip=$(echo "$rule" | jq -e '.ip_cidr // .ip // empty' 2>/dev/null)
            if [[ -n "$has_domain" || -n "$has_ip" ]]; then
                continue
            fi
            # 这是一个默认路由规则
            local inbound_array=$(echo "$rule" | jq -r '.inbound[]? // empty' 2>/dev/null)
            local outbound=$(echo "$rule" | jq -r '.outbound // ""' 2>/dev/null)
            if [[ -n "$outbound" && "$outbound" != "direct" ]]; then
                while IFS= read -r inbound_tag; do
                    default_relay["$inbound_tag"]="$outbound"
                done <<< "$inbound_array"
            fi
        done <<< "$route_rules"
        
        # 应用到 INBOUND_RELAY_TAGS
        for i in "${!INBOUND_TAGS[@]}"; do
            local tag="${INBOUND_TAGS[$i]}"
            if [[ -n "${default_relay[$tag]}" ]]; then
                INBOUND_RELAY_TAGS[$i]="${default_relay[$tag]}"
            fi
        done
    fi
    
    return 0
}
# ==================== 从配置文件重新生成链接 ====================
# ==================== 链接重新生成子函数 ====================

# 从 inbound JSON 生成 Reality 链接
regenerate_reality_link() {
    local inbound="$1" port="$2"
    local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
    local pbk=$(echo "$inbound" | jq -r '.tls.reality.public_key // ""' 2>/dev/null)
    local sid=$(echo "$inbound" | jq -r '.tls.reality.short_id[0] // ""' 2>/dev/null)

    [[ -z "$pbk" && -n "${REALITY_PUBLIC}" ]] && pbk="${REALITY_PUBLIC}"
    [[ -z "$sid" && -n "${SHORT_ID}" ]] && sid="${SHORT_ID}"
    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"

    if [[ -n "$uuid" && -n "$pbk" ]]; then
        local link_ipv4=$(generate_proto_link "reality" "${SERVER_IP}" "${port}" "uuid=${uuid}" "sni=${sni}" "pbk=${pbk}" "sid=${sid}")
        add_link "$link_ipv4" "Reality" "" "${SERVER_IP}" "${port}" "${sni}"

        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "reality" "[${SERVER_IPV6}]" "${port}" "uuid=${uuid}" "sni=${sni}" "pbk=${pbk}" "sid=${sid}")
            add_link "$link_ipv6" "Reality" "" "[${SERVER_IPV6}]" "${port}" "${sni}"
        fi
    fi
}

# 从 inbound JSON 生成 HTTPS 链接
regenerate_https_link() {
    local inbound="$1" port="$2"
    local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"

    if [[ -n "$uuid" ]]; then
        local link_ipv4=$(generate_proto_link "https" "${SERVER_IP}" "${port}" "uuid=${uuid}" "sni=${sni}")
        add_link "$link_ipv4" "HTTPS" "" "${SERVER_IP}" "${port}" "${sni}"

        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "https" "[${SERVER_IPV6}]" "${port}" "uuid=${uuid}" "sni=${sni}")
            add_link "$link_ipv6" "HTTPS" "" "[${SERVER_IPV6}]" "${port}" "${sni}"
        fi
    fi
}

# 从 inbound JSON 生成 Hysteria2 链接
regenerate_hysteria2_link() {
    local inbound="$1" port="$2"
    local password=$(echo "$inbound" | jq -r '.users[0].password // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
    local obfs_type=$(echo "$inbound" | jq -r '.obfs.type // ""' 2>/dev/null)
    local obfs_password=$(echo "$inbound" | jq -r '.obfs.password // ""' 2>/dev/null)
    local port_range_num=$(echo "$inbound" | jq -r '.port_range // 0' 2>/dev/null)
    local listen_port=$(echo "$inbound" | jq -r '.listen_port' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"

    if [[ -n "$password" ]]; then
        local port_part="$port"
        if [[ "$port_range_num" -gt 1 ]]; then
            local end_port=$(( listen_port + port_range_num - 1 ))
            port_part="${listen_port}-${end_port}"
        fi

        local link_ipv4=$(generate_proto_link "hysteria2" "${SERVER_IP}" "${port_part}" "password=${password}" "sni=${sni}" "obfs_type=${obfs_type}" "obfs_password=${obfs_password}")
        add_link "$link_ipv4" "Hysteria2" "" "${SERVER_IP}" "${port_part}" "${sni}"

        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "hysteria2" "[${SERVER_IPV6}]" "${port_part}" "password=${password}" "sni=${sni}" "obfs_type=${obfs_type}" "obfs_password=${obfs_password}")
            add_link "$link_ipv6" "Hysteria2" "" "[${SERVER_IPV6}]" "${port_part}" "${sni}"
        fi
    fi
}

# 从 inbound JSON 生成 SOCKS5 链接
regenerate_socks5_link() {
    local inbound="$1" port="$2"
    local username=$(echo "$inbound" | jq -r '.users[0].username // ""' 2>/dev/null)
    local password=$(echo "$inbound" | jq -r '.users[0].password // ""' 2>/dev/null)

    local link_ipv4=$(generate_proto_link "socks5" "${SERVER_IP}" "${port}" "username=${username}" "password=${password}")
    add_link "$link_ipv4" "SOCKS5" "" "${SERVER_IP}" "${port}" ""

    if [[ -n "${SERVER_IPV6}" ]]; then
        local link_ipv6=$(generate_proto_link "socks5" "[${SERVER_IPV6}]" "${port}" "username=${username}" "password=${password}")
        add_link "$link_ipv6" "SOCKS5" "" "[${SERVER_IPV6}]" "${port}" ""
    fi
}

# 从 inbound JSON 生成 ShadowTLS 链接
regenerate_shadowtls_link() {
    local inbound="$1" port="$2"
    local shadowtls_password=$(echo "$inbound" | jq -r '.users[0].password // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.handshake.server // ""' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"

    if [[ -n "$shadowtls_password" ]]; then
        local ss_inbound=$(jq -c ".inbounds[] | select(.tag == \"shadowsocks-in-${port}\")" "${CONFIG_FILE}" 2>/dev/null)
        local ss_password=$(echo "$ss_inbound" | jq -r '.password // ""' 2>/dev/null)
        local ss_method=$(echo "$ss_inbound" | jq -r '.method // "2022-blake3-aes-128-gcm"' 2>/dev/null)

        if [[ -n "$ss_password" ]]; then
            local link_ipv4=$(generate_proto_link "shadowtls" "${SERVER_IP}" "${port}" "sni=${sni}" "shadowtls_password=${shadowtls_password}" "ss_method=${ss_method}" "ss_password=${ss_password}")
            add_link "$link_ipv4" "ShadowTLS v3" "" "${SERVER_IP}" "${port}" "${sni}"

            local client_config_file_ipv4="${LINK_DIR}/shadowtls_client_${port}_ipv4.json"
            generate_shadowtls_client_config "${client_config_file_ipv4}" "${SERVER_IP}" "${port}" "${sni}" "${shadowtls_password}" "${ss_method}" "${ss_password}"

            if [[ -n "${SERVER_IPV6}" ]]; then
                local link_ipv6=$(generate_proto_link "shadowtls" "[${SERVER_IPV6}]" "${port}" "sni=${sni}" "shadowtls_password=${shadowtls_password}" "ss_method=${ss_method}" "ss_password=${ss_password}")
                add_link "$link_ipv6" "ShadowTLS v3" "" "[${SERVER_IPV6}]" "${port}" "${sni}"

                local client_config_file_ipv6="${LINK_DIR}/shadowtls_client_${port}_ipv6.json"
                generate_shadowtls_client_config "${client_config_file_ipv6}" "${SERVER_IPV6}" "${port}" "${sni}" "${shadowtls_password}" "${ss_method}" "${ss_password}"
            fi
        fi
    fi
}

# 从 inbound JSON 生成 AnyTLS 链接
regenerate_anytls_link() {
    local inbound="$1" port="$2"
    local password=$(echo "$inbound" | jq -r '.users[0].password // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
    local reality_enabled=$(echo "$inbound" | jq -r '.tls.reality.enabled // false' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"

    if [[ -n "$password" ]]; then
        if [[ "$reality_enabled" == "true" ]]; then
            local link_text="[AnyTLS+REALITY] ${SERVER_IP}:${port} (SNI: ${sni})\n请使用 sing-box 客户端配置文件\n----------------------------------------\n\n"
            ALL_LINKS_TEXT="${ALL_LINKS_TEXT}${link_text}"
            ANYTLS_LINKS="${ANYTLS_LINKS}${link_text}"

            if [[ -n "${SERVER_IPV6}" ]]; then
                local link_text_ipv6="[AnyTLS+REALITY] [${SERVER_IPV6}]:${port} (SNI: ${sni})\n请使用 sing-box 客户端配置文件\n----------------------------------------\n\n"
                ALL_LINKS_TEXT="${ALL_LINKS_TEXT}${link_text_ipv6}"
                ANYTLS_LINKS="${ANYTLS_LINKS}${link_text_ipv6}"
            fi

            # 重新生成客户端 JSON 中的 server 字段（IPv4）
            local client_config_file_ipv4="${LINK_DIR}/anytls_reality_client_${port}.json"
            if [[ -f "${client_config_file_ipv4}" ]]; then
                jq --arg server "${SERVER_IP}" '.outbounds[0].server = $server' "${client_config_file_ipv4}" > "${client_config_file_ipv4}.tmp" && mv "${client_config_file_ipv4}.tmp" "${client_config_file_ipv4}"
            fi
            # 重新生成客户端 JSON 中的 server 字段（IPv6）
            if [[ -n "${SERVER_IPV6}" ]]; then
                local client_config_file_ipv6="${LINK_DIR}/anytls_reality_client_${port}_ipv6.json"
                if [[ -f "${client_config_file_ipv6}" ]]; then
                    jq --arg server "${SERVER_IPV6}" '.outbounds[0].server = $server' "${client_config_file_ipv6}" > "${client_config_file_ipv6}.tmp" && mv "${client_config_file_ipv6}.tmp" "${client_config_file_ipv6}"
                fi
            fi
        else
            local link_ipv4=$(generate_proto_link "anytls" "${SERVER_IP}" "${port}" "password=${password}" "sni=${sni}" "insecure=true")
            add_link "$link_ipv4" "AnyTLS" "" "${SERVER_IP}" "${port}" "${sni}"

            # 重新生成客户端 JSON 中的 server 字段（IPv4）
            local client_config_file_ipv4="${LINK_DIR}/anytls_client_${port}.json"
            if [[ -f "${client_config_file_ipv4}" ]]; then
                jq --arg server "${SERVER_IP}" '.outbounds[0].server = $server' "${client_config_file_ipv4}" > "${client_config_file_ipv4}.tmp" && mv "${client_config_file_ipv4}.tmp" "${client_config_file_ipv4}"
            fi

            if [[ -n "${SERVER_IPV6}" ]]; then
                local link_ipv6=$(generate_proto_link "anytls" "[${SERVER_IPV6}]" "${port}" "password=${password}" "sni=${sni}" "insecure=true")
                add_link "$link_ipv6" "AnyTLS" "" "[${SERVER_IPV6}]" "${port}" "${sni}"

                # 重新生成客户端 JSON 中的 server 字段（IPv6）
                local client_config_file_ipv6="${LINK_DIR}/anytls_client_${port}_ipv6.json"
                if [[ -f "${client_config_file_ipv6}" ]]; then
                    jq --arg server "${SERVER_IPV6}" '.outbounds[0].server = $server' "${client_config_file_ipv6}" > "${client_config_file_ipv6}.tmp" && mv "${client_config_file_ipv6}.tmp" "${client_config_file_ipv6}"
                fi
            fi
        fi
    fi
}

# 从 inbound JSON 生成 VLESS-CDN 链接 (VLESS + WS/gRPC/HTTPUpgrade + TLS)
regenerate_cdn_vless_link() {
    local inbound="$1" port="$2"
    local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
    local transport=$(echo "$inbound" | jq -r '.transport.type // "ws"' 2>/dev/null)
    local ws_path=$(echo "$inbound" | jq -r '.transport.path // "/ws"' 2>/dev/null)
    local ws_host=$(echo "$inbound" | jq -r '.transport.headers.Host // ""' 2>/dev/null)
    local grpc_service=$(echo "$inbound" | jq -r '.transport.service_name // "grpc"' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"
    [[ -z "$ws_host" ]] && ws_host="$sni"

    if [[ -n "$uuid" ]]; then
        local link_ipv4=$(generate_proto_link "vless-ws" "${SERVER_IP}" "${port}" \
            "uuid=${uuid}" "sni=${sni}" "transport=${transport}" \
            "path=${ws_path}" "host=${ws_host}" "grpc_service=${grpc_service}")
        add_link "$link_ipv4" "VLESS-CDN" "" "${SERVER_IP}" "${port}" "${sni}"

        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "vless-ws" "[${SERVER_IPV6}]" "${port}" \
                "uuid=${uuid}" "sni=${sni}" "transport=${transport}" \
                "path=${ws_path}" "host=${ws_host}" "grpc_service=${grpc_service}")
            add_link "$link_ipv6" "VLESS-CDN" "" "[${SERVER_IPV6}]" "${port}" "${sni}"
        fi
    fi
}

# 从 inbound JSON 生成 VMess-CDN 链接 (VMess + WS/gRPC + TLS)
regenerate_cdn_vmess_link() {
    local inbound="$1" port="$2"
    local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
    local transport=$(echo "$inbound" | jq -r '.transport.type // "ws"' 2>/dev/null)
    local ws_path=$(echo "$inbound" | jq -r '.transport.path // "/ws"' 2>/dev/null)
    local ws_host=$(echo "$inbound" | jq -r '.transport.headers.Host // ""' 2>/dev/null)
    local grpc_service=$(echo "$inbound" | jq -r '.transport.service_name // "grpc"' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"
    [[ -z "$ws_host" ]] && ws_host="$sni"

    if [[ -n "$uuid" ]]; then
        local link_ipv4=$(generate_proto_link "vmess-ws" "${SERVER_IP}" "${port}" \
            "uuid=${uuid}" "sni=${sni}" "transport=${transport}" \
            "path=${ws_path}" "host=${ws_host}" "grpc_service=${grpc_service}")
        add_link "$link_ipv4" "VMess-CDN" "" "${SERVER_IP}" "${port}" "${sni}"

        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "vmess-ws" "[${SERVER_IPV6}]" "${port}" \
                "uuid=${uuid}" "sni=${sni}" "transport=${transport}" \
                "path=${ws_path}" "host=${ws_host}" "grpc_service=${grpc_service}")
            add_link "$link_ipv6" "VMess-CDN" "" "[${SERVER_IPV6}]" "${port}" "${sni}"
        fi
    fi
}

# 从 inbound JSON 生成 Trojan-CDN 链接 (Trojan + WS/gRPC + TLS)
regenerate_cdn_trojan_link() {
    local inbound="$1" port="$2"
    local password=$(echo "$inbound" | jq -r '.users[0].password // ""' 2>/dev/null)
    local sni=$(echo "$inbound" | jq -r '.tls.server_name // ""' 2>/dev/null)
    local transport=$(echo "$inbound" | jq -r '.transport.type // "ws"' 2>/dev/null)
    local ws_path=$(echo "$inbound" | jq -r '.transport.path // "/ws"' 2>/dev/null)
    local ws_host=$(echo "$inbound" | jq -r '.transport.headers.Host // ""' 2>/dev/null)
    local grpc_service=$(echo "$inbound" | jq -r '.transport.service_name // "grpc"' 2>/dev/null)

    [[ -z "$sni" ]] && sni="${DEFAULT_SNI}"
    [[ -z "$ws_host" ]] && ws_host="$sni"

    if [[ -n "$password" ]]; then
        local link_ipv4=$(generate_proto_link "trojan-ws" "${SERVER_IP}" "${port}" \
            "password=${password}" "sni=${sni}" "transport=${transport}" \
            "path=${ws_path}" "host=${ws_host}" "grpc_service=${grpc_service}")
        add_link "$link_ipv4" "Trojan-CDN" "" "${SERVER_IP}" "${port}" "${sni}"

        if [[ -n "${SERVER_IPV6}" ]]; then
            local link_ipv6=$(generate_proto_link "trojan-ws" "[${SERVER_IPV6}]" "${port}" \
                "password=${password}" "sni=${sni}" "transport=${transport}" \
                "path=${ws_path}" "host=${ws_host}" "grpc_service=${grpc_service}")
            add_link "$link_ipv6" "Trojan-CDN" "" "[${SERVER_IPV6}]" "${port}" "${sni}"
        fi
    fi
}

# ==================== 链接重新生成（主函数） ====================
regenerate_links_from_config() {
    print_info "正在从配置文件重新生成链接..."

    # 清空所有链接变量
    ALL_LINKS_TEXT=""
    REALITY_LINKS=""
    HYSTERIA2_LINKS=""
    SOCKS5_LINKS=""
    SHADOWTLS_LINKS=""
    HTTPS_LINKS=""
    ANYTLS_LINKS=""
    VLESS_CDN_LINKS=""
    VMESS_CDN_LINKS=""
    TROJAN_CDN_LINKS=""

    # 加载密钥文件
    if [[ -f "${KEY_FILE}" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value="${value#\"}"
            value="${value%\"}"
            case "$key" in
                REALITY_PRIVATE) REALITY_PRIVATE="$value" ;;
                REALITY_PUBLIC) REALITY_PUBLIC="$value" ;;
                SHORT_ID) SHORT_ID="$value" ;;
            esac
        done < "${KEY_FILE}"
    fi

    # 确保 SERVER_IP 已设置
    if [[ -z "${SERVER_IP}" ]]; then
        get_ip || return 1
    fi

    if [[ ! -f "${CONFIG_FILE}" ]] || ! command -v jq &>/dev/null; then
        print_warning "无法重新生成链接：配置文件不存在或 jq 未安装"
        return 1
    fi

    local inbounds_count=$(jq '.inbounds | length' "${CONFIG_FILE}" 2>/dev/null || echo "0")

    if [[ "$inbounds_count" -eq 0 ]]; then
        print_warning "配置文件中没有找到节点"
        return 1
    fi

    # 加载 IP 配置
    load_ip_config

    # 遍历每个 inbound 生成链接
    for ((i=0; i<inbounds_count; i++)); do
        local inbound=$(jq -c ".inbounds[${i}]" "${CONFIG_FILE}" 2>/dev/null)
        [[ -z "$inbound" ]] && continue

        local type=$(echo "$inbound" | jq -r '.type' 2>/dev/null)
        local port=$(echo "$inbound" | jq -r '.listen_port' 2>/dev/null)
        [[ -z "$type" || -z "$port" ]] && continue

        case "$type" in
            "vless")
                local tls_enabled=$(echo "$inbound" | jq -r '.tls.enabled // false' 2>/dev/null)
                if [[ "$tls_enabled" == "true" ]]; then
                    local reality_enabled=$(echo "$inbound" | jq -r '.tls.reality.enabled // false' 2>/dev/null)
                    if [[ "$reality_enabled" == "true" ]]; then
                        regenerate_reality_link "$inbound" "$port"
                    else
                        # 区分普通 HTTPS（TCP）和 CDN（带 transport）
                        local has_transport=$(echo "$inbound" | jq -r '.transport.type // ""' 2>/dev/null)
                        if [[ -n "$has_transport" ]]; then
                            regenerate_cdn_vless_link "$inbound" "$port"
                        else
                            regenerate_https_link "$inbound" "$port"
                        fi
                    fi
                fi
                ;;
            "vmess")     regenerate_cdn_vmess_link "$inbound" "$port" ;;
            "trojan")    regenerate_cdn_trojan_link "$inbound" "$port" ;;
            "hysteria2")  regenerate_hysteria2_link "$inbound" "$port" ;;
            "socks")      regenerate_socks5_link "$inbound" "$port" ;;
            "shadowtls")  regenerate_shadowtls_link "$inbound" "$port" ;;
            "anytls")     regenerate_anytls_link "$inbound" "$port" ;;
        esac
    done

    print_success "链接重新生成完成"
    save_links_to_files
}

# ==================== 统一链接生成函数 ====================
# 根据协议类型和参数生成标准分享链接
# 用法: generate_proto_link <proto> <ip> <port> [key=value ...]
# 支持的协议: reality, hysteria2, socks5, shadowtls, https, anytls, anytls-reality,
#             vless-ws, vmess-ws, trojan-ws (CDN 适用，支持 ws/grpc/httpupgrade transport)
generate_proto_link() {
    local proto="$1"
    local ip="$2"
    local port="$3"
    shift 3

    # 解析 key=value 参数
    local uuid="" password="" sni="" pbk="" sid="" fp="chrome" flow=""
    local obfs_type="" obfs_password="" insecure="1"
    local ss_method="" ss_password="" shadowtls_password=""
    local padding="" security=""
    local transport="" ws_path="" ws_host="" grpc_service=""
    local username=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            uuid=*) uuid="${1#uuid=}" ;;
            username=*) username="${1#username=}" ;;
            password=*) password="${1#password=}" ;;
            sni=*) sni="${1#sni=}" ;;
            pbk=*) pbk="${1#pbk=}" ;;
            sid=*) sid="${1#sid=}" ;;
            fp=*) fp="${1#fp=}" ;;
            flow=*) flow="${1#flow=}" ;;
            obfs_type=*) obfs_type="${1#obfs_type=}" ;;
            obfs_password=*) obfs_password="${1#obfs_password=}" ;;
            insecure=*) insecure="${1#insecure=}" ;;
            ss_method=*) ss_method="${1#ss_method=}" ;;
            ss_password=*) ss_password="${1#ss_password=}" ;;
            shadowtls_password=*) shadowtls_password="${1#shadowtls_password=}" ;;
            padding=*) padding="${1#padding=}" ;;
            security=*) security="${1#security=}" ;;
            transport=*) transport="${1#transport=}" ;;
            path=*) ws_path="${1#path=}" ;;
            host=*) ws_host="${1#host=}" ;;
            grpc_service=*) grpc_service="${1#grpc_service=}" ;;
        esac
        shift
    done

    local link=""
    local proto_label=""

    case "$proto" in
        "reality")
            link="vless://${uuid}@${ip}:${port}?encryption=none&flow=${flow:-xtls-rprx-vision}&security=reality&sni=${sni}&fp=${fp}&pbk=${pbk}&sid=${sid}&type=tcp#Reality-${ip}"
            proto_label="Reality"
            ;;
        "hysteria2")
            link="hysteria2://${password}@${ip}:${port}?insecure=${insecure}&sni=${sni}"
            if [[ "$obfs_type" == "salamander" && -n "$obfs_password" ]]; then
                link="${link}&obfs=salamander&obfs-password=${obfs_password}"
            fi
            link="${link}#Hysteria2-${ip}"
            proto_label="Hysteria2"
            ;;
        "socks5")
            if [[ -n "$username" && -n "$password" ]]; then
                link="socks5://${username}:${password}@${ip}:${port}#SOCKS5-${ip}"
            else
                link="socks5://${ip}:${port}#SOCKS5-${ip}"
            fi
            proto_label="SOCKS5"
            ;;
        "https")
            link="vless://${uuid}@${ip}:${port}?encryption=none&security=tls&sni=${sni}&type=tcp&allowInsecure=${insecure}#HTTPS-${ip}"
            proto_label="HTTPS"
            ;;
        "anytls")
            link="anytls://${password}@${ip}:${port}?security=tls&fp=${fp}&insecure=${insecure}&sni=${sni}&type=tcp#AnyTLS-${ip}"
            proto_label="AnyTLS"
            ;;
        "anytls-reality")
            # AnyTLS+REALITY 不生成标准链接
            link=""
            proto_label="AnyTLS+REALITY"
            ;;
        "vless-ws")
            # VLESS + WS/gRPC/HTTPUpgrade + TLS，CDN 适用
            # 客户端 address 可替换为 CDN 优选 IP/域名
            [[ -z "$transport" ]] && transport="ws"
            [[ -z "$ws_path" ]] && ws_path="/ws"
            [[ -z "$ws_host" ]] && ws_host="$sni"
            if [[ "$transport" == "grpc" ]]; then
                [[ -z "$grpc_service" ]] && grpc_service="grpc"
                link="vless://${uuid}@${ip}:${port}?encryption=none&security=tls&sni=${sni}&fp=${fp}&allowInsecure=${insecure}&type=grpc&serviceName=${grpc_service}#VLESS-CDN-${ip}"
            else
                link="vless://${uuid}@${ip}:${port}?encryption=none&security=tls&sni=${sni}&fp=${fp}&allowInsecure=${insecure}&type=${transport}&host=${ws_host}&path=${ws_path}#VLESS-CDN-${ip}"
            fi
            proto_label="VLESS-CDN"
            ;;
        "vmess-ws")
            # VMess + WS/gRPC + TLS，CDN 适用
            # VMess 链接为 base64 编码的 JSON
            [[ -z "$transport" ]] && transport="ws"
            [[ -z "$ws_path" ]] && ws_path="/ws"
            [[ -z "$ws_host" ]] && ws_host="$sni"
            [[ -z "$grpc_service" ]] && grpc_service="grpc"
            local vmess_aid="0"
            local vmess_json
            if [[ "$transport" == "grpc" ]]; then
                vmess_json=$(cat <<EOF
{"v":"2","ps":"VMess-CDN-${ip}","add":"${ip}","port":"${port}","id":"${uuid}","aid":"${vmess_aid}","net":"grpc","type":"none","host":"","path":"${grpc_service}","tls":"tls","sni":"${sni}"}
EOF
)
            else
                vmess_json=$(cat <<EOF
{"v":"2","ps":"VMess-CDN-${ip}","add":"${ip}","port":"${port}","id":"${uuid}","aid":"${vmess_aid}","net":"${transport}","type":"none","host":"${ws_host}","path":"${ws_path}","tls":"tls","sni":"${sni}"}
EOF
)
            fi
            # base64 编码（URL-safe 不要求，标准 base64 即可）
            link="vmess://$(echo -n "$vmess_json" | base64 -w0)"
            proto_label="VMess-CDN"
            ;;
        "trojan-ws")
            # Trojan + WS/gRPC + TLS，CDN 适用
            [[ -z "$transport" ]] && transport="ws"
            [[ -z "$ws_path" ]] && ws_path="/ws"
            [[ -z "$ws_host" ]] && ws_host="$sni"
            [[ -z "$grpc_service" ]] && grpc_service="grpc"
            if [[ "$transport" == "grpc" ]]; then
                link="trojan://${password}@${ip}:${port}?security=tls&sni=${sni}&allowInsecure=${insecure}&type=grpc&serviceName=${grpc_service}#Trojan-CDN-${ip}"
            else
                link="trojan://${password}@${ip}:${port}?security=tls&sni=${sni}&allowInsecure=${insecure}&type=${transport}&host=${ws_host}&path=${ws_path}#Trojan-CDN-${ip}"
            fi
            proto_label="Trojan-CDN"
            ;;
        "shadowtls")
            if [[ -n "$ss_method" && -n "$ss_password" && -n "$shadowtls_password" ]]; then
                local ss_userinfo=$(echo -n "${ss_method}:${ss_password}" | base64 -w0 | sed 's/+/-/g; s/\//_/g; s/=//g')
                local plugin_json="{\"version\":\"3\",\"password\":\"${shadowtls_password}\",\"host\":\"${sni}\",\"port\":\"${port}\",\"address\":\"${ip}\"}"
                local plugin_base64=$(echo -n "$plugin_json" | base64 -w0 | sed 's/+/-/g; s/\//_/g; s/=//g')
                link="ss://${ss_userinfo}@${ip}:${port}?shadow-tls=${plugin_base64}#ShadowTLS-${ip}"
            fi
            proto_label="ShadowTLS v3"
            ;;
        *)
            return 1
            ;;
    esac

    echo "${link}"
}

# ==================== 链接生成辅助函数 ====================
add_link() {
    local link="$1"
    local proto="$2"
    local extra_info="$3"
    local ip="$4"
    local port="$5"
    local sni="$6"
    
    # 生成链接文本
    local line="[${proto}] ${ip}:${port}"
    [[ -n "$sni" ]] && line="${line} (SNI: ${sni})"
    line="${line}\n${link}\n----------------------------------------\n\n"
    
    # 添加到所有链接
    ALL_LINKS_TEXT="${ALL_LINKS_TEXT}${line}"
    
    # 添加到对应的协议链接
    case "$proto" in
        "Reality") REALITY_LINKS="${REALITY_LINKS}${line}" ;;
        "Hysteria2") HYSTERIA2_LINKS="${HYSTERIA2_LINKS}${line}" ;;
        "SOCKS5") SOCKS5_LINKS="${SOCKS5_LINKS}${line}" ;;
        "ShadowTLS v3") SHADOWTLS_LINKS="${SHADOWTLS_LINKS}${line}" ;;
        "HTTPS") HTTPS_LINKS="${HTTPS_LINKS}${line}" ;;
        "AnyTLS"|"AnyTLS+REALITY") ANYTLS_LINKS="${ANYTLS_LINKS}${line}" ;;
        VLESS-CDN-*) VLESS_CDN_LINKS="${VLESS_CDN_LINKS}${line}" ;;
        VMess-CDN-*) VMESS_CDN_LINKS="${VMESS_CDN_LINKS}${line}" ;;
        Trojan-CDN-*) TROJAN_CDN_LINKS="${TROJAN_CDN_LINKS}${line}" ;;
    esac
}

# ==================== 监听地址获取 ====================
get_listen_address() {
    case "${INBOUND_IP_MODE}" in
        "ipv4")
            echo "0.0.0.0"
            ;;
        "ipv6")
            echo "::"
            ;;
        "dual"|*)
            echo "::"
            ;;
    esac
}

