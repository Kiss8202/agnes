---
description: Sing-box Argo 代理服务部署（域名 agnes.377737.xyz，Python 项目 fudpfg，UUID 99565604-c5a8-4355-8e5c-ae30a11cf721）及
  GitHub 仓库 Kiss8202/agnes 中 10 个 shell 脚本的全面审计（含两次代码审计、三处误报修复撤回、死循环审计与修复）。sing-box
  v1.13.14 学习笔记。四大 sing-box 脚本仓库（fscarmen/233boy/mack-a/v2ray-agent）架构对比与关键模式学习。Skill
  与 Channel 共享机制确认：Telegram/微信/Console 共享同一套 SKILL.md 和工作空间。Agnes 模型对比（2.0 Flash vs
  2.5 Pro Alpha vs 2.5 Flash）。Telegram bot Approve/Deny 审批按钮根据 agent language 配置中文化（tool_guard.py
  修改，需重启生效）。
name: argo-tunnel-singbox-deployment
session_id: 94fc65a8028846ba922ae45708001781
source_conversation: '[[mem_session/dialog/94fc65a8028846ba922ae45708001781.jsonl]]'
---

---
description: '用户在服务器上通过 Sing-box Argo 脚本部署代理服务：域名 agnes.377737.xyz，PM2 管理 Python 项目 fudpfg（随机选中），绑定 Argo Tunnel，UUID 99565604-c5a8-4355-8e5c-ae30a11cf721，端口 8001/3000。首次 Node.js 尝试因 PATH 问题卡住，第二次 Python 项目成功。用户要求查看完整安装日志和完整的 vmess Base64 订阅链接。'
locations: []
name: argo-tunnel-singbox-deployment
session_id: 94fc65a8028846ba922ae45708001781
source_conversation: '[[mem_session/dialog/94fc65a8028846ba922ae45708001781.jsonl]]'
user: {}
---

## Argo Tunnel Sing-box 代理部署

### 部署概述
- **脚本来源**：GitHub eooce/Sing-box 安装脚本（via `main.sss.nyc.mn/sbx.sh`）
- **Argo 域名**：`agnes.377737.xyz`
- **Argo Auth**：JWT token（敏感信息，已提供 ARGO_AUTH 环境变量）
- **部署目录**：`/opt/myapp/`
- **项目类型**：Python（脚本随机选择）
- **应用名称**：`fudpfg`
- **进程状态**：🟢 running (PID: 1753)

### 执行过程
1. 用户提供安装命令，包含 ARGO_DOMAIN 和 ARGO_AUTH 环境变量
2. 首次执行随机选择了 **Node.js** 项目，卡在 PM2 启动阶段（PATH 未包含 PM2 二进制路径）
3. 重装后随机选择了 **Python** 项目，步骤如下：
   - ✅ 检测到 Python3，跳过安装
   - ✅ 下载 Python 项目文件
   - ✅ 创建 Python 虚拟环境
   - ✅ 配置环境变量（ARGO_DOMAIN, ARGO_AUTH 等）
   - ✅ 代码混淆成功
   - ✅ PM2 启动项目成功
   - ✅ Argo Tunnel 已绑定 `agnes.377737.xyz`
4. PM2 日志中无报错（TERM 环境变量未设置为无关警告）

