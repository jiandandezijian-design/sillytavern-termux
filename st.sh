#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
# 🍊 橘子酒馆 · 安卓 Termux 一键部署与管理脚本
# 全国内源，无需梯子 · 每次打开 Termux 自动显示控制面板
#==========================================================================

# 注意：不使用 set -e，避免交互式 read 被意外中断

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/SillyTavern"
MENU_FILE="$HOME/st-menu.sh"
BACKUP_DIR="$HOME/SillyTavern_Backups"

#=========================================================================
# 输出函数
#=========================================================================

clear
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     🍊 橘子酒馆 · Termux 控制面板        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

show_menu() {
    # 检查酒馆是否在运行
    echo ""
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "  ${GREEN}🟢 酒馆运行中 → http://127.0.0.1:8000${NC}"
    else
        echo -e "  ${YELLOW}🔴 酒馆未运行${NC}"
    fi
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
# 功能函数
#=========================================================================

check_installed() {
    [ -f "$INSTALL_DIR/start.sh" ]
}

start_tavern() {
    if ! check_installed; then
        echo -e "${RED}酒馆尚未安装！${NC}"
        return
    fi
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "${GREEN}酒馆已在运行中 → http://127.0.0.1:8000${NC}"
        return
    fi
    echo -e "${GREEN}正在启动酒馆...${NC}"
    cd "$INSTALL_DIR"
    nohup bash start.sh > "$INSTALL_DIR/nohup.out" 2>&1 &
    sleep 3
    echo -e "${GREEN}✓ 启动成功！${NC}"
    echo -e "  ${CYAN}浏览器访问:${NC} ${BOLD}http://127.0.0.1:8000${NC}"
    echo -e "  ${YELLOW}💡 挂小窗保持 Termux 后台运行${NC}"
}

stop_tavern() {
    echo -e "${YELLOW}正在停止酒馆...${NC}"
    pkill -f "node.*server.js" 2>/dev/null && sleep 1 || true
    pkill -9 -f "node.*server.js" 2>/dev/null || true
    echo -e "${GREEN}✓ 酒馆已停止${NC}"
}

restart_tavern() {
    stop_tavern
    sleep 1
    start_tavern
}

update_tavern() {
    if ! check_installed; then echo -e "${RED}酒馆尚未安装${NC}"; return; fi
    stop_tavern 2>/dev/null || true
    cd "$INSTALL_DIR"
    echo -e "${CYAN}正在更新酒馆...${NC}"
    git remote set-url origin https://gh.api.99988866.xyz/https://github.com/SillyTavern/SillyTavern 2>/dev/null || true
    git pull --rebase --autostash 2>/dev/null || git pull 2>/dev/null
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true
    echo -e "${CYAN}更新依赖...${NC}"
    npm install --no-audit --no-fund 2>/dev/null || true
    echo -e "${GREEN}✓ 更新完成${NC}"
    read -p "是否现在启动？[Y/n] " START
    [ "$START" != "n" ] && [ "$START" != "N" ] && start_tavern
}

show_logs() {
    if ! check_installed; then echo -e "${RED}酒馆尚未安装${NC}"; return; fi
    echo -e "${CYAN}=== 最近 30 行日志 ===${NC}"
    PID=$(pgrep -f "node.*server.js" | head -1)
    [ -n "$PID" ] && echo -e "${GREEN}酒馆运行中 (PID: $PID)${NC}" || echo -e "${RED}酒馆未运行${NC}"
    echo ""
    if [ -f "$INSTALL_DIR/nohup.out" ]; then
        tail -30 "$INSTALL_DIR/nohup.out"
    else
        echo -e "${YELLOW}无日志文件${NC}"
    fi
    echo ""
    read -p "按回车返回菜单..." _
}

switch_branch() {
    if ! check_installed; then echo -e "${RED}酒馆尚未安装${NC}"; return; fi
    stop_tavern 2>/dev/null || true
    cd "$INSTALL_DIR"
    CURRENT=$(git branch --show-current 2>/dev/null)
    echo -e "当前: ${YELLOW}$CURRENT${NC}"
    echo "  [1] release (稳定)  [2] staging (开发)"
    read -p "选择: " BR
    case $BR in 1) T="release";; 2) T="staging";; *) echo "取消"; return;; esac
    echo -e "${CYAN}切换到 $T ...${NC}"
    git fetch --all 2>/dev/null; git checkout "$T" 2>/dev/null; git pull 2>/dev/null
    npm install --no-audit --no-fund 2>/dev/null || true
    echo -e "${GREEN}✓ 已切换到 $T${NC}"
}

backup_data() {
    if ! check_installed; then echo -e "${RED}酒馆尚未安装${NC}"; return; fi
    mkdir -p "$BACKUP_DIR"
    NAME="ST_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${CYAN}备份中...${NC}"
    cd "$INSTALL_DIR"
    tar czf "$BACKUP_DIR/$NAME" data/ 2>/dev/null
    echo -e "${GREEN}✓ 备份完成${NC}"
    echo -e "  文件: ${CYAN}$BACKUP_DIR/$NAME${NC} ($(du -h "$BACKUP_DIR/$NAME" | cut -f1))"
    echo -e "  ${YELLOW}💡 MT管理器路径: Termux Home → SillyTavern_Backups${NC}"
    echo ""
    read -p "按回车返回..." _
}

