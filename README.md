# 🍊 橘子酒馆 · Termux 一键部署

安卓 Termux 一键部署 SillyTavern（酒馆），全国内源加速，无需梯子。

## 一条命令安装

打开 Termux，粘贴回车：

```bash
curl -O https://raw.githubusercontent.com/jiandandezijian-design/sillytavern-termux/main/st.sh && bash st.sh
```

## 功能

首次运行自动安装，之后每次打开 Termux 输入 `st` 进入控制面板：

```
  ═══════ 酒馆管理 ═══════
  [1] 启动酒馆       [2] 停止酒馆       [3] 重启酒馆

  ═══════ 维护升级 ═══════
  [4] 更新到最新版   [5] 查看运行日志   [6] 切换分支

  ═══════ 数据管理 ═══════
  [7] 备份用户数据   [8] 恢复用户数据

  ═══════ 系统 ═══════
  [9] 完全卸载酒馆   [0] 退出
```

- ✅ 全程国内源加速，无需梯子
- ✅ 清华镜像（Termux 包）+ npmmirror（npm）+ GitHub 加速代理（源码）
- ✅ 支持 release / staging 双分支
- ✅ 数据备份恢复，MT 管理器直接操作
- ✅ 自动保活提示

## Termux 保活

玩酒馆期间 Termux 必须保持后台运行：

- 挂小窗模式
- 系统设置 → 省电策略 → 无限制
- 长按卡片 → 锁定

## 数据目录

用 MT 管理器授权 Termux 后：

| 路径 | 说明 |
|------|------|
| `SillyTavern/data/default-user` | 用户数据（角色卡/聊天/设置） |
| `SillyTavern_Backups` | 备份文件 |

## 许可证

MIT License
