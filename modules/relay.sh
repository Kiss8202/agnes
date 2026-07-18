# ==================== sing-box 中转功能模块 ====================
# ==================== 中转配置管理 ====================
save_relays_to_file() {
    mkdir -p "$(dirname "${RELAY_FILE}")"
    
    cat > "${RELAY_FILE}" << EOF
# Sing-box 中转配置文件
# 格式: TAG|DESCRIPTION|JSON_CONFIG
EOF
    
    for i in "${!RELAY_TAGS[@]}"; do
        local tag="${RELAY_TAGS[$i]}"
        local desc="${RELAY_DESCS[$i]}"
        local json="${RELAY_JSONS[$i]}"
        # 使用 base64 编码 JSON 避免换行问题
        local json_base64=$(echo "$json" | base64 -w0)
        echo "${tag}|${desc}|${json_base64}" >> "${RELAY_FILE}"
    done
}

load_relays_from_file() {
    RELAY_TAGS=()
    RELAY_JSONS=()
    RELAY_DESCS=()
    
    if [[ ! -f "${RELAY_FILE}" ]]; then
        return 0
    fi
    
    while IFS='|' read -r tag desc json_base64; do
        # 跳过注释和空行
        [[ "$tag" =~ ^#.*$ || -z "$tag" ]] && continue
        
        local json=$(echo "$json_base64" | base64 -d 2>/dev/null)
        if [[ -n "$json" ]]; then
            RELAY_TAGS+=("$tag")
            RELAY_DESCS+=("$desc")
            RELAY_JSONS+=("$json")
        fi
    done < "${RELAY_FILE}"
}

# ==================== 分流规则管理 ====================
save_domain_routes_to_file() {
    mkdir -p "$(dirname "${DOMAIN_ROUTE_FILE}")"
    
    cat > "${DOMAIN_ROUTE_FILE}" << EOF
# Sing-box 分流规则配置文件
# 格式: INBOUND_TAG|MATCH_TYPE|MATCH_VALUE|RELAY_TAG|DESCRIPTION
# MATCH_TYPE: domain_suffix(域名后缀), domain(完整域名), domain_keyword(关键词), ip_cidr(IP/CIDR)
EOF
    
    for route in "${DOMAIN_ROUTES[@]}"; do
        echo "$route" >> "${DOMAIN_ROUTE_FILE}"
    done
}

load_domain_routes_from_file() {
    DOMAIN_ROUTES=()
    
    if [[ ! -f "${DOMAIN_ROUTE_FILE}" ]]; then
        return 0
    fi
    
    while IFS= read -r line; do
        # 跳过注释和空行
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        DOMAIN_ROUTES+=("$line")
    done < "${DOMAIN_ROUTE_FILE}"
}

cleanup_links() {
    rm -rf "${LINK_DIR}" 2>/dev/null || true
    ALL_LINKS_TEXT=""
    REALITY_LINKS=""
    HYSTERIA2_LINKS=""
    SOCKS5_LINKS=""
    SHADOWTLS_LINKS=""
    HTTPS_LINKS=""
    ANYTLS_LINKS=""
}

regenerate_all_links() {
    echo ""
    echo -e "${YELLOW}此操作将从配置文件重新生成所有节点链接${NC}"
    echo ""
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        print_error "配置文件不存在，无法重新生成链接"
        return 1
    fi
    
    print_info "清理旧链接文件..."
    cleanup_links
    
    print_info "从配置文件重新生成链接..."
    if regenerate_links_from_config; then
        print_success "链接文件已重新生成"
        print_info "可以在 [配置/查看节点] 菜单中查看"
    else
        print_error "重新生成链接失败"
        return 1
    fi
}

# ==================== 网络工具 ====================
get_ip() {
    print_info "获取服务器 IP 地址..."
    local old_ip="${SERVER_IP}"
    local old_ipv6="${SERVER_IPV6}"
    
    local ipv4=""
    local ipv6=""

    for service in "ifconfig.me" "api.ipify.org" "ip.sb"; do
        ipv4=$(curl -s4 --connect-timeout 5 "https://${service}" 2>/dev/null)
        [[ -n "$ipv4" && "$ipv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
        ipv4=""
    done

    for service in "ifconfig.me" "api6.ipify.org" "ip.sb"; do
        ipv6=$(curl -s6 --connect-timeout 5 "https://${service}" 2>/dev/null)
        [[ -n "$ipv6" && "$ipv6" =~ ^[0-9a-fA-F:]+$ ]] && break
        ipv6=""
    done

    # 兜底：外网服务都失败时，从本机网卡读取 IP
    # 注意：网卡上的 IP 通常是内网 IP（NAT 后），仅作最后兜底，并明确提示用户
    if [[ -z "$ipv4" ]]; then
        local nic_ipv4=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | head -1)
        [[ -z "$nic_ipv4" ]] && nic_ipv4=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
        if [[ -n "$nic_ipv4" ]]; then
            ipv4="$nic_ipv4"
            print_warning "外网 IP 服务不可达，从网卡读取 IP: ${ipv4}"
            print_warning "如果这是内网 IP，请在主菜单 [出入站配置] 中手动填写公网 IP"
        fi
    fi
    if [[ -z "$ipv6" ]]; then
        local nic_ipv6=$(ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -vE '^fe80|^fc|^fd' | head -1)
        if [[ -n "$nic_ipv6" ]]; then
            ipv6="$nic_ipv6"
        fi
    fi

    # 显示检测到的 IP
    echo ""
    if [[ -n "$ipv4" ]]; then
        echo -e "  ${GREEN}检测到 IPv4:${NC} ${ipv4}"
    fi
    if [[ -n "$ipv6" ]]; then
        echo -e "  ${GREEN}检测到 IPv6:${NC} ${ipv6}"
    fi
    echo ""

    # 如果两个都没有，报错退出
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        print_error "无法获取服务器 IP 地址"
        print_info "排查建议："
        print_info "  1. 检查 DNS: cat /etc/resolv.conf"
        print_info "  2. 测试连通: ping -c 2 8.8.8.8 && ping -c 2 ifconfig.me"
        print_info "  3. 检查网卡: ip addr show"
        print_info "  4. 若网络正常但服务被墙，可设置 GH_MIRROR 后重试"
        exit 1
    fi
    
    # 优先使用 IPv4，没有 IPv4 时使用 IPv6
    if [[ -n "$ipv4" ]]; then
        SERVER_IP="$ipv4"
        SERVER_IPV6="$ipv6"
        if [[ -n "$ipv6" ]]; then
            print_success "检测到双栈网络，默认使用 IPv4: ${SERVER_IP}"
            echo -e "${CYAN}提示: 可在主菜单 [出入站配置] 中切换 IPv6${NC}"
        else
            print_success "使用 IPv4: ${SERVER_IP}"
        fi
    elif [[ -n "$ipv6" ]]; then
        SERVER_IP=""
        SERVER_IPV6="$ipv6"
        INBOUND_IP_MODE="ipv6"
        [[ -z "$OUTBOUND_IP_MODE" || "$OUTBOUND_IP_MODE" == "dual" ]] && OUTBOUND_IP_MODE="dual"
        print_success "仅 IPv6 网络: ${SERVER_IPV6}"
        print_info "已自动设置入站为 IPv6，出站为双栈模式"
    fi
    
    if [[ -n "$old_ip" && "$old_ip" != "$SERVER_IP" ]]; then
        print_warning "服务器 IPv4 已从 ${old_ip} 变更为 ${SERVER_IP}"
        print_info "建议使用主菜单 [5] 重新生成链接文件"
    fi
    if [[ -n "$old_ipv6" && "$old_ipv6" != "$SERVER_IPV6" ]]; then
        print_warning "服务器 IPv6 已从 ${old_ipv6} 变更为 ${SERVER_IPV6}"
        print_info "建议使用主菜单 [5] 重新生成链接文件"
    fi
    # 保存 IP 配置
    save_ip_config
}

check_port_in_use() {
    local port="$1"

    if command -v ss &>/dev/null; then
        ss -tuln | awk '{print $5}' | grep -E "[:.]${port}$" >/dev/null 2>&1 && return 0 || return 1
    elif command -v netstat &>/dev/null; then
        netstat -tuln | awk '{print $4}' | grep -E "[:.]${port}$" >/dev/null 2>&1 && return 0 || return 1
    else
        return 1
    fi
}

get_port_process() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tulnp 2>/dev/null | grep -E "[:.]${port}$" | awk '{print $NF}'
    elif command -v netstat &>/dev/null; then
        netstat -tulnp 2>/dev/null | grep -E "[:.]${port}$" | awk '{print $NF}'
    fi
}

# 获取随机可用端口
get_random_free_port() {
    local port
    local max_attempts=100
    local attempt=0
    while (( attempt < max_attempts )); do
        port=$((RANDOM % 55536 + 10000))  # 10000-65535
        if ! check_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
        ((attempt++))
    done
    return 1
}

# 从 DEFAULT_SNI1 随机选择 SNI
get_random_sni() {
    local -a _sni_array
    IFS=',' read -ra _sni_array <<< "${DEFAULT_SNI1}"
    if [[ ${#_sni_array[@]} -eq 0 ]]; then
        echo "${DEFAULT_SNI}"
        return
    fi
    echo "${_sni_array[$((RANDOM % ${#_sni_array[@]}))]}"
}

read_port_with_check() {
    local default_port="$1"
    
    while true; do
        read -p "监听端口 [${default_port}]: " PORT
        PORT=${PORT:-${default_port}}
        
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
            print_error "端口无效，请输入 1-65535 之间的数字"
            continue
        fi
        
        if check_port_in_use "$PORT"; then
            local proc_info=$(get_port_process "$PORT")
            print_warning "端口 ${PORT} 已被占用"
            [[ -n "$proc_info" ]] && print_info "占用进程: ${proc_info}"
            continue
        fi
        
        break
    done
}

# ==================== 服务器地址解析（兼容 IPv6） ====================
# 用法: parse_server_port <server:port字符串>
# 输出: 两行 —— 第一行 server，第二行 port
# 支持: 1.2.3.4:443 / [2a0f:1cc6:b120::12]:443 / example.com:443
parse_server_port() {
    local input="$1"
    # 清理尾部 / # 等杂质
    input="${input%%/*}"
    input="${input%%#*}"
    if [[ "$input" =~ ^\[([^\]]+)\]:([0-9]+) ]]; then
        # IPv6 格式: [addr]:port
        echo "${BASH_REMATCH[1]}"
        echo "${BASH_REMATCH[2]}"
    else
        # IPv4 / 域名格式: addr:port
        echo "${input%:*}"
        echo "${input##*:}"
    fi
}

# ==================== 中转链接解析 ====================
parse_socks_link() {
    local link="$1"
    local custom_desc="$2"
    
    if [[ "$link" =~ ^socks://([A-Za-z0-9+/=]+) ]]; then
        print_info "检测到 base64 编码的 SOCKS 链接，正在解码..."
        local base64_part="${BASH_REMATCH[1]}"
        local decoded=$(echo "$base64_part" | base64 -d 2>/dev/null)
        
        if [[ -z "$decoded" ]]; then
            print_error "base64 解码失败"
            return 1
        fi
        
        link="socks5://${decoded}"
    fi
    
    local data=$(echo "$link" | sed 's|socks5\?://||')
    data=$(echo "$data" | cut -d'?' -f1 | cut -d'#' -f1)
    
    local relay_json=""
    local relay_desc=""
    
    if [[ "$data" =~ @ ]]; then
        local userpass=$(echo "$data" | cut -d'@' -f1)
        local username=$(echo "$userpass" | cut -d':' -f1)
        local password=$(echo "$userpass" | cut -d':' -f2-)
        local server_port=$(echo "$data" | cut -d'@' -f2)
        local _sp=($(parse_server_port "$server_port"))
        local server="${_sp[0]}"
        local port="${_sp[1]}"

        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            print_error "端口无效: ${port}"
            return 1
        fi

        local tag="relay-socks5-${#RELAY_TAGS[@]}"
        relay_json="{
  \"type\": \"socks\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"version\": \"5\",
  \"username\": \"${username}\",
  \"password\": \"${password}\"
}"
        if [[ -n "$custom_desc" ]]; then
            relay_desc="$custom_desc"
        else
            relay_desc="SOCKS5 ${server}:${port} (认证)"
        fi
    else
        local _sp=($(parse_server_port "$data"))
        local server="${_sp[0]}"
        local port="${_sp[1]}"
        
        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            print_error "端口无效: ${port}"
            return 1
        fi
        
        local tag="relay-socks5-${#RELAY_TAGS[@]}"
        relay_json="{
  \"type\": \"socks\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"version\": \"5\"
}"
        if [[ -n "$custom_desc" ]]; then
            relay_desc="$custom_desc"
        else
            relay_desc="SOCKS5 ${server}:${port}"
        fi
    fi
    
    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")
    
    save_relays_to_file
    print_success "SOCKS5 中转已添加: ${relay_desc}"
}

parse_http_link() {
    local link="$1"
    local custom_desc="$2"
    local protocol=$(echo "$link" | cut -d':' -f1)
    local data=$(echo "$link" | sed 's|https\?://||')
    
    local tls="false"
    [[ "$protocol" == "https" ]] && tls="true"
    
    local relay_json=""
    local relay_desc=""
    local tag="relay-http-${#RELAY_TAGS[@]}"
    
    if [[ "$data" =~ @ ]]; then
        local userpass=$(echo "$data" | cut -d'@' -f1)
        local username=$(echo "$userpass" | cut -d':' -f1)
        local password=$(echo "$userpass" | cut -d':' -f2)
        local server_port=$(echo "$data" | cut -d'@' -f2 | cut -d'/' -f1 | cut -d'#' -f1 | cut -d'?' -f1)
        local _sp=($(parse_server_port "$server_port"))
        local server="${_sp[0]}"
        local port="${_sp[1]}"
        
        relay_json="{
  \"type\": \"http\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"username\": \"${username}\",
  \"password\": \"${password}\",
  \"tls\": {\"enabled\": ${tls}}
}"
        if [[ -n "$custom_desc" ]]; then
            relay_desc="$custom_desc"
        else
            relay_desc="${protocol^^} ${server}:${port} (认证)"
        fi
    else
        local server_port=$(echo "$data" | cut -d'/' -f1 | cut -d'#' -f1 | cut -d'?' -f1)
        local _sp=($(parse_server_port "$server_port"))
        local server="${_sp[0]}"
        local port="${_sp[1]}"
        
        relay_json="{
  \"type\": \"http\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"tls\": {\"enabled\": ${tls}}
}"
        if [[ -n "$custom_desc" ]]; then
            relay_desc="$custom_desc"
        else
            relay_desc="${protocol^^} ${server}:${port}"
        fi
    fi
    
    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")
    
    save_relays_to_file
    print_success "HTTP(S) 中转已添加: ${relay_desc}"
}

parse_ss_link() {
    local link="$1"
    local custom_desc="$2"
    local data=$(echo "$link" | sed 's|ss://||' | cut -d'#' -f1)
    
    if [[ "$data" =~ @ ]]; then
        local userinfo=$(echo "$data" | cut -d'@' -f1)
        local server_port=$(echo "$data" | cut -d'@' -f2 | cut -d'?' -f1)
        local _sp=($(parse_server_port "$server_port"))
        local server="${_sp[0]}"
        local port="${_sp[1]}"
        
        local decoded=$(echo "$userinfo" | base64 -d 2>/dev/null)
        if [[ -z "$decoded" ]]; then
            print_error "Shadowsocks 链接解码失败"
            return 1
        fi
        
        local method=$(echo "$decoded" | cut -d':' -f1)
        local password=$(echo "$decoded" | cut -d':' -f2-)
        
        local tag="relay-ss-${#RELAY_TAGS[@]}"
        local relay_json="{
  \"type\": \"shadowsocks\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"method\": \"${method}\",
  \"password\": \"${password}\"
}"
        local relay_desc
        if [[ -n "$custom_desc" ]]; then
            relay_desc="$custom_desc"
        else
            relay_desc="Shadowsocks ${server}:${port}"
        fi
        
        RELAY_TAGS+=("$tag")
        RELAY_JSONS+=("$relay_json")
        RELAY_DESCS+=("$relay_desc")
        
        save_relays_to_file
        print_success "Shadowsocks 中转已添加: ${relay_desc}"
    else
        print_error "Shadowsocks 链接格式错误"
        return 1
    fi
}

parse_vmess_link() {
    local link="$1"
    local custom_desc="$2"
    local base64_data=$(echo "$link" | sed 's|vmess://||')
    local json=$(echo "$base64_data" | base64 -d 2>/dev/null)
    
    if [[ -z "$json" ]]; then
        print_error "VMess 链接解码失败"
        return 1
    fi
    
    if ! command -v jq &>/dev/null; then
        print_error "需要 jq 工具来解析 VMess 链接"
        return 1
    fi
    
    local server=$(echo "$json" | jq -r '.add // .address')
    local port=$(echo "$json" | jq -r '.port')
    local uuid=$(echo "$json" | jq -r '.id')
    local alterId=$(echo "$json" | jq -r '.aid // 0')
    local security=$(echo "$json" | jq -r '.scy // "auto"')
    local net=$(echo "$json" | jq -r '.net // "tcp"')
    local path=$(echo "$json" | jq -r '.path // ""')
    local host=$(echo "$json" | jq -r '.host // ""')
    local tls=$(echo "$json" | jq -r '.tls // ""')
    local sni=$(echo "$json" | jq -r '.sni // ""')
    local alpn=$(echo "$json" | jq -r '.alpn // ""')
    
    # 构建传输层配置
    local transport_config=""
    if [[ "$net" == "ws" ]]; then
        local ws_headers=""
        if [[ -n "$host" ]]; then
            ws_headers=", \"headers\": {\"Host\": \"${host}\"}"
        fi
        local ws_path="/"
        if [[ -n "$path" ]]; then
            ws_path="$path"
        fi
        transport_config=",
  \"transport\": {
    \"type\": \"ws\",
    \"path\": \"${ws_path}\"${ws_headers}
  }"
    elif [[ "$net" == "grpc" ]]; then
        local service_name=$(echo "$json" | jq -r '.path // ""')
        transport_config=",
  \"transport\": {
    \"type\": \"grpc\",
    \"service_name\": \"${service_name}\"
  }"
    elif [[ "$net" == "http" || "$net" == "h2" ]]; then
        local h2_path="/"
        [[ -n "$path" ]] && h2_path="$path"
        local h2_host=""
        [[ -n "$host" ]] && h2_host=", \"host\": [\"${host}\"]"
        transport_config=",
  \"transport\": {
    \"type\": \"http\",
    \"path\": \"${h2_path}\"${h2_host}
  }"
    fi
    
    # 构建 TLS 配置
    local tls_config=""
    if [[ "$tls" == "tls" ]]; then
        local sni_config=""
        if [[ -n "$sni" ]]; then
            sni_config=", \"server_name\": \"${sni}\""
        elif [[ -n "$host" ]]; then
            sni_config=", \"server_name\": \"${host}\""
        fi
        local alpn_config=""
        if [[ -n "$alpn" ]]; then
            alpn_config=", \"alpn\": [\"$(echo "$alpn" | sed 's/,/","/g')\"]"
        fi
        tls_config=",
  \"tls\": {
    \"enabled\": true${sni_config}${alpn_config},
    \"min_version\": \"1.3\"
  }"
    fi
    
    local tag="relay-vmess-${#RELAY_TAGS[@]}"
    local relay_json="{
  \"type\": \"vmess\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"uuid\": \"${uuid}\",
  \"alter_id\": ${alterId},
  \"security\": \"${security}\"${transport_config}${tls_config}
}"
    local relay_desc
    if [[ -n "$custom_desc" ]]; then
        relay_desc="$custom_desc"
    else
        relay_desc="VMess ${server}:${port}"
    fi
    
    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")
    
    save_relays_to_file
    print_success "VMess 中转已添加: ${relay_desc}"
}

