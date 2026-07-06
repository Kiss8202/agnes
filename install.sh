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
RELEASE_URL="https://github.com/${REPO}/releases/download/latest/sb-modules.tar.gz"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/modules"

# 下载并解压模块压缩包
download_modules_archive() {
    local tmp_file=$(mktemp /tmp/sb-modules.XXXXXX.tar.gz)
    echo -n "[引导] 下载模块压缩包 ... "
    if curl -sfL --connect-timeout 15 --max-time 60 "${RELEASE_URL}" -o "${tmp_file}" 2>/dev/null; then
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
    for module in core install links dns relay protocols config menu; do
        echo -n "[引导] 下载模块 ${module}.sh ... "
        if curl -sfL --connect-timeout 10 --max-time 30 "${RAW_URL}/${module}.sh" -o "${MODULES_DIR}/${module}.sh" 2>/dev/null; then
            echo "完成"
        else
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
    REMOTE_VERSION=$(curl -sf --connect-timeout 5 --max-time 10 "${RAW_URL}/core.sh" 2>/dev/null | grep '^MODULE_VERSION=' | head -1 | cut -d'"' -f2)

    if [[ -n "$REMOTE_VERSION" && "$REMOTE_VERSION" != "$CURRENT_VERSION" ]]; then
        echo "[引导] 检测到模块更新 (本地: ${CURRENT_VERSION:-未知} → 远程: ${REMOTE_VERSION})，正在更新..."
        return 0  # 需要更新
    fi
    return 1  # 不需要更新
}

if [[ ! -d "$MODULES_DIR" ]]; then
    # 模块目录不存在，首次安装
    echo "[引导] 模块目录不存在，正在从 Releases 下载..."
    if ! download_modules_archive; then
        echo "[引导] Releases 下载失败，回退到逐个下载..."
        if ! download_modules_raw; then
            echo "错误: 所有下载方式均失败，请检查网络连接"
            exit 1
        fi
    fi
else
    # 模块目录已存在，检查是否需要更新
    if check_version_update; then
        # 优先从 Releases 下载
        if ! download_modules_archive; then
            echo "[引导] Releases 下载失败，回退到逐个下载..."
            for module in core install links dns relay protocols config menu; do
                echo -n "[引导] 更新模块 ${module}.sh ... "
                if curl -sfL --connect-timeout 10 --max-time 30 "${RAW_URL}/${module}.sh" -o "${MODULES_DIR}/${module}.sh" 2>/dev/null; then
                    echo "完成"
                else
                    echo "失败（保留旧版本）"
                fi
            done
        fi
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
source "${MODULES_DIR}/menu.sh"     || { echo "错误: 无法加载 menu.sh"; exit 1; }

# 启动主函数
main "$@"
