# Endfield Tray

一个为 **KDE Plasma 6 + Wayland** 写的紧凑型悬浮任务栏。视觉语言参考《明日方舟：终末地》的 UI：深灰 HUD、橄榄荧光绿、细线框、等宽小字和菱形标记。

它不是 Plasma 小组件，而是独立的 Qt 6 / Qt Quick + LayerShell 程序；因此可以完全脱离 KDE 默认面板的视觉和布局，悬浮在屏幕底部中央。

![Endfield Tray 预览](docs/preview.png)

> 非官方粉丝作品，与《明日方舟：终末地》的开发方 / 发行方无隶属关系。

## 功能

- **紧凑圆角长条**：灰色 HUD，展开约 580×44 逻辑像素；鼠标离开后收缩为 108×44 的纯时间胶囊，悬浮在屏幕底部中央。
- **电源二级菜单**：睡眠、重启、关机、注销；操作需要二次确认。睡眠走 logind，重启/关机/注销走 `org.kde.Shutdown`。
- **窗口二级菜单**：读取 KWin 当前窗口；点击切换，中键最小化，悬停显示关闭按钮。窗口数据来自 Plasma 的 `LibTaskManager`。
- **系统托盘**：自带 StatusNotifierItem host，不依赖 Plasma 系统托盘；支持左键激活、右键菜单、DBusMenu 子菜单、托盘抽屉。
- **Wi-Fi**：读取 NetworkManager；状态栏只显示圆环信号徽章，不显示 SSID；详细面板可扫描、连接（含密码输入）、断开、开关 radio。
- **蓝牙**：状态栏在 Wi-Fi 左侧显示蓝牙按钮；详细面板可开关适配器、扫描附近设备、连接 / 断开已知设备（BlueZ / `bluetoothctl`）。
- **音量**：PipeWire / WirePlumber (`wpctl`)，支持滑块、滚轮调节和静音；状态栏用圆环徽章显示音量；详细面板可切换输出设备。
- **电池**：sysfs `power_supply`；状态栏用圆环徽章显示电量，详细面板显示百分比、充电状态、剩余时间、健康度，并可切换省电 / 平衡 / 性能电源模式（power-profiles-daemon）。
- **圆环徽章**：WiFi / 音量 / 电池采用参考项目的 HUD 进度徽章——深灰圆盘、荧光绿弧形进度、中央图标、圆形端点；窗口、蓝牙和电源是按钮型圆环，外圈只表示按钮边界，不伪装成进度。
- **扁平外壳 + 轻投影**：条和面板都是纯色 `#312F30`，没有外描边、没有顶部高光 / 底部压暗渐变；外侧只有一层很轻的柔和阴影。
- **紧凑详情页**：窗口 / 蓝牙 / Wi-Fi / 音量 / 电池 / 电源面板整体缩放为 90%，仍以对应按钮为中心展开。
- **低内存**：详情面板按需加载，未打开时不创建列表/图标委托；透明图层只覆盖屏幕底部 620px，不再占用整屏缓冲。
- **不抢焦点**：打开详情页不会激活 HUD 或打断当前窗口；输入区域只覆盖条和详情页，网页滚动等操作仍然正常。只有 Wi-Fi 密码输入时才临时请求键盘焦点。
- **外部操作自动收起**：鼠标离开面板/悬浮条后，详情页会自动关闭，悬浮条收缩为时间胶囊；点击网页或切换窗口即可回到干净桌面。
- **全屏自动隐藏**：当前活动窗口进入全屏时，HUD 会完全隐藏并清空输入区域；退出全屏后恢复为时间胶囊，不会遮挡全屏视频或游戏。

![圆环徽章](docs/ring-badges.png)
- **时钟**：30 秒刷新一次，不做无意义的秒针/常驻动画；鼠标离开后自动收缩为只显示时间的小胶囊。
- **最近窗口**：展开时显示最近使用的 3 个应用图标（按应用分组，同应用只占一个位置，不显示应用名）；悬停多窗口组可在上方展开该组的窗口列表，其余窗口仍在 `WINDOWS` 二级菜单中。
- **低空载开销**：没有常驻扫描线、粒子或循环动画；收缩状态下暂停音频、网络、电池和托盘轮询，只在展开时恢复。圆环重绘也只发生在数值变化时。