parse_vless_link() {
    local link="$1"
    local custom_desc="$2"
    local data=$(echo "$link" | sed 's|vless://||')
    local uuid=$(echo "$data" | cut -d'@' -f1)
    local server_port_params=$(echo "$data" | cut -d'@' -f2)
    local server_port_part=$(echo "$server_port_params" | cut -d'?' -f1 | cut -d'#' -f1)
    local _sp=($(parse_server_port "$server_port_part"))
    local server="${_sp[0]}"
    local port="${_sp[1]}"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        print_error "端口无效: ${port}"
        return 1
    fi

    local params=$(echo "$server_port_params" | grep -o '?.*' | sed 's|?||' | cut -d'#' -f1)

    local security="none"
    local sni=""
    local flow=""
    local pbk=""
    local sid=""
    local encryption="none"

    if [[ -n "$params" ]]; then
        IFS='&' read -ra param_pairs <<< "$params"
        for pair in "${param_pairs[@]}"; do
            key="${pair%%=*}"
            value="${pair#*=}"
            case "$key" in
                security) security="$value" ;;
                sni) sni="$value" ;;
                flow) flow="$value" ;;
                pbk) pbk="$value" ;;
                sid) sid="$value" ;;
                encryption) encryption="$value" ;;
            esac
        done
    fi

    local tls_config=""
    local reality_config=""
    if [[ "$security" == "tls" ]]; then
        tls_config=",
  \"tls\": {
    \"enabled\": true,
    \"server_name\": \"${sni}\",
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"utls\": {\"enabled\": true, \"fingerprint\": \"chrome\"}
  }"
    elif [[ "$security" == "reality" ]]; then
        if [[ -z "$pbk" ]]; then
            print_error "REALITY 链接缺少公钥 (pbk)"
            return 1
        fi
        reality_config=",
  \"tls\": {
    \"enabled\": true,
    \"server_name\": \"${sni}\",
    \"min_version\": \"1.3\",
    \"utls\": {\"enabled\": true, \"fingerprint\": \"chrome\"},
    \"reality\": {
      \"enabled\": true,
      \"public_key\": \"${pbk}\",
      \"short_id\": \"${sid}\"
    }
  }"
    fi

    local flow_config=""
    [[ -n "$flow" ]] && flow_config=",
  \"flow\": \"${flow}\""

    local encryption_config=""
    [[ "$encryption" != "none" ]] && encryption_config=",
  \"encryption\": \"${encryption}\""

    local tag="relay-vless-${#RELAY_TAGS[@]}"
    local relay_json="{
  \"type\": \"vless\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"uuid\": \"${uuid}\"${encryption_config}${flow_config}${tls_config}${reality_config}
}"

    local relay_desc
    if [[ -n "$custom_desc" ]]; then
        relay_desc="$custom_desc"
    else
        if [[ "$security" == "reality" ]]; then
            relay_desc="VLESS+REALITY ${server}:${port} (SNI: ${sni})"
        else
            relay_desc="VLESS ${server}:${port}"
        fi
    fi

    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")

    save_relays_to_file
    print_success "VLESS 中转已添加: ${relay_desc}"
}

