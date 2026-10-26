# Endfield Tray

一个为 **KDE Plasma 6 + Wayland** 写的紧凑型悬浮任务栏。视觉语言参考《明日方舟：终末地》的 UI：深炭黑、酸性荧光绿、细线框、等宽小字和菱形标记。

它不是 Plasma 小组件，而是独立的 Qt 6 / Qt Quick + LayerShell 程序；因此可以完全脱离 KDE 默认面板的视觉和布局，悬浮在屏幕底部中央。

![Endfield Tray 预览](docs/preview.png)

> 非官方粉丝作品，与《明日方舟：终末地》的开发方 / 发行方无隶属关系。

## 功能

- **紧凑圆角长条**：约 860×56 逻辑像素，默认悬浮在屏幕底部中央。
- **电源二级菜单**：睡眠、重启、关机、注销；操作需要二次确认。睡眠走 logind，重启/关机/注销走 `org.kde.Shutdown`。
- **窗口二级菜单**：读取 KWin 当前窗口；点击切换，中键最小化，悬停显示关闭按钮。窗口数据来自 Plasma 的 `LibTaskManager`。
- **系统托盘**：自带 StatusNotifierItem host，不依赖 Plasma 系统托盘；支持左键激活、右键菜单、DBusMenu 子菜单、托盘抽屉。
- **Wi-Fi**：读取 NetworkManager；显示当前 SSID / 信号，扫描、连接（含密码输入）、断开、开关 radio。
- **音量**：PipeWire / WirePlumber (`wpctl`)，支持滑块、滚轮调节和静音。
- **电池**：sysfs `power_supply`；显示百分比、充电状态、剩余时间、健康度。
- **时钟**：15 秒刷新一次，不做无意义的秒针/常驻动画。
- **低空载开销**：没有常驻扫描线、粒子或循环动画；网络/音频/电池轮询间隔经过拉长。

![网络面板](docs/network.png)

## 环境要求

已在以下环境测试：

- CachyOS Linux (Arch 系)
- KDE Plasma **6.8.1**，KWin **6.8.1**，Wayland 会话
- Qt **6.12.0**
- 分辨率 1920×1200，缩放 1.25×
- NetworkManager、PipeWire + WirePlumber

需要 **Wayland 会话**。程序通过 `layer-shell-qt` 创建底部 layer surface，因此不支持纯 X11 下的悬浮定位。

### Arch / CachyOS 依赖

```bash
sudo pacman -S --needed \
  base-devel cmake ninja \
  qt6-base qt6-declarative qt6-wayland \
  layer-shell-qt plasma-workspace \
  networkmanager pipewire wireplumber glib2
```

其中 `plasma-workspace` 提供 `LibTaskManager` 和 Plasma 的窗口任务接口。

## 构建与运行

```bash
git clone https://github.com/hhdtc/EndfieldTray.git
cd EndfieldTray

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

./build/endfield-tray
```

开发时可以直接抓取程序自己的 QML 截图，不需要系统截图权限：

```bash
./build/endfield-tray --no-lock --screenshot /tmp/endfield.png
./build/endfield-tray --no-lock --preview-panel power --screenshot /tmp/power.png
```

`--preview-panel` 支持 `windows`、`power`、`network`、`volume`、`battery`、`tray`、`trayMenu`。

## 安装

```bash
# 安装到 ~/.local，并加入开机自启
./scripts/install.sh --autostart

# 同时把现有 Plasma 面板设为自动隐藏
./scripts/install.sh --autostart --hide-panel
```

脚本会安装：

- `~/.local/bin/endfield-tray`
- `~/.local/bin/endfield-plasma-panel`
- 应用程序菜单项
- 图标
- 可选的 `~/.config/autostart/endfield-tray.desktop`

### 隐藏 KDE 面板

```bash
# 设置所有 Plasma 面板为自动隐藏（可逆，不会删除面板布局）
endfield-plasma-panel hide

# 恢复
endfield-plasma-panel show

# 查看状态
endfield-plasma-panel status
```

悬浮条默认比屏幕底边高 **10 px**，并使用 LayerShell 的 overlay 层，位于 Plasma 自动隐藏面板之上。`bottomGap` 在 `qml/Main.qml` 中可调。

### 卸载

```bash
./scripts/uninstall.sh
```

不会自动修改 Plasma 面板状态；恢复面板使用：

```bash
endfield-plasma-panel show
```

## 使用

| 操作 | 效果 |
| --- | --- |
| 点击左侧 `WINDOWS` | 打开窗口列表 |
| `WINDOWS` 列表中左键 | 切换窗口 |
| `WINDOWS` 列表中键 | 最小化 / 还原 |
| 点击 WiFi / 音量 / 电池 | 打开对应面板 |
| 在音量 chip 上滚轮 | 调节音量 |
| 点击托盘图标 | 激活；部分程序为打开菜单 |
| 托盘图标右键 | 打开 DBusMenu |
| 点击托盘抽屉（点阵图标） | 查看全部托盘项目 |
| 点击右侧圆形电源 | 打开电源菜单 |
| `Esc` / 点击空白 | 关闭当前面板 |

## 设计说明

- **不是一个 Plasma 面板**：`plasmashell` 的 panel/applet 约束太强，难以做到完整的悬浮圆角长条和自定义二级菜单。这里使用 LayerShell 直接和 KWin 组合，窗口任务使用 Plasma 的 `LibTaskManager`，托盘使用原生 StatusNotifier 协议。
- **不使用常驻动画**：只有面板打开/关闭、Toast 和扫描中的刷新图标会有短动画；没有循环扫描线、呼吸灯或每秒重绘。
- **轮询间隔**：音频 2 s、网络 20 s、电池 30 s、托盘属性 15 s；打开对应面板时会按需立即刷新。
- **圆角长条**：外层是 `Rectangle + radius` 的轻量框架，不使用大面积 Canvas/FBO，减少 GPU/内存占用。

## 代码结构

```text
src/
  main.cpp           Qt/QML 入口、单实例锁、字体、命令行
  theme.*            调色板与字体
  windowmodel.*      LibTaskManager -> 扁平窗口模型
  traymodel.*        StatusNotifierItem host / 托盘项目
  traycontroller.*   DBusMenu 导入与菜单事件
  systemservice.*    WiFi / 音频 / 电池 / 电源
qml/
  Main.qml           悬浮条、窗口尺寸、菜单定位
  components/        圆角框架、图标、chip、按钮、滑块
  panels/            窗口 / 电源 / 网络 / 音量 / 电池 / 托盘 / 托盘菜单
scripts/
  install.sh
  plasma-panel.sh
  uninstall.sh
```

## 已知限制

- 仅验证 KDE Plasma 6.8 Wayland；X11 不保证。
- 不提供设置界面；修改宽度、间距、颜色需要改 `src/theme.h` / `qml/Main.qml` 后重新构建。
- 托盘图标依赖应用提供的 `IconName` 或主题图标；少数应用只提供 pixmap，会显示菱形占位符。
- 没有系统级自动隐藏；悬浮条常驻显示。
- 最大化窗口会延伸到悬浮条下方（LayerShell 不额外设置 strut，以免 KWin 把悬浮条整体上推）。
- 电源操作的可用性取决于 `org.kde.Shutdown` / logind / polkit 配置。

## 许可证

代码以 MIT License 发布，见 [LICENSE](LICENSE)。

内置字体：

- Rajdhani — SIL Open Font License 1.1，见 `assets/fonts/OFL-Rajdhani.txt`
- JetBrains Mono — SIL Open Font License 1.1，见 `assets/fonts/OFL-JetBrainsMono.txt`
