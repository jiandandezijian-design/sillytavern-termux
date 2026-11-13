#!/data/data/com.termux/files/usr/bin/bash
#==========================================================================
#  🍊 橘子酒馆 · Termux 一键部署与管理 v3.0
#  全国内源加速 · 无需梯子 · 唤醒锁防休眠 · 数据安全
#  用法：
#     curl -O https://raw.githubusercontent.com/jiandandezijian-design/sillytavern-termux/main/st.sh && bash st.sh
#     装完后：打开 Termux 自动弹菜单；或输入 st 进入
#==========================================================================

set -o pipefail

# ---- 常量 ----
INSTALL_DIR="$HOME/SillyTavern"
MENU_FILE="$HOME/.st-menu.sh"
BACKUP_DIR="$HOME/SillyTavern_Backups"
LOG_FILE="$INSTALL_DIR/nohup.out"
PID_FILE="$HOME/.st-sillytavern.pid"
LOCK_DIR="$HOME/.st-lock"
ST_PORT="${ST_PORT:-8000}"
ST_BRANCH_DEFAULT="release"

# ---- 颜色 ----
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; BOLD=''; DIM=''; NC=''
fi

# ---- 镜像列表（GitHub 加速，按速度排序）----
MIRRORS="
https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern
https://gh.llkk.cc/https://github.com/SillyTavern/SillyTavern
https://ghfast.top/https://github.com/SillyTavern/SillyTavern
https://gh.api.99988866.xyz/https://github.com/SillyTavern/SillyTavern
https://github.com/SillyTavern/SillyTavern
"

#==========================================================================
# 工具函数
#==========================================================================
check_installed() { [ -f "$INSTALL_DIR/server.js" ] && [ -f "$INSTALL_DIR/package.json" ]; }

# 用 PID 文件精确判断，避免误杀别的 node 进程
is_running() {
    if [ -f "$PID_FILE" ]; then
        local p
        p=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
            return 0
        fi
    fi
    # 兜底：只匹配工作目录在酒馆目录下的 node
    if command -v pgrep >/dev/null 2>&1; then
        local pids
        pids=$(pgrep -f "node .*server\.js" 2>/dev/null)
        for p in $pids; do
            if [ -r "/proc/$p/cwd" ] && [ "$(readlink -f "/proc/$p/cwd" 2>/dev/null)" = "$(readlink -f "$INSTALL_DIR")" ]; then
                echo "$p" > "$PID_FILE"
                return 0
            fi
        done
    fi
    return 1
}

st_pid() {
    [ -f "$PID_FILE" ] && cat "$PID_FILE" 2>/dev/null
}

port_in_use() {
    # Termux 没有 ss 时退回 /proc
    (echo > /dev/tcp/127.0.0.1/"$ST_PORT") >/dev/null 2>&1
}

status_text() {
    if is_running; then
        echo -e "${GREEN}🟢 运行中${NC} → ${BOLD}http://127.0.0.1:${ST_PORT}${NC}"
    else
        echo -e "${YELLOW}🔴 未运行${NC}"
    fi
}

wake_lock_on() {
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock 2>/dev/null && echo -e "  ${GREEN}✓${NC} 唤醒锁已开启（防休眠断服）"
    else
        echo -e "  ${DIM}提示：装 termux-api 可开启唤醒锁防休眠${NC}"
    fi
}

wake_lock_off() {
    command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null
}

# 简易互斥锁，防止重复安装/并发操作
acquire_lock() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        local age
        age=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0) ))
        if [ "$age" -gt 600 ]; then
            rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR" 2>/dev/null || return 1
        else
            echo -e "${YELLOW}另一个操作正在进行，请稍候（若卡死请删 $LOCK_DIR）${NC}"
            return 1
        fi
    fi
    trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT
    return 0
}
release_lock() { rm -rf "$LOCK_DIR" 2>/dev/null; }

# 安全读取（读不到就给默认值，绝不挂住）
ask() {
    local prompt="$1" default="${2:-}"
    printf "%s" "$prompt"
    if ! read -r _ans; then _ans=""; fi
    [ -z "$_ans" ] && _ans="$default"
    printf "%s" "$_ans"
}