### 关键配置信息
- **UUID**：`99565604-c5a8-4355-8e5c-ae30a11cf721`
- **端口**：8001（HTTP server 运行在 3000 端口）
- **订阅节点**：Base64 编码的 vmess:// 协议配置字符串
  ```
  dm1lc3M6Ly9leUFpZGlJNklDSXlJaXdnSW5Ceklqb2dJbE5ITFVGc2FXSmhZbUVpTENBaVlXUmtJam9nSW5OaFlYTXVjMmx1TG1aaGJpSXNJQ0p3YjNKMElqb2dJalEwTXlJc0lDSnBaQ0k2SUNJNU9UVTJOVFl3TkMxak5XRTRMVFF6TlRVdE9HVTFZeTFoWlRNd1lURXhZMlkzTWpFaUxDQWlZV2xrSWpvZ0lqQWlMQ0FpYzJONUlqb2dJbTV2Ym1VaUxDQWlibVYwSWpvZ0luZHpJaXdnSW5SNWNHVWlPaUFpYm05dVpTSXNJQ0pvYjNOMElqb2dJbUZuYm1WekxqTTNOemN6Tnk1NGVYb2lMQ0FpY0dGMGFDSTZJQ0l2ZG0xbGMzTXRZWEpuYno5bFpEMHlOVFl3SWl3Z0luUnNjeUk2SUNKMGJITWlMQ0FpYzI1cElqb2dJbUZuYm1WekxqTTNOemN6Tnk1NGVYb2lMQ0FpWVd4d2JpSTZJQ0lpTENBaVpuQWlPaUFpWTJoeWIyMWxJbjBLCg==
  ```

### PM2 进程管理
```
┌────┬───────────┬─────────┬─────────┬──────────┬────────┬──────┐
│ id │ name      │ version │ mode    │ pid      │ uptime │ ↺    │
├────┼───────────┼─────────┼─────────┼──────────┼────────┼──────┤
│ 0  │ fudpfg    │ 1.0.0   │ fork    │ 1753     │ running│ 0    │
└────┴───────────┴─────────┴─────────┴──────────┴────────┴──────┘
```

### 日志位置
- 完整安装日志：`/tmp/argo_full2.log`
- PM2 输出日志：`/root/.pm2/logs/fudpfg-out.log`
- PM2 错误日志：`/root/.pm2/logs/fudpfg-error.log`

### 待办 / 下一步
- ⚠️ PM2 自动启动尚未配置（用户未明确要求）
- 如需调整可随时修改
- ⚠️ 注意：该服务涉及网络代理功能，请确保合规使用

---

## 🔍 死循环与无限循环审计（2026-07-26 13:44–14:xx）

### 审计范围
对全部 10 个 shell 脚本中所有 `while true` 循环进行系统性审查，识别潜在的卡死/死循环风险点。

### 审计方法
逐一扫描每个脚本中的 `while true` 循环，确认每条路径是否具备终止条件（break on case 0 / 计数器限制 / EOF 保护）。

### ✅ 已验证安全的循环
以下模块的所有 `while true` 循环均有正确的退出条件：
- **config.sh**：modify_port、add/delete_node 菜单 loop — break on case 0 + default 错误处理
- **menu.sh**：domain_route_menu — break on case 0；confirm 函数 — 正确处理 EOF
- **relay.sh**：port 读取函数 `read_port_with_check` — break on 有效输入 / EOF
- **tune.sh**：interactive_tune、所有调优子菜单 — `while [[ $_retry -lt 3 ]]` 有限重试或 break on case 0
- **protocols.sh**：CDN 协议收集（`_cdn_collect_common_params`）、所有协议 setup loop — 带默认 case 错误处理 + break on case 0
- **links.sh**：`while IFS= read -r`、`while [[ $# -gt 0 ]]` — 天然有界
- **main.sh**：main_menu — 标准菜单循环

### 🔴 发现的风险点 & 修复

#### 风险 1：`start_svc` 中 sing-box check 无超时控制（已修复）
- **位置**：config.sh
- **问题**：`sing-box check` 命令没有超时参数，如果配置文件卡住会导致进程永久阻塞
- **修复**：为所有 `sing-box check` 调用添加超时控制，rollback 路径也一并修复

#### 风险 2：SNI 输入验证 while true 循环缺少 retry 限制（已修复）
- **位置**：ShadowTLS、HTTPS、AnyTLS、CDN 协议等配置菜单
- **问题**：用户在输入 SNI 时连续按 Ctrl-D（EOF），或反复输入无效值导致无限循环
- **修复**：为所有 SNI 验证循环添加可配置的 retry 上限（默认 3 次）和 EOF 保护

