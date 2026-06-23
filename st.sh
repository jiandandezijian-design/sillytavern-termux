#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
# 🍊 橘子酒馆 · Termux 一键部署与管理 v2.0
# 全国内源加速 · 无需梯子 · 打开 Termux 自动弹出菜单
#==========================================================================

# ---- 常量 ----
INSTALL_DIR="$HOME/SillyTavern"
MENU_FILE="$HOME/st-menu.sh"
BACKUP_DIR="$HOME/SillyTavern_Backups"

# ---- 颜色 ----
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; BOLD=''; NC=''
fi

# ---- 工具函数 ----
check_installed() { [ -f "$INSTALL_DIR/start.sh" ]; }
is_running() { pgrep -f "node.*server.js" >/dev/null 2>&1; }
status_text() {
    if is_running; then echo -e "${GREEN}🟢 运行中 → http://127.0.0.1:8000${NC}"
    else echo -e "${YELLOW}🔴 未运行${NC}"; fi
}

header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║   🍊 橘子酒馆 · Termux 控制面板     ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    status_text
    echo ""
}

show_menu() {
    echo -e "  ${BOLD}═══ 管理 ═══${NC}"
    echo -e "  ${GREEN}[1]${NC} 启动  ${GREEN}[2]${NC} 停止  ${GREEN}[3]${NC} 重启"
    echo ""
    echo -e "  ${BOLD}═══ 维护 ═══${NC}"
    echo -e "  ${BLUE}[4]${NC} 更新  ${BLUE}[5]${NC} 日志  ${BLUE}[6]${NC} 切换分支"
    echo ""
    echo -e "  ${BOLD}═══ 数据 ═══${NC}"
    echo -e "  ${YELLOW}[7]${NC} 备份  ${YELLOW}[8]${NC} 恢复"
    echo ""
    echo -e "  ${RED}[9]${NC} 卸载  ${RED}[0]${NC} 退出"
    echo ""
}

read_input() {
    # 安全读取用户输入，超时不卡
    local prompt="$1" default="$2" var="$3"
    printf "%s" "$prompt"
    read -r REPLY
    eval "$var=\${REPLY:-\$default}"
}

# ======================================
# 首次安装（独立函数，不依赖任何外部定义）
# ======================================
do_install() {
    clear
    echo "  🍊 橘子酒馆 · 首次安装"
    echo "  ========================"
    echo ""

    # [1/5] 换清华源
    echo "[1/5] 配置国内镜像..."
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y
    echo "  ✓ Termux → 清华镜像"

    # [2/5] 装 git + nodejs
    echo "[2/5] 安装运行环境..."
    pkg install -y git nodejs-lts 2>/dev/null || { echo "  ✗ 依赖安装失败"; return 1; }
    echo "  ✓ Node.js $(node -v)"

    # [3/5] npm 淘宝源
    echo "[3/5] 配置 npm 加速..."
    npm config set registry https://registry.npmmirror.com 2>/dev/null || true
    echo "  ✓ npm → npmmirror"

    # [4/5] 克隆酒馆（多代理轮换）
    echo "[4/5] 下载酒馆源码..."
    cd ~
    MIRRORS="
https://gh.api.99988866.xyz/https://github.com/SillyTavern/SillyTavern
https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern
https://gh.llkk.cc/https://github.com/SillyTavern/SillyTavern
https://gh.xiu2.xyz/https://github.com/SillyTavern/SillyTavern
https://github.com/SillyTavern/SillyTavern
"
    OK=0
    for URL in $MIRRORS; do
        echo "  → $URL"
        if git clone "$URL" -b release "$INSTALL_DIR" --depth 1 2>/dev/null; then
            echo "  ✓ release 分支"; OK=1; break
        fi
        if git clone "$URL" -b staging "$INSTALL_DIR" --depth 1 2>/dev/null; then
            echo "  ✓ staging 分支"; OK=1; break
        fi
    done
    if [ "$OK" != "1" ]; then
        echo "  ✗ 克隆失败，请检查网络后重试"
        return 1
    fi
    cd "$INSTALL_DIR"
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    # [5/5] npm install
    echo "[5/5] 安装项目依赖（约 2-3 分钟）..."
    npm install --no-audit --no-fund 2>/dev/null || npm install
    echo "  ✓ 依赖安装完成"

    # 创建备份目录
    mkdir -p "$BACKUP_DIR"

    # 保存菜单脚本到 ~/st-menu.sh
    SCRIPT_SRC=""
    [ -f "$HOME/st.sh" ] && SCRIPT_SRC="$HOME/st.sh"
    [ -f "./st.sh" ] && SCRIPT_SRC="./st.sh"
    if [ -n "$SCRIPT_SRC" ] && [ -f "$SCRIPT_SRC" ]; then
        cp "$SCRIPT_SRC" "$MENU_FILE"
        chmod +x "$MENU_FILE"
    fi

    # 写入 .bashrc 自动启动
    if ! grep -q "st-menu.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo '# 🍊 橘子酒馆自动菜单' >> "$HOME/.bashrc"
        echo 'if [ -f "$HOME/st-menu.sh" ]; then bash "$HOME/st-menu.sh"; fi' >> "$HOME/.bashrc"
    fi

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║   🍊 安装完成！                     ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
    echo "  💡 现在输入 1 启动酒馆"
    echo ""
}

