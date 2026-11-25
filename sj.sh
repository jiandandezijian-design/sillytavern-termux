#!/data/data/com.termux/files/usr/bin/bash
# ==========================================================
#  🍊 橘子酒馆 · Termux 一键安装脚本
#  仓库：https://github.com/jiandandezijian-design/sillytavern-termux
#  用法（下载到手机后在 Termux 里执行）：
#    bash sj.sh               安装 / 打开控制面板
#    bash sj.sh start         直接启动（桌面小部件用）
#  装好之后：每次打开 Termux 自动弹面板，或输入 ./sj.sh / bash ~/.sj.sh
# ==========================================================

ST_DIR="$HOME/SillyTavern"
ST_BRANCH="release"
# 自愈所需路径（面板与安装脚本共用）
PID_FILE="$HOME/.st.pid"
LOCK_DIR="$HOME/.st.lock"
BACKUP_DIR="$HOME/SillyTavern_Backups"
INSTALL_LOG="$HOME/橘子酒馆安装日志.txt"
# 下载线路：按顺序尝试，失效的镜像可以随时换掉
REPO_LIST=(
  "https://github.com/SillyTavern/SillyTavern.git"
  "https://gh-proxy.com/https://github.com/SillyTavern/SillyTavern.git"
  "https://ghfast.top/https://github.com/SillyTavern/SillyTavern.git"
)
NPM_MIRROR="https://registry.npmmirror.com"
# 国内软件源：按顺序尝试，哪个能用就用哪个
# 地址来自 Termux 官方的国内镜像列表（termux-tools/mirrors/chinese_mainland）
MIRROR_NAMES=("清华源" "中科大源" "北外源" "阿里云源" "南大源" "上交源")
MIRROR_URLS=(
  "https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main"
  "https://mirrors.ustc.edu.cn/termux/termux-main"
  "https://mirrors.bfsu.edu.cn/termux/apt/termux-main"
  "https://mirrors.aliyun.com/termux/termux-main"
  "https://mirrors.nju.edu.cn/termux/apt/termux-main"
  "https://mirror.sjtu.edu.cn/termux/termux-main"
)
OFFICIAL_MIRROR="https://packages-cf.termux.dev/apt/termux-main"
TERMUX_MIRROR=""
TOTAL=7
SCRIPT_VER="v3.1"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"   # 本脚本自身路径（bash sj.sh 运行时有效）
SJ="$HOME/.sj.sh"                          # 控制面板存放位置（唯一真身）
MENU_URL="https://raw.githubusercontent.com/jiandandezijian-design/sillytavern-termux/main/sj.sh"
LOG="$INSTALL_LOG"

G='\033[32m'; Y='\033[33m'; R='\033[31m'; C='\033[36m'; P='\033[35m'; B='\033[1m'; N='\033[0m'
info(){ echo -e "${C}  ▸ $*${N}"; }
ok(){   echo -e "${G}  ✔ $* (๑•̀ㅂ•́)و✧${N}"; }
warn(){ echo -e "${Y}  ⚠ $* (・_・;)${N}"; }
fail(){
  echo
  echo -e "${R}  ✘ $* (╥﹏╥)${N}"
  echo -e "${Y}  别慌～可以截图保存上面的报错，方便排查问题 (っ´▽\`)っ${N}"
  if [[ -d "$HOME/storage/downloads" ]] && cp "$LOG" "$HOME/storage/downloads/" 2>/dev/null; then
    echo -e "${C}  完整的安装日志已经存到手机 Download 文件夹：橘子酒馆安装日志.txt${N}"
  else
    echo -e "${C}  完整的安装日志在：~/橘子酒馆安装日志.txt（输入 cat ~/橘子酒馆安装日志.txt 查看）${N}"
  fi
  exit 1
}
step(){
  echo
  echo -e "${P}${B}  ━━━━━ 【$1/$TOTAL】$2 ━━━━━${N}"
}
TIPS=(
  "等待的时候可以去倒杯水 (｡･ω･｡)ﾉ♡"
  "屏幕在滚动就是没卡住哦～ ٩(ˊᗜˋ*)و"
  "正在努力搬砖中… ε=ε=ε=┏(゜ロ゜;)┛"
  "第一次装会慢一点，之后就快啦 (ฅ´ω\`ฅ)"
  "装好以后记得把 Termux 加进电池白名单～ (｀・ω・´)"
)
tip(){ echo -e "${P}  ♪ ${TIPS[$((RANDOM % ${#TIPS[@]}))]}${N}"; }
# 通过 curl | bash 运行时，输入要从 /dev/tty 读
ask(){ local a; echo -ne "${B}  ? $1 ${N}[Y/n] "; read -r a < /dev/tty; [[ -z "$a" || "$a" =~ ^[Yy] ]]; }
# 默认「否」的提问：要输入 y 才算同意
ask_no(){ local a; echo -ne "${B}  ? $1 ${N}[y/N] "; read -r a < /dev/tty; [[ "$a" =~ ^[Yy] ]]; }

