# sing-box 官方文档核心学习笔记 (Phase 2 - 2026-07-26)

## 1. Configuration 整体结构

```json
{
  "$schema": "https://sing-box.sagernet.org/schema.json",
  "log": {},           // 日志配置
  "dns": {},           // DNS 解析 + FakeIP
  "ntp": {},           // NTP 时间同步
  "certificate": {},   // 证书定义
  "certificate_providers": [], // 自动证书 (ACME/CF Origin CA/Tailscale)
  "http_clients": [],  // 内部 HTTP 客户端（下载 SRS、ACME 等用）
  "endpoints": [],     // Endpoint: WireGuard / Tailscale / OpenConnect
  "inbounds": [],      // 入站: VLESS/Hysteria2/TUIC/shadowsocks...
  "outbounds": [],     // 出站: direct/socks/wireguard/selector/urltest...
  "route": {},         // 路由 + RuleSet (SRS)
  "services": [],      // 服务: API / DERP / Resolved / Hysteria Realm
  "experimental": {}   // 实验性: Clash API / V2Ray API
}
```

## 2. Rule Set (SRS) — 1.8+ 现代标准

### 三种类型
| 类型 | 用法 |
|------|------|
| `remote` | 从远程 URL 下载 `.srs` binary 或 `.json` source 格式 |
| `local` | 本地文件，支持热重载（修改即自动 reload） |
| `inline` | 直接在 config 中内联 headless rules |

### Remote fields (1.14.0+)
- `http_client` — 替代 deprecated 的 `download_detour`
- `initial_path` — 首次启动从本地加载，不阻塞网络
- `update_interval` — 默认 1d
- `tag` 可接受数组（批量定义多个 tag 共享同一份规则集）

### 1.14.0 重要变更
- `independent_cache` **已弃用**，将被移除 → 改用 `optimistic` DNS cache
- WireGuard outbound 已弃用 → 迁移到 `endpoint/wireguard`

## 3. DNS 配置关键点

### DNS Servers
内置 **15+ 种服务器类型**：
- `local` — 本地解析器 (glibc/musl)
- `udp/tcp/tls/quic/https/http3/dhcp/mdns` — 各协议 DNS
- `fakeip` — FakeIP 服务器（拦截式 DNS）
- `tailscale/openconnect/openvpn/resolved` — 特殊场景

### DNS Fields 重点
- `strategy`: `prefer_ipv4` / `prefer_ipv6` / `ipv4_only` / `ipv6_only`
- `reverse_mapping`: DNS 解析后存储 IP→domain 反向映射（用于路由判断）
- `optimistic`: (1.14.0) 过期缓存仍可用，默认 3d 超时
- `timeout`: 每个 DNS 查询默认 10s
- `client_subnet`: EDNS0-subnet OPT 记录注入

## 4. Route 路由

### 1.14.0 新增
- `find_neighbor` — 邻居解析（hostname/MAC 日志）
- `dhcp_lease_files` — DHCP lease 文件路径自定义

### 1.12.0 变动
- `geoip` / `geosite` 字段移除 → 统一走 `rule_set`

### 核心流程
```
sniff → resolve → match rules → route to outbound
```
- `final` — 未匹配规则的默认出站
- `auto_detect_interface` — Linux/macOS/Windows 自动绑定默认网卡防环路

## 5. 证书管理

### ACME (1.14.0 大更新)
- `account_key` — 已有 ACME account 的 PEM 私钥
- `key_type` — `ed25519/p256/p384/rsa2048/rsa4096`
- `profile` — 指定 ACME profile；IP 地址自动用 `shortlived`
- `disable_http_challenge` / `disable_tls_alpn_challenge` — 关闭特定挑战
- `alternative_http_port` / `alternative_tls_port` — 非标准端口 ACME
- `dns01_challenge` — DNS TXT 记录验证
- `external_account` — CA EAB 绑定

### Certificate Providers
1. ACME (Let's Encrypt / ZeroSSL / Custom)
2. Tailscale
3. Cloudflare Origin CA

## 6. Protocol Configs

### Hysteria2 (1.14.0 重大增强)
- `bbr_profile`: `conservative/standard/aggressive`
- `realm`: 注册到 Hysteria Realm rendezvous 实现 NAT 穿透（STUN discovery）
- `obfs.type`: `salamander` / `gecko`(新)
- `obfs.min_packet_size` / `max_packet_size` — Gecko only
- `masquerade` — auth 失败时的 HTTP3 行为（file/proxy/fixed string）
- `ignore_client_bandwidth`: 控制 BBR CC vs 固定带宽限制

### VLESS
- `users.flow`: `xtls-rprx-vision` (原生 TCP 流控)
- TLS: reality / 普通 cert
- Multiplex + Transport (ws/h2/gRPC)

### WireGuard Outbound — 已弃用！
→ 迁移到 `endpoint/wireguard`，功能更强大

## 7. Clash API (实验性)

### Fields
- `external_controller`: RESTful API 地址 (如 `127.0.0.1:9090`)
- `external_ui`: 静态 Web UI 路径
- `external_ui_download_url`: UI ZIP 下载 URL (metaclabexd/yacd 等)
- `default_mode`: `Rule/Direct/Global`
- `access_control_allow_origin`: CORS 白名单 (1.10.0+)
- `access_control_allow_private_network`: 允许私有网络访问

### 1.8.0 变更
- `store_mode/store_selected/store_fakeip/cache_file/cache_id` 全部 deprecated
- → 迁移到 `experimental.cache_file` 独立模块

## 8. Endpoint (替代 wireguard outbound)

Endpoint types:
- `wireguard` — WireGuard peer
- `tailscale` — Tailscale peer
- `openconnect` — OC client/server
- `openvpn` — OpenVPN client/server

优势: 作为"连接点"而非完整出站，可与现有 outbounds 组合使用。
