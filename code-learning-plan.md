# 📚 代码能力提升计划 (2026-07-26 制定)

## 🕐 学习时间规划

**每日学习时段：北京时间 03:00-07:00（我活跃但你可能在睡觉，不打扰你）**
- 每天约 4 小时
- 每个知识点学完就写笔记（中文），推送到 GitHub
- 学完一个标记一个 ✅
- 不拖沓，有明确产出

## 🎯 学习计划

### Phase 1: Linux Shell 脚本工程化（第1-2天）
- [x] Bash/Shell 脚本最佳实践
- [x] JSON 处理技巧（jq vs sed/awk）
- [x] Heredoc 生成 JSON 的技巧和坑
- [x] 配置文件分段管理 vs 单文件管理
- [x] sing-box merge/directory 两种模式
- [x] 四大主流脚本对比分析
- [ ] 错误处理与用户交互设计
- [ ] 多发行版兼容（Debian/CentOS/Alpine/Fedora/Arch）
- **产出**: shell-engineering-notes.md

### Phase 2: 网络协议深度（第3-7天）
- [x] sing-box 整体配置架构（13个顶层字段）
- [x] Rule Set (SRS) 三种类型 + 1.14.0 变更
- [x] DNS 15+ 种服务器类型 + optimistic cache
- [x] Route 路由引擎 + find_neighbor
- [x] ACME 证书管理（ed25519/key_type/profile）
- [x] Hysteria2 1.14.0 大更新
- [x] VLESS config 结构
- [x] Clash API + 配置迁移
- [x] Endpoint 替代 wireguard outbound
- [ ] Reality/TLS fingerprinting/SNI/OBfuscation
- [ ] Hysteria2/QUIC 协议底层原理
- [ ] TUIC v5/IETF QUIC 特性
- [ ] ShadowTLS v3 实现细节
- [ ] NaiveProxy/HTTP CONNECT 隧道原理
- [ ] WARP/Wireguard 工作原理
- **产出**: sing-box-official-doc-study.md

### Phase 3: 系统运维知识（第8-10天）
- [ ] systemd service 文件编写规范
- [ ] Nginx 反向代理配置（WebSocket/gRPC/TLS）
- [ ] Caddy 自动 HTTPS 和 ACME 证书
- [ ] Firewall/UFW/firewalld 规则管理
- [ ] DNS over HTTPS/DoT/DoH3 配置
- [ ] Log rotation (logrotate) 配置
- [ ] Cloudflare Turnstile CAPTCHA 集成
- [ ] Argo Tunnel 配置（固定域名 vs 临时隧道）
- [ ] BBR 拥塞控制算法原理
- **产出**: sysadmin-notes.md

### Phase 4: Go 语言基础 — 读 sing-box 源码（第11-18天）
- [ ] Go 基础语法和类型系统
- [ ] struct + interface 的基本用法
- [ ] JSON tag 和反序列化
- [ ] context 和 goroutine 基本模型
- [ ] Read the sing-box source code: core/config 加载流程
- [ ] Read the source: routing engine 实现
- [ ] Read the source: inbound/outbound 注册机制
- [ ] Read the source: realitiy 密钥生成代码
- **产出**: go-lang-notes.md, singbox-source-read-notes.md

### Phase 5: 编写自己的完整安装脚本（第19-25天）
- [ ] 从零搭建一个多协议 VPS 安装脚本
- [ ] 实现 Reality + Hysteria2 + TUIC + VLESS 全协议
- [ ] 接入 WARP 出站 + 自定义路由规则
- [ ] 支持 Clash Meta YAML + Base64 订阅
- [ ] 支持系统检测、依赖安装、服务部署
- [ ] 热更新（SIGHUP reload）支持
- [ ] 完整的安装/卸载/更新/诊断菜单
- **产出**: my-installer.sh（原创脚本）+ README.md

### Phase 6: 进阶能力（第26-35天）
- [ ] Docker Compose 一键部署方案
- [ ] Web UI 控制面板开发（可选）
- [ ] 监控和日志分析脚本
- [ ] CI/CD 自动化测试
- [ ] 编写 SKILL.md 沉淀所有经验

## 📋 学习方式
- 官方文档逐行精读（中文翻译）
- GitHub 优质脚本源码对比分析
- CLI 工具链实践（curl/wget/jq/openssl/dig/systemctl）
- 笔记全部用中文写，推送到 GitHub 持久保存

## 📊 进度追踪
- 每天学习完成自动更新此计划
- 已完成的部分标记 ✅，待完成保持 [ ]
- 所有学习笔记推送至 agnes-repo 仓库
