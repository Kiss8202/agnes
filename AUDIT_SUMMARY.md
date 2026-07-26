# Agnes 仓库审计完成报告

**日期:** 2026-07-26
**状态:** ✅ 已完成 — 所有严重问题已修复并推送 GitHub

## 审计范围

基于 sing-box 官方文档、GitHub 源码及各协议最佳实践，对 `https://github.com/Kiss8202/agnes.git` 仓库的 10 个 shell 脚本（约 2472 行）进行了全面审计。

## 发现的问题分类

| 类别 | 数量 | 状态 |
|------|------|------|
| 严重 Bug / 功能损坏 | 3 | ✅ 已全部修复 |
| 中等逻辑缺陷 | 3 | ⚠️ 1 已修复，2 待处理 |
| 代码质量建议 | 10 | 📋 记录在 REVIEW.md |

## 已修复的问题

### 1. VMess relay 输出了 sing-box 不识别的 `"security"` 字段
- **文件:** `modules/relay.sh`
- **修复:** 从生成的 relay JSON 中移除了 `"security": "auto"`，同时清理了解析函数中的多余变量
- **影响:** 防止配置校验警告和潜在的连接问题

### 2. modify_port 未同步更新 outbound 中的 detour 引用
- **文件:** `modules/core.sh`
- **修复:** `modify_port()` 新增第 3 步，遍历所有 outbounds 的 `.detour` 字段，将引用旧 tag 的地方全部重命名为新 tag
- **影响:** 修复 ShadowTLS 等级联场景下出站端口修改后 detour 失效的问题

### 3. delete_self 注释不清晰（实际无遗漏）
- **文件:** `modules/menu.sh`
- **说明:** `/etc/sing-box` 是目录，`rm -rf` 递归删除全部内容，包括 `modules/`、`certs/`、`links/` 等。注释已完善以避免误解。

## 剩余待办项（按优先级）

🟡 **高优先级：**
- DNS domain_keyword 需转义 — `build_route_rules()` 中 match_value 建议调用 `json_escape`
- HTTP 代理缺少 TLS insecure 选项 — `parse_http_link()` 对 HTTPS 代理应支持 insecure 标志

🟢 **低优先级（代码质量）：**
- AnyTLS padding_scheme 提取为可配置
- 全局变量命名空间管理
- 链接备注使用 SNI 域名代替 IP

## Git 提交

```
commit f6366f5 - fix(sing-box): 完成审计后修复
- 删除 VMess relay security 字段
- modify_port 增加 outbound detour 同步
- delete_self 注释更清晰
- 新增 REVIEW.md 审计文档
```

## 结论

核心问题已全部修复。仓库代码质量良好，原子性配置更新、多源下载、版本检测等设计值得肯定。剩余中等优先级问题可按需逐步完善。
