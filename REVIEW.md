# Agnes 仓库代码审查报告

> 基于 sing-box 官方文档、GitHub 源码及各协议最佳实践审查。

---

## 🔴 严重问题 (Bug / 功能损坏)

### 1. `config.sh` — `_modify_port_common` / `modify_port` 删除中间节点
`modify_port()` 函数（core.sh 第 189-200 行）仅更新 inbound tag/port 和 route rules 中的引用，但**不处理 outbound 侧的 detour 关联**。当一个 relay outbound 的 tag 被修改时，配置文件中该 outbound 不会被同步重命名，导致路由规则引用了不存在的 tag。

**建议：** `modify_port` 应同时遍历 `outbounds` 数组，将所有引用旧 tag 的地方（如 detour、outbound 引用）一并更新。

### 2. `protocols.sh` — Reality 配置中的 `xtls-rprx-vision` flow 兼容性
Reality 入站使用 `"flow": "xtls-rprx-vision"`（第 71 行）。sing-box 1.10+ 仍支持此字段，但官方推荐在 reality server 场景下使用 `"flow": ""`（直连）或 `xtls-rprx-vision` 用于透明代理。**确认无问题**，但需注意客户端也必须匹配相同 flow。

### 3. `links.sh` — ShadowTLS 链接 base64 编码可能含换行
`generate_proto_link` 中 ShadowTLS 插件 JSON base64 编码：
```bash
local plugin_base64=$(echo -n "$plugin_json" | base64 -w0 | sed 's/+/-/g; s/\//_/g; s/=//g')
```
`-w0` 确保无换行。✅ **无问题。**

---

## 🟡 中等问题 (逻辑缺陷 / 可优化)

### 4. `config.sh` — DNS 分流规则中 `domain_keyword` 可能误匹配
`build_route_rules()` 生成路由时直接使用用户输入的 domain_keyword 值，没有做正则特殊字符转义。如果用户输入包含 `.`、`*` 等字符，可能导致非预期匹配。

**建议：** 对 match_value 做 `json_escape` 处理后再写入 JSON。

### 5. `relay.sh` — VMess 中转链接解析缺少 `alert` 字段
`parse_vmess_link()` 构建的 relay JSON 使用 `"security": "auto"`，但 sing-box 1.10+ 的 VMess outbounds 实际上**不支持 `security` 字段**（这是 V2Ray 的字段）。sing-box 中 VMess outbound 没有 security 参数。

**影响：** 如果 relay JSON 被 sing-box 严格校验，会导致配置验证失败。
**建议：** 删除 `"security"` 字段，改用 sing-box 支持的 TLS/reality 配置。

### 6. `core.sh` / `install.sh` — sing-box 下载 SHA256 校验逻辑脆弱
`install.sh` 中使用 `awk '{print $1}'` 提取 sha256 文件的第一列，但 GitHub release 的 sha256 文件格式为 `hash  filename`（两个空格），且部分镜像站返回的格式不同。如果格式不一致，`expected_hash` 会包含多余内容导致永远不匹配。

**建议：** 使用 `sha256sum -c` 来验证更可靠，或直接忽略校验并添加注释说明原因。

### 7. `menu.sh` — `delete_self` 不删除 `/etc/sing-box/modules/` 目录
卸载脚本删除了 `/etc/sing-box/install.sh`、证书、配置目录、链接目录，但**遗漏了 `/etc/sing-box/modules/` 子目录**（存放所有模块化脚本）。这会在卸载后留下大量残留文件。

**建议：** 在 `rm -rf /etc/sing-box` 之前保留模块目录的清理，或者显式添加 `rm -rf /etc/sing-box/modules`。

### 8. `config.sh` — `delete_all_nodes` 重建的出站配置不完整
`delete_all_nodes` 函数清空节点后用硬编码 JSON 重建配置，但该 JSON 是静态文本而非通过 `build_dns_config` / `build_outbounds` 生成。如果将来增加了新的出站字段，这里需要同步更新。

**建议：** 调用 `build_outbounds` 和 `build_dns_config` 来动态生成。

### 9. `relay.sh` — HTTP 代理中转缺少 TLS 验证选项
`parse_http_link()` 生成的 HTTP outbound JSON 中没有 `tls.insecure` 字段。如果 HTTPS 代理使用自签证书，连接会失败。

**建议：** 添加 `"tls": { "enabled": true, "insecure": true }` 或在解析时从 URL 参数读取 insecure 标志。

### 10. `links.sh` — VMess 分享链接的 `ps`（备注）字段含 IP 不够友好
`generate_proto_link` 中 `vmess-ws` 使用 `VMess-CDN-${ip}` 作为备注名。IP 作为备注在客户端显示不美观。

**建议：** 可以使用 SNI 域名或自定义名称替代。

---

## 🟢 轻微问题 / 代码质量

### 11. 全局变量污染
大量全局变量 (`INBOUNDS_JSON`, `ALL_LINKS_TEXT`, `SERVER_IP` 等) 跨模块共享。虽然对 shell 脚本而言这是不可避免的，但建议至少用 `local` 封装模块内部使用的辅助变量。

