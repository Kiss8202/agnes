# Sing-box 源代码学习 - 核心知识

## 1. 项目概览

sing-box 是一个用 Go 编写的 universal proxy platform，由 SagerNet 维护（作者 nekohasekai）。
- **语言**: Go (97.5%) + Shell (1.3%)
- **仓库**: https://github.com/SagerNet/sing-box
- **当前最新稳定版**: v1.13.14 (Jun 2026)
- **License**: GPL-3.0

## 2. 源码目录结构（从官方仓库 testing 分支）

```
sing-box/
├── box.go                  # 核心启动入口（sing-box 实例生命周期）
├── cmd/sing-box/           # CLI 入口（main, check, format, merge, schema 等命令）
├── adapter/                # 适配器层
│   ├── inbound/            # Inbound 注册和实现
│   ├── outbound/           # Outbound 注册和实现
│   ├── endpoint/           # Endpoint 适配
│   ├── certificate/        # 证书管理
│   └── service/            # 服务适配
├── protocol/               # 协议实现（核心）
│   ├── vmess/              # VMess 协议
│   ├── vless/              # VLESS 协议
│   ├── shadowsocks/        # Shadowsocks 协议
│   ├── trojan/             # Trojan 协议
│   ├── hysteria/           # Hysteria 协议
│   ├── hysteria2/          # Hysteria2 协议
│   ├── tuic/               # TUIC 协议
│   ├── snell/              # Snell 协议
│   ├── naive/              # NaiveProxy
│   ├── socks/              # SOCKS
│   ├── http/               # HTTP
│   ├── mixed/              # Mixed (SOCKS+HTTP)
│   ├── dns/                # DNS (出站)
│   ├── direct/             # 直连
│   ├── block/              # 阻断
│   ├── bridge/             # 桥接
│   ├── tun/                # TUN 接口
│   ├── openvpn/            # OpenVPN
│   ├── openconnect/        # OpenConnect (Cisco AnyConnect)
│   ├── shadowtls/          # ShadowTLS
│   ├── anytls/             # AnyTLS
│   ├── vless/              # VLESS
│   ├── group/              # 分组协议 (selector, urltest)
│   ├── redirect/           # 重定向
│   ├── ssh/                # SSH
│   ├── tor/                # Tor
│   ├── wireguard/          # WireGuard
│   └── cloudflare/         # Cloudflare 相关
├── transport/              # 传输层
│   ├── v2ray/              # V2Ray 传输 (HTTP, WebSocket, gRPC 等)
│   ├── v2raygrpc/          # V2Ray gRPC
│   ├── v2rayhttp/          # V2Ray HTTP/2
│   ├── v2raywebsocket/     # V2Ray WebSocket
│   ├── v2rayhttpupgrade/   # HTTP Upgrade
│   ├── v2rayquic/          # V2Ray QUIC
│   ├── simple-obfs/        # Simple-Obfs
│   ├── sip003/             # SIP003 (SS 插件规范)
│   ├── trojan/             # Trojan 传输
│   ├── wireguard/          # WireGuard 传输
│   └── openvpn/            # OpenVPN 传输
├── option/                 # 配置选项定义（JSON 映射到 Go struct）
├── route/                  # 路由引擎
│   └── rule/               # 规则系统
├── dns/                    # DNS 解析器
│   └── transport/          # DNS over HTTPS/TLS 等
├── experimental/           # 实验性功能
│   ├── clashapi/           # Clash API 兼容层
│   ├── cachefile/          # 缓存文件
│   ├── locale/             # 本地化
│   └── v2rayapi/           # V2Ray API 兼容
├── common/                 # 公共模块
│   ├── dialer/             # 连接拨号器
│   ├── tls/                # TLS 配置
│   ├── tlsfragment/        # TLS 分片 (反检测)
│   ├── tlsspoof/           # TLS 欺骗
│   ├── ja3/                # JA3 fingerprinting
│   ├── mux/                # 多路复用
│   ├── sniff/              # 协议嗅探
│   ├── certificate/        # 证书管理
│   ├── geoip/              # GeoIP 数据库
│   ├── geosite/            # GeoSite 数据库
│   ├── redir/              # 透明代理
│   ├── listener/           # 监听器抽象
│   ├── httpclient/         # HTTP 客户端
│   ├── netns/              # 网络命名空间
│   └── srs/                # 路由集 (SRS 格式)
├── daemon/                 # 守护进程管理
├── service/                # 系统服务管理
├── schema/                 # JSON Schema 生成
├── log/                    # 日志系统
├── constant/               # 常量定义
├── test/                   # 测试
├── docs/                   # 文档 (mkdocs)
├── release/                # 发布配置
└── include/                # 头文件/构建配置
```

