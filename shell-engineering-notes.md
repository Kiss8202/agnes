# 🐚 Shell 脚本工程化最佳实践 (2026-07-26)

> 基于 Google Shell Style Guide + 实战经验，用中文精译

## 一、脚本框架模板（可直接复制）

```bash
#!/bin/bash
#
# 脚本功能描述
# 作者: Agnes
# 日期: 2026-07-26
#

set -euo pipefail    # 关键！见下方详解
export DEBIAN_FRONTEND=noninteractive

# ==================== 常量定义（大写，放在顶部） ====================
readonly WORK_DIR='/etc/sing-box'
readonly TEMP_DIR='/tmp/sing-box'
readonly VERSION='v1.0.0'

# ==================== 工具函数 ====================
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

info() {
  echo "[INFO] $*"
}

# ==================== 清理函数（trap） ====================
cleanup() {
  rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ==================== 主逻辑 ====================
main() {
  local user_input="$1"  # local 声明局部变量
  
  if [[ "${user_input}" == "" ]]; then
    err "参数不能为空"
    exit 1
  fi
  
  info "处理中: ${user_input}"
}

main "$@"
```

---

## 二、set -euo pipefail 详解

这三个标志是脚本安全的基石：

| 标志 | 含义 | 为什么需要 |
|------|------|-----------|
| `-e` | 命令失败立即退出 | 防止错误蔓延 |
| `-u` | 未定义变量报错 | 防止 `${undefined_var}` 静默展开为空 |
| `-o pipefail` | 管道中任一命令失败则整体失败 | 默认只有最后一个命令状态码起作用 |

**例子**: 没有 pipefail 时 `false | true` 会成功（因为 last command 是 true），有 pipefail 会失败。

---

## 三、JSON 生成技巧

### ✅ 正确做法：Heredoc + 大写字母分隔符
```bash
cat > "${WORK_DIR}/config.json" << 'EOF'
{
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [{"password": "${UUID}"}]
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct"}
  ]
}
EOF
```

### ⚠️ Heredoc 坑点
1. **引用分隔符**：`<< 'EOF'` 不展开变量，`<< EOF` 展开变量。生成 JSON 通常用 `<< EOF`（无引号）
2. **注释**：JSON 不支持 `//` 或 `/* */` 注释！如果 JSON 文件需要注释，可以用 YAML 或者写在 shell 文档注释里
3. **缩进**：Heredoc 的缩进要整齐，建议从行首开始

### ❌ 错误示范
```bash
# 不要用 eval
eval "$(generate_config)"

# 不要拼字符串拼接 JSON
config='{"port":'$PORT'}'   # 容易出错
```

### ✅ jq vs sed/awk 的选择
| 场景 | 推荐方案 |
|------|---------|
| 全新生成 JSON | Heredoc（简单快速） |
| 修改已有 JSON 某个字段 | `jq`（安全） |
| 检查/验证 JSON | `sing-box check -c config.json` |
| 复杂条件替换 | `jq`（比 sed 可靠得多） |
| 极大数据量性能敏感 | `sed`（但要有备份） |

**jq 常用操作**：
```bash
# 读取字段
port=$(jq '.inbounds[0].listen_port' config.json)

# 修改字段
jq '.log.level = "debug"' config.json > tmp.json && mv tmp.json config.json

# 添加字段
jq '.experimental.cache_file.enabled = true' config.json > tmp.json && mv tmp.json config.json

# 删除字段
jq 'del(.experimental.clash_api)' config.json > tmp.json && mv tmp.json config.json
```

---

## 四、多发行版兼容

### 系统检测模板
```bash
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID,,}"         # 转为小写
    OS_VERSION="${VERSION_ID}"
  elif [[ -f /etc/redhat-release ]]; then
    OS_ID="centos"
  else
    err "不支持的系统"
    exit 1
  fi
}

install_deps() {
  if [[ "${OS_ID}" =~ (debian|ubuntu) ]]; then
    apt-get update -y
    apt-get install -y curl wget jq
  elif [[ "${OS_ID}" =~ (centos|rhel|fedora) ]]; then
    yum -y install curl wget jq
  elif [[ "${OS_ID}" == "alpine" ]]; then
    apk add --no-cache curl wget jq
  elif [[ "${OS_ID}" == "arch" ]]; then
    pacman -S --noconfirm curl wget jq
  fi
}
```

---

## 五、用户交互设计

### 菜单系统
```bash
menu() {
  local choice
  echo "===== sing-box 管理脚本 ====="
  echo "1). 安装 sing-box"
  echo "2). 卸载 sing-box"
  echo "3). 更新配置"
  echo "4). 查看状态"
  echo "0). 退出"
  echo -n "请输入选择 [0-4]: "
  read -r choice
  
  case "${choice}" in
    1) install_singbox ;;
    2) uninstall_singbox ;;
    3) update_config ;;
    4) show_status ;;
    0) exit 0 ;;
    *) err "无效选择"; return 1 ;;
  esac
}
```