parse_trojan_link() {
    local link="$1"
    local custom_desc="$2"
    local data=$(echo "$link" | sed 's|trojan://||')
    local password=$(echo "$data" | cut -d'@' -f1)
    local server_port_params=$(echo "$data" | cut -d'@' -f2)
    local server_port_part=$(echo "$server_port_params" | cut -d'?' -f1 | cut -d'#' -f1)
    local _sp=($(parse_server_port "$server_port_part"))
    local server="${_sp[0]}"
    local port="${_sp[1]}"

    local params=$(echo "$server_port_params" | grep -o '?.*' | sed 's|?||' | cut -d'#' -f1)
    
    local sni=""
    local insecure="false"
    local net="tcp"
    local path=""
    local host=""
    local fp=""
    
    if [[ -n "$params" ]]; then
        IFS='&' read -ra param_pairs <<< "$params"
        for pair in "${param_pairs[@]}"; do
            key="${pair%%=*}"
            value="${pair#*=}"
            case "$key" in
                sni) sni="$value" ;;
                insecure) insecure="$value" ;;
                type) net="$value" ;;
                path) path="$value" ;;
                host) host="$value" ;;
                fp) fp="$value" ;;
            esac
        done
    fi
    
    # 转换 insecure 为布尔值
    local insecure_bool="false"
    [[ "$insecure" == "1" || "$insecure" == "true" ]] && insecure_bool="true"
    
    # 构建 TLS 配置
    local sni_config=""
    if [[ -n "$sni" ]]; then
        sni_config=", \"server_name\": \"${sni}\""
    elif [[ -n "$host" ]]; then
        sni_config=", \"server_name\": \"${host}\""
    fi
    local utls_config=""
    if [[ -n "$fp" ]]; then
        utls_config=", \"utls\": {\"enabled\": true, \"fingerprint\": \"${fp}\"}"
    fi
    local tls_config=",
  \"tls\": {
    \"enabled\": true${sni_config}${utls_config},
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"insecure\": ${insecure_bool}
  }"
    
    # 构建传输层配置
    local transport_config=""
    if [[ "$net" == "ws" ]]; then
        local ws_headers=""
        if [[ -n "$host" ]]; then
            ws_headers=", \"headers\": {\"Host\": \"${host}\"}"
        fi
        local ws_path="/"
        [[ -n "$path" ]] && ws_path="$path"
        transport_config=",
  \"transport\": {
    \"type\": \"ws\",
    \"path\": \"${ws_path}\"${ws_headers}
  }"
    elif [[ "$net" == "grpc" ]]; then
        transport_config=",
  \"transport\": {
    \"type\": \"grpc\",
    \"service_name\": \"${path}\"
  }"
    fi
    
    local tag="relay-trojan-${#RELAY_TAGS[@]}"
    local relay_json="{
  \"type\": \"trojan\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"password\": \"${password}\"${tls_config}${transport_config}
}"
    local relay_desc
    if [[ -n "$custom_desc" ]]; then
        relay_desc="$custom_desc"
    else
        relay_desc="Trojan ${server}:${port}"
    fi
    
    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")
    
    save_relays_to_file
    print_success "Trojan 中转已添加: ${relay_desc}"
}

