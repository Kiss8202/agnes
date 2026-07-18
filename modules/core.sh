# ==================== sing-box 管理脚本模块 ====================
# 模块版本号，用于检查模块是否需要更新
MODULE_VERSION="1.13"

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ==================== 路径配置 ====================
CONFIG_FILE="/etc/sing-box/config.json"
INSTALL_DIR="/usr/local/bin"
CERT_DIR="/etc/sing-box/certs"
LINK_DIR="/etc/sing-box/links"
KEY_FILE="/etc/sing-box/keys.txt"
DNS_CONFIG_FILE="/etc/sing-box/dns.conf"

# 链接文件路径
ALL_LINKS_FILE="${LINK_DIR}/all.txt"
REALITY_LINKS_FILE="${LINK_DIR}/reality.txt"
HYSTERIA2_LINKS_FILE="${LINK_DIR}/hysteria2.txt"
SOCKS5_LINKS_FILE="${LINK_DIR}/socks5.txt"
SHADOWTLS_LINKS_FILE="${LINK_DIR}/shadowtls.txt"
HTTPS_LINKS_FILE="${LINK_DIR}/https.txt"
ANYTLS_LINKS_FILE="${LINK_DIR}/anytls.txt"

# 脚本路径
SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")

# ==================== 全局变量 ====================
INBOUNDS_JSON=""
ALL_LINKS_TEXT=""
SERVER_IP=""
REALITY_LINKS=""
HYSTERIA2_LINKS=""
SOCKS5_LINKS=""
SHADOWTLS_LINKS=""
HTTPS_LINKS=""
ANYTLS_LINKS=""

# IP 配置
SERVER_IPV6=""
INBOUND_IP_MODE="dual"   # ipv4, ipv6 或 dual，控制入站监听地址（默认双栈）
OUTBOUND_IP_MODE="dual"  # ipv4, ipv6, ipv6_only 或 dual，控制出站连接（默认双栈）
IP_CONFIG_FILE="/etc/sing-box/ip_config.conf"

# 中转配置数组
RELAY_TAGS=()        # 中转标签数组
RELAY_JSONS=()       # 中转JSON配置数组
RELAY_DESCS=()       # 中转描述数组
RELAY_FILE="/etc/sing-box/relays.conf"

# 分流规则配置
DOMAIN_ROUTES=()     # 分流规则数组: 入站标签|匹配类型|匹配值|中转标签|描述
DOMAIN_ROUTE_FILE="/etc/sing-box/domain_routes.conf"

# DNS 分流配置
DNS_SERVERS=()       # 自定义 DNS 服务器数组: TAG|TYPE|SERVER|DESCRIPTION
DNS_ROUTES=()        # DNS 分流规则数组: MATCH_TYPE|MATCH_VALUE|DNS_TAG|DESCRIPTION
DNS_SERVERS_FILE="/etc/sing-box/dns_servers.conf"
DNS_ROUTES_FILE="/etc/sing-box/dns_routes.conf"

# 节点数组
INBOUND_TAGS=()
INBOUND_PORTS=()
INBOUND_PROTOS=()
INBOUND_RELAY_TAGS=()  # 存储每个节点使用的中转标签，"direct" 表示直连
INBOUND_SNIS=()

# 密钥变量
UUID=""
REALITY_PRIVATE=""
REALITY_PUBLIC=""
SHORT_ID=""
HY2_PASSWORD=""
SS_PASSWORD=""
SHADOWTLS_PASSWORD=""
ANYTLS_PASSWORD=""
SOCKS_USER=""
SOCKS_PASS=""

# 默认SNI
DEFAULT_SNI="www.notion.so"
DEFAULT_SNI1="www.notion.so,www.atlassian.com"

# Alpine 标记
ALPINE=0

# 临时文件清理
TEMP_FILES=()
cleanup_temp_files() {
    for f in "${TEMP_FILES[@]}"; do
        rm -rf "$f" 2>/dev/null
    done
}
# 防止重复 source 时覆盖 trap
if [[ -z "${TRAP_SET:-}" ]]; then
    trap cleanup_temp_files EXIT INT TERM
    TRAP_SET=1
fi