# ---------- 生成控制面板、自动弹面板、桌面快捷方式 ----------
write_menu(){
cat > "$PREFIX/bin/st" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 🍊 橘子酒馆 · Termux 控制面板
# 一键：./sj.sh   自动开菜单：bash ~/.sj.sh   一键启动：bash ~/.sj.sh start
ST_REPO="https://github.com/SillyTavern/SillyTavern.git"
ST_BRANCH="release"
ST_DIR="$HOME/SillyTavern"
NPM_MIRROR="https://registry.npmmirror.com"
# 下载线路：按顺序尝试
REPO_LIST=(
  "$ST_REPO"
  "https://gh-proxy.com/$ST_REPO"
  "https://ghfast.top/$ST_REPO"
)
HELPER_DIR="$ST_DIR/data/default-user/extensions/JS-Slash-Runner"
ST_PORT="${ST_PORT:-8000}"
LOG_FILE="$ST_DIR/nohup.out"
BACKUP_DIR="$HOME/SillyTavern_Backups"
PID_FILE="$HOME/.st.pid"
LOCK_DIR="$HOME/.st.lock"
MANIFEST="$HOME/.st.nodever"
# 面板自身（唯一真身）与在线更新地址
SJ="$HOME/.sj.sh"
ME="$SJ"                       # 自愈时的复制源（本文件就是 ~/.sj.sh）
MENU_URL="https://raw.githubusercontent.com/jiandandezijian-design/sillytavern-termux/main/sj.sh"
G='\033[32m'; Y='\033[33m'; R='\033[31m'; C='\033[36m'; P='\033[35m'; B='\033[1m'; N='\033[0m'

ok(){   echo -e "${G}  ✔ $*${N}"; }
warn(){ echo -e "${Y}  ⚠ $*${N}"; }
err(){  echo -e "${R}  ✘ $*${N}"; }
line(){ echo -e "${C}  ╭──────────────────────────────────────╮${N}"; }
mid(){  echo -e "${C}  │${N}  $*"; }
end(){  echo -e "${C}  ╰──────────────────────────────────────╯${N}"; }

# 端口探测：200/302/303 才算真的起来了
alive(){ local c; c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$ST_PORT/" 2>/dev/null); [[ "$c" == 2* || "$c" == 3* ]]; }
port_busy(){ (echo > /dev/tcp/127.0.0.1/"$ST_PORT") >/dev/null 2>&1; }

need_st(){ [[ -f "$ST_DIR/package.json" ]] || { err "酒馆还没装，先运行 ./sj.sh 安装一下"; return 1; }; }

# 用 PID 文件 + /proc 工作目录双重确认，绝不误杀别的 node
is_running(){
  local p
  if [[ -f "$PID_FILE" ]]; then
    p=$(cat "$PID_FILE" 2>/dev/null)
    [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null && return 0
  fi
  command -v pgrep >/dev/null 2>&1 || return 1
  local q cwd
  cwd=$(readlink -f "$ST_DIR" 2>/dev/null)
  for q in $(pgrep -f "node .*server\.js" 2>/dev/null); do
    if [[ -r "/proc/$q/cwd" && "$(readlink -f "/proc/$q/cwd" 2>/dev/null)" == "$cwd" ]]; then
      echo "$q" > "$PID_FILE"; return 0
    fi
  done
  return 1
}

# 互斥锁：防止两次安装/启动打架
lock_acquire(){
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    local age=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if [[ "$age" -gt 600 ]]; then rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR" 2>/dev/null || return 1
    else warn "另一个操作正在进行，稍候（卡死可删 $LOCK_DIR）"; return 1; fi
  fi
  trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT
  return 0
}

wake_on(){ command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null; return 0; }
wake_off(){ command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null; return 0; }

do_start(){
  need_st || return
  local bg="${1:-foreground}"
  if is_running; then
    ok "已经在运行 → http://127.0.0.1:$ST_PORT"
    command -v termux-open-url >/dev/null 2>&1 && termux-open-url "http://127.0.0.1:$ST_PORT" 2>/dev/null &
    return 0
  fi
  if port_busy; then
    err "端口 $ST_PORT 被占用（可能是残留进程）"; return 1
  fi
  cd "$ST_DIR" || return 1
  wake_on
  if [[ "$bg" == "background" ]]; then
    : > "$LOG_FILE"
    nohup node server.js >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo -e "${G}  ✧ 后台启动中…${N}"
  else
    echo -e "${G}  ✧ 启动中，浏览器会自动打开（第一次要等一会）${N}"
    echo -e "${Y}  关掉：音量下键 + C${N}"
    ( for _ in $(seq 1 180); do
        alive && { command -v termux-open-url >/dev/null 2>&1 && termux-open-url "http://127.0.0.1:$ST_PORT" 2>/dev/null; exit 0; }
        sleep 1
      done ) &
    node server.js &
    echo $! > "$PID_FILE"
    wait $! 2>/dev/null
    rm -f "$PID_FILE"
    wake_off
    ok "酒馆已关闭"
    return 0
  fi
  local i
  for i in $(seq 1 60); do alive && { ok "启动成功 → http://127.0.0.1:$ST_PORT"; return 0; }; sleep 1; done
  err "启动超时，看日志：$LOG_FILE"; tail -n 20 "$LOG_FILE" 2>/dev/null; return 1
}

do_stop(){
  local p
  p=$(cat "$PID_FILE" 2>/dev/null)
  if [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null; then
    kill "$p" 2>/dev/null
    local i; for i in $(seq 1 10); do kill -0 "$p" 2>/dev/null || break; sleep 1; done
    kill -9 "$p" 2>/dev/null
  fi
  # 兜底：只杀工作目录在本站的 node
  local q cwd; cwd=$(readlink -f "$ST_DIR" 2>/dev/null)
  if command -v pgrep >/dev/null 2>&1; then
    for q in $(pgrep -f "node .*server\.js" 2>/dev/null); do
      [[ -r "/proc/$q/cwd" && "$(readlink -f "/proc/$q/cwd" 2>/dev/null)" == "$cwd" ]] && kill -9 "$q" 2>/dev/null
    done
  fi
  rm -f "$PID_FILE"; wake_off
  sleep 1
  if alive; then err "停不掉，试试 音量下键 + C"; else ok "已停止"; fi
}

do_restart(){ do_stop; do_start "$@"; }

do_update(){
  need_st || return
  local was=0; is_running && was=1
  cd "$ST_DIR" || return
  warn "建议先备份（菜单 7）"
  [[ "$was" == 1 ]] && do_stop >/dev/null 2>&1
  local okk=0
  # 1) 先试直连/原 origin
  if git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 pull --rebase --autostash -q 2>/dev/null; then okk=1; fi
  # 2) 不行就走加速镜像，避免单点失效
  if [[ "$okk" == 0 ]]; then
    local url
    for url in "$ST_REPO" "https://gh-proxy.com/$ST_REPO" "https://ghfast.top/$ST_REPO" "https://gh.llkk.cc/$ST_REPO" "https://gh.api.99988866.xyz/$ST_REPO"; do
      echo -e "${C}  ▸ 线路：$url${N}"
      if git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 fetch "$url" HEAD -q 2>/dev/null; then
        git rebase --autostash FETCH_HEAD -q 2>/dev/null || git reset --hard FETCH_HEAD; okk=1; break
      fi
    done
  fi
  if [[ "$okk" == 0 ]]; then err "更新失败（网络）"; [[ "$was" == 1 ]] && do_start background >/dev/null; return 1; fi
  ok "代码已更新到 $(git rev-parse --short HEAD 2>/dev/null)"
  node_sync || warn "依赖同步有问题，可在菜单里选修复"
  [[ -d "$HELPER_DIR/.git" ]] && do_helper
  if [[ "$was" == 1 ]]; then
    echo -ne "${Y}  更新前在运行，现在重启？[Y/n] ${N}"; local a; read -r a
    [[ "$a" =~ ^[Nn]$ ]] || do_start background
  fi
}

# 依赖同步：只有 package.json 变了才重装（大幅缩短更新时间、减少卡住概率）
node_sync(){
  local stamp oldpkg newpkg
  oldpkg=$(cat "$MANIFEST" 2>/dev/null)
  newpkg=$(sha256sum "$ST_DIR/package.json" 2>/dev/null | cut -d' ' -f1)
  if [[ -d "$ST_DIR/node_modules" && "$oldpkg" == "$newpkg" ]]; then
    echo -e "${DIM}  依赖没有变化，跳过 npm install${N}"; return 0
  fi
  ( cd "$ST_DIR" && npm install --no-audit --no-fund --omit=dev --loglevel=error ) \
    && { echo "$newpkg" > "$MANIFEST"; ok "依赖已同步"; } || return 1
}

do_logs(){
  local f=""
  [[ -f "$LOG_FILE" ]] && f="$LOG_FILE"
  [[ -z "$f" ]] && f=$(ls -t "$ST_DIR"/*.log "$INSTALL_LOG" 2>/dev/null | head -n 1)
  if [[ -z "$f" ]]; then warn "暂无日志（还没启动过？）"; return; fi
  echo -e "${C}  日志：$f（$(du -h "$f" 2>/dev/null | cut -f1)）${N}"
  echo -e "${DIM}--------------- 最近 40 行 ---------------${N}"
  tail -n 40 "$f" 2>/dev/null
  echo -e "${DIM}-----------------------------------------${N}"
  echo -ne "${B}  [1] 实时跟随  [2] 清空日志  [0] 返回：${N}"
  local a; read -r a
  case "$a" in
    1) echo -e "${DIM}  Ctrl+C 退出跟随${N}"; tail -f "$f" 2>/dev/null ;;
    2) : > "$f" 2>/dev/null && ok "日志已清空" ;;
  esac
}

do_branch(){
  need_st || return
  cd "$ST_DIR" || return
  echo -e "${C}  当前分支：${B}$(git rev-parse --abbrev-ref HEAD)${N}"
  echo "    1. release（正式版）    2. staging（测试版）    0. 返回"
  echo -ne "${B}  输入数字后回车：${N}"
  local c; read -r c
  case "$c" in
    1) ST_BRANCH="release" ;;
    2) ST_BRANCH="staging" ;;
    *) return ;;
  esac
  local cur was=0
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ "$cur" == "$ST_BRANCH" ]] && { ok "已经在 $ST_BRANCH 了"; return; }
  is_running && was=1
  [[ "$was" == 1 ]] && do_stop >/dev/null 2>&1
  echo -e "${C}  切换到 $ST_BRANCH …${N}"
  if git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 fetch origin "$ST_BRANCH" --depth 1 -q 2>/dev/null \
     && git checkout "$ST_BRANCH" -q 2>/dev/null \
     && git rebase --autostash FETCH_HEAD -q 2>/dev/null; then
    node_sync || npm install --no-audit --no-fund --omit=dev
    ok "已切到 $ST_BRANCH"
  else
    err "切换失败，回滚到 $cur"
    git checkout "$cur" -q 2>/dev/null
  fi
  [[ "$was" == 1 ]] && do_start background
}

# 备份：一份存 ~/SillyTavern_Backups（不依赖存储权限），一份复制到 Download
do_backup(){
  need_st || return
  mkdir -p "$BACKUP_DIR"
  local name="酒馆备份_$(date +%Y%m%d_%H%M).tar.gz"
  local f="$BACKUP_DIR/$name"
  echo -e "${C}  打包中…（数据多时需要一会）${N}"
  if ! tar -czf "$f" -C "$ST_DIR" data 2>/dev/null || ! tar -tzf "$f" >/dev/null 2>&1; then
    rm -f "$f"; err "备份失败"; return 1
  fi
  ok "已备份 → $f（$(du -h "$f" 2>/dev/null | cut -f1)）"
  if [[ -d "$HOME/storage/downloads" ]] || { command -v termux-setup-storage >/dev/null 2>&1 && termux-setup-storage && sleep 3 && [[ -d "$HOME/storage/downloads" ]]; }; then
    cp "$f" "$HOME/storage/downloads/" 2>/dev/null && ok "已复制到手机 Download 文件夹"
  fi
  # 只留最近 5 份，防手机空间被吃光
  local n; n=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
  if [[ "$n" -gt 5 ]]; then
    ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +6 | while read -r x; do rm -f "$x"; done
    echo -e "${DIM}  已清理旧备份，保留最近 5 份${N}"
  fi
}

do_restore(){
  # 两个来源都找：本地备份目录（不需要权限）+ 手机 Download
  command -v termux-setup-storage >/dev/null 2>&1 && [[ ! -d "$HOME/storage/downloads" ]] && { termux-setup-storage; sleep 3; }
  local files=()
  mapfile -t files < <(ls -t "$BACKUP_DIR"/*.tar.gz "$HOME"/storage/downloads/酒馆备份_*.tar.gz 2>/dev/null | awk '!seen[$0]++')
  [[ ${#files[@]} -gt 0 ]] || { warn "没找到备份（$BACKUP_DIR 和 Download 都是空的）"; return; }
  local i
  for i in "${!files[@]}"; do echo -e "  ${B}$((i+1)).${N} $(basename "${files[$i]}")"; done
  echo -ne "${B}  输入要恢复的编号，回车取消：${N}"
  local n; read -r n
  [[ "$n" =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#files[@]} ]] || { ok "已取消"; return; }
  local f="${files[$((n-1))]}"
  tar -tzf "$f" 2>/dev/null | head -n 1 | grep -q '^data' || { err "这个文件不是酒馆备份或已损坏"; return; }
  echo -e "${Y}  会替换现在的聊天/角色卡/设置（旧的会改名保存，不删）${N}"
  echo -ne "${Y}  确认恢复？y 确认，回车取消：${N}"
  local a; read -r a
  [[ "$a" =~ ^[Yy]$ ]] || { ok "已取消"; return; }
  local was=0; is_running && was=1
  [[ "$was" == 1 ]] && do_stop >/dev/null 2>&1
  mkdir -p "$ST_DIR"
  local old=""
  if [[ -d "$ST_DIR/data" ]]; then old="$ST_DIR/data_旧_$(date +%Y%m%d_%H%M%S)"; mv "$ST_DIR/data" "$old"; fi
  if tar -xzf "$f" -C "$ST_DIR"; then
    ok "恢复完成，启动就能看到"
    [[ -n "$old" ]] && echo -e "${C}  旧数据保留在 $(basename "$old")，确认无误后可删${N}"
    [[ "$was" == 1 ]] && do_start background
  else
    rm -rf "$ST_DIR/data"; [[ -n "$old" ]] && mv "$old" "$ST_DIR/data"
    err "恢复失败，原数据已放回"
    [[ "$was" == 1 ]] && do_start background
  fi
}

do_helper(){
  local dir="$HELPER_DIR"
  echo -e "${C}  酒馆助手是可选扩展，装不上不影响酒馆本体${N}"
  mkdir -p "$(dirname "$dir")"
  local url
  if [[ -d "$dir/.git" ]]; then
    if git -C "$dir" -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 pull --ff-only; then ok "助手已更新"; else err "更新失败（网络？）"; fi
    return
  fi
  for url in "https://github.com/jiandandezijian-design/JS-Slash-Runner.git" \
             "https://gh-proxy.com/https://github.com/jiandandezijian-design/JS-Slash-Runner.git" \
             "https://ghfast.top/https://github.com/jiandandezijian-design/JS-Slash-Runner.git" \
             "https://gh.llkk.cc/https://github.com/jiandandezijian-design/JS-Slash-Runner.git"; do
    echo -e "${C}  ▸ 线路：$url${N}"
    if timeout 300 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 clone --progress --depth 1 "$url" "$dir"; then
      ok "助手装好了，重启酒馆后在扩展里看"; return
    fi
    rm -rf "$dir"
  done
  err "助手没装上，网络问题，之后再试"
}

do_fix(){
  need_st || return
  local was=0; is_running && was=1
  [[ "$was" == 1 ]] && do_stop >/dev/null 2>&1
  cd "$ST_DIR" || return
  echo -e "${C}  重装依赖中…（可能需要几分钟）${N}"
  rm -rf node_modules
  rm -f "$MANIFEST"
  npm install --no-audit --no-fund --omit=dev \
    && { sha256sum "$ST_DIR/package.json" | cut -d' ' -f1 > "$MANIFEST"; ok "依赖修复完成"; } \
    || { err "依赖安装失败，检查网络后重试"; return 1; }
  [[ "$was" == 1 ]] && do_start background
}

# 一键自检：把最常见的「用着用着就废了」的原因逐条查出来
do_doctor(){
  echo -e "${C}  ── 环境自检 ──${N}"
  local bad=0
  # 1 运行环境
  command -v node >/dev/null 2>&1 && echo -e "  ${G}✔${N} Node $(node -v)" || { echo -e "  ${R}✘${N} 没有 node（pkg install nodejs）"; bad=1; }
  command -v git  >/dev/null 2>&1 && echo -e "  ${G}✔${N} git $(git --version 2>/dev/null | awk '{print $3}')" || { echo -e "  ${R}✘${N} 没有 git"; bad=1; }
  # 2 安装完整性
  if [[ -f "$ST_DIR/package.json" && -d "$ST_DIR/node_modules" ]]; then
    echo -e "  ${G}✔${N} 酒馆目录完整（$(du -sh "$ST_DIR" 2>/dev/null | cut -f1)）"
  else
    echo -e "  ${R}✘${N} 酒馆目录不完整（缺 package.json 或 node_modules）→ 菜单 4/5 修复"; bad=1
  fi
  # 3 依赖是否与 package.json 对得上
  local pkg; pkg=$(sha256sum "$ST_DIR/package.json" 2>/dev/null | cut -d' ' -f1)
  if [[ -d "$ST_DIR/node_modules" && "$(cat "$MANIFEST" 2>/dev/null)" != "$pkg" ]]; then
    echo -e "  ${Y}!${N} 依赖可能过期（package.json 变过但没重装）→ 菜单 5 可修"
  fi
  # 4 数据目录
  [[ -d "$ST_DIR/data/default-user" ]] && echo -e "  ${G}✔${N} 用户数据在 $(du -sh "$ST_DIR/data" 2>/dev/null | cut -f1)" || echo -e "  ${Y}!${N} 还没有用户数据（首次启动会生成）"
  # 5 磁盘
  local free; free=$(df -m "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
  if [[ -n "$free" && "$free" -lt 500 ]]; then echo -e "  ${R}✘${N} 空间不足（剩 ${free}MB）→ 清理备份或安装包"; bad=1
  else echo -e "  ${G}✔${N} 可用空间 ${free}MB"; fi
  # 6 端口
  if port_busy; then echo -e "  ${Y}!${N} 端口 $ST_PORT 被占用"; fi
  # 7 面板自身
  [[ -f "$SJ" ]] && echo -e "  ${G}✔${N} 控制面板 $SJ" || { echo -e "  ${Y}!${N} 面板文件缺失，已在退出时自动修复"; bad=1; }
  # 8 自动启动项
  grep -q '# >>> 橘子酒馆 >>>' "$HOME/.bashrc" 2>/dev/null && echo -e "  ${G}✔${N} 打开 Termux 自动弹面板已启用" || echo -e "  ${Y}!${N} 自动弹面板未启用"
  # 9 网络：GitHub 与镜像可达性
  local u okk=0
  for u in "$MENU_URL" "https://gh-proxy.com/$ST_REPO" "https://ghfast.top/$ST_REPO"; do
    if curl -s -o /dev/null --max-time 6 -r 0-0 "$u" 2>/dev/null; then okk=1; echo -e "  ${G}✔${N} 线路通：$u"; break; fi
  done
  [[ "$okk" == 1 ]] || echo -e "  ${Y}!${N} 镜像都不通（更新/重装会失败，换网络再试）"
  echo
  [[ "$bad" == 1 ]] && warn "有需要处理的问题，按上面提示修一下" || ok "自检通过"
  return 0
}

do_uninstall(){
  echo -e "${R}${B}  ⚠ 会删除酒馆、助手、聊天记录和角色卡！${N}"
  echo -ne "${Y}  真要卸载？y 确认，回车取消：${N}"
  local a; read -r a
  [[ "$a" =~ ^[Yy]$ ]] || { ok "已取消"; return; }
  echo -ne "${Y}  卸载前先导出备份？[Y/n] ${N}"
  read -r a
  if [[ -z "$a" || "$a" =~ ^[Yy] ]]; then
    do_backup
    echo -ne "${Y}  备份好了就输入 y 继续卸载：${N}"
    read -r a
    [[ "$a" =~ ^[Yy]$ ]] || { ok "已取消"; return; }
  fi
  do_stop >/dev/null 2>&1
  rm -rf "$ST_DIR" "$HOME/.shortcuts/启动酒馆"
  [[ -f "$HOME/.bashrc" ]] && sed -i '/# >>> 橘子酒馆 >>>$/,/^# <<< 橘子酒馆 <<<$/d' "$HOME/.bashrc"
  rm -f "$SJ" ~/sj.sh "$PID_FILE" "$MANIFEST" ~/.st_latest ~/.st_update_check
  echo -e "${C}  备份保留在 $BACKUP_DIR（没删）${N}"
  ok "卸载完成，有缘再见～"
  exit 0
}

# 面板自愈：如果 ~/.sj.sh 丢了（被误删/U盘清理/卸载残留），
# 只要用户还能运行 st 或 bash sj.sh，就从本进程内存里把它重新写回去。
repair_on_exit(){
  if [[ ! -s "$SJ" ]]; then
    mkdir -p "$(dirname "$SJ")"
    cp "$ME" "$SJ" 2>/dev/null && chmod +x "$SJ" && echo -e "${G}  ✔ 控制面板已自动修复${N}" && return 0
    echo -e "${Y}  ⚠ 控制面板文件缺失，联网会自动拉取${N}"
  fi
  return 0
}

# 菜单自身在线更新（不会丢功能：新版本校验通过才替换）
menu_update(){
  echo -e "${C}  检查菜单更新…${N}"
  local tmp="${TMPDIR:-$HOME}/sj_new.$$"
  local url
  for url in "$MENU_URL" "https://gh-proxy.com/$MENU_URL" "https://ghfast.top/$MENU_URL" "https://gh.llkk.cc/$MENU_URL"; do
    if curl -fsSL --max-time 20 -o "$tmp" "$url" 2>/dev/null && bash -n "$tmp" 2>/dev/null; then
      if cmp -s "$tmp" "$SJ"; then ok "已经是最新版"; rm -f "$tmp"; return 0; fi
      cp "$tmp" "$SJ" && chmod +x "$SJ" && ok "菜单已更新，按回车生效" && rm -f "$tmp"
      echo -ne "${C}  按回车重开面板…${N}"; read -r
      exec bash "$SJ"
    fi
  done
  rm -f "$tmp"; err "更新失败（网络不通），可稍后再试"
}

# ---- 快捷调用（桌面小部件/外部调用）----
case "$1" in
  start)   do_start background; exit $? ;;
  startbg) do_start background; exit $? ;;
  stop)    do_stop; exit ;;
  restart) do_restart background; exit $? ;;
  status)  if is_running; then echo "running"; else echo "stopped"; fi; exit 0 ;;
  doctor)  do_doctor; exit ;;
  helper)  do_helper; exit ;;
esac

# 进来先修一次面板（静默：只在文件真丢失时提示）
[[ -s "$SJ" ]] || repair_on_exit

while true; do
  clear
  echo
  line
  mid "${B}🍊 橘子酒馆 · Termux 控制面板${N}"
  end
  echo
  if alive; then echo -e "${G}  ● 运行中${N} → http://127.0.0.1:8000"; else echo -e "${R}  ○ 未运行${N}"; fi
  echo
  echo -e "${C}  —— 管理 ——${N}"
  echo -e "  ${B}[1]${N} 启动   ${B}[2]${N} 停止   ${B}[3]${N} 重启"
  echo
  echo -e "${C}  —— 维护 ——${N}"
  echo -e "  ${B}[4]${N} 更新   ${B}[5]${N} 日志   ${B}[6]${N} 切换分支"
  echo
  echo -e "${C}  —— 数据 ——${N}"
  echo -e "  ${B}[7]${N} 备份   ${B}[8]${N} 恢复"
  echo
  echo -e "  ${B}[9]${N} 卸载   ${B}[0]${N} 退出"
  echo
  echo -e "${C}  —— 其他 ——${N}"
  echo -e "  ${B}[s]${N} 自检   ${B}[u]${N} 更新菜单"
  echo
  echo -ne "${B}  请输入选项 [0-9/s/u]: ${N}"
  read -r c
  case "$c" in
    1) do_start ;;
    2) do_stop ;;
    3) do_restart ;;
    4) do_update ;;
    5) do_logs ;;
    6) do_branch ;;
    7) do_backup ;;
    8) do_restore ;;
    9) do_uninstall ;;
    0) repair_on_exit; echo -e "${P}  已退出，下次输入 ./sj.sh 或 bash ~/.sj.sh (ﾉ´▽｀)ﾉ♪${N}"; exit 0 ;;
    s|S) do_doctor ;;
    u|U) menu_update ;;
    "") ;;
    *) warn "没有这个选项哦" ;;
  esac
  echo
  echo -ne "${C}  按回车返回面板…${N}"
  read -r
done

EOF

chmod +x "$SJ"
ok "已创建控制面板：$SJ（磁盘上的 sj.sh 指向它）"
# 磁盘上的 ./sj.sh 变成转接器，避免两份菜单不同步
if [[ "$(readlink -f "$SELF" 2>/dev/null)" != "$(readlink -f "$SJ" 2>/dev/null)" ]]; then
  cp "$SELF" "$SJ" 2>/dev/null
  cat > "$SELF" <<'SJWRAP'
#!/data/data/com.termux/files/usr/bin/bash
# 🍊 橘子酒馆 · 转接器（真正逻辑在 ~/.sj.sh）
exec bash "$HOME/.sj.sh" "$@"
SJWRAP
  chmod +x "$SELF"
  ok "已把 ./$(basename "$SELF") 设为转接器"
fi

# 打开 Termux 时自动显示控制面板（重复安装不会重复添加）
if ! grep -q "# >>> 橘子酒馆 >>>" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'SJRC'
# >>> 橘子酒馆 >>>
[[ $- == *i* && -z "$ST_MENU_SHOWN" ]] && { export ST_MENU_SHOWN=1; bash "$HOME/.sj.sh"; }
# <<< 橘子酒馆 <<<
SJRC
fi
ok "已设置打开 Termux 自动显示控制面板"
mkdir -p "$HOME/.shortcuts"
cat > "$HOME/.shortcuts/启动酒馆" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
/data/data/com.termux/files/usr/bin/bash "$HOME/.sj.sh" start
EOF
chmod +x "$HOME/.shortcuts/启动酒馆"
ok "已创建桌面快捷方式（需装 Termux:Widget）"
}

# 只更新控制面板（不重装任何东西）
if [[ "$1" == "--update-menu" ]]; then
  [[ "$PREFIX" == *com.termux* ]] || { echo "请在 Termux 里运行"; exit 1; }
  write_menu
  exit 0
fi

clear
# 把安装过程同时记录到日志文件，方便排查
exec 3>&1 4>&2
exec > >(tee "$LOG") 2>&1
echo -e "\033[2m  安装脚本 $SCRIPT_VER · $(date '+%Y-%m-%d %H:%M')\033[0m"
echo -e "${P}"
echo "       /\\_/\\"
echo "      ( o.o )    ✧ 酒馆一键安装 ✧"
echo "       > ^ <"
echo -e "${N}${C}  ╭───────────────────────${N}"
echo -e "${C}  │${N}  全程大概 5～15 分钟，放着就好～"
echo -e "${C}  ╰───────────────────────${N}"

# ---------- 0. 检查环境 ----------
[[ "$PREFIX" == *com.termux* ]] || fail "请在 Termux 里运行这个脚本（不是手机自带终端哦）"

# 互斥锁：防止同时开两个 Termux 窗口重复安装（这是「装到一半废掉」最常见原因之一）
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  _age=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0) ))
  if [[ "$_age" -gt 900 ]]; then
    rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR" 2>/dev/null || fail "无法创建锁目录 $LOCK_DIR"
  else
    fail "另一个安装/操作正在进行（$_age 秒前开始）。如果确认没有在跑，删掉 $LOCK_DIR 再试"
  fi
fi
trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT

# ---------- 1. 换源 ----------
step 1 "选择软件源"
set_source(){ echo "deb $1 stable main" > "$PREFIX/etc/apt/sources.list"; }
# 依次试国内源，第一个能刷新成功的就用它
pick_mirror(){
  local i
  for i in "${!MIRROR_URLS[@]}"; do
    info "试试${MIRROR_NAMES[$i]}…"
    set_source "${MIRROR_URLS[$i]}"
    if apt-get -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 update; then
      TERMUX_MIRROR="${MIRROR_URLS[$i]}"
      ok "已切换到${MIRROR_NAMES[$i]}"
      return 0
    fi
    warn "${MIRROR_NAMES[$i]}现在用不了，换下一个"
  done
  return 1
}

if ask "要换成国内软件源吗？（国内网络强烈建议选 Y）"; then
  if ! pick_mirror; then
    warn "国内源都连不上，先用官方源试试（可能会比较慢）"
    TERMUX_MIRROR="$OFFICIAL_MIRROR"
    set_source "$TERMUX_MIRROR"
  fi
else
  info "好哒，保持原来的源～"
fi

# ---------- 2. 安装基础软件 ----------
step 2 "更新软件包"
tip
apt-get update || fail "软件源连不上，检查一下网络（关掉 VPN 或换成手机流量试试），再重新运行一次"
apt-get -y -o Dpkg::Options::=--force-confnew upgrade || fail "软件包更新失败，检查一下网络再重新运行一次"
# 更新时软件源配置可能被新版本覆盖，这里重新设置一次并刷新列表
[[ -n "$TERMUX_MIRROR" ]] && set_source "$TERMUX_MIRROR"
apt-get update || fail "软件源连不上，检查一下网络（关掉 VPN 或换成手机流量试试），再重新运行一次"
ok "软件包更新好啦"

step 3 "安装基础工具"
PKGS="git curl"
command -v node >/dev/null 2>&1 || PKGS="$PKGS nodejs-lts"
info "安装 $PKGS ..."
tip
apt-get install -y $PKGS || fail "基础软件安装失败"
ok "Node $(node -v) 已就绪"

# ---------- 3. 下载酒馆 ----------
step 4 "下载酒馆本体"
OLD_ST=""
if [[ -f "$ST_DIR/package.json" ]]; then
  warn "发现已经装过酒馆了，跳过下载（想更新请在菜单里选「更新」）"
else
  # 文件夹在但不完整（比如之前下载到一半断了）：先挪到一边，保住里面可能有的聊天数据
  if [[ -e "$ST_DIR" ]]; then
    OLD_ST="${ST_DIR}_旧_$(date +%Y%m%d_%H%M%S)"
    mv "$ST_DIR" "$OLD_ST" || fail "酒馆文件夹不完整，而且挪不动它，可以手动删掉 ~/SillyTavern 再试"
    warn "发现一个不完整的酒馆文件夹，已经挪到 $(basename "$OLD_ST")，重新下载"
  fi
  cloned=0
  # 网络时好时坏的话，所有线路最多轮流试 3 遍
  for round in 1 2 3; do
    [[ $round -gt 1 ]] && { warn "第 $round 轮重试，网络不稳的话多试几次常常就好了"; sleep 3; }
    for url in "${REPO_LIST[@]}"; do
      info "尝试线路：$url"
      info "  （40 秒没动静会自动换下一条线路）"
      if timeout 900 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 clone --progress --depth 1 -b "$ST_BRANCH" "$url" "$ST_DIR" \
         && [[ -f "$ST_DIR/package.json" ]]; then
        cloned=1; break 2
      fi
      # 只有确认是半成品才删，避免误删可续传的进度
      [[ -d "$ST_DIR/.git" ]] || rm -rf "$ST_DIR"
      warn "这条线路不通，换下一条"
    done
  done
  [[ $cloned == 1 ]] || fail "试了好几轮都没下载下来，网络可能不太稳。换个网络（Wi-Fi / 手机流量 / 开关 VPN）再运行一次试试"
  ok "酒馆下载完成"
  # 旧文件夹里有聊天数据的话，搬回来
  if [[ -n "$OLD_ST" && -d "$OLD_ST/data" ]]; then
    mv "$OLD_ST/data" "$ST_DIR/data" && ok "已经把旧文件夹里的聊天和角色卡搬回来了"
  fi
fi

# ---------- 4. 安装依赖 ----------
step 5 "安装酒馆依赖"
info "用国内 npm 源，会刷一堆英文，别怕～"
tip
npm config set registry "$NPM_MIRROR"
cd "$ST_DIR" || fail "找不到酒馆文件夹"
if ! npm install --no-audit --no-fund --omit=dev --loglevel=error; then
  warn "精简安装失败，改用完整安装再试一次"
  npm install --no-audit --no-fund || fail "依赖安装失败：换网络重跑本脚本即可续装，已下好的部分不会重下"
fi
# 记录依赖指纹：以后 package.json 没变就不必再跑 npm install（大幅减少更新时间）
sha256sum "$ST_DIR/package.json" 2>/dev/null | cut -d' ' -f1 > "$MANIFEST"
ok "依赖安装完成"


# ---------- 5. 生成控制面板 ----------
step 6 "布置小窝"
write_menu

# ---------- 7. 安装酒馆助手（装不上也不影响酒馆本体） ----------
step 7 "酒馆助手（可选）"
echo -e "${C}  酒馆助手是可选扩展，装不上不影响酒馆本体${N}"
if ask_no "要安装酒馆助手吗？"; then
  bash "$SJ" helper || warn "酒馆助手先跳过，酒馆本体已经装好，之后在菜单里选 4 补装就行"
else
  info "好哒，跳过酒馆助手，以后想装可以在菜单里选 4～"
fi


# ---------- 完成 ----------
echo
echo -e "${P}       /\\_/\\      ✧*｡ 安装完成 ｡*✧"
echo -e "      ( ^ω^ )    ヽ(✿ﾟ▽ﾟ)ノ"
echo -e "       > ♡ <${N}"
echo -e "${G}  ══════════════════════════════════════${N}"
echo -e "   以后打开 Termux 会自动弹出控制面板；关掉后输入 ${C}${B}./sj.sh${N} 或 ${C}${B}bash ~/.sj.sh${N} 叫回来"
echo -e "   装了 Termux:Widget 的话，桌面添加小部件就能一键启动"
echo -e "   记得把 Termux 加进电池白名单，不然切后台会被杀～"
echo -e "${G}  ══════════════════════════════════════${N}"
echo
echo -e "${C}  安装日志保存在 ~/橘子酒馆安装日志.txt${N}"
# 停止记录日志，之后的酒馆运行输出不写进日志
exec 1>&3 2>&4 3>&- 4>&-
sleep 0.3
if ask "现在就启动酒馆吗？"; then
  exec bash "$SJ" start < /dev/tty
fi
echo -e "${P}  好哒～想玩的时候输入 ./sj.sh 就行 (｡•ᴗ-)✧${N}"