restore_data() {
    if ! check_installed; then echo -e "${RED}酒馆尚未安装${NC}"; return; fi
    [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ] && {
        echo -e "${RED}无备份文件。请将 .tar.gz 放到 SillyTavern_Backups/${NC}"; return
    }
    echo -e "${CYAN}可用备份：${NC}"
    i=1
    for f in "$BACKUP_DIR"/*.tar.gz; do echo -e "  [$i] $(basename "$f") ($(du -h "$f" | cut -f1))"; i=$((i+1)); done
    echo "  [0] 取消"
    read -p "选择: " N
    [ "$N" = "0" ] || [ -z "$N" ] && return
    FILE=$(ls "$BACKUP_DIR"/*.tar.gz | sed -n "${N}p")
    [ ! -f "$FILE" ] && { echo -e "${RED}无效${NC}"; return; }
    echo -e "${YELLOW}⚠️ 覆盖当前 data${NC}"
    read -p "确认? [y/N] " CF
    [ "$CF" != "y" ] && [ "$CF" != "Y" ] && { echo "取消"; return; }
    stop_tavern 2>/dev/null || true
    cd "$INSTALL_DIR"; rm -rf data; tar xzf "$FILE"
    echo -e "${GREEN}✓ 已恢复${NC}"
}

uninstall_tavern() {
    echo -e "${RED}${BOLD}⚠️ 删除 SillyTavern 目录！${NC}"
    read -p "输入 YES 确认: " CF
    [ "$CF" != "YES" ] && { echo "取消"; return; }
    stop_tavern 2>/dev/null || true
    rm -rf "$INSTALL_DIR" "$MENU_FILE"
    # 清理 bashrc
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/st-menu.sh/d' "$HOME/.bashrc" 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ 已卸载。备份目录 SillyTavern_Backups 保留${NC}"
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
    pkg install -y git nodejs-lts 2>/dev/null || { echo -e "${RED}依赖安装失败${NC}"; return 1; }
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
    [ "$CLONED" = "0" ] && { echo -e "${RED}克隆失败，检查网络${NC}"; return 1; }
    cd "$INSTALL_DIR"
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null || true

    #----- npm install -----
    echo -e "${CYAN}[5/5] 安装项目依赖...${NC}"
    npm install --no-audit --no-fund 2>/dev/null || npm install 2>/dev/null
    echo -e "${GREEN}✓ 安装完成${NC}"

    #----- 保存菜单脚本 -----
    echo -e "${CYAN}配置开机菜单...${NC}"
    mkdir -p "$BACKUP_DIR"
    cp "$0" "$MENU_FILE" 2>/dev/null
    chmod +x "$MENU_FILE" 2>/dev/null

    #----- 写入 bashrc（每次打开 Termux 自动运行）-----
    echo "" >> "$HOME/.bashrc" 2>/dev/null || true
    # 只加一次
    if ! grep -q "st-menu.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo '# 🍊 橘子酒馆自动菜单' >> "$HOME/.bashrc"
        echo 'bash "$HOME/st-menu.sh"' >> "$HOME/.bashrc"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════╗"
    echo -e "  ║   🍊 橘子酒馆 安装成功！            ║"
    echo -e "  ╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}💡 以后每次打开 Termux 自动弹出控制面板${NC}"
    echo -e "  ${CYAN}  也可以手动输入:${NC} ${BOLD}bash ~/st-menu.sh${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ 保活必做：挂小窗 + 省电策略→无限制${NC}"
    echo ""
    read -p "是否现在启动酒馆？[Y/n] " START || START=y
    if [ "$START" != "n" ] && [ "$START" != "N" ]; then
        start_tavern
    fi
}

#=========================================================================
# 主逻辑
#=========================================================================

# 如果是首次安装的脚本（不在 ~/st-menu.sh），执行安装
SELF=$(realpath "$0" 2>/dev/null || echo "$0")

if [ "$SELF" != "$MENU_FILE" ] && [ ! -f "$MENU_FILE" ]; then
    # 以安装模式运行，安装完继续显示菜单
    install_tavern
fi

# 把自身保存为菜单文件（如果在安装中没保存）
if [ "$SELF" != "$MENU_FILE" ] && [ -f "$SELF" ]; then
    cp "$SELF" "$MENU_FILE" 2>/dev/null || true
    chmod +x "$MENU_FILE" 2>/dev/null || true
fi

# 检查酒馆是否安装
if ! check_installed; then
    echo -e "${RED}检测到酒馆文件丢失，重新安装...${NC}"
    install_tavern
fi

# 显示菜单 + 循环
show_menu
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
        0) echo "👋"; exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; show_menu ;;
    esac
done