# ==================== jq 配置文件原子更新 ====================
# 用法: jq_update_config <jq参数...>
# 功能: 原子性更新配置文件，先写临时文件再替换，失败时保留原文件
jq_update_config() {
    local tmp_file
    tmp_file=$(mktemp) || { print_error "创建临时文件失败" >&2; return 1; }
    if jq "$@" "${CONFIG_FILE}" > "$tmp_file" && [[ -s "$tmp_file" ]]; then
        mv "$tmp_file" "${CONFIG_FILE}"
        return 0
    else
        rm -f "$tmp_file"
        print_error "配置修改失败" >&2
        return 1
    fi
}

# ==================== 输入验证与安全 ====================
# 验证 SNI 域名格式
validate_sni() {
    local sni="$1"
    if [[ -z "$sni" ]]; then
        return 0  # 空值由调用方处理
    fi
    # SNI 只允许域名格式（字母数字点连字符）
    if [[ ! "$sni" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        print_error "SNI 格式无效: ${sni}（仅允许域名格式）"
        return 1
    fi
    return 0
}

# JSON 字符串转义（防止用户输入破坏 JSON 结构）
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"   # 反斜杠
    str="${str//\"/\\\"}"   # 双引号
    str="${str//$'\n'/\\n}" # 换行
    str="${str//$'\r'/\\r}" # 回车
    str="${str//$'\t'/\\t}" # 制表符
    echo -n "$str"
}

# 验证端口号
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        return 1
    fi
    return 0
}

# ==================== 交互辅助函数 ====================
# 暂停等待用户按回车
pause() {
    local msg="${1:-按回车继续...}"
    read -p "$msg" _
}

# 确认操作 (y/N)，返回 0=确认, 1=取消
confirm() {
    local prompt="${1:-确认? (y/N): }"
    local ans
    read -p "$prompt" ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# 显示菜单标题分隔线
menu_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  ${title}${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 按协议分组显示节点链接
show_protocol_links() {
    local proto="$1"
    local links="$2"
    local color="$3"

    if [[ -z "$links" ]]; then
        return 0
    fi

    echo -e "${color}【${proto}】${NC}"
    echo -e "$links"
    echo ""
}

# 统一追加节点链接（自动追加 #协议-IP 后缀）
# 用法: add_node_links <link_template> <proto> <ip> <port> [sni]
# link_template 中的 __IP__ 会被替换为实际 IP
add_node_links() {
    local template="$1"
    local proto="$2"
    local ip="$3"
    local port="$4"

    # 替换 __IP__ 占位符
    local link="${template//__IP__/$ip}"
    # 追加协议-IP 后缀
    link="${link}#${proto}-${ip}"

    add_link "$link" "$proto" "" "$ip" "$port" ""
}

# 生成 ShadowTLS 客户端配置文件
# 用法: generate_shadowtls_client_config <output_file> <server> <port> <sni> <stls_password> <ss_method> <ss_password>
generate_shadowtls_client_config() {
    local output_file="$1"
    local server="$2"
    local port="$3"
    local sni="$4"
    local stls_password="$5"
    local ss_method="$6"
    local ss_password="$7"

    cat > "${output_file}" << EOFCLIENT
{
  "log": {"level": "info"},
  "dns": {"servers": [{"tag": "google", "type": "udp", "server": "8.8.8.8"}]},
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": ["ShadowTLS-${port}"],
      "default": "ShadowTLS-${port}"
    },
    {
      "type": "shadowsocks",
      "tag": "ShadowTLS-${port}",
      "method": "${ss_method}",
      "password": "${ss_password}",
      "detour": "shadowtls-out-${port}"
    },
    {
      "type": "shadowtls",
      "tag": "shadowtls-out-${port}",
      "server": "${server}",
      "server_port": ${port},
      "version": 3,
      "password": "${stls_password}",
      "tls": {
        "enabled": true,
        "server_name": "${sni}",
        "min_version": "1.3",
        "utls": {"enabled": true, "fingerprint": "chrome"}
      }
    },
    {"type": "direct", "tag": "direct"}
  ],
  "route": {
    "rules": [
      {"action":"sniff","sniffer":["http","tls","quic"]},
      {"geosite": "cn", "outbound": "direct"},
      {"geoip": "cn", "outbound": "direct"}
    ],
    "final": "proxy"
  }
}
EOFCLIENT
}