### 确认与重试
```bash
confirm_action() {
  local prompt="$1"
  local max_retries=5
  local retries=0
  
  while (( retries < max_retries )); do
    echo -n "${prompt} [y/N]: "
    read -r yn
    
    case "${yn}" in
      [yY][eE][sS]|[yY]) return 0 ;;
      [nN][oO]|[nN]|"") return 1 ;;
      *) 
        retries=$((retries + 1))
        err "输入无效，剩余尝试次数: $((max_retries - retries))"
        ;;
    esac
  done
  
  err "输入错误达${max_retries}次，脚本退出"
  exit 1
}
```

### 超时控制
```bash
# 使用 timeout 命令
if ! timeout 30s wget -qO- "https://example.com" > /dev/null 2>&1; then
  err "网络超时或不可达"
fi
```

---

## 六、错误处理规范

### 核心原则
1. **所有错误输出到 stderr**（`>&2`）
2. **每次关键命令后检查返回值**
3. **使用 trap 清理临时文件**
4. **给出具体的错误信息，不要只打印命令名**

```bash
# 检查依赖是否存在
check_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    err "缺少必要命令: ${cmd}，请先安装"
    return 1
  fi
}

# 检查端口是否可用
check_port() {
  local port="$1"
  if (( port < 1 || port > 65535 )); then
    err "端口号必须在 1-65535 之间，当前: ${port}"
    return 1
  fi
  if ss -tlnp | grep -q ":${port} "; then
    err "端口 ${port} 已被占用"
    return 1
  fi
}

# 检查配置文件语法
validate_config() {
  local config="$1"
  if ! sing-box check -c "${config}" 2>/dev/null; then
    err "配置文件语法错误: ${config}"
    sing-box check -c "${config}"  # 输出详细错误
    return 1
  fi
}
```

---

## 七、性能优化

### 内置命令优先于外部命令
```bash
# ✅ 快：使用 bash 内置功能
addition=$(( X + Y ))          # 算术
substitution="${string/foo/bar}" # 字符串替换
regex_match="${string##*/}"     # 路径处理

# ❌ 慢：调用外部程序
addition=$(expr "${X}" + "${Y}")
substitution=$(echo "${string}" | sed 's/^foo/bar/')
```

### 避免子shell陷阱
```bash
# ❌ 管道创建子shell，变量不会传递回父shell
last_line=''
your_cmd | while read -r line; do
  last_line="${line}"   # 修改在子shell中，父shell看不到！
done
echo "${last_line}"     # 永远是空

# ✅ 使用进程替代符（不创建子shell）
last_line=''
while read -r line; do
  last_line="${line}"   # 在当前shell中
done < <(your_cmd)
echo "${last_line}"     # 正确输出最后一行

# ✅ 或者用 readarray
readarray -t lines < <(your_cmd)
for line in "${lines[@]}"; do
  last_line="${line}"
done
```

---

## 八、Google Style Guide 要点速查

| 规则 | 说明 |
|------|------|
| 缩进 | 2 空格，不要 tab |
| 行长度 | 最大 80 字符 |
| 变量引用 | `"${var}"` 而不是 `$var` |
| 数组传参 | `"${array[@]}"` 而不是 `${array}` |
| 字符串测试 | `[[ "${str}" == "val" ]]` |
| 数值比较 | `(( a > b ))` 而不是 `[[ a > b ]]` |
| 命令替换 | `$(command)` 而不是 `` `command` `` |
| eval | **绝对不用** |
| 别名 | 用函数代替 |
| 管道检查 | 使用 PIPESTATUS 捕获每个环节 |

---

## 九、Sing-box 专用 Shell 技巧

### Reality 密钥生成
```bash
generate_reality_keys() {
  local keypair
  keypair=$(sing-box generate reality-keypair)
  REALITY_PRIVATE=$(echo "${keypair}" | awk '/PrivateKey/{print $NF}')
  REALITY_PUBLIC=$(echo "${keypair}" | awk '/PublicKey/{print $NF}')
}
```

### jq 动态修改 JSON 片段
```bash
# 为指定协议入站添加 TLS 配置
add_tls_to_inbound() {
  local inbound_file="$1"
  local cert_path="$2"
  local key_path="$3"
  
  jq --arg cert "${cert_path}" \
     --arg key "${key_path}" \
     '.inbounds[0].tls.enabled = true |
      .inbounds[0].tls.certificate_path = $cert |
      .inbounds[0].tls.key_path = $key' \
    "${inbound_file}" > "${inbound_file}.tmp" && \
    mv "${inbound_file}.tmp" "${inbound_file}"
}
```

### 检查服务状态
```bash
check_service() {
  local service_name="$1"
  if systemctl is-active --quiet "${service_name}"; then
    info "✓ ${service_name} 正在运行"
  else
    err "✗ ${service_name} 未运行"
    journalctl -u "${service_name}" --no-pager -n 20
    return 1
  fi
}
```