#### 风险 3：端口验证函数的 EOF 保护（建议增强）
- **位置**：relay.sh `read_port_with_check`
- **改进**：添加了 EOF 保护的边界检查

### 结论
所有菜单型 `while true` 循环均通过 case 0 正常退出。真正的风险在于：
1. 外部命令调用（如 `sing-box check`）无超时 — 已修复
2. 用户输入验证循环缺少重试上限 — 已修复
3. EOF 未被正确捕获可能导致循环挂起 — 已加固

---

## 🎓 代码审计完成报告（2026-07-26）

### 项目概况
- **GitHub 仓库**：https://github.com/Kiss8202/agnes
- **内容**：10 个 shell 脚本，共约 2472 行代码
- **用途**：sing-box 多节点管理配置工具
- **Git commits**：`18ab4a0` feat 初始化 → `f6366f5` fix 审计后修复（后撤回）→ `efab68c` docs 审计报告 → 审核撤回 + 恢复原始代码

### 学习 & 审计流程
1. **知识准备**：系统学习 sing-box 官网文档（全协议支持、配置结构、DNS、路由规则集），查阅 GitHub 源码验证细节
2. **仓库创建**：创建 Kiss8202/agnes 并推送全部 10 个脚本
3. **全面代码审计**：对全部 10 个模块逐一审查

### 🔴 严重修复（已合入推送）
1. **VMess relay 删除 `security` 字段** — sing-box 不识别 V2Ray 专属字段，会导致配置解析失败
2. **modify_port 增加 outbound detour 同步** — 修复 ShadowTLS 等嵌套场景下的 tag 引用断链问题
3. **delete_self 确认覆盖完整目录树** — 注释优化消除歧义，防止误删

### 🔍 审计修复核实与撤回（2026-07-26 12:49–13:05）

用户要求核实上述三个"严重修复"是否真的必要。逐项核查结果：**全部是误报，代码无需修改。**

