# 四大 sing-box 安装脚本对比学习 (2026-07-26)

## 1. fscarmen/sing-box (6115行) - **目前最强大**

### 配置生成模式：Directory merge (`sing-box run -C conf_dir/`)
- 将配置拆分为多个 JSON 片段，放在 `/etc/sing-box/conf/` 下
- `01_outbounds.json` - 出站（direct + warp-ep）
- `02_endpoints.json` - endpoint（wireguard warp）
- `03_route.json` - 路由规则（含 SRS 远程规则集）
- `04_experimental.json` - 缓存文件
- `05_dns.json` - DNS 配置
- `06_ntp.json` - NTP
- `07_http_clients.json` - HTTP 客户端
- 每个协议一个 inbounds 文件: `11_xtls-reality`, `12_hysteria2`, `13_tuic`, `14_ShadowTLS`, `15_shadowsocks`, `16_trojan`, `17_vmess-ws`, `18_vless-ws-tls`, `19_h2-reality`, `20_grpc-reality`, `21_anytls`, `22_naive`
- 支持 SIGHUP 热更、bind_interface 绑定网卡
- 内建 Cloudflare Turnstile CAPTCHA 验证
- 支持 WARP 出站、自定义路由
- CDN 域名选择丰富

## 2. v2ray-agent/mack-a (10099行) - **最全面但更复杂**

### 配置生成模式：sing-box merge 命令 (`sing-box merge config.json -C dir/ -D dest/`)
- 单文件配置 `/conf/config.json`，从 `/conf/config/` 目录合并片段
- 同时支持 Xray 和 sing-box 双内核
- 配置文件按协议命名: `02_VLESS_TCP_inbounds.json`, `06_hysteria2_inbounds.json`, etc.
- 支持 hysteria1/hysteria2/v2ray/xray/sing-box 全家族
- 大量 Clash API 集成
- 配置文件合并时自动处理 JSON 格式

## 3. 233boy/sing-box - **轻量模块化**

### 配置结构：src/ 模块化管理
- 主脚本仅 5 行，功能全部在 src/ 目录下
- src/ 包含: init.sh, core.sh, download.sh, help.sh, log.sh, systemd.sh, bbr.sh, caddy.sh, dns.sh, import.sh
- 安装路径: `/etc/sing-box/bin/sing-box`, 配置: `-C /etc/sing-box/conf`
- 最简洁的分层设计思想值得学习

## 4. Devmiston/sing-box - **中等复杂度**

### 配置生成模式：直接 sed/awk 操作 JSON 文件
- 安装路径: `/usr/local/etc/sing-box/config.json`
- 用 sed/awk 直接修改单文件 JSON
- 相对简单的实现方式

## 关键发现

### 1. sing-box 有两种配置合并方式
```bash
# 方式A: 启动时自动合并目录下所有 JSON（fscarmen, 233boy）
sing-box run -C /etc/sing-box/conf/

# 方式B: 手动合并（v2ray-agent）
sing-box merge config.json -C /etc/v2ray-agent/sing-box/conf/config/ -D /etc/v2ray-agent/sing-box/conf/
```

### 2. 主流做法都是多文件拆分模式
比单文件更容易维护，每个协议独立文件

### 3. DNS 配置通用模式
```json
{
  "dns": {
    "servers": [
      {"type": "local", "tag": "local"},
      {"type": "https", "server": "1.1.1.1", "port": 443, "tag": "dns-proxy"},
      {"type": "udp", "server": "114.114.114.114", "tag": "dns-direct"}
    ],
    "rules": [
      {"clash_mode": "direct", "server": "dns-direct"},
      {"clash_mode": "global", "server": "dns-proxy"},
      {"rule_set": ["geosite-cn"], "server": "dns-direct"}
    ],
    "strategy": "prefer_ipv4"
  }
}
```

### 4. 路由规则模板化
- Rule set (SRS remote) 是最佳实践
- 支持 geosite/geoip 自动更新
- Sniff + auto-route 流程

### 5. Reality 密钥生成
- 需要处理 base64url 到 DER 的转换
- 注意 padding 和 PKCS8 header
- `sing-box generate reality-keypair` 可以自动生成

### 6. Warp 出站配置
- wireguard endpoint 已是标配
- Cloudflare WARP 服务器和 public key 固定
- 支持 custom endpoint（防封锁）

### 7. 订阅功能
- 通常通过 Nginx/Caddy 提供
- 返回 clash meta yaml 或 sing-box json 格式
- 支持 Base64 编码

### 8. Common patterns learned

#### a) Protocol detection & installation
- Check OS first, use different package managers
- Support multiple distros (Debian/Ubuntu/CentOS/Alpine/Fedora/Arch/Rocky)

#### b) JSON generation with heredoc
```bash
cat > ${WORK_DIR}/conf/XX_protocol_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
            "tag":"...",
            "listen":"::",
            "listen_port":PORT,
            ...
        }
    ]
}
EOF
```

#### c) Config validation
- Use `sing-box check -c config.json` to validate
- Fallback to manual sed fixes if needed

#### d) Service management
- Detect systemd vs openrc
- Generate appropriate service files
- SIGHUP for hot reload
