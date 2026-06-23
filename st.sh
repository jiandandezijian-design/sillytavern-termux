#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
# 🍊 橘子酒馆 · 安卓 Termux 一键部署与管理脚本
# 全国内源，无需梯子 · 每次打开都有控制菜单
#==========================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/SillyTavern"
ST_DIR="$HOME/.st-manager"

clear
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     🍊 橘子酒馆 · Termux 控制面板        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

#=========================================================================
# 主菜单
#=========================================================================

show_menu() {
    echo ""
    echo -e "  ${BOLD}═══════ 酒馆管理 ═══════${NC}"
    echo -e "  ${GREEN}[1]${NC} 启动酒馆"
    echo -e "  ${GREEN}[2]${NC} 停止酒馆"
    echo -e "  ${GREEN}[3]${NC} 重启酒馆"
    echo ""
    echo -e "  ${BOLD}═══════ 维护升级 ═══════${NC}"
    echo -e "  ${BLUE}[4]${NC} 更新到最新版"
    echo -e "  ${BLUE}[5]${NC} 查看运行日志"
    echo -e "  ${BLUE}[6]${NC} 切换分支 (release ↔ staging)"
    echo ""
    echo -e "  ${BOLD}═══════ 数据管理 ═══════${NC}"
    echo -e "  ${YELLOW}[7]${NC} 备份用户数据"
    echo -e "  ${YELLOW}[8]${NC} 恢复用户数据"
    echo ""
    echo -e "  ${BOLD}═══════ 系统 ═══════${NC}"
    echo -e "  ${RED}[9]${NC} 完全卸载酒馆"
    echo -e "  ${RED}[0]${NC} 退出"
    echo ""
}

#=========================================================================
# 各功能函数
#=========================================================================

check_installed() {
    if [ ! -f "$INSTALL_DIR/start.sh" ]; then
        return 1
    fi
    return 0
}

start_tavern() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装，请先安装！${NC}"
        return
    fi
    # 检查是否已在运行
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "${YELLOW}酒馆似乎已在运行中${NC}"
        echo -e "  访问: ${GREEN}http://127.0.0.1:8000${NC}"
        return
    fi
    echo -e "${GREEN}正在启动酒馆...${NC}"
    cd "$INSTALL_DIR"
    nohup bash start.sh > /dev/null 2>&1 &
    sleep 3
    echo -e "${GREEN}✓ 启动成功！${NC}"
    echo -e "  ${CYAN}访问地址:${NC} ${BOLD}http://127.0.0.1:8000${NC}"
    echo -e "  ${YELLOW}提示：挂小窗保持 Termux 运行${NC}"
}

stop_tavern() {
    echo -e "${YELLOW}正在停止酒馆...${NC}"
    # 优雅停止
    pkill -f "node.*server.js" 2>/dev/null && sleep 1 || true
    # 强制清理
    pkill -9 -f "node.*server.js" 2>/dev/null || true
    echo -e "${GREEN}✓ 酒馆已停止${NC}"
}

restart_tavern() {
    stop_tavern
    sleep 1
    start_tavern
}

update_tavern() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装${NC}"
        return
    fi
    stop_tavern 2>/dev/null || true
    cd "$INSTALL_DIR"
    echo -e "${CYAN}正在更新酒馆...${NC}"
    
    # 走国内加速
    git remote set-url origin https://gh.api.99988866.xyz/https://github.com/SillyTavern/SillyTavern 2>/dev/null || true
    git pull --rebase --autostash 2>/dev/null || git pull 2>/dev/null
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true
    
    echo -e "${CYAN}更新依赖...${NC}"
    npm install --no-audit --no-fund 2>/dev/null || true
    
    echo -e "${GREEN}✓ 更新完成${NC}"
    read -p "是否现在启动？[Y/n] " START
    if [ "$START" != "n" ] && [ "$START" != "N" ]; then
        start_tavern
    fi
}

show_logs() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装${NC}"
        return
    fi
    echo -e "${CYAN}=== 最近 30 行日志 ===${NC}"
    # 找进程日志
    PID=$(pgrep -f "node.*server.js" | head -1)
    if [ -n "$PID" ]; then
        echo -e "${GREEN}酒馆正在运行 (PID: $PID)${NC}"
        echo ""
        # Termux 里没有 journalctl，直接看 nohup 输出
        if [ -f "$INSTALL_DIR/nohup.out" ]; then
            tail -30 "$INSTALL_DIR/nohup.out"
        else
            echo -e "${YELLOW}无日志文件，酒馆可能直接在前台运行${NC}"
        fi
    else
        echo -e "${RED}酒馆未运行${NC}"
        if [ -f "$INSTALL_DIR/nohup.out" ]; then
            echo -e "${YELLOW}上次运行的最后日志：${NC}"
            tail -10 "$INSTALL_DIR/nohup.out"
        fi
    fi
    echo ""
    read -p "按回车返回菜单..." _
}

