# 🍊 橘子酒馆 · Termux 一键部署

安卓 Termux 上一键部署并管理 SillyTavern（酒馆）。全程国内源加速，不用梯子。

## 一条命令安装

打开 Termux，粘贴回车：

```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/jiandandezijian-design/sillytavern-termux/main/sj.sh | bash
```

备用线路（上面不通时换这条）：

```bash
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/jiandandezijian-design/sillytavern-termux/main/sj.sh | bash
```

装好后：**每次打开 Termux 自动弹出控制面板**，关掉后输入 `./sj.sh` 或 `bash ~/.sj.sh` 叫回来。

## 控制面板

```
╭──────────────────────────────────────╮
│  🍊 橘子酒馆 · Termux 控制面板
╰──────────────────────────────────────╯

  ● 运行中 → http://127.0.0.1:8000

  —— 管理 ——
  [1] 启动   [2] 停止   [3] 重启

  —— 维护 ——
  [4] 更新   [5] 日志   [6] 切换分支

  —— 数据 ——
  [7] 备份   [8] 恢复

  [9] 卸载   [0] 退出

  —— 其他 ——
  [s] 自检   [u] 更新菜单
```

## 为长期稳定做的设计

| 问题 | 处理方式 |
|------|---------|
| 镜像挂了一个就装不动 | 10 条加速线路轮换，任一条通即可 |
| npm 更新一次卡十几分钟 | 记录 dependencies 指纹，`package.json` 没变就跳过 `npm install` |
| 停止时误杀别的 node | PID 文件 + `/proc/<pid>/cwd` 双重确认，只动本站进程 |
| 更新断了变半成品 | 更新前自动停服，失败自动回滚到原提交 |
| 面板文件被清理掉 | 每次启动自检，缺失自动重建；`[u]` 可在线更新面板 |
| 重复开窗口装两遍 | 互斥锁，10 分钟内不允许并发安装 |
| 手机空间被备份吃光 | 本地备份目录自动只留最近 5 份 |
| 出问题不知道查哪 | 菜单 `[s]` 一键自检：Node/git/目录/依赖/磁盘/端口/镜像连通性 |

## 常用参数

```bash
bash ~/.sj.sh            # 打开面板
bash ~/.sj.sh start      # 后台启动（桌面小部件用）
bash ~/.sj.sh stop       # 停止
bash ~/.sj.sh status     # running / stopped
bash ~/.sj.sh doctor     # 自检
ST_PORT=8080 bash ~/.sj.sh   # 换端口
```

## Termux 保活

玩酒馆期间 Termux 必须留在后台：

- 挂小窗模式
- 系统设置 → 省电策略 → 无限制
- 长按任务卡片 → 锁定
- 面板启动时会自动开唤醒锁（需装 termux-api）

## 数据目录

| 路径 | 说明 |
|------|------|
| `SillyTavern/data/default-user` | 用户数据（角色卡/聊天/设置） |
| `SillyTavern_Backups` | 备份文件（保留最近 5 份） |
| `~/橘子酒馆安装日志.txt` | 安装日志 |

## 卸载

菜单 `[9]`，会先问你要不要备份。备份目录不会被删。

## 许可证

MIT License