# ======================================
# 菜单功能
# ======================================
fn_start() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    if is_running; then echo -e "${GREEN}已在运行${NC}"; return; fi
    echo -e "${GREEN}启动中...${NC}"
    cd "$INSTALL_DIR"
    nohup bash start.sh > "$INSTALL_DIR/nohup.out" 2>&1 &
    sleep 3
    echo -e "${GREEN}✓ 已启动 → http://127.0.0.1:8000${NC}"
}

fn_stop() {
    pkill -f "node.*server.js" 2>/dev/null || true
    sleep 1
    pkill -9 -f "node.*server.js" 2>/dev/null || true
    echo -e "${GREEN}✓ 已停止${NC}"
}

fn_restart() { fn_stop; sleep 1; fn_start; }

fn_update() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR"
    echo -e "${CYAN}更新中...${NC}"
    git remote set-url origin https://gh.api.99988866.xyz/https://github.com/SillyTavern/SillyTavern 2>/dev/null || true
    git pull --rebase --autostash 2>/dev/null || git pull 2>/dev/null
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true
    npm install --no-audit --no-fund 2>/dev/null || true
    echo -e "${GREEN}✓ 更新完成${NC}"
    printf "是否启动？[Y/n] "; read -r YN; [ "$YN" != "n" ] && [ "$YN" != "N" ] && fn_start
}

fn_logs() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    echo -e "${CYAN}=== 最近 30 行 ===${NC}"
    if [ -f "$INSTALL_DIR/nohup.out" ]; then
        tail -30 "$INSTALL_DIR/nohup.out"
    else
        echo "(无日志)"
    fi
    printf "按回车返回..."; read -r _
}

fn_switch() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR"
    echo "当前: $(git branch --show-current 2>/dev/null)"
    echo "[1] release  [2] staging"
    printf "选择: "; read -r BR
    case "$BR" in 1) T="release";; 2) T="staging";; *) echo "取消"; return;; esac
    git fetch --all 2>/dev/null; git checkout "$T" 2>/dev/null; git pull 2>/dev/null
    npm install --no-audit --no-fund 2>/dev/null || true
    echo -e "${GREEN}✓ 已切换 $T${NC}"
}