switch_branch() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装${NC}"
        return
    fi
    stop_tavern 2>/dev/null || true
    cd "$INSTALL_DIR"
    CURRENT=$(git branch --show-current 2>/dev/null)
    echo -e "当前分支: ${YELLOW}$CURRENT${NC}"
    echo ""
    echo "  [1] release (稳定版)"
    echo "  [2] staging (开发版)"
    echo ""
    read -p "选择分支: " BRANCH_CHOICE
    case $BRANCH_CHOICE in
        1) TARGET="release" ;;
        2) TARGET="staging" ;;
        *) echo "已取消"; return ;;
    esac
    
    echo -e "${CYAN}切换到 $TARGET ...${NC}"
    git fetch --all 2>/dev/null
    git checkout "$TARGET" 2>/dev/null && git pull 2>/dev/null
    npm install --no-audit --no-fund 2>/dev/null || true
    echo -e "${GREEN}✓ 已切换到 $TARGET${NC}"
}

backup_data() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装${NC}"
        return
    fi
    BACKUP_NAME="ST_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    BACKUP_DIR="$HOME/SillyTavern_Backups"
    mkdir -p "$BACKUP_DIR"
    
    echo -e "${CYAN}正在备份...${NC}"
    cd "$INSTALL_DIR"
    tar czf "$BACKUP_DIR/$BACKUP_NAME" data/ 2>/dev/null
    
    SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    echo -e "${GREEN}✓ 备份完成${NC}"
    echo -e "  文件: ${CYAN}$BACKUP_DIR/$BACKUP_NAME${NC}"
    echo -e "  大小: ${YELLOW}$SIZE${NC}"
    echo ""
    echo -e "${YELLOW}💡 用 MT 管理器可访问此路径${NC}"
    echo -e "   路径: Termux Home → SillyTavern_Backups"
    echo ""
    read -p "按回车返回菜单..." _
}