# ==================== 修改端口封装 ====================
# 用法: modify_port <old_tag> <new_tag_prefix> <new_port> [extra_jq_update]
# 自动更新 inbound tag/port 和 route rules 中的引用
modify_port() {
    local old_tag="$1"
    local new_tag_prefix="$2"
    local new_port="$3"
    local new_tag="${new_tag_prefix}${new_port}"

    jq_update_config --arg old_tag "$old_tag" --arg new_tag "$new_tag" --argjson new_port "$new_port" \
        '(.inbounds[] | select(.tag == $old_tag)) |= (.tag = $new_tag | .listen_port = $new_port)'

    if jq -e '.route.rules' "${CONFIG_FILE}" >/dev/null 2>&1; then
        jq_update_config --arg old_tag "$old_tag" --arg new_tag "$new_tag" \
            '(.route.rules[] | select(.inbound[]? == $old_tag)) |= (.inbound = [.inbound[] | if . == $old_tag then $new_tag else . end])'
    fi

    echo "$new_tag"
}

# ==================== 重新生成密钥/密码封装 ====================
# 用法: regenerate_secret <type> <tag> [extra_arg]
# type: uuid | password | sid | obfs_password | ss_password | stls_password | socks_user
regenerate_secret() {
    local type="$1"
    local tag="$2"
    local new_value=""

    case "$type" in
        uuid)
            new_value=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
            if [[ -z "$new_value" ]]; then
                print_error "UUID 生成失败"; return 1
            fi
            jq_update_config --arg tag "$tag" --arg uuid "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.users[0].uuid = $uuid)'
            print_success "UUID 已重新生成: ${new_value}"
            ;;
        password)
            new_value=$(openssl rand -hex 16)
            jq_update_config --arg tag "$tag" --arg password "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.users[0].password = $password)'
            print_success "密码已重新生成: ${new_value}"
            ;;
        sid)
            new_value=$(openssl rand -hex 8)
            jq_update_config --arg tag "$tag" --arg sid "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.tls.reality.short_id = [$sid])'
            print_success "Short ID 已重新生成: ${new_value}"
            ;;
        obfs_password)
            new_value=$(openssl rand -hex 16)
            jq_update_config --arg tag "$tag" --arg password "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.obfs.password = $password)'
            print_success "混淆密码已重新生成: ${new_value}"
            ;;
        ss_password)
            new_value=$(openssl rand -base64 16)
            jq_update_config --arg tag "$tag" --arg password "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.password = $password)'
            print_success "SS 密码已重新生成: ${new_value}"
            ;;
        stls_password)
            new_value=$(openssl rand -hex 16)
            jq_update_config --arg tag "$tag" --arg password "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.users[0].password = $password)'
            print_success "ShadowTLS 密码已重新生成: ${new_value}"
            ;;
        socks_password)
            new_value=$(openssl rand -hex 16)
            jq_update_config --arg tag "$tag" --arg password "$new_value" \
                '(.inbounds[] | select(.tag == $tag)) |= (.users[0].password = $password)'
            print_success "密码已重新生成: ${new_value}"
            ;;
        *)
            print_error "未知的密钥类型: $type"; return 1
            ;;
    esac
    return 0
}

# ==================== 打印函数 ====================
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

show_banner() {
    clear
    echo ""
}
# ==================== 系统检测 ====================
detect_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="${NAME}"
        # 标记是否为 Alpine
        if [[ "$ID" == "alpine" ]]; then
            ALPINE=1
        else
            ALPINE=0
        fi
    else
        print_error "无法检测系统"
        exit 1
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        *)
            print_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    
    print_success "系统: ${OS} (${ARCH})"
}
# ==================== sing-box 版本检测 ====================
# 全局版本标志
SB_GE_1_11=0
SB_GE_1_12=0
SB_GE_1_13=0
SB_GE_1_14=0