parse_hysteria2_link() {
    local link="$1"
    local custom_desc="$2"

    # 去除协议前缀 (hy2:// 或 hysteria2://)
    local data="${link#*://}"
    # 提取密码 (第一个 @ 之前)
    local userinfo="${data%%@*}"
    local rest="${data#*@}"
    # 提取服务器和端口
    local server_port_part=$(echo "$rest" | cut -d'?' -f1 | cut -d'#' -f1 | sed 's|/$||')
    local _sp=($(parse_server_port "$server_port_part"))
    local server="${_sp[0]}"
    local port="${_sp[1]}"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        print_error "端口无效: ${port}"
        return 1
    fi

    # 提取参数部分
    local params=""
    if [[ "$rest" == *"?"* ]]; then
        params="${rest#*\?}"
        params="${params%%#*}"  # 去除可能的 # 备注
    fi

    # 默认值
    local password="$userinfo"
    local sni=""
    local insecure="false"
    local obfs_type=""
    local obfs_password=""

    # 解析参数
    if [[ -n "$params" ]]; then
        # 按 & 分割
        IFS='&' read -ra param_pairs <<< "$params"
        for pair in "${param_pairs[@]}"; do
            key="${pair%%=*}"
            value="${pair#*=}"
            case "$key" in
                sni) sni="$value" ;;
                insecure) insecure="$value" ;;
                obfs) obfs_type="$value" ;;
                obfs-password) obfs_password="$value" ;;
            esac
        done
    fi

    # 转换 insecure 为布尔值
    local insecure_bool="false"
    [[ "$insecure" == "1" || "$insecure" == "true" ]] && insecure_bool="true"

    # 构建 tls 配置
    local tls_config="{
    \"enabled\": true,
    \"server_name\": \"${sni}\",
    \"alpn\": [\"h3\"],
    \"min_version\": \"1.3\",
    \"insecure\": ${insecure_bool}
  }"
    local obfs_config=""
    if [[ "$obfs_type" == "salamander" && -n "$obfs_password" ]]; then
        obfs_config=",
  \"obfs\": {
    \"type\": \"salamander\",
    \"password\": \"${obfs_password}\"
  }"
    fi

    local tag="relay-hysteria2-${#RELAY_TAGS[@]}"
    local relay_json="{
  \"type\": \"hysteria2\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"password\": \"${password}\",
  \"tls\": ${tls_config}${obfs_config}
}"

    local relay_desc
    if [[ -n "$custom_desc" ]]; then
        relay_desc="$custom_desc"
    else
        relay_desc="Hysteria2 ${server}:${port} (SNI: ${sni})"
    fi

    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")

    save_relays_to_file
    print_success "Hysteria2 中转已添加: ${relay_desc}"
}

