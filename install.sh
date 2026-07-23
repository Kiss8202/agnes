#!/bin/sh
# POSIX sh 引导：检测 bash 是否可用，不可用则安装后用 bash 重新执行
if [ -z "$BASH_VERSION" ]; then
    if ! command -v bash >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            echo "[引导] Alpine 系统，正在安装 bash ..."
            apk add --no-cache bash gcompat >/dev/null 2>&1
        elif command -v apt-get >/dev/null 2>&1; then
            echo "[引导] 正在安装 bash ..."
            apt-get update -qq && apt-get install -y bash >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y bash >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y bash >/dev/null 2>&1
        fi
    fi
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "错误: 需要 bash，请先安装 (Alpine: apk add bash; Debian: apt install bash)"
    exit 1
fi

# ==================== 模块加载 ====================
# 模块目录固定使用 /etc/sing-box/modules，确保 sb 快捷命令和首次安装路径一致
MODULES_DIR="/etc/sing-box/modules"
REPO="Kiss8202/Trae"

# ==================== GitHub 镜像支持 ====================
# 环境变量 GH_MIRROR 可手动指定镜像前缀，例如：
#   GH_MIRROR=https://ghfast.top bash install.sh
# 如果未设置，自动从配置文件恢复；仍为空则尝试国内镜像列表
GH_MIRROR="${GH_MIRROR:-}"
# 尝试从已保存的配置文件恢复镜像设置
if [[ -z "$GH_MIRROR" ]] && [[ -f "/etc/sing-box/ip_config.conf" ]]; then
    _saved_mirror=$(grep '^GH_MIRROR=' "/etc/sing-box/ip_config.conf" 2>/dev/null | head -1 | cut -d'"' -f2)
    [[ -n "$_saved_mirror" ]] && GH_MIRROR="$_saved_mirror"
    unset _saved_mirror
fi

# GitHub 直连 URL
GH_RELEASE_URL="https://github.com/${REPO}/releases/download/latest/sb-modules.tar.gz"
GH_RAW_URL="https://raw.githubusercontent.com/${REPO}/main/modules"
GH_INSTALL_RAW_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"

# 国内镜像列表（镜像前缀 + GitHub 原始 URL = 镜像 URL）
# 格式：镜像会拼接原始 GitHub URL，如 https://ghfast.top/https://github.com/...
GH_MIRRORS=(
    "https://ghfast.top"
    "https://gh-proxy.com"
    "https://gh.api.999888y.com"
)

# 生成镜像 URL 列表
build_download_urls() {
    local base_url="$1"
    local urls=("$base_url")
    # 如果手动指定了镜像，优先使用
    if [[ -n "$GH_MIRROR" ]]; then
        urls=("${GH_MIRROR}/${base_url}" "$base_url")
    else
        # 自动添加镜像列表
        for mirror in "${GH_MIRRORS[@]}"; do
            urls+=("${mirror}/${base_url}")
        done
    fi
    echo "${urls[@]}"
}