## 3. 核心设计模式

### 3.1 Outbound 注册机制

sing-box 使用**工厂注册模式**来管理协议：

```go
// 在 protocol/vmess/outbound.go 中
func RegisterOutbound(registry *outbound.Registry) {
    outbound.Register[option.VMessOutboundOptions](registry, C.TypeVMess, NewOutbound)
}
```

每个协议需要实现：
1. **Options struct** (`option/vmess.go`) — JSON 配置字段映射
2. **NewOutbound 函数** — 根据 options 创建 Outbound 实例
3. **Register 函数** — 在 init() 中注册到工厂

### 3.2 Outbound 接口抽象

```go
// 核心接口 (adapter/outbound/outbound.go)
type Outbound interface {
    Tag() string
    Type() C.Class
    DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error)
    ListenPacket(ctx context.Context, destination M.Socksaddr) (net.PacketConn, error)
    Close() error
}
```

支持扩展的 mixin 接口：
- `OutboundWithMultiplex` — 启用多路复用
- `OutboundWithDialer` — 自定义拨号器
- `OutboundWithTransport` — 自定义传输层

### 3.3 Adapter 模式

实际实现通过 `outbound.Adapter` 组合来复用代码：

```go
type Outbound struct {
    outbound.Adapter    // 提供基础能力：Tag, Class, Network 管理等
    logger             logger.ContextLogger
    dialer             N.Dialer          // 连接拨号器
    client             *vmess.Client     // 协议客户端
    serverAddr         M.Socksaddr       // 服务端地址
    multiplexDialer    *mux.Client       // 多路复用器
    tlsConfig          tls.Config        // TLS 配置
    tlsDialer          tls.Dialer        // TLS 拨号器
    transport          adapter.V2RayClientTransport // 传输层
}
```

### 3.4 Dialer 链

每个 Outbound 内部有一个 dialer 链路（按优先级）：
1. **transport** — V2Ray 传输层（WebSocket/gRPC/HTTP 等）
2. **tlsDialer** — TLS 加密层
3. **dialer** — 基础 TCP/UDP 拨号器（含域名解析、绑定等）

源码对应 (vmess outbound.DialContext):
```go
if h.transport != nil {
    conn, err = h.transport.DialContext(ctx)
} else if h.tlsDialer != nil {
    conn, err = h.tlsDialer.DialTLSContext(ctx, h.serverAddr)
} else {
    conn, err = h.dialer.DialContext(ctx, N.NetworkTCP, h.serverAddr)
}
```

### 3.5 配置解析流程

```
config.json → option/config.go → UnmarshalJSONContext
    │
    ├─ JSON "type" 字段决定使用哪个 Options struct
    ├─ 通过 OutboundOptionsRegistry 查找对应的 CreateOptions
    ├─ badjson.UnmarshallExcludedContext 映射字段
    └─ 最终存入 Outbound.Options (interface{})
```

关键文件: `option/outbound.go` — `_Outbound` struct 的 MarshalJSONContext / UnmarshalJSONContext

## 4. 各协议关键配置字段

### 4.1 VMess (protocol/vmess/)

```json
{
  "type": "vmess",
  "tag": "vmess-out",
  "server": "example.com",
  "server_port": 443,
  "uuid": "bf000d23-0752-40b4-affe-68f7707a9661",
  "security": "auto",           // auto/none/zero/aes-128-gcm/chacha20-poly1305
  "alter_id": 0,
  "global_padding": false,
  "authenticated_length": true,
  "network": "tcp",             // tcp/udp
  "tls": { "enabled": true },
  "transport": { "type": "websocket", ... },
  "multiplex": { "enabled": true, ... }
}
```