parse_anytls_link() {
    local link="$1"
    local custom_desc="$2"
    local data=$(echo "$link" | sed 's|anytls://||')
    local userinfo=$(echo "$data" | cut -d'@' -f1)
    local server_port_params=$(echo "$data" | cut -d'@' -f2)
    local server_port_part=$(echo "$server_port_params" | cut -d'?' -f1 | cut -d'#' -f1)
    local _sp=($(parse_server_port "$server_port_part"))
    local server="${_sp[0]}"
    local port="${_sp[1]}"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        print_error "端口无效: ${port}"
        return 1
    fi

    local params=$(echo "$server_port_params" | grep -o '?.*' | sed 's|?||' | cut -d'#' -f1)
    local password="$userinfo"
    local sni=""
    local insecure="false"
    local security="none"
    local fp=""
    local pbk=""
    local sid=""
    local padding=""

    if [[ -n "$params" ]]; then
        IFS='&' read -ra param_pairs <<< "$params"
        for pair in "${param_pairs[@]}"; do
            key="${pair%%=*}"
            value="${pair#*=}"
            case "$key" in
                sni) sni="$value" ;;
                insecure) insecure="$value" ;;
                security) security="$value" ;;
                fp) fp="$value" ;;
                pbk) pbk="$value" ;;
                sid) sid="$value" ;;
                padding) padding="$value" ;;
            esac
        done
    fi

    # 转换为布尔值
    local insecure_bool="false"
    [[ "$insecure" == "1" || "$insecure" == "true" ]] && insecure_bool="true"

    # 构建 TLS 配置
    local tls_config=""
    if [[ "$security" == "reality" ]]; then
        if [[ -z "$pbk" ]]; then
            print_error "AnyTLS+REALITY 链接缺少公钥 (pbk)"
            return 1
        fi
        local utls_config=""
        if [[ -n "$fp" ]]; then
            utls_config=", \"utls\": {\"enabled\": true, \"fingerprint\": \"${fp}\"}"
        fi
        tls_config=",
  \"tls\": {
    \"enabled\": true,
    \"server_name\": \"${sni}\"${utls_config},
    \"min_version\": \"1.3\",
    \"reality\": {
      \"enabled\": true,
      \"public_key\": \"${pbk}\",
      \"short_id\": \"${sid}\"
    }
  }"
    else
        tls_config=",
  \"tls\": {
    \"enabled\": true,
    \"server_name\": \"${sni}\",
    \"alpn\": [\"h2\", \"http/1.1\"],
    \"min_version\": \"1.3\",
    \"insecure\": ${insecure_bool}
  }"
    fi

    # 构建 padding 配置
    local padding_config=""
    if [[ -n "$padding" ]]; then
        padding_config=",
  \"padding_scheme\": [${padding}]"
    fi

    local tag="relay-anytls-${#RELAY_TAGS[@]}"
    local relay_json="{
  \"type\": \"anytls\",
  \"tag\": \"${tag}\",
  \"server\": \"${server}\",
  \"server_port\": ${port},
  \"password\": \"${password}\"${padding_config}${tls_config}
}"

    local relay_desc
    if [[ -n "$custom_desc" ]]; then
        relay_desc="$custom_desc"
    else
        if [[ "$security" == "reality" ]]; then
            relay_desc="AnyTLS+REALITY ${server}:${port} (SNI: ${sni})"
        else
            relay_desc="AnyTLS ${server}:${port} (SNI: ${sni})"
        fi
    fi

    RELAY_TAGS+=("$tag")
    RELAY_JSONS+=("$relay_json")
    RELAY_DESCS+=("$relay_desc")

    save_relays_to_file
    print_success "AnyTLS 中转已添加: ${relay_desc}"
}