restore_data() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装${NC}"
        return
    fi
    BACKUP_DIR="$HOME/SillyTavern_Backups"
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${RED}没有找到备份文件${NC}"
        echo -e "  请先将 .tar.gz 备份文件放到: ${CYAN}SillyTavern_Backups/${NC}"
        return
    fi
    
    echo -e "${CYAN}可用备份：${NC}"
    echo ""
    i=1
    for f in "$BACKUP_DIR"/*.tar.gz; do
        SIZE=$(du -h "$f" | cut -f1)
        echo -e "  [$i] $(basename "$f") (${SIZE})"
        i=$((i+1))
    done
    echo "  [0] 取消"
    echo ""
    read -p "选择要恢复的备份: " RESTORE_NUM
    
    if [ "$RESTORE_NUM" = "0" ] || [ -z "$RESTORE_NUM" ]; then
        return
    fi
    
    FILE=$(ls "$BACKUP_DIR"/*.tar.gz | sed -n "${RESTORE_NUM}p")
    if [ ! -f "$FILE" ]; then
        echo -e "${RED}无效选择${NC}"
        return
    fi
    
    echo -e "${YELLOW}⚠️ 此操作会覆盖当前 data 目录！${NC}"
    read -p "确认恢复？[y/N] " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "已取消"
        return
    fi
    
    stop_tavern 2>/dev/null || true
    cd "$INSTALL_DIR"
    rm -rf data
    tar xzf "$FILE"
    echo -e "${GREEN}✓ 数据已恢复${NC}"
}

uninstall_tavern() {
    echo -e "${RED}${BOLD}⚠️ 此操作将删除 SillyTavern 目录！${NC}"
    echo ""
    read -p "输入 YES 确认卸载: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo "已取消"
        return
    fi
    
    stop_tavern 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    rm -rf "$ST_DIR"
    echo -e "${GREEN}✓ 酒馆已卸载${NC}"
    echo -e "${YELLOW}备份目录 SillyTavern_Backups 已保留${NC}"
    exit 0
}

#=========================================================================
# 首次安装
#=========================================================================

install_tavern() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║     🍊 橘子酒馆 · 首次安装          ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    #----- 换源 -----
    echo -e "${CYAN}[1/5] 配置国内镜像...${NC}"
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@' "$PREFIX/etc/apt/sources.list" 2>/dev/null || true
    fi
    pkg update -y 2>/dev/null || pkg update -y -q
    echo -e "${GREEN}✓ Termux → 清华镜像${NC}"

    #----- 依赖 -----
    echo -e "${CYAN}[2/5] 安装运行环境...${NC}"
    pkg install -y git nodejs-lts 2>/dev/null || {
        echo -e "${RED}依赖安装失败${NC}"
        return 1
    }
    echo -e "${GREEN}✓ Node.js $(node -v)${NC}"

    #----- npm 源 -----
    echo -e "${CYAN}[3/5] 配置 npm 加速...${NC}"
    npm config set registry https://registry.npmmirror.com 2>/dev/null || true
    echo -e "${GREEN}✓ npm → npmmirror${NC}"

    #----- 克隆 -----
    echo -e "${CYAN}[4/5] 下载酒馆源码...${NC}"
    cd ~
    
    GIT_MIRRORS=(
        "https://gh.api.99988866.xyz/https://github.com/SillyTavern/SillyTavern"
        "https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern"
        "https://gh.llkk.cc/https://github.com/SillyTavern/SillyTavern"
        "https://gh.xiu2.xyz/https://github.com/SillyTavern/SillyTavern"
        "https://github.com/SillyTavern/SillyTavern"
    )
    
    CLONED=0
    for MIRROR in "${GIT_MIRRORS[@]}"; do
        echo -e "  → ${MIRROR}"
        if git clone "$MIRROR" -b release "$INSTALL_DIR" --depth 1 2>/dev/null; then
            CLONED=1; echo -e "${GREEN}✓ release 克隆成功${NC}"; break
        fi
        if git clone "$MIRROR" -b staging "$INSTALL_DIR" --depth 1 2>/dev/null; then
            CLONED=1; echo -e "${YELLOW}✓ staging 克隆成功${NC}"; break
        fi
    done
    
    if [ "$CLONED" = "0" ]; then
        echo -e "${RED}克隆失败，请检查网络${NC}"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    #----- npm install -----
    echo -e "${CYAN}[5/5] 安装项目依赖...${NC}"
    npm install --no-audit --no-fund 2>/dev/null || npm install 2>/dev/null
    echo -e "${GREEN}✓ 安装完成${NC}"

    #----- 创建管理器目录 -----
    mkdir -p "$ST_DIR"
    mkdir -p "$HOME/SillyTavern_Backups"

    echo ""
    echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════╗"
    echo -e "  ║   🍊 橘子酒馆 安装成功！            ║"
    echo -e "  ╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}以后每次打开 Termux 输入:${NC}"
    echo -e "  ${BOLD}  st${NC}"
    echo -e "  ${CYAN}就会进入控制面板${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ 保活必做：挂小窗 + 省电策略→无限制${NC}"
    echo ""
    read -p "是否现在启动酒馆？[Y/n] " START
    if [ "$START" != "n" ] && [ "$START" != "N" ]; then
        start_tavern
    fi
}

#=========================================================================
# 安装 st 快捷命令
#=========================================================================

install_alias() {
    BASHRC="$HOME/.bashrc"
    ALIAS_LINE='alias st="bash $HOME/.st-manager/menu.sh"'
    
    if ! grep -q "alias st=" "$BASHRC" 2>/dev/null; then
        echo "$ALIAS_LINE" >> "$BASHRC"
    fi
    
    # 把菜单脚本复制到固定位置
    SCRIPT_PATH=$(realpath "$0" 2>/dev/null || echo "$0")
    mkdir -p "$ST_DIR"
    if [ "$SCRIPT_PATH" != "$ST_DIR/menu.sh" ]; then
        cp "$SCRIPT_PATH" "$ST_DIR/menu.sh" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ 快捷命令 'st' 已配置${NC}"
    echo -e "  下次打开 Termux 直接输入 ${BOLD}st${NC}"
}

#=========================================================================
# 主逻辑
#=========================================================================

# 自安装到管理目录
if [ ! -f "$ST_DIR/menu.sh" ]; then
    mkdir -p "$ST_DIR"
    SCRIPT_PATH=$(realpath "$0" 2>/dev/null || echo "$HOME/st.sh")
    cp "$SCRIPT_PATH" "$ST_DIR/menu.sh" 2>/dev/null || true
fi
install_alias

# 检查是否已安装酒馆
if ! check_installed; then
    echo -e "${YELLOW}未检测到酒馆安装，进入首次安装...${NC}"
    echo ""
    install_tavern
    # 安装完显示菜单
    if check_installed; then
        show_menu
    else
        exit 0
    fi
else
    show_menu
fi

# 读取用户选择
while true; do
    read -p "请输入选项 [0-9]: " CHOICE
    case $CHOICE in
        1) start_tavern; show_menu ;;
        2) stop_tavern; show_menu ;;
        3) restart_tavern; show_menu ;;
        4) update_tavern; show_menu ;;
        5) show_logs; show_menu ;;
        6) switch_branch; show_menu ;;
        7) backup_data; show_menu ;;
        8) restore_data; show_menu ;;
        9) uninstall_tavern ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; show_menu ;;
    esac
done