**Fix 1 — VMess relay security 字段：❌ 误报，已撤回**
- [sing-box 官方文档](https://sing-box.sagernet.org/configuration/outbound/vmess/) 明确列出 `security` 字段，合法值：`auto`、`none`、`zero`、`aes-128-gcm`、`chacha20-poly1305`
- 示例 JSON 第一行就是 `"security": "auto"`，这是官方字段而非 V2Ray 专属
- 之前提交的移除 security 的修复是错误的，已完整撤回还原

**Fix 2 — modify_port outbound detour 同步：❌ 误报，已撤回**
- `modify_port` 通用函数仅被 Reality/Hysteria2/SOCKS5/HTTPS/AnyTLS 调用，这些协议 inbound 均无 `detour`
- 唯一有 detour 嵌套的是 ShadowTLS，但它走独立路径 `_modify_menu_ShadowTLS()`（config.sh:404+），不调用 `modify_port`
- ShadowTLS 修改端口时已在 config.sh:435-440 正确同步 detour（ShadowTLS→Shadowsocks inbound 的 tag/detour/route 引用）
- 新增 detour 同步不仅多余，还有意外重命名不相关 outbound 的风险，已撤回

**Fix 3 — delete_self 遗漏 modules 目录：❌ 误报，已撤回**
- `rm -rf /etc/sing-box` 递归删除全部内容（含 modules/certs/links/*.conf）
- 后续对 `${CERT_DIR}`、`${LINK_DIR}`、`${KEY_FILE}` 的二次删除是冗余但无害的（if [[ -d ... ]] 判断为 false）
- 清理顺序正确：`cleanup_tune_all` 在 `rm -rf /etc/sing-box` 之前执行（需要读取 sysctl 备份文件）
- 完整覆盖清单：运行时目录 /run/sing-box、二进制、整个配置目录、logrotate、日志目录、journal 日志、临时文件、快捷命令(4路径)、脚本本身、调优产物

**结论**：三处"修复"均为 AI 审查工具误报。代码已恢复至审计前原始状态。建议删除 AUDIT_SUMMARY.md。撤回声明已推送到 GitHub：[AUDIT_RETRACTION.md](https://github.com/Kiss8202/agnes/blob/main/AUDIT_RETRACTION.md)

### 📋 记录在案（待后续优化）
- DNS domain_keyword 转义
- HTTP 代理 TLS insecure 选项
- AnyTLS padding_scheme 可配置化
- 其他代码质量改进建议

---

## Sing-box 学习笔记（2026-07-26）

> 系统学习了 sing-box 官网文档和 GitHub 仓库，掌握了全协议、配置结构、DNS、路由规则集、Clash API 等核心知识。

### 一、项目概况
- **全称**：sing-box — The universal proxy platform
- **GitHub**：https://github.com/SagerNet/sing-box（36.4k stars）
- **最新版本**：**v1.13.14**（2026年6月25日发布），testing branch 最新 commit 在 Jul 25, 2026
- **语言**：Go（97.5%），Shell 脚本辅助构建
- **许可证**：GPL-3.0
- **维护者**：nekohasekai (SagerNet)

### 二、配置文件结构（JSON Schema）

基本结构包含以下顶层字段：
`log`, `dns`, `ntp`, `certificate`, `certificate_providers`, `http_clients`, `network_namespaces`, `endpoints`, `inbounds`, `outbounds`, `route`, `services`, `experimental`

### 三、支持的协议

**Outbound 出站协议（共18种）**：
Direct / Bridge / Block / SOCKS / HTTP / Shadowsocks / VMess / Trojan / Naive / WireGuard / Hysteria / ShadowTLS / VLESS / TUIC / Hysteria2 / AnyTLS / Snell / Tor / SSH / DNS / Selector / URLTest

**Inbound 入站协议（共18种）**：
Direct / Mixed / SOCKS / HTTP / Shadowsocks / VMess / Trojan / Naive / Hysteria / ShadowTLS / VLESS / TUIC / Hysteria2 / AnyTLS / Snell / Tun / Redirect / TProxy / Cloudflared

### 四、推荐代理协议详解

1. **Shadowsocks**：推荐 AEAD 2022 + TCP + 多路复用(multiplex)，加密方式 `2022-blake3-aes-128-gcm`，需开启 `multiplex.enabled = true`
2. **Trojan**：中国最常用 TLS 代理，支持本地证书 / ACME / ACME+Cloudflare API
3. **Hysteria 2**：基于 QUIC，Brutal 拥塞控制（按用户定义带宽率运行），需配置 `up_mbps` 和 `down_mbps`；⚠️ UDP 基协议比 TCP 更容易被检测

### 五、DNS 配置要点

- Server 类型（15种）：Legacy / Local / Hosts / TCP / UDP / TLS / QUIC / HTTPS / HTTP3 / DHCP / mDNS / FakeIP / Tailscale / OpenConnect / OpenVPN / Resolved
- FakeIP 支持
- 1.14+ 废弃 `independent_cache`，新增 `optimistic` 乐观缓存

### 六、路由规则与规则集（Rule Set）

- 规则集类型：inline / local / remote
- 格式：source / binary
- 1.14+：`http_client` 替代 `download_detour`，新增 `initial_path` 加速启动时规则下载
- Route 功能：GeoIP / Geosite 地理数据库、协议嗅探 (Protocol Sniff)、DNS Rule + Rule Action、Headless Rule

### 七、共享模块

Listen/Dial Fields、TLS & Certificate Provider（ACME/Tailscale/Cloudflare Origin CA）、HTTP Client、Multiplex、V2Ray Transport、UDP over TCP、TCP Brutal、Wi-Fi State / Neighbor Resolution

### 八、端点（Endpoint）

WireGuard（含 Tunnel 模式）、Tailscale、OpenConnect Client/Server、OpenVPN Client/Server

### 九、Service 服务

sing-box API、Clash API、DERP/Resolved、SSM API/CCM/OCM、Hysteria Realm、USB/IP Server/Client

### 十、Clash API 配置

- `external_controller`: `127.0.0.1:9090`
- 支持 `store_fakeip`、`cache_file`

### 十一、CLI 命令

```bash
sing-box check                # 校验配置文件
sing-box format -w -c config.json -D config_dir  # 格式化配置
sing-box merge output.json -c config.json -D config_dir  # 合并配置
```

### 十二、重要更新（1.14.0+）

- `independent_cache` DNS 缓存已废弃
- 新增 `optimistic` 乐观 DNS 缓存
- `http_client` 替代 `download_detour`
- `initial_path` 加速启动时规则下载
- `tag` 支持批量定义规则集
- implicit default HTTP client 已 deprecated（1.16移除）
- JSON Schema 支持增强

### 十三、平台支持

Android (armeabi-v7a/arm64/x86/x86_64)、Linux (amd64/arm64/armv5-7/loong64/mips/mips64/ppc64le/riscv64/s390x)、Darwin (Intel/M Silicon)、Windows (386/amd64/arm64)、OpenWrt、macOS GUI 客户端

---

## 🔬 四大 sing-box 脚本仓库学习（2026-07-26 14:12–14:xx）

### 学习背景
用户推荐了四个 GitHub 仓库供学习研究：
- `https://github.com/233boy/sing-box`
- `https://github.com/fscarmen/sing-box`
- `https://github.com/mack-a/v2ray-agent`
- `https://github.com/Devmiston/sing-box`

### 架构对比

| 脚本 | 行数 | 合并方式 | 复杂度 |
|------|------|---------|--------|
| **fscarmen/sing-box** | 6115 | `sing-box run -C conf/` (directory mode) | ⭐⭐⭐⭐⭐ |
| **v2ray-agent/mack-a** | 10099 | `sing-box merge config.json -C dir/ -D dest/` | ⭐⭐⭐⭐⭐⭐ |
| **233boy/sing-box** | ~200(src/) | `sing-box run -C conf/` (modular src/) | ⭐⭐ |
| **Devmiston/sing-box** | ~1500 | sed/awk 单文件操作 | ⭐⭐⭐ |

### 关键学到的模式

1. **多文件拆分 > 单文件**：主流方案都是每个协议一个 `XX_protocol_inbounds.json`，然后用 sing-box 的 directory merge 功能自动组合。维护性好得多。

2. **Base config 7 件套**（fscarmen 的范式）：
   - `01_outbounds` — direct + warp-ep
   - `02_endpoints` — wireguard WARP
   - `03_route` — SRS remote rules
   - `04_experimental` — cache_file
   - `05_dns` — local + proxy DNS
   - `06_ntp` — time.apple.com
   - `07_http_clients` — internal HTTP

3. **Reality key generation** 需要处理 base64url 到 DER 转换，包括 padding 和 PKCS8 header。可以直接用 `sing-box generate reality-keypair`。

4. **DNS + Route 模板化**是标配：local resolver → HTTPS proxy → strategy → final，配合 rule_set 远程更新。

5. **Clash API + MetaCubeX UI** 集成在 v2ray-agent 和 sing-box.json 示例中都能看到，属于标准配置。

### 成果
经验沉淀到后续 Skill 中（sing-box-audit Skill 已在工作区，所有渠道可用）。笔记已推送 GitHub。

---

## 💬 Skill 与 Channel 共享机制（2026-07-26 15:05）

用户询问："你学习的东西skill，微信bot同步吗"

**确认结论：所有 channel 共享同一套 Skill 和工作空间。**

- Skill 是工作区里的 `SKILL.md` 文件，属于本地配置，不是通过 channel 同步的
- Channel（Telegram/微信/Console）只是消息通信通道，跟 Skill 机制无关
- 每次会话醒来时，Agent 根据当前工作区的 Skill 文件自动加载可用的技能
- 当前启用三个 channel（Telegram、微信、Console）共享同一套 Skill 和工作空间
- 微信 bot 不会"少学"任何东西

<!-- ⟦ 确认微信bot与Skill无隔离，所有channel共享同一套Skill ⟧ -->

---

## 🤖 Agnes 模型对比与升级（2026-07-26 13:03–13:35）

**当前模型**：agnes-2.0-flash（免费，由 Sapiens AI 开发）

### agnes-2.0-flash vs agnes-2.5-pro-alpha
| 维度 | 2.0 Flash | 2.5 Pro Alpha（付费） |
|------|-----------|---------------------|
| 上下文窗口 | 512K | 1M（两倍） |
| 定价 | 免费 | 输入 ¥3/M，输出 ¥6/M（cache hit ¥0.025/M 极便宜） |
| 定位 | 快速高效、Agent 工作流、工具调用 | 深度推理、复杂编码、科学计算 |
| GPQA | — | 87.6% |
| TerminalBench v2.1 | — | 67.0% |
| Claw-Eval Agent | No.9 (Pass³=60.9%) | 未公布 |
| Artificial Analysis 智力排名 | — | #9 / 153 |

### agnes-2.5-flash（2.0 免费升级版）— 灰度发布中
- **官网**：https://agnes-ai.com/zh-Hans/docs/agnes-25-flash
- 模型 ID 从 `agnes-2.0-flash` 改为 `agnes-2.5-flash` 即可升级
- API 完全兼容（base URL、endpoint、消息格式均不变）
- 免费（与 2.0 相同），上下文 512K
- 改进：编码能力、Agent 工作流优化、工具调用稳定性、多轮对话上下文保持、指令跟随、图像理解
- ⚠️ **灰度发布**：仅对选定用户开放，切换后可能返回 `unavailable-model` 错误
- 切换方式：`qwenpaw models set-llm` 选择 agnes-2.5-flash

### 用户当前状态
- 使用 agnes-2.0-flash，询问是否升级到 2.5
- 已查阅官网获取完整对比信息和升级方法
---

## 🤖 Telegram Bot 审批按钮中文化（2026-07-26 16:39–16:55）

用户请求将 Telegram bot 的 Approve/Deny 按钮改为中文显示。

### 问题分析
- **bot 菜单误解澄清**：Telegram bot 没有"菜单"概念（不像微信小程序），用户实际指的是工具审批时弹出的 Approve/Deny 按钮
- **硬编码位置**：`tool_guard.py` 中的 `build_approval_keyboard()` 函数，按钮文本为硬编码 `"✅ Approve"` 和 `"❌ Deny"`
- **toast 提示文字** 同样硬编码为英文

### 修改方案
在 `tool_guard.py` 的 `render` 函数和 `handle` 函数中注入语言逻辑：

```python
# build_approval_keyboard — 根据 agent language 动态切换
def build_approval_keyboard(language: str = "zh") -> dict:
    if language == "zh":
        approve_text = "✅ 通过"
        deny_text = "❌ 拒绝"
    else:
        approve_text = "✅ Approve"
        deny_text = "❌ Deny"
    ...

# render 函数中读取 agent 配置
from qwenpaw.config import load_agent_config
_language = load_agent_config().agents.profiles.default.language
keyboard = build_approval_keyboard(_language)

# handle 函数中 toast 文字也翻译
toast_ok = "工具操作已通过 ✅" if _language == "zh" else "Tool operation approved ✅"
toast_denied = "工具操作被拒绝 ❌" if _language == "zh" else "Tool operation denied ❌"
```

### 关键细节
- Agent 配置文件中的 `language` 字段默认值为 `"zh"`，用户当前配置已是此值
- 使用 `load_agent_config()` 而非 `load_config()`，因为 `AgentProfileRef` 不含 language 属性
- 原代码中有一个 `_language` 字段（TelegramChannel 无此属性），未生效，改用动态读取

### 部署状态
- ✅ 代码已修改完成
- ⏳ 需要重启 QwenPaw app 服务才能生效（可通过 supervisor 或 `/daemon restart`）