### 4.2 VLESS (protocol/vless/)

```json
{
  "type": "vless",
  "tag": "vless-out",
  "server": "example.com",
  "server_port": 443,
  "uuid": "...",
  "flow": "xtls-rprx-vision",   // 流控: xtls-rprx-vision
  "network": "tcp",
  "tls": { "enabled": true },
  "transport": { ... },
  "multiplex": { ... }
}
```

### 4.3 Shadowsocks (protocol/shadowsocks/)

```json
{
  "type": "shadowsocks",
  "tag": "ss-out",
  "server": "example.com",
  "server_port": 443,
  "method": "2022-blake3-aes-128-gcm",
  "password": "...",
  "plugin": "",
  "network": "udp",
  "udp_over_tcp": false,
  "multiplex": { ... }
}
```

支持的 cipher: 2022-blake3-aes-128-gcm, 2022-blake3-aes-256-gcm, aes-128-gcm, chacha20-ietf-poly1305, xchacha20-ietf-poly1305 等

### 4.4 Hysteria2 (protocol/hysteria2/)

```json
{
  "type": "hysteria2",
  "tag": "hy2-out",
  "server": "example.com",
  "server_port": 443,
  "password": "...",
  "tls": { "enabled": true, "insecure": false },
  "obfs": { "type": "salamander", "password": "..." },
  "speed_limit": { ... },
  "transport": { ... }
}
```

## 5. 传输层（V2Ray Transport）

支持多种 V2Ray 兼容传输：

| type | 说明 |
|------|------|
| websocket | WS/WebSocket with path + headers |
| http | HTTP/1.1 隧道 |
| httpupgrade | HTTP Upgrade (反检测) |
| quic | QUIC 传输 |
| grpc | gRPC (gwrpc/gun) |
| xsplithttp | XSplitHTTP |

示例 (websocket transport):
```json
"transport": {
  "type": "websocket",
  "path": "/ws-path",
  "headers": { "Host": "example.com" },
  "max_early_data": 2048,
  "early_data_header_name": "Sec-WebSocket-Protocol"
}
```

## 6. 路由引擎 (route/)

### 配置结构
```json
{
  "route": {
    "rules": [],
    "rule_set": [],
    "final": "direct",
    "auto_detect_interface": true,
    "default_domain_resolver": "remote",
    "domain_strategy": "prefer_ipv4"
  }
}
```

### Rule 类型 (route/rule/)
- domain / domain_suffix / domain_keyword
- ip_cidr / ip_is_private
- protocol (dns, quic, bittorrent, etc.)
- inbound / outbound / process_name / user / port / port_range
- rule_set / geoip / geosite

### 1.12.0+ 变化
- `geoip` / `geosite` 被移除 → 改用 `rule_set` (外部加载)
- 新增 `default_domain_resolver` 替代 `domain_strategy`

### 1.14.0+ 新增
- `find_neighbor` — 邻居解析
- `dhcp_lease_files` — DHCP lease 文件路径
- `default_http_client` — 远程 rule-set 的 HTTP 客户端

## 7. DNS 引擎 (dns/)

```json
{
  "dns": {
    "servers": [
      { "tag": "local", "type": "local" },
      { "tag": "remote", "type": "https", "server": "dns.google", "server_port": 443 },
      { "tag": "dns-block", "type": "block" }
    ],
    "rules": [
      { "server": "remote", "domain": "geosite:gfw" },
      { "server": "dns-block", "rule_set": "geosite-malware" }
    ],
    "strategy": "prefer_ipv4",
    "final": "remote",
    "disable_cache": false,
    "disable_expire": false
  }
}
```

### 1.14.0+ 新增 optimistic 缓存
```json
"dns": { "optimistic": true }
```

## 8. 入站 (Inbound) 注册