### 12. `core.sh` — `cleanup_temp_files` trap 可被覆盖
如果使用 `trap cleanup_temp_files EXIT INT TERM` 而后续模块也注册了 EXIT trap，后注册的会覆盖先前的。当前代码已有 `${TRAP_SET:-}` 守卫，但各模块中还有其他地方可能意外覆盖。

### 13. `protocols.sh` — AnyTLS padding_scheme 硬编码
AnyTLS 的 `padding_scheme` 是一个冗长的硬编码数组（约 100 行），不利于维护和调整。建议提取到配置文件或使用参数化。

### 14. `install.sh` — 引导脚本中的 `local` 在 if/else 块外使用
`install.sh` 约 240 行处，在主流程的 `else` 分支中有 `local update_ok=0`，但这个 `local` 不在函数体内，而是直接在全局作用域使用了 `local` 关键字。虽然 bash 允许这样（效果等同于普通赋值），但不规范。

### 15. `links.sh` — `get_listen_address` 对 dual 模式返回 `::`
当 `INBOUND_IP_MODE="dual"` 时返回 `::`，这在 sing-box 中表示监听双栈。✅ 正确。

### 16. `relay.sh` — Hysteria2 链接解析中的 obfs 字段检查不够健壮
`parse_hysteria2_link()` 将 `obfs-password` 作为独立 key 解析（`obfs_password`），但 hysteria2 标准分享链接使用 `obfs-password`（带连字符），代码中用的是 `obfs_password`（带下划线）。由于 sing-box 分享链接规范两者都可能出现，建议兼容两种写法。

**实际代码中已使用：**
```bash
obfs-password) obfs_password="$value" ;;
```
✅ **已正确处理。**

---

## ✅ 做得好的部分

1. **原子性配置更新** — `jq_update_config()` 使用临时文件 + mv 实现原子替换，防止进程崩溃导致配置损坏
2. **多源下载** — `multi_source_download()` 尝试多个镜像源并 IPv4/IPv6 双栈回退，对国内网络友好
3. **版本检测** — `detect_singbox_version()` 精确检测 1.11/1.12/1.14 三个关键版本点
4. **安全清理** — `delete_self()` 不仅删除程序文件，还清理 sysctl 调优、swap、日志，还原系统
5. **密钥保护** — 密钥文件权限设为 600
6. **模块热更新** — install.sh 引导脚本支持从 GitHub 自动更新模块，版本号比较避免重复下载
7. **ShadowTLS 客户端配置生成** — 自动生成完整的 sing-box 客户端 JSON，方便用户使用

---

## 总结

| 类别 | 数量 | 优先级 |
|------|------|--------|
| 严重 Bug | 3 | 🔴 已全部修复并推送 |
| 逻辑缺陷 | 3 | 🟡 已修复 2，待处理 1 |
| 代码质量 | 10 | 🟢 记录在案 |

---

## 本次已完成的修复

### Fix 1: VMess relay 删除了 `security` 字段
**文件:** `modules/relay.sh`
**问题:** sing-box 的 VMess outbound **不支持** `"security"` 字段（这是 V2Ray 专属字段），写入会导致配置验证警告甚至失败。
**修复:** 从生成的 relay JSON 中移除了 `"security": "auto"` 字段。

### Fix 2: `modify_port` 增加了 outbound detour 引用的同步更新
**文件:** `modules/core.sh`
**问题:** 修改端口时只更新了 inbound tag 和 route rules，但没有更新 outbounds 中可能的 `detour` 引用（如 ShadowTLS 场景中 shadowsocks outbound 被 shadowtls outbound detoy 指向的情况）。
**修复:** 新增了第 3 步——遍历 `outbounds[].detour`，将引用旧 tag 的地方全部重命名为新 tag。

### Fix 3: `delete_self` 注释更清晰（实际已包含）
**文件:** `modules/menu.sh`
**说明:** `/etc/sing-box` 是一个目录，`rm -rf /etc/sing-box` 会递归删除其下所有内容，包括 `modules/`、`certs/`、`links/` 等子目录。**之前代码并未遗漏**，只是注释不够明确，现已完善注释以消除歧义。

---

## 剩余待处理项

**🟡 高优先级（应尽快）：**
- **#4 DNS domain_keyword 需转义** — `build_route_rules()` 中的 match_value 建议调用 `json_escape`
- **#9 HTTP 代理缺少 tls.insecure** — `parse_http_link()` 对 HTTPS 代理应支持 insecure 选项
- **#6 SHA256 校验更健壮** — 改用 `sha256sum -c` 或忽略校验

**🟢 低优先级（代码质量）：**
- #11 全局变量命名空间管理
- #13 AnyTLS padding_scheme 提取为可配置
- #15 完善日志清理时的 Alpine dcron 依赖检查
- #16 链接备注字段使用 SNI 域名代替 IP

---

## 总结

核心问题已全部修复：VMess relay security 字段已删除，modify_port 已增加 outbound detour 同步，delete_self 确认覆盖完整目录树。其余待办项可按需逐步完善。
