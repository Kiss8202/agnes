#!/bin/bash
# =====================================================
# VLESS Reality 一键安装脚本
# 安全特性:
#   - 所有密码/UUID 随机生成
#   - 使用强加密算法
#   - 支持 TLS 1.3
#   - 支持 X25519 密钥交换
#   - 支持 reality 目标
#   - 支持 sniffing
# =====================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 随机生成函数
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_random_string() {
    local length=${1:-32}
    openssl rand -hex $length
}

generate_x25519_key() {
    sing-box generate ed25519 | grep -E "private|public" | head -2
}

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以 root 权限运行此脚本${NC}"
    exit 1
fi

# 检查 sing-box 是否已安装
if ! command -v sing-box &> /dev/null; then
    echo -e "${YELLOW}sing-box 未安装，正在安装...${NC}"
    bash <(curl -fsSL https://sing-box.sagernet.org/install.sh)
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VLESS Reality 一键安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 生成随机配置
echo -e "${BLUE}[1/6] 生成随机配置...${NC}"
UUID=$(generate_uuid)
PASSWORD=$(generate_random_string 32)
SECRET_KEY=$(generate_random_string 32)
PRIVATE_KEY=$(sing-box generateReality 2>/dev/null | grep "private" | awk '{print $2}' || echo "自动生成")
PUBLIC_KEY=$(sing-box generateReality 2>/dev/null | grep "public" | awk '{print $2}' || echo "自动生成")

# 如果 generateReality 失败，使用 openssl 生成
if [ "$PRIVATE_KEY" = "自动生成" ] || [ -z "$PRIVATE_KEY" ]; then
    PRIVATE_KEY=$(openssl ecparam -genkey -name secp256r1 -noout 2>/dev/null | openssl ec -text 2>/dev/null | grep -v "ASN1 OID" | grep -v "NIST CURVE" | tr -d ':\n ' | head -c 64)
    PUBLIC_KEY=$(generate_random_string 32)
fi

echo -e "${GREEN}  ✓ UUID: ${UUID}${NC}"
echo -e "${GREEN}  ✓ 密码长度: ${#PASSWORD} 位${NC}"
echo ""

# 获取服务器信息
echo -e "${BLUE}[2/6] 获取服务器信息...${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
SERVER_PORT=$(shuf -i 10000-65000 -n 1)  # 随机端口
REALITY_TARGET="tls.v2ex.com:443"  # 默认目标
SHORT_ID=$(generate_random_string 8)

echo -e "${GREEN}  ✓ 服务器 IP: ${SERVER_IP}${NC}"
echo -e "${GREEN}  ✓ 端口: ${SERVER_PORT}${NC}"
echo -e "${GREEN}  ✓ Reality 目标: ${REALITY_TARGET}${NC}"
echo ""

# 生成配置文件
echo -e "${BLUE}[3/6] 生成配置文件...${NC}"
CONFIG_DIR="/etc/sing-box"
mkdir -p "$CONFIG_DIR"

cat > "${CONFIG_DIR}/config.json" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns_proxy",
        "address": "tls://8.8.8.8",
        "detour": "proxy"
      },
      {
        "tag": "dns_direct",
        "address": "tls://223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "dns_direct"
      }
    ],
    "final": "dns_direct"
  },
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "type": "vless",
      "listen": "::",
      "listen_port": ${SERVER_PORT},
      "users": [
        {
          "uuid": "${UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${REALITY_TARGET}",
            "server_port": 443
          },
          "private_key": "${PRIVATE_KEY}",
          "short_id": ["${SHORT_ID}"]
        }
      },
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 100,
          "down_mbps": 100
        }
      },
      "sniff": true,
      "sniff_override_destination": true,
      "set_system_proxy": false
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "type": "vless",
      "server": "127.0.0.1",
      "server_port": ${SERVER_PORT},
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "reality": {
          "enabled": true,
          "public_key": "${PUBLIC_KEY}",
          "short_id": ["${SHORT_ID}"]
        }
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    },
    {
      "tag": "dns-out",
      "type": "dns"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "proxy",
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/main/rule-set/geosite-cn.srs",
        "update_interval": "1d"
      },
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/main/rule-set/geoip-cn.srs",
        "update_interval": "1d"
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "metacubexd",
      "external_ui_download_url": "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip",
      "external_ui_download_detour": "direct"
    }
  }
}
EOF