收缩状态只保留时间，悬停/点击展开：

![收缩状态](docs/collapsed.png)

最近窗口按应用分组，最多 3 个应用以图标占据展开条；多窗口组悬停展开：

![最近窗口分组](docs/recent.png)

![网络面板](docs/network.png)

音量详细面板可切换输出设备：

![音量与输出设备](docs/volume.png)

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
  networkmanager pipewire wireplumber bluez-utils glib2
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

`--preview-panel` 支持 `windows`、`power`、`network`、`volume`、`battery`、`bluetooth`、`tray`、`trayMenu`，以及开发用的 `recent`。

## Homebrew（Linux x86_64）

预编译二进制通过公开 tap 安装，不依赖 Homebrew 构建 Qt：

```bash
brew tap hhdtc/tap
brew install endfield-tray
endfield-tray --autostart enable
```

查看 / 关闭登录自启动：

```bash
endfield-tray --autostart status
endfield-tray --autostart disable
```

升级：

```bash
brew update
brew upgrade endfield-tray
```

Homebrew 只负责安装二进制；Qt 6 / KDE Plasma / NetworkManager / PipeWire / BlueZ 仍使用系统包（见上方 Arch/CachyOS 依赖）。

## 开机自启动

安装时使用：

```bash
./scripts/install.sh --autostart
```

也可以在安装后随时查看 / 修改：

```bash
# 查看是否启用
endfield-tray --autostart status

# 启用（写入 ~/.config/autostart/endfield-tray.desktop）
endfield-tray --autostart enable

# 禁用
endfield-tray --autostart disable
```

这是 KDE 登录后的 XDG autostart，不是系统级 systemd 服务；需要有 Wayland 会话。`--autostart` 在创建 QGuiApplication 之前处理，因此可以在无显示环境/脚本里使用。

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
- **不使用常驻动画**：只有条展开/收缩（180 ms）、面板打开/关闭、Toast 和扫描中的刷新图标会有短动画；没有循环扫描线、呼吸灯或每秒重绘。
- **输入区域跟随可见区域**：LayerShell 窗口保持全屏透明，但通过 Wayland `wl_surface` 输入区域限制为当前可见的胶囊、分组浮层或面板；这样收缩后不会挡住桌面点击。
- **轮询间隔**：展开时音频 3 s、网络 30 s、电池 60 s、托盘属性 30 s；收缩后全部暂停；打开对应面板时会按需立即刷新。
- **圆角长条**：外层是 `Rectangle + radius` 的轻量框架，不使用大面积 Canvas/FBO，减少 GPU/内存占用。

## 代码结构

```text
src/
  main.cpp           Qt/QML 入口、单实例锁、字体、命令行
  theme.*            调色板与字体
  windowmodel.*      LibTaskManager -> 扁平窗口模型
  recentappsmodel.*  窗口按应用分组 / 最近使用排序
  inputregion.*      全屏透明 LayerShell 的输入区域裁剪
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
- 没有“整条自动隐藏”选项；鼠标离开后只收缩为时间胶囊，仍保留一个可悬停的入口。
- 最大化窗口会延伸到悬浮条下方（LayerShell 不额外设置 strut，以免 KWin 把悬浮条整体上推）。
- 电源操作的可用性取决于 `org.kde.Shutdown` / logind / polkit 配置。

## 许可证

代码以 MIT License 发布，见 [LICENSE](LICENSE)。

内置字体：

- Rajdhani — SIL Open Font License 1.1，见 `assets/fonts/OFL-Rajdhani.txt`
- JetBrains Mono — SIL Open Font License 1.1，见 `assets/fonts/OFL-JetBrainsMono.txt`