pause_ret() {
    printf "\n${DIM}按回车返回...${NC}"
    read -r _ 2>/dev/null || true
}

header() {
    clear 2>/dev/null
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║      🍊 橘子酒馆 · Termux 控制面板       ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    status_text
    echo ""
}

show_menu() {
    echo -e "  ${BOLD}═══ 运行控制 ═══${NC}"
    echo -e "  ${GREEN}[1]${NC} 启动   ${GREEN}[2]${NC} 停止   ${GREEN}[3]${NC} 重启"
    echo ""
    echo -e "  ${BOLD}═══ 维护升级 ═══${NC}"
    echo -e "  ${BLUE}[4]${NC} 更新到最新版   ${BLUE}[5]${NC} 查看日志   ${BLUE}[6]${NC} 切换分支"
    echo ""
    echo -e "  ${BOLD}═══ 数据管理 ═══${NC}"
    echo -e "  ${YELLOW}[7]${NC} 备份数据   ${YELLOW}[8]${NC} 恢复数据"
    echo ""
    echo -e "  ${BOLD}═══ 其他 ═══${NC}"
    echo -e "  ${CYAN}[s]${NC} 安装状态   ${RED}[9]${NC} 卸载   ${RED}[0]${NC} 退出"
    echo ""
}

#==========================================================================
# 首次安装
#==========================================================================
do_install() {
    clear 2>/dev/null
    echo -e "${CYAN}${BOLD}  🍊 橘子酒馆 · 首次安装${NC}"
    echo "  ========================================"
    echo ""

    # [1/6] 清华镜像
    echo -e "${BOLD}[1/6]${NC} 配置国内镜像..."
    if [ -f "$PREFIX/etc/apt/sources.list" ]; then
        [ ! -f "$PREFIX/etc/apt/sources.list.bak" ] && \
            cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null
        sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@g' \
            "$PREFIX/etc/apt/sources.list" 2>/dev/null
        # 新版 Termux 数据源是 sources.list.d 里的文件
        for f in "$PREFIX/etc/apt/sources.list.d"/*.list "$PREFIX/etc/apt/sources.list.d"/*.sources; do
            [ -f "$f" ] || continue
            sed -i 's@packages.termux.dev@mirrors.tuna.tsinghua.edu.cn/termux@g' "$f" 2>/dev/null
        done
        echo -e "  ${GREEN}✓${NC} Termux → 清华镜像"
    else
        echo -e "  ${YELLOW}!${NC} 未找到 sources.list，跳过换源"
    fi
    pkg update -y >/dev/null 2>&1 || pkg update -y

    # [2/6] 依赖（nodejs-lts 已废弃，改用 nodejs）
    echo -e "${BOLD}[2/6]${NC} 安装运行环境..."
    if ! pkg install -y nodejs git >/dev/null 2>&1; then
        echo -e "  ${YELLOW}!${NC} nodejs 安装失败，尝试 nodejs-lts 兜底"
        if ! pkg install -y nodejs-lts git >/dev/null 2>&1; then
            echo -e "  ${RED}✗ 依赖安装失败${NC}"
            echo -e "  ${DIM}试试：pkg update && pkg upgrade -y 后重跑${NC}"
            return 1
        fi
    fi
    if ! command -v node >/dev/null 2>&1; then
        echo -e "  ${RED}✗ node 未安装成功${NC}"; return 1
    fi
    local nmajor
    nmajor=$(node -v | sed 's/v//' | cut -d. -f1)
    echo -e "  ${GREEN}✓${NC} Node.js $(node -v) / git $(git --version 2>/dev/null | awk '{print $3}')"
    if [ "$nmajor" -lt 18 ] 2>/dev/null; then
        echo -e "  ${YELLOW}!${NC} Node 版本过低（需 ≥18），请 pkg upgrade 后重跑"; return 1
    fi

    # [3/6] npm 源
    echo -e "${BOLD}[3/6]${NC} 配置 npm 加速..."
    npm config set registry https://registry.npmmirror.com >/dev/null 2>&1
    npm config set fund false >/dev/null 2>&1
    npm config set audit false >/dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} npm → npmmirror"

    # [4/6] 源码（多镜像轮换，浅克隆）
    echo -e "${BOLD}[4/6]${NC} 下载酒馆源码..."
    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}!${NC} 目录已存在，跳过下载（幂等）"
    else
        rm -rf "$INSTALL_DIR"
        local ok=0 url
        for url in $MIRRORS; do
            echo -e "  ${DIM}→ $url${NC}"
            if git clone --depth 1 -b "$ST_BRANCH_DEFAULT" "$url" "$INSTALL_DIR" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $ST_BRANCH_DEFAULT 分支"; ok=1; break
            fi
            if git clone --depth 1 -b staging "$url" "$INSTALL_DIR" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} staging 分支"; ok=1; break
            fi
            rm -rf "$INSTALL_DIR"
        done
        if [ "$ok" != "1" ]; then
            echo -e "  ${RED}✗ 所有镜像均失败${NC}"
            echo -e "  ${DIM}检查网络，或手动 git clone 后重跑${NC}"
            return 1
        fi
        # 还原真 origin，便于后续更新
        cd "$INSTALL_DIR" && git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null
        # 浅克隆转完整历史（更新时不至于拉不动）
        git fetch --unshallow >/dev/null 2>&1 || true
    fi

    # [5/6] 依赖
    echo -e "${BOLD}[5/6]${NC} 安装项目依赖（首次约 3-8 分钟）..."
    cd "$INSTALL_DIR" || return 1
    if [ ! -d node_modules ]; then
        if ! npm install --no-audit --no-fund --loglevel=error; then
            echo -e "  ${YELLOW}!${NC} 生产依赖失败，尝试完整安装"
            npm install --no-audit --no-fund || { echo -e "  ${RED}✗ 依赖安装失败${NC}"; return 1; }
        fi
    else
        echo -e "  ${DIM}node_modules 已存在，跳过${NC}"
    fi
    echo -e "  ${GREEN}✓${NC} 依赖安装完成"

    # [6/6] 数据目录 + 菜单
    echo -e "${BOLD}[6/6]${NC} 收尾配置..."
    mkdir -p "$BACKUP_DIR" "$INSTALL_DIR/data"

    # 菜单脚本（运行的是 st.sh 本身时复制；这个文件就是菜单版）
    local src=""
    [ -f "$HOME/st.sh" ] && src="$HOME/st.sh"
    [ -f "./st.sh" ] && [ -z "$src" ] && src="./st.sh"
    [ -n "$src" ] && cp "$src" "$MENU_FILE" && chmod +x "$MENU_FILE"
    [ -f "$MENU_FILE" ] && echo -e "  ${GREEN}✓${NC} 菜单已保存 → $MENU_FILE"

    # st 快捷命令
    mkdir -p "$PREFIX/bin"
    cat > "$PREFIX/bin/st" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
[ -f "$MENU_FILE" ] && bash "$MENU_FILE" || echo "菜单丢失，请重跑安装脚本"
EOF
    chmod +x "$PREFIX/bin/st"
    echo -e "  ${GREEN}✓${NC} 快捷命令 ${BOLD}st${NC} 已安装"

    # .bashrc 自动菜单（幂等，防重复）
    if ! grep -q "橘子酒馆自动菜单" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# 🍊 橘子酒馆自动菜单（2026 v3.0）"
            echo 'if [ -f "$HOME/.st-menu.sh" ]; then bash "$HOME/.st-menu.sh"; fi'
        } >> "$HOME/.bashrc"
        echo -e "  ${GREEN}✓${NC} 已设置打开 Termux 自动弹菜单"
    else
        echo -e "  ${DIM}自动菜单已存在，跳过${NC}"
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}╔════════════════════════════════════╗"
    echo -e "  ║      🍊 安装完成！                ║"
    echo -e "  ╚════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  下一步 ${BOLD}输入 1 启动酒馆${NC}"
    echo -e "  ${DIM}小提示：把 Termux 加进「省电白名单」+ 切小窗，后台更稳${NC}"
    echo ""
}

#==========================================================================
# 菜单功能
#==========================================================================
fn_start() {
    if ! check_installed; then echo -e "${RED}未安装，请先运行安装${NC}"; return 1; fi
    if is_running; then echo -e "${GREEN}已经在运行了${NC} → http://127.0.0.1:${ST_PORT}"; return 0; fi
    if port_in_use; then
        echo -e "${YELLOW}端口 ${ST_PORT} 被占用${NC}，可能是残留进程"
        echo -e "${DIM}尝试：pkill -f 'node .*server.js' 后再启动${NC}"
        return 1
    fi
    echo -e "${CYAN}启动中...${NC}"
    cd "$INSTALL_DIR" || return 1
    wake_lock_on
    : > "$LOG_FILE"
    nohup node server.js >> "$LOG_FILE" 2>&1 &
    local p=$!
    echo "$p" > "$PID_FILE"

    # 等真正起来再报成功
    local i code=""
    printf "  ${DIM}等待就绪"
    for i in $(seq 1 30); do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${ST_PORT}/" 2>/dev/null || echo 000)
        case "$code" in 200|302|303) break ;; esac
        printf "."
        sleep 1
    done
    echo -e "${NC}"
    case "$code" in
        200|302|303)
            echo -e "${GREEN}✓ 启动成功${NC} → ${BOLD}http://127.0.0.1:${ST_PORT}${NC}"
            ;;
        *)
            echo -e "${RED}✗ 启动异常（${code}）${NC}"
            echo -e "${DIM}最后 20 行日志：${NC}"
            tail -20 "$LOG_FILE" 2>/dev/null | sed 's/^/    /'
            return 1
            ;;
    esac
}

fn_stop() {
    local p
    p=$(st_pid)
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
        kill "$p" 2>/dev/null
        local i
        for i in $(seq 1 10); do kill -0 "$p" 2>/dev/null || break; sleep 1; done
        kill -9 "$p" 2>/dev/null
    fi
    # 兜底：只杀 cwd 在酒馆目录的 node
    if command -v pgrep >/dev/null 2>&1; then
        local q
        for q in $(pgrep -f "node .*server\.js" 2>/dev/null); do
            if [ -r "/proc/$q/cwd" ] && [ "$(readlink -f "/proc/$q/cwd" 2>/dev/null)" = "$(readlink -f "$INSTALL_DIR")" ]; then
                kill -9 "$q" 2>/dev/null
            fi
        done
    fi
    rm -f "$PID_FILE"
    wake_lock_off
    echo -e "${GREEN}✓ 已停止${NC}"
}

fn_restart() { fn_stop >/dev/null 2>&1; sleep 1; fn_start; }

fn_update() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return 1; fi
    local was_running=0
    is_running && was_running=1
    [ "$was_running" = "1" ] && fn_stop >/dev/null 2>&1
    cd "$INSTALL_DIR" || return 1

    echo -e "${CYAN}更新中...${NC}"
    git remote set-url origin https://github.com/SillyTavern/SillyTavern 2>/dev/null
    # 浅克隆自动补历史
    if [ -f .git/shallow ]; then
        git fetch --unshallow >/dev/null 2>&1 || git fetch --depth 50 >/dev/null 2>&1
    fi
    if ! git pull --rebase --autostash >/dev/null 2>&1; then
        echo -e "  ${YELLOW}!${NC} 直连失败，尝试加速镜像"
        local ok=0 url
        for url in $MIRRORS; do
            if git -c http.extraHeader= fetch "$url" HEAD >/dev/null 2>&1; then ok=1; break; fi
        done
        if [ "$ok" = "1" ]; then
            git rebase --autostash FETCH_HEAD >/dev/null 2>&1 || git reset --hard FETCH_HEAD
        else
            echo -e "  ${RED}✗ 更新失败（网络）${NC}"
            [ "$was_running" = "1" ] && fn_start
            return 1
        fi
    fi
    echo -e "  ${GREEN}✓${NC} 代码已更新到 $(git rev-parse --short HEAD 2>/dev/null)"
    npm install --no-audit --no-fund --loglevel=error >/dev/null 2>&1 || npm install --no-audit --no-fund
    echo -e "  ${GREEN}✓${NC} 依赖已同步"

    if [ "$was_running" = "1" ]; then
        local yn
        yn=$(ask "更新前服务在运行，现在重启？[Y/n] " "y")
        case "$yn" in n|N) echo -e "${DIM}已更新，未启动${NC}" ;; *) fn_start ;; esac
    fi
}

fn_logs() {
    if [ ! -f "$LOG_FILE" ]; then echo -e "${YELLOW}暂无日志（未启动过？）${NC}"; return; fi
    echo -e "${CYAN}=== 最近 40 行 ===${NC}"
    tail -40 "$LOG_FILE"
    echo ""
    echo -e "${DIM}--- 文件大小: $(du -h "$LOG_FILE" 2>/dev/null | cut -f1) ---${NC}"
    echo -e "${BOLD}[1]${NC} 实时跟随   ${BOLD}[2]${NC} 清空日志   ${BOLD}[0]${NC} 返回"
    local c
    c=$(ask "选择: " "0")
    case "$c" in
        1) echo -e "${DIM}Ctrl+C 退出跟随${NC}"; tail -f "$LOG_FILE" ;;
        2) : > "$LOG_FILE"; echo -e "${GREEN}✓ 已清空${NC}" ;;
    esac
    pause_ret
}

fn_switch() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return 1; fi
    cd "$INSTALL_DIR" || return 1
    echo -e "当前分支: ${BOLD}$(git branch --show-current 2>/dev/null || echo unknown)${NC}"
    echo "  [1] release（稳定）"
    echo "  [2] staging（尝鲜）"
    echo "  [0] 取消"
    local br
    br=$(ask "选择: " "0")
    local target=""
    case "$br" in 1) target="release" ;; 2) target="staging" ;; *) return 0 ;; esac
    local was_running=0; is_running && was_running=1
    [ "$was_running" = "1" ] && fn_stop >/dev/null 2>&1
    echo -e "${CYAN}切换到 $target ...${NC}"
    git fetch origin "$target" --depth 1 >/dev/null 2>&1 || true
    if git checkout "$target" >/dev/null 2>&1 && git pull >/dev/null 2>&1; then
        npm install --no-audit --no-fund --loglevel=error >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ 已切换到 $target${NC}"
        [ "$was_running" = "1" ] && fn_start
    else
        echo -e "${RED}✗ 切换失败${NC}"
        [ "$was_running" = "1" ] && fn_start
    fi
}

fn_backup() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return 1; fi
    mkdir -p "$BACKUP_DIR"
    local name="ST_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${CYAN}备份中（数据量大可能需要一会）...${NC}"
    cd "$INSTALL_DIR" || return 1
    if tar czf "$BACKUP_DIR/$name" data/ 2>/dev/null; then
        echo -e "${GREEN}✓ 备份完成${NC}"
        echo -e "  $BACKUP_DIR/$name （$(du -h "$BACKUP_DIR/$name" 2>/dev/null | cut -f1)）"
    else
        echo -e "${RED}✗ 备份失败${NC}"
    fi
    # 只保留最近 5 份
    local cnt
    cnt=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$cnt" -gt 5 ]; then
        ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +6 | while read -r f; do rm -f "$f"; done
        echo -e "${DIM}已清理旧备份，保留最近 5 份${NC}"
    fi
    pause_ret
}

fn_restore() {
    if ! check_installed; then echo -e "${RED}未安装${NC}"; return 1; fi
    local files
    files=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)
    if [ -z "$files" ]; then
        echo -e "${RED}没有备份文件${NC}"
        echo -e "${DIM}把 .tar.gz 放进：$BACKUP_DIR${NC}"
        pause_ret; return 1
    fi
    echo -e "${BOLD}可用备份：${NC}"
    local i=1 f
    for f in $files; do
        echo "  [$i] $(basename "$f")  $(du -h "$f" 2>/dev/null | cut -f1)"
        i=$((i+1))
    done
    echo "  [0] 取消"
    local n
    n=$(ask "选择: " "0")
    [ "$n" = "0" ] && return 0
    local target
    target=$(echo "$files" | sed -n "${n}p")
    [ -z "$target" ] || [ ! -f "$target" ] && { echo -e "${RED}无效选择${NC}"; return 1; }

    local cf
    cf=$(ask "${RED}确认覆盖当前所有数据？[y/N] ${NC}" "n")
    case "$cf" in y|Y) ;; *) echo "已取消"; return 0 ;; esac

    fn_stop >/dev/null 2>&1
    cd "$INSTALL_DIR" || return 1
    # 先备份现有数据再覆盖（安全网）
    if [ -d data ] && [ "$(ls -A data 2>/dev/null)" ]; then
        mv data "data.bak.$(date +%s)" 2>/dev/null
    fi
    if tar xzf "$target" 2>/dev/null; then
        echo -e "${GREEN}✓ 已恢复${NC}"
        echo -e "${DIM}旧数据保留在 $INSTALL_DIR/data.bak.*（确认无误后可删）${NC}"
    else
        echo -e "${RED}✗ 恢复失败${NC}"
    fi
    pause_ret
}

fn_status() {
    echo -e "${BOLD}=== 安装状态 ===${NC}"
    if check_installed; then
        echo -e "  安装目录  ${GREEN}✓${NC} $INSTALL_DIR"
        echo -e "  版本      $(node -e "console.log(require('$INSTALL_DIR/package.json').version)" 2>/dev/null || echo '?')"
        echo -e "  分支      $(cd "$INSTALL_DIR" 2>/dev/null && git branch --show-current 2>/dev/null || echo '?')"
        echo -e "  提交      $(cd "$INSTALL_DIR" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo '?')"
        echo -e "  数据大小  $(du -sh "$INSTALL_DIR/data" 2>/dev/null | cut -f1)"
        echo -e "  备份数量  $(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)"
    else
        echo -e "  ${RED}✗ 未安装${NC}"
    fi
    echo -e "  运行状态  $(status_text)"
    echo -e "  Node      $(node -v 2>/dev/null || echo '未安装')"
    echo -e "  端口      $ST_PORT"
    echo -e "  唤醒锁    $(command -v termux-wake-lock >/dev/null 2>&1 && echo '可用' || echo '不可用（缺 termux-api）')"
    pause_ret
}

fn_uninstall() {
    echo -e "${RED}⚠️  将删除所有酒馆文件和菜单${NC}"
    echo -e "${DIM}备份目录 $BACKUP_DIR 会保留${NC}"
    local cf
    cf=$(ask "输入 YES 确认: " "")
    [ "$cf" != "YES" ] && { echo "已取消"; return 0; }
    fn_stop >/dev/null 2>&1
    rm -rf "$INSTALL_DIR" "$MENU_FILE" "$PID_FILE"
    rm -f "$PREFIX/bin/st" 2>/dev/null
    # 精确删除自己写入的 .bashrc 段（含标记行）
    if [ -f "$HOME/.bashrc" ]; then
        grep -v '橘子酒馆自动菜单' "$HOME/.bashrc" | grep -v 'st-menu.sh' > "$HOME/.bashrc.tmp" 2>/dev/null
        mv "$HOME/.bashrc.tmp" "$HOME/.bashrc" 2>/dev/null
    fi
    echo -e "${GREEN}✓ 已卸载${NC}（备份保留在 $BACKUP_DIR）"
    exit 0
}

#==========================================================================
# 主入口
#==========================================================================
main() {
    # 首次安装判定
    if ! check_installed; then
        if ! acquire_lock; then return 1; fi
        do_install || { release_lock; echo -e "${RED}安装未完成，修好后重跑本脚本即可续做${NC}"; exit 1; }
        release_lock
    fi

    # 菜单循环
    while true; do
        header
        show_menu
        printf "请输入选项 [0-9/s]: "
        if ! read -r CHOICE; then
            echo ""
            echo -e "${DIM}输入结束，退出${NC}"
            exit 0
        fi
        case "$CHOICE" in
            1) fn_start ;;
            2) fn_stop ;;
            3) fn_restart ;;
            4) fn_update ;;
            5) fn_logs ;;
            6) fn_switch ;;
            7) fn_backup ;;
            8) fn_restore ;;
            s|S) fn_status ;;
            9) fn_uninstall ;;
            0) echo -e "${GREEN}👋 再见，记得 Termux 保活哦${NC}"; exit 0 ;;
            "") ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

main "$@"