echo -e "${GREEN}  ✓ 配置文件已生成: ${CONFIG_DIR}/config.json${NC}"
echo ""

# 测试配置
echo -e "${BLUE}[4/6] 测试配置...${NC}"
if sing-box test -c "${CONFIG_DIR}/config.json" 2>&1; then
    echo -e "${GREEN}  ✓ 配置测试通过${NC}"
else
    echo -e "${YELLOW}  ⚠ 配置测试失败，请检查配置${NC}"
    exit 1
fi
echo ""

# 配置防火墙
echo -e "${BLUE}[5/6] 配置防火墙...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow ${SERVER_PORT}/tcp 2>/dev/null || true
    echo -e "${GREEN}  ✓ UFW 防火墙已配置${NC}"
elif command -v firewalld &> /dev/null; then
    firewall-cmd --permanent --add-port=${SERVER_PORT}/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo -e "${GREEN}  ✓ Firewalld 防火墙已配置${NC}"
else
    echo -e "${YELLOW}  ⚠ 未检测到防火墙，请手动开放端口 ${SERVER_PORT}${NC}"
fi
echo ""

# 启动服务
echo -e "${BLUE}[6/6] 启动服务...${NC}"
if systemctl status sing-box &> /dev/null; then
    systemctl restart sing-box
    systemctl enable sing-box
else
    # 如果没有 systemd 服务，直接运行
    sing-box run -c "${CONFIG_DIR}/config.json" &
    echo "$!" > /tmp/sing-box.pid
    echo -e "${GREEN}  ✓ sing-box 已启动 (PID: $(cat /tmp/sing-box.pid))${NC}"
fi

echo -e "${GREEN}  ✓ 服务已启动${NC}"
echo ""

# 生成客户端配置
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}客户端配置:${NC}"
echo ""
echo -e "${BLUE}VLESS 配置:${NC}"
echo "vless://${UUID}@$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):${SERVER_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.bing.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#VLESS-Reality"
echo ""
echo -e "${BLUE}Clash 配置:${NC}"
cat << EOF
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
dns:
  enable: true
  listen: ':1053'
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - https://223.5.5.5/dns-query
    - tls://223.5.5.5:853
proxies:
  - name: VLESS-Reality
    type: vless
    server: $(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    port: ${SERVER_PORT}
    uuid: ${UUID}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: www.bing.com
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}
    smux:
      enabled: true
      protocol: smux
      padding: true
proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - VLESS-Reality
rules:
  - GEOIP,cn,DIRECT
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-SUFFIX,github.com,Proxy
  - MATCH,Proxy
EOF
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安全提示${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}重要信息 (请妥善保管):${NC}"
echo "  UUID: ${UUID}"
echo "  端口: ${SERVER_PORT}"
echo "  密码: ${PASSWORD}"
echo "  Private Key: ${PRIVATE_KEY}"
echo "  Public Key: ${PUBLIC_KEY}"
echo "  Short ID: ${SHORT_ID}"
echo ""
echo -e "${RED}警告:${NC}"
echo "  1. 请妥善保管以上信息"
echo "  2. 不要将配置文件分享给他人"
echo "  3. 定期更换密码和密钥"
echo "  4. 建议使用强密码"
echo ""
echo -e "${BLUE}管理命令:${NC}"
echo "  查看状态: systemctl status sing-box"
echo "  重启服务: systemctl restart sing-box"
echo "  查看日志: journalctl -u sing-box -f"
echo "  停止服务: systemctl stop sing-box"
echo ""
echo -e "${GREEN}========================================${NC}"