fn_backup() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    mkdir -p "$BACKUP_DIR"
    NAME="ST_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${CYAN}备份中...${NC}"
    cd "$INSTALL_DIR"
    tar czf "$BACKUP_DIR/$NAME" data/ 2>/dev/null
    echo -e "${GREEN}✓ $BACKUP_DIR/$NAME ($(du -h "$BACKUP_DIR/$NAME" | cut -f1))${NC}"
    printf "按回车返回..."; read -r _
}

fn_restore() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return; fi
    FILES=$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null || true)
    if [ -z "$FILES" ]; then
        echo -e "${RED}无备份文件，请将 .tar.gz 放到 SillyTavern_Backups/${NC}"
        printf "按回车返回..."; read -r _; return
    fi
    echo "可用备份:"
    i=1; for f in $FILES; do echo "  [$i] $(basename "$f")"; i=$((i+1)); done
    echo "  [0] 取消"
    printf "选择: "; read -r N
    [ "$N" = "0" ] || [ -z "$N" ] && return
    FILE=$(echo "$FILES" | sed -n "${N}p")
    [ ! -f "$FILE" ] && { echo "无效"; return; }
    printf "确认覆盖当前数据？[y/N] "; read -r CF
    [ "$CF" != "y" ] && [ "$CF" != "Y" ] && return
    fn_stop 2>/dev/null || true
    cd "$INSTALL_DIR"; rm -rf data; tar xzf "$FILE"
    echo -e "${GREEN}✓ 已恢复${NC}"
}

fn_uninstall() {
    echo -e "${RED}⚠️ 删除所有酒馆文件${NC}"
    printf "输入 YES 确认: "; read -r CF
    [ "$CF" != "YES" ] && return
    fn_stop 2>/dev/null || true
    rm -rf "$INSTALL_DIR" "$MENU_FILE"
    sed -i '/st-menu.sh/d' "$HOME/.bashrc" 2>/dev/null || true
    echo -e "${GREEN}✓ 已卸载，备份目录保留${NC}"
    exit 0
}

# ======================================
# 主入口
# ======================================

# 检测运行模式：是安装脚本还是菜单脚本
# 如果是首次安装（curl下载的 st.sh），没有 ~/st-menu.sh
# 正常模式：~/.st-menu.sh 已存在
IS_FRESH_INSTALL=0
if [ ! -f "$MENU_FILE" ]; then
    IS_FRESH_INSTALL=1
fi

if [ "$IS_FRESH_INSTALL" = "1" ]; then
    # ---- 首次安装 ----
    do_install

    # 安装完成后把自身保存为菜单文件
    # 从 PATH 或当前目录查找 st.sh
    if [ -f "$HOME/st.sh" ]; then
        cp "$HOME/st.sh" "$MENU_FILE"
        chmod +x "$MENU_FILE"
    elif [ -f "./st.sh" ]; then
        cp "./st.sh" "$MENU_FILE"
        chmod +x "$MENU_FILE"
    fi

    # 如果没有成功保存菜单，用自身存
    if [ ! -f "$MENU_FILE" ]; then
        echo "  ⚠ 无法保存菜单脚本，请手动复制"
    fi

    echo ""
    header
    show_menu
else
    # ---- 正常模式：已有菜单，直接显示 ----
    header
    show_menu
fi

# 检查安装状态
if ! check_installed; then
    echo -e "${RED}酒馆文件丢失，重新安装...${NC}"
    do_install
    header
    show_menu
fi

# 主循环
while true; do
    printf "请输入选项 [0-9]: "
    read -r CHOICE
    case "$CHOICE" in
        1) fn_start;   header; show_menu ;;
        2) fn_stop;    header; show_menu ;;
        3) fn_restart; header; show_menu ;;
        4) fn_update;  header; show_menu ;;
        5) fn_logs;    header; show_menu ;;
        6) fn_switch;  header; show_menu ;;
        7) fn_backup;  header; show_menu ;;
        8) fn_restore; header; show_menu ;;
        9) fn_uninstall ;;
        0) echo "👋"; exit 0 ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
done
