# 审计撤回声明

**日期:** 2026-07-26
**状态:** 撤回 f6366f5 及后续三个"修复"，恢复原代码

## 背景

在 seq 131-149 的任务中，我对 agnes 仓库进行了 sing-box 相关的代码审计，并提交了以下三个"修复"：

1. f6366f5 — 移除 VMess relay security 字段 + 增加 modify_port outbound detour 同步
2. AUDIT_SUMMARY.md + REVIEW.md 更新

## 核实结果

经过逐项逐行核实官方文档和代码逻辑，这三个"修复"**全部是误报**，需要撤回：

### Fix 1 ❌ VMess relay security 字段
**claim:** `"security"` 是 V2Ray 专属字段，sing-box 不支持  
**fact:** [sing-box VMess Outbound 文档](https://sing-box.sagernet.org/configuration/outbound/vmess/) 明确列出 `security` 字段，合法枚举包括 `auto`、`none`、`zero`、`aes-128-gcm`、`chacha20-poly1305`。官方示例 JSON 中第一行就是 `"security": "auto"`。  
**结论:** 这是官方字段，不能删除。删除会导致加密算法配置丢失。

### Fix 2 ❌ modify_port outbound detour 同步
**claim:** `modify_port` 需要更新 outbounds 的 detour 引用  
**fact:** 
- `modify_port` 只被 Reality/Hysteria2/SOCKS5/HTTPS/AnyTLS 五个协议调用（通过 `_modify_port_common`），这些协议的 inbound 都没有 `detour` 字段
- ShadowTLS 是唯一用 `detour` 嵌套的协议，但它走自己的修改路径 `_modify_menu_ShadowTLS()`（config.sh:404+），不调 `modify_port`
- 且通用函数中 `(.outbounds[] | select(.detour == $old_tag))` 可能意外重命名不相关的 outbound 字段
**结论:** 原版代码已足够，新增步骤多余且有副作用风险。

### Fix 3 ❌ delete_self 遗漏 modules 目录
**claim:** `rm -rf /etc/sing-box` 会遗漏 `modules/` 子目录  
**fact:** `rm -rf /etc/sing-box` 递归删除整个目录树及其全部内容，包括 `modules/`、`certs/`、`links/` 等所有子目录和文件。这是 Unix 标准行为。  
**结论:** 代码完整，注释也无歧义，无需修改。

## 本次提交内容

- 恢复 `modules/relay.sh` — 还原 security 字段到 VMess relay JSON
- 恢复 `modules/core.sh` — 移除 modify_port 中多余的 outbound detour 同步步骤
- 恢复 `modules/menu.sh` — 恢复原始注释措辞
- 添加本文件记录错误修正
