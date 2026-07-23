# sing-box 一键管理脚本

基于 sing-box 的代理节点一键部署与管理脚本，支持多种协议、中转、域名分流、网络调优。

## 安装

### 国际机器
```bash
wget -O /root/install.sh https://raw.githubusercontent.com/kiss8202/Trae/main/install.sh && bash /root/install.sh
```

### 国内机器（使用镜像）
```bash
wget -O /root/install.sh https://ghfast.top/https://raw.githubusercontent.com/Kiss8202/Trae/main/install.sh && bash /root/install.sh
```

或指定镜像变量（推荐，模块下载也会走镜像）：
```bash
GH_MIRROR=https://ghfast.top bash <(curl -sfL https://raw.githubusercontent.com/Kiss8202/Trae/main/install.sh)
```

安装完成后输入 `sb` 即可进入管理菜单。

## 功能

### 协议支持
- **VLESS Reality** - 抗审查最强，伪装真实 TLS，无需证书
- **Hysteria2** - 基于 QUIC，速度快，适合垃圾线路
- **SOCKS5** - 适合中转的代理协议
- **ShadowTLS v3** - TLS 流量伪装
- **HTTPS** - 标准 HTTPS，可过 CDN
- **AnyTLS** - 通用 TLS 协议，可启用 REALITY 伪装

### 中转与分流
- 中转配置（添加/修改/删除）
- 域名分流（按域名匹配走指定中转）
- 支持多种中转协议（VLESS/Hysteria2/Trojan/SOCKS5/AnyTLS 等）

### DNS 配置
- 自定义 DNS 服务器
- DNS 分流规则
- 预设 DNS 方案（Google/Cloudflare/阿里/国内）

### 出入站配置
- IPv4 / IPv6 / 双栈模式切换
- 入站监听地址控制
- 出站连接模式控制

### 网络调优（BBR + SWAP）
- **BBR v3 拥塞控制** - 自动检测内核版本并启用
- **TCP 缓冲区** - 基于 BDP 估算，支持交互式输入带宽/RTT 精准计算
- **宽带缓存/backlog** - 根据 CPU 核心数自动建议
- **SWAP 虚拟内存** - 自动创建 swap 文件防 OOM，小内存 VPS 友好
- **交互式调优** - 检测 VPS 配置后给出建议值，回车即用，可手动输入
- **一键恢复** - 调优前自动备份原值，可随时恢复
- **容器检测** - 自动识别 OpenVZ/LXC/Docker 环境，避免误操作

## 使用

安装后运行 `sb` 进入主菜单：

```
[1] 添加/继续添加节点
[2] 中转配置 (添加/配置/删除/域名分流)
[3] 出入站配置 (IPv4/IPv6)
[4] 配置/查看节点
[5] 重新生成链接文件
[6] 一键删除脚本并退出
[7] DNS 配置
[8] 网络调优
[0] 退出脚本
```

## 系统要求

- Linux 4.9+（BBR 需要内核支持，Debian 13 内置 BBR v3）
- root 权限
- 支持 Debian/Ubuntu/Alpine
- 架构：amd64 / arm64

## 安全设计

- **不安装任何第三方软件** - 调优模块仅修改 sysctl 参数和创建 swap 文件
- **所有改动可恢复** - 调优前自动备份原值
- **独立配置文件** - 调优写入 `/etc/sysctl.d/99-sing-box-tuning.conf`，不污染主配置
- **下载内容校验** - 模块下载后校验 shebang，防止镜像返回 HTML 错误页被执行
- **sing-box sha256 校验** - 下载后自动校验完整性
- **原子更新** - 配置文件更新使用临时文件原子替换，中断不会损坏配置

## 镜像支持

国内机器如果拉取 GitHub 失败，可设置 `GH_MIRROR` 环境变量：

| 镜像 | 地址 |
|---|---|
| ghfast | `https://ghfast.top` |
| gh-proxy | `https://gh-proxy.com` |
| 999888y | `https://gh.api.999888y.com` |

设置后会持久化到 `/etc/sing-box/ip_config.conf`，后续 `sb` 自动使用。