detect_singbox_version() {
    SB_GE_1_11=0
    SB_GE_1_12=0
    SB_GE_1_13=0
    SB_GE_1_14=0

    if ! [[ -x "${INSTALL_DIR}/sing-box" ]]; then
        return 0
    fi

    local version=$(${INSTALL_DIR}/sing-box version 2>/dev/null | awk '/sing-box version/{print $3}' || echo "0.0.0")
    if [[ -z "$version" || "$version" == "0.0.0" ]]; then
        return 0
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    major=$((10#${major:-0}))
    minor=$((10#${minor:-0}))

    # 设置版本标志
    if [[ $major -gt 1 ]] || [[ $major -eq 1 && $minor -ge 14 ]]; then
        SB_GE_1_14=1
        SB_GE_1_13=1
        SB_GE_1_12=1
        SB_GE_1_11=1
    elif [[ $major -eq 1 && $minor -ge 13 ]]; then
        SB_GE_1_13=1
        SB_GE_1_12=1
        SB_GE_1_11=1
    elif [[ $major -eq 1 && $minor -ge 12 ]]; then
        SB_GE_1_12=1
        SB_GE_1_11=1
    elif [[ $major -eq 1 && $minor -ge 11 ]]; then
        SB_GE_1_11=1
    fi

    print_info "sing-box 版本: ${version} (1.11:${SB_GE_1_11} 1.12:${SB_GE_1_12} 1.13:${SB_GE_1_13} 1.14:${SB_GE_1_14})"
}
# ==================== 服务控制（兼容 systemd / OpenRC） ====================
svc_start() {
    if [[ $ALPINE -eq 1 ]]; then
        rc-service sing-box start 2>/dev/null
    else
        systemctl start sing-box
    fi
}

svc_stop() {
    if [[ $ALPINE -eq 1 ]]; then
        rc-service sing-box stop 2>/dev/null
    else
        systemctl stop sing-box
    fi
}

svc_restart() {
    if [[ $ALPINE -eq 1 ]]; then
        rc-service sing-box restart 2>/dev/null
    else
        systemctl restart sing-box
    fi
}

svc_enable() {
    if [[ $ALPINE -eq 1 ]]; then
        rc-update add sing-box default >/dev/null 2>&1
    else
        systemctl enable sing-box >/dev/null 2>&1
    fi
}

svc_disable() {
    if [[ $ALPINE -eq 1 ]]; then
        rc-update del sing-box default >/dev/null 2>&1
    else
        systemctl disable sing-box >/dev/null 2>&1
    fi
}

svc_is_active() {
    if [[ $ALPINE -eq 1 ]]; then
        rc-service sing-box status 2>/dev/null | grep -q 'started'
    else
        systemctl is-active --quiet sing-box
    fi
}
# ==================== 日志自动清理配置（首次安装时生效） ====================
LOGROTATE_FLAG="/etc/sing-box/.logrotate_setup"

setup_log_cleanup() {
    [[ -f "${LOGROTATE_FLAG}" ]] && return 0

    print_info "配置日志自动清理（7天 / 100M）..."

    if [[ $ALPINE -eq 1 ]]; then
        # 安装 logrotate 和 dcron，打印错误以便排错
        apk add --no-cache logrotate dcron || {
            print_error "安装 logrotate/dcron 失败，请检查网络或 apk 源"
            return 1
        }

        # 创建 logrotate 配置
        cat > /etc/logrotate.d/sing-box << 'EOF'
/var/log/sing-box.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    maxsize 100M
}
EOF

        # 确保 dcron 在默认运行级别并启动
        rc-update add dcron default 2>/dev/null
        rc-service dcron start 2>/dev/null

        # 等待服务启动，然后检查状态
        sleep 1
        if ! rc-service dcron status | grep -q started; then
            print_error "dcron 服务启动失败，请手动检查"
            return 1
        fi

        print_success "Alpine 日志清理已配置（logrotate + dcron）"
    else
        mkdir -p /etc/systemd/journald.conf.d
        cat > /etc/systemd/journald.conf.d/sing-box-log.conf << 'EOF'
[Journal]
SystemMaxUse=100M
MaxRetentionSec=7day
EOF
        systemctl restart systemd-journald
        print_success "systemd journald 日志限制已生效"
    fi

    # 仅在全部成功后创建标记文件
    mkdir -p "$(dirname "${LOGROTATE_FLAG}")"
    touch "${LOGROTATE_FLAG}"
}