# 多源下载：依次尝试 URL 列表，第一个成功即返回
multi_source_download() {
    local output_file="$1"
    shift
    local urls=("$@")
    for url in "${urls[@]}"; do
        if curl -sfL --connect-timeout 10 --max-time 60 "${url}" -o "${output_file}" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

# 下载并解压模块压缩包
download_modules_archive() {
    local tmp_file=$(mktemp /tmp/sb-modules.XXXXXX.tar.gz)
    echo -n "[引导] 下载模块压缩包 ... "

    local release_urls=($(build_download_urls "$GH_RELEASE_URL"))
    if multi_source_download "${tmp_file}" "${release_urls[@]}"; then
        # 验证是否为有效的 gzip 文件
        if tar -tzf "${tmp_file}" >/dev/null 2>&1; then
            mkdir -p "${MODULES_DIR}"
            if tar -xzf "${tmp_file}" -C "${MODULES_DIR}" 2>/dev/null; then
                rm -f "${tmp_file}"
                echo "完成"
                return 0
            else
                echo "解压失败"
                rm -f "${tmp_file}"
                return 1
            fi
        else
            echo "文件无效"
            rm -f "${tmp_file}"
            return 1
        fi
    else
        echo "下载失败"
        rm -f "${tmp_file}"
        return 1
    fi
}

# 逐个下载模块文件（回退方案）
download_modules_raw() {
    mkdir -p "${MODULES_DIR}"
    for module in core install links dns relay protocols config tune menu; do
        echo -n "[引导] 下载模块 ${module}.sh ... "
        local raw_urls=($(build_download_urls "${GH_RAW_URL}/${module}.sh"))
        local tmp_mod
        tmp_mod=$(mktemp /tmp/sb-mod.XXXXXX.sh) || { echo "失败（创建临时文件失败）"; return 1; }
        if multi_source_download "${tmp_mod}" "${raw_urls[@]}"; then
            # 校验下载内容：必须是 shell 脚本（shebang 或注释开头），防止镜像返回 HTML 错误页被 source 执行
            if [[ ! -s "${tmp_mod}" ]] || ! head -1 "${tmp_mod}" | grep -qE '^#!|^#'; then
                rm -f "${tmp_mod}"
                echo "失败（内容无效）"
                echo "错误: 模块 ${module}.sh 下载内容不是有效的 shell 脚本，可能镜像返回了错误页"
                return 1
            fi
            mv "${tmp_mod}" "${MODULES_DIR}/${module}.sh"
            echo "完成"
        else
            rm -f "${tmp_mod}"
            echo "失败"
            echo "错误: 无法下载模块 ${module}.sh，请检查网络连接"
            return 1
        fi
    done
    return 0
}

# 检查本地版本与远程版本是否一致
check_version_update() {
    local CURRENT_VERSION=""
    if [[ -f "${MODULES_DIR}/core.sh" ]]; then
        CURRENT_VERSION=$(grep '^MODULE_VERSION=' "${MODULES_DIR}/core.sh" 2>/dev/null | head -1 | cut -d'"' -f2)
    fi
    local REMOTE_VERSION=""
    local raw_urls=($(build_download_urls "${GH_RAW_URL}/core.sh"))
    local tmp_ver=$(mktemp /tmp/sb-ver.XXXXXX)
    if multi_source_download "${tmp_ver}" "${raw_urls[@]}"; then
        REMOTE_VERSION=$(grep '^MODULE_VERSION=' "${tmp_ver}" 2>/dev/null | head -1 | cut -d'"' -f2)
        rm -f "${tmp_ver}"
    fi

    if [[ -n "$REMOTE_VERSION" && "$REMOTE_VERSION" != "$CURRENT_VERSION" ]]; then
        echo "[引导] 检测到模块更新 (本地: ${CURRENT_VERSION:-未知} → 远程: ${REMOTE_VERSION})，正在更新..."
        return 0  # 需要更新
    fi
    return 1  # 不需要更新
}

# 自更新 install.sh 引导脚本本身（避免引导脚本与新模块版本不一致导致函数丢失）
# 用法: self_update_install
self_update_install() {
    # 注意：此时 core.sh 还未 source，SCRIPT_PATH 变量不存在
    # 用 BASH_SOURCE 探测实际脚本路径，回退到固定路径
    local self_path="${BASH_SOURCE[0]:-$0}"
    # 如果是进程替换或 stdin，跳过
    if [[ "$self_path" == /dev/fd/* ]] || [[ "$self_path" == /dev/stdin ]] || [[ ! -f "$self_path" ]]; then
        self_path="/etc/sing-box/install.sh"
    fi
    # 仍然不存在则跳过
    if [[ ! -f "$self_path" ]]; then
        return 0
    fi

    local install_urls=($(build_download_urls "$GH_INSTALL_RAW_URL"))
    # 临时文件放在目标同目录，保证 mv 原子替换（同文件系统）
    local tmp_install
    tmp_install=$(mktemp "${self_path}.XXXXXX.sh") || { echo "[引导] 自更新创建临时文件失败"; return 0; }
    if ! multi_source_download "$tmp_install" "${install_urls[@]}"; then
        rm -f "$tmp_install"
        echo "[引导] install.sh 自更新下载失败，继续使用本地版本"
        return 0
    fi

    # 校验下载内容：必须是 bash 脚本且包含 MODULES_DIR 标志
    if ! head -1 "$tmp_install" | grep -q '^#!' || ! grep -q 'MODULES_DIR=' "$tmp_install" 2>/dev/null; then
        echo "[引导] 下载的 install.sh 校验失败，跳过自更新"
        rm -f "$tmp_install"
        return 0
    fi

    # 内容未变化则跳过（避免无意义的 exec 重新执行）
    local old_md5 new_md5
    old_md5=$(md5sum "$self_path" 2>/dev/null | awk '{print $1}')
    new_md5=$(md5sum "$tmp_install" 2>/dev/null | awk '{print $1}')
    if [[ "$old_md5" == "$new_md5" ]]; then
        rm -f "$tmp_install"
        return 0
    fi

    # 备份旧版本，原子替换，失败可回滚
    cp -p "$self_path" "${self_path}.bak" 2>/dev/null
    if ! mv "$tmp_install" "$self_path"; then
        echo "[引导] 自更新替换失败，回滚到旧版本"
        mv "${self_path}.bak" "$self_path" 2>/dev/null
        rm -f "$tmp_install"
        return 0
    fi
    rm -f "${self_path}.bak"
    chmod +x "$self_path"
    echo "[引导] install.sh 引导脚本已更新，重新执行以加载新版本..."
    exec bash "$self_path" "$@"
}

if [[ ! -d "$MODULES_DIR" ]]; then
    # 模块目录不存在，首次安装
    echo "[引导] 模块目录不存在，正在从 Releases 下载..."
    if ! download_modules_archive; then
        echo "[引导] Releases 下载失败，回退到逐个下载..."
        if ! download_modules_raw; then
            echo "错误: 所有下载方式均失败，请检查网络连接"
            echo "提示: 国内机器可设置镜像: GH_MIRROR=https://ghfast.top bash install.sh"
            exit 1
        fi
    fi
else
    # 模块目录已存在，检查是否需要更新
    if check_version_update; then
        # 优先从 Releases 下载
        if ! download_modules_archive; then
            echo "[引导] Releases 下载失败，回退到逐个下载..."
            # 复用 download_modules_raw 的校验逻辑，但允许单个失败保留旧版本
            mkdir -p "${MODULES_DIR}"
            for module in core install links dns relay protocols config tune menu; do
                echo -n "[引导] 更新模块 ${module}.sh ... "
                local raw_urls=($(build_download_urls "${GH_RAW_URL}/${module}.sh"))
                local tmp_mod
                tmp_mod=$(mktemp /tmp/sb-mod.XXXXXX.sh) || { echo "失败（创建临时文件失败）"; continue; }
                if multi_source_download "${tmp_mod}" "${raw_urls[@]}" \
                   && [[ -s "${tmp_mod}" ]] \
                   && head -1 "${tmp_mod}" | grep -qE '^#!|^#'; then
                    mv "${tmp_mod}" "${MODULES_DIR}/${module}.sh"
                    echo "完成"
                else
                    rm -f "${tmp_mod}"
                    echo "失败（保留旧版本）"
                fi
            done
        fi
        # 同步更新 install.sh 本身并重新执行（避免引导脚本与新模块不一致）
        self_update_install "$@"
    fi
fi

# 按顺序加载模块
source "${MODULES_DIR}/core.sh"     || { echo "错误: 无法加载 core.sh"; exit 1; }
source "${MODULES_DIR}/install.sh"  || { echo "错误: 无法加载 install.sh"; exit 1; }
source "${MODULES_DIR}/links.sh"    || { echo "错误: 无法加载 links.sh"; exit 1; }
source "${MODULES_DIR}/dns.sh"      || { echo "错误: 无法加载 dns.sh"; exit 1; }
source "${MODULES_DIR}/relay.sh"    || { echo "错误: 无法加载 relay.sh"; exit 1; }
source "${MODULES_DIR}/protocols.sh"|| { echo "错误: 无法加载 protocols.sh"; exit 1; }
source "${MODULES_DIR}/config.sh"   || { echo "错误: 无法加载 config.sh"; exit 1; }
source "${MODULES_DIR}/tune.sh"     || { echo "错误: 无法加载 tune.sh"; exit 1; }
source "${MODULES_DIR}/menu.sh"     || { echo "错误: 无法加载 menu.sh"; exit 1; }

# 启动主函数
main "$@"