setup_relay() {
    # 加载中转配置和分流规则
    load_relays_from_file
    load_domain_routes_from_file
    
    while true; do
        echo ""
        menu_header "中转配置菜单"
        
        # 显示当前中转列表
        if [[ ${#RELAY_TAGS[@]} -gt 0 ]]; then
            echo -e "${YELLOW}当前中转列表:${NC}"
            for i in "${!RELAY_TAGS[@]}"; do
                idx=$((i+1))
                echo -e "  ${GREEN}[${idx}]${NC} ${RELAY_DESCS[$i]}"
            done
            echo ""
        else
            echo -e "${YELLOW}当前没有配置中转${NC}"
            echo ""
        fi
        
        echo -e "  ${GREEN}[1]${NC} 添加新的中转链接"
        echo -e "  ${GREEN}[2]${NC} 为节点配置中转"
        echo -e "  ${GREEN}[3]${NC} 删除中转链接"
        echo -e "  ${GREEN}[4]${NC} 域名分流配置"
        echo -e "  ${GREEN}[5]${NC} 修改中转链接"
        echo -e "  ${GREEN}[0]${NC} 返回主菜单"
        echo ""
        read -p "请选择 [0-5]: " r_choice
        
        case $r_choice in
            1)
                echo ""
                menu_header "支持的中转协议格式"
                echo -e "${GREEN}1. SOCKS5 代理${NC}"
                echo -e "   ${YELLOW}格式:${NC} socks5://[用户名:密码@]服务器:端口"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     socks5://user:pass@1.2.3.4:1080"
                echo -e "     socks5://1.2.3.4:1080 ${YELLOW}(无认证)${NC}"
                echo ""
                echo -e "${GREEN}2. HTTP/HTTPS 代理${NC}"
                echo -e "   ${YELLOW}格式:${NC} http(s)://[用户名:密码@]服务器:端口"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     http://user:pass@1.2.3.4:8080"
                echo -e "     https://1.2.3.4:443 ${YELLOW}(无认证)${NC}"
                echo ""
                echo -e "${GREEN}3. Shadowsocks${NC}"
                echo -e "   ${YELLOW}格式:${NC} ss://base64(加密方式:密码)@服务器:端口"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@1.2.3.4:8388"
                echo ""
                echo -e "${GREEN}4. VMess${NC}"
                echo -e "   ${YELLOW}格式:${NC} vmess://base64(JSON配置)"
                echo -e "   ${CYAN}说明:${NC} 标准 V2Ray 分享链接"
                echo ""
                echo -e "${GREEN}5. VLESS${NC}"
                echo -e "   ${YELLOW}格式:${NC} vless://UUID@服务器:端口?参数#备注"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     vless://uuid@1.2.3.4:443?security=tls&sni=example.com"
                echo -e "   ${YELLOW}支持参数:${NC} security, sni, flow, type 等"
                echo ""
                echo -e "${GREEN}6. Trojan${NC}"
                echo -e "   ${YELLOW}格式:${NC} trojan://密码@服务器:端口?参数#备注"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     trojan://password@1.2.3.4:443?sni=example.com"
                echo -e "   ${YELLOW}支持参数:${NC} sni, type, security 等"
                echo ""
                echo -e "${GREEN}7. Hysteria2${NC}"
                echo -e "   ${YELLOW}格式:${NC} hysteria2://密码@服务器:端口?参数"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     hysteria2://password@1.2.3.4:443?insecure=1&sni=example.com&obfs=salamander&obfs-password=xxx"
                echo ""
                echo -e "${GREEN}8. AnyTLS${NC}"
                echo -e "   ${YELLOW}格式:${NC} anytls://密码@服务器:端口?参数"
                echo -e "   ${CYAN}示例:${NC}"
                echo -e "     anytls://password@1.2.3.4:443?insecure=1&sni=example.com"
                echo ""
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}提示:${NC} 直接粘贴完整的节点分享链接即可，脚本会自动识别协议类型"
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                read -p "粘贴中转链接: " RELAY_LINK
                
                if [[ -z "$RELAY_LINK" ]]; then
                    print_warning "未提供链接，中转配置保持不变"
                else
                    echo ""
                    read -p "请输入此节点的描述信息 (如：香港-电信-1x 或 日本-软银-2x，留空则自动生成): " custom_desc
                    
                    if [[ "$RELAY_LINK" =~ ^socks ]]; then
                        parse_socks_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^https? ]]; then
                        parse_http_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^ss:// ]]; then
                        parse_ss_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^vmess:// ]]; then
                        parse_vmess_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^vless:// ]]; then
                        parse_vless_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^trojan:// ]]; then
                        parse_trojan_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^(hy2|hysteria2):// ]]; then
                        parse_hysteria2_link "$RELAY_LINK" "$custom_desc"
                    elif [[ "$RELAY_LINK" =~ ^anytls:// ]]; then
                        parse_anytls_link "$RELAY_LINK" "$custom_desc"
                    else
                        print_error "不支持的链接格式"
                    fi
                fi
                ;;
            2)
                if [[ ${#INBOUND_TAGS[@]} -eq 0 ]]; then
                    print_warning "当前尚未添加任何节点，请先添加节点"
                    continue
                fi
                
                if [[ ${#RELAY_TAGS[@]} -eq 0 ]]; then
                    print_warning "尚未添加任何中转链接，请先选择选项 [1] 添加中转"
                    continue
                fi
                
                # 选择节点
                echo ""
                echo -e "${CYAN}选择要配置中转的节点:${NC}"
                for i in "${!INBOUND_TAGS[@]}"; do
                    idx=$((i+1))
                    local relay_status="${INBOUND_RELAY_TAGS[$i]}"
                    local relay_desc="直连"
                    
                    if [[ "$relay_status" != "direct" ]]; then
                        # 查找中转描述
                        for j in "${!RELAY_TAGS[@]}"; do
                            if [[ "${RELAY_TAGS[$j]}" == "$relay_status" ]]; then
                                relay_desc="中转: ${RELAY_DESCS[$j]}"
                                break
                            fi
                        done
                    fi
                    
                    echo -e "  ${GREEN}[${idx}]${NC} ${INBOUND_PROTOS[$i]}:${INBOUND_PORTS[$i]} → ${YELLOW}${relay_desc}${NC}"
                done
                echo ""
                read -p "请输入节点序号 (输入 0 返回): " node_idx
                
                if [[ "$node_idx" == "0" ]]; then
                    continue
                fi
                
                if ! [[ "$node_idx" =~ ^[0-9]+$ ]] || (( node_idx < 1 || node_idx > ${#INBOUND_TAGS[@]} )); then
                    print_error "无效的节点序号"
                    continue
                fi
                
                local n=$((node_idx-1))
                
                # 选择中转
                echo ""
                echo -e "${CYAN}选择中转方式:${NC}"
                echo -e "  ${GREEN}[0]${NC} 直连 (不使用中转)"
                for i in "${!RELAY_TAGS[@]}"; do
                    idx=$((i+1))
                    echo -e "  ${GREEN}[${idx}]${NC} ${RELAY_DESCS[$i]}"
                done
                echo ""
                read -p "请选择: " relay_idx
                
                if [[ "$relay_idx" == "0" ]]; then
                    INBOUND_RELAY_TAGS[$n]="direct"
                    print_success "节点已设置为直连"
                elif [[ "$relay_idx" =~ ^[0-9]+$ ]] && (( relay_idx >= 1 && relay_idx <= ${#RELAY_TAGS[@]} )); then
                    local r=$((relay_idx-1))
                    INBOUND_RELAY_TAGS[$n]="${RELAY_TAGS[$r]}"
                    print_success "节点已设置为: ${RELAY_DESCS[$r]}"
                else
                    print_error "无效选择"
                    continue
                fi
                
                # 应用配置
                if [[ -n "$INBOUNDS_JSON" ]]; then
                    generate_config && start_svc
                fi
                ;;
            3)
                if [[ ${#RELAY_TAGS[@]} -eq 0 ]]; then
                    print_warning "当前没有中转链接"
                    continue
                fi
                
                echo ""
                echo -e "${CYAN}删除中转链接:${NC}"
                echo -e "  ${GREEN}[0]${NC} 删除全部中转"
                for i in "${!RELAY_TAGS[@]}"; do
                    idx=$((i+1))
                    echo -e "  ${GREEN}[${idx}]${NC} ${RELAY_DESCS[$i]}"
                done
                echo ""
                read -p "请选择要删除的中转 (输入 0 删除全部, 输入 -1 取消): " del_idx
                
                if [[ "$del_idx" == "-1" ]]; then
                    continue
                elif [[ "$del_idx" == "0" ]]; then
                    echo ""
                    if confirm "确认删除全部中转? (y/N): "; then
                        RELAY_TAGS=()
                        RELAY_JSONS=()
                        RELAY_DESCS=()
                        rm -f "${RELAY_FILE}"
                        
                        # 将所有节点设置为直连
                        for i in "${!INBOUND_RELAY_TAGS[@]}"; do
                            INBOUND_RELAY_TAGS[$i]="direct"
                        done
                        
                        # 同时删除所有相关的分流规则
                        DOMAIN_ROUTES=()
                        rm -f "${DOMAIN_ROUTE_FILE}"
                        
                        print_success "已删除全部中转配置和相关分流规则"
                        
                        # 重新生成配置
                        if [[ -n "$INBOUNDS_JSON" ]]; then
                            generate_config && start_svc
                        fi
                    fi
                elif [[ "$del_idx" =~ ^[0-9]+$ ]] && (( del_idx >= 1 && del_idx <= ${#RELAY_TAGS[@]} )); then
                    local d=$((del_idx-1))
                    local del_tag="${RELAY_TAGS[$d]}"
                    local del_desc="${RELAY_DESCS[$d]}"
                    echo ""
                    if confirm "确认删除中转: ${del_desc}? (y/N): "; then
                        # 删除中转
                        unset RELAY_TAGS[$d]
                        unset RELAY_JSONS[$d]
                        unset RELAY_DESCS[$d]
                        
                        # 重建数组
                        RELAY_TAGS=("${RELAY_TAGS[@]}")
                        RELAY_JSONS=("${RELAY_JSONS[@]}")
                        RELAY_DESCS=("${RELAY_DESCS[@]}")
                        
                        # 将使用该中转的节点改为直连
                        for i in "${!INBOUND_RELAY_TAGS[@]}"; do
                            if [[ "${INBOUND_RELAY_TAGS[$i]}" == "$del_tag" ]]; then
                                INBOUND_RELAY_TAGS[$i]="direct"
                            fi
                        done
                        
                        # 同时删除所有相关的分流规则
                        local new_routes=()
                        for route in "${DOMAIN_ROUTES[@]}"; do
                            IFS='|' read -r in_tag match_type match_val relay_tag desc <<< "$route"
                            if [[ "$relay_tag" != "$del_tag" ]]; then
                                new_routes+=("$route")
                            fi
                        done
                        DOMAIN_ROUTES=("${new_routes[@]}")
                        save_domain_routes_to_file
                        
                        save_relays_to_file
                        print_success "已删除中转: ${del_desc}"
                        
                        # 重新生成配置
                        if [[ -n "$INBOUNDS_JSON" ]]; then
                            generate_config && start_svc
                        fi
                    fi
                else
                    print_error "无效选择"
                fi
                ;;
            4)
                domain_route_menu
                ;;
            5)
                if [[ ${#RELAY_TAGS[@]} -eq 0 ]]; then
                    print_warning "当前没有中转链接"
                    continue
                fi
                
                echo ""
                echo -e "${CYAN}修改中转链接:${NC}"
                for i in "${!RELAY_TAGS[@]}"; do
                    idx=$((i+1))
                    echo -e "  ${GREEN}[${idx}]${NC} ${RELAY_DESCS[$i]}"
                done
                echo ""
                read -p "请选择要修改的中转 (输入 -1 取消): " edit_idx
                
                if [[ "$edit_idx" == "-1" ]]; then
                    continue
                fi
                
                if ! [[ "$edit_idx" =~ ^[0-9]+$ ]] || (( edit_idx < 1 || edit_idx > ${#RELAY_TAGS[@]} )); then
                    print_error "无效选择"
                    continue
                fi
                
                local e=$((edit_idx-1))
                local old_tag="${RELAY_TAGS[$e]}"
                local old_desc="${RELAY_DESCS[$e]}"
                
                echo ""
                echo -e "${YELLOW}当前中转: ${old_desc}${NC}"
                echo -e "${CYAN}请输入新的中转链接 (保留原tag，分流和中转配置不受影响):${NC}"
                echo ""
                read -p "粘贴新的中转链接: " NEW_RELAY_LINK
                
                if [[ -z "$NEW_RELAY_LINK" ]]; then
                    print_warning "未提供链接，修改取消"
                    continue
                fi
                
                echo ""
                read -p "请输入新的描述信息 (留空则自动生成): " new_custom_desc
                
                # 临时保存当前数组状态（解析失败时恢复）
                local saved_tags=("${RELAY_TAGS[@]}")
                local saved_jsons=("${RELAY_JSONS[@]}")
                local saved_descs=("${RELAY_DESCS[@]}")
                
                # 临时清空数组，解析新链接以获取JSON结构
                local tmp_tags=("${RELAY_TAGS[@]}")
                local tmp_jsons=("${RELAY_JSONS[@]}")
                local tmp_descs=("${RELAY_DESCS[@]}")
                RELAY_TAGS=()
                RELAY_JSONS=()
                RELAY_DESCS=()
                
                # 解析新链接
                local parse_ok=0
                if [[ "$NEW_RELAY_LINK" =~ ^socks ]]; then
                    parse_socks_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^https? ]]; then
                    parse_http_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^ss:// ]]; then
                    parse_ss_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^vmess:// ]]; then
                    parse_vmess_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^vless:// ]]; then
                    parse_vless_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^trojan:// ]]; then
                    parse_trojan_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^(hy2|hysteria2):// ]]; then
                    parse_hysteria2_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                elif [[ "$NEW_RELAY_LINK" =~ ^anytls:// ]]; then
                    parse_anytls_link "$NEW_RELAY_LINK" "$new_custom_desc" && parse_ok=1
                else
                    print_error "不支持的链接格式"
                fi
                
                if [[ $parse_ok -eq 1 ]]; then
                    # 从解析结果中提取新JSON和新描述
                    local new_json="${RELAY_JSONS[0]}"
                    local new_desc="${RELAY_DESCS[0]}"
                    
                    # 将新JSON中的tag替换为原tag
                    local new_tag="${RELAY_TAGS[0]}"
                    new_json=$(echo "$new_json" | sed "s/\"${new_tag}\"/\"${old_tag}\"/g")
                    
                    # 恢复原数组，替换指定位置
                    RELAY_TAGS=("${tmp_tags[@]}")
                    RELAY_JSONS=("${tmp_jsons[@]}")
                    RELAY_DESCS=("${tmp_descs[@]}")
                    
                    RELAY_JSONS[$e]="$new_json"
                    RELAY_DESCS[$e]="$new_desc"
                    
                    save_relays_to_file
                    print_success "中转已修改: ${old_desc} → ${new_desc}"
                    
                    # 重新生成配置
                    if [[ -n "$INBOUNDS_JSON" ]]; then
                        generate_config && start_svc
                    fi
                else
                    # 解析失败，恢复原数组
                    RELAY_TAGS=("${saved_tags[@]}")
                    RELAY_JSONS=("${saved_jsons[@]}")
                    RELAY_DESCS=("${saved_descs[@]}")
                    print_error "新链接解析失败，中转配置未修改"
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