类似 Outbound，Inbound 也用注册模式：
```go
adapter/inbound/registry.go
```

支持的入站协议: vmess, vless, trojan, shadowsocks, mixed, socks, http, tun, naive 等

每个 inbounds 需要:
- listen_addr + listen_port
- tag (唯一标识)
- protocol 特定的配置字段
- detour (转发出站到另一个 outbound)
- sniff (协议嗅探开关)

## 9. 多路复用 (Mux)

```json
"multiplex": {
  "enabled": true,
  "protocol": "h2mux",       // h2mux / smux / yamux
  "max_connections": 8,
  "min_streams": 4,
  "padding": true
}
```

注意：multiplex 和 udp_over_tcp 互斥。

## 10. config.sh 与官方配置的映射关系

我们的 install.sh / config.sh 使用了 jq 操作 JSON 配置，以下是关键映射：

| config.sh 操作 | 对应的 sing-box 配置项 | 对应源码位置 |
|---------------|----------------------|-------------|
| `jq '.inbounds += [...]'` | `inbounds` 数组 | `adapter/inbound/` |
| `jq '.outbounds += [...]'` | `outbounds` 数组 | `adapter/outbound/` |
| `tls.reality.handshake` | Reality 回落目标 | `common/tls/` + protocol/*/outbound.go |
| `tls.certificate_path` | 证书路径 | `common/certificate/` |
| `route.rules[]` | 路由规则 | `route/rule/` |
| `dns.servers[]` | DNS 服务器列表 | `dns/` |
| `sniff.enabled` | 协议嗅探 | `common/sniff/` |

## 11. 写一个新协议需要的步骤

参考现有 vmess/vless 的实现：

1. **创建目录**: `protocol/myproto/`
2. **实现 Options struct**: `option/outbound.go` 中添加 `MyProtoOutboundOptions`
3. **实现 Outbound struct**: `protocol/myproto/outbound.go` 中实现 `NewOutbound`
4. **注册**: 在 `protocol/myproto/init.go` 中调用 `outbound.Register`
5. **添加常量和类型**: `constant/` 中添加 `C.TypeMyProto`
6. **更新文档**: `docs/configuration/outbound/myproto.md`
7. **更新测试**: `test/` 中添加测试用例

## 12. 关键依赖库

从 go.mod 中提取的关键依赖：

| 库 | 用途 |
|----|-----|
| github.com/sagernet/sing-vmess | VMess 协议核心库 |
| github.com/caddyserver/certmagic | TLS 证书管理 (ACME) |
| github.com/coder/websocket | WebSocket 支持 |
| github.com/creack/pty | PTY (伪终端) 支持 |
| github.com/cretz/bine | Tor 集成 |
| github.com/go-chi/chi/v5 | HTTP 路由 (Clash API) |
| filippo.io/age | 加密密钥派生 |
| github.com/anytls/sing-anytls | AnyTLS 协议 |
| github.com/insomniacslk/dhcp | DHCP 支持 |
| github.com/jsimonetti/rtnetlink | Linux 路由 netlink |

## 13. 调试和运维命令

```bash
# 验证配置
sing-box check -c config.json

# 格式化配置
sing-box format -w -c config.json

# 合并配置
sing-box merge output.json -c config.json

# 查看实时日志
journalctl -u sing-box -f

# 查看运行状态
svc_status sing-box  # 或 systemctl status sing-box
```

## 14. 版本兼容性要点

| 版本 | 关键变化 |
|------|---------|
| 1.8.0 | 引入 rule_set (替代 geoip/geosite) |
| 1.11.0 | 移除 DNS outbound, 引入 network_strategy/network_type/fallback |
| 1.12.0 | 移除 geoip/geosite, 引入 default_domain_resolver, address_resolver → domain_resolver |
| 1.13.0 | 完全移除 DNS outbound |
| 1.14.0 | 新增 find_neighbor, dhcp_lease_files, optimistic DNS, initial_path for rule-sets |

<!-- ⟦ sing-box 源代码学习笔记已整理完成，涵盖架构、协议、传输、路由等核心知识点 ⟧ -->
