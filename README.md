# 自动真后台 (AutoBackground17)

一个面向 iOS 17.0 – 17.3.1 无根（rootless）越狱的插件：应用切到后台后**进程保持真正运行**，不会被系统挂起（suspend）或冻结（freeze）。

默认**全自动**：安装后无需配置，所有应用进入后台都会保持运行。可在 设置 → 自动真后台 中按需调整。

---

## 工作原理（两层方案）

### 1. 主方案：SpringBoard 侧阻止挂起
在 SpringBoard 进程中 Hook FrontBoard / SpringBoard 的私有类：

| Hook | 作用 |
| --- | --- |
| `FBApplicationProcess -suspend` / `-_suspend` | 阻止进程挂起（核心：真后台） |
| `SBApplication -suspend` | 双重保险，同样阻止挂起 |
| `SBApplication -isFreezingEnabled` | iOS 15+ 的“应用冻结”，返回 NO 防止内存被回收 |
| `FBApplicationProcess/SBApplication -killForReason:` | 可选：阻止 App 切换器上滑终止 |

进程不挂起 = 继续占 CPU、继续联网、计时器照常走，这就是“真后台”。

### 2. 备用方案：应用侧静音音频保活
在应用进程内监听 `UIApplicationDidEnterBackgroundNotification`，进入后台时用 `AVAudioPlayer` 无限循环播放内存中的静音 WAV，维持音频会话存活。默认**关闭**（可能显示播放指示），仅在主方案失效时建议开启。

## 配置

设置 → 自动真后台：

- **启用**（默认开）：总开关。
- **保持所有应用**（默认开）：开 = 所有应用默认保持后台；关 = 只保持“应用管理”里手动打开的应用。
- **应用管理**：按应用单独设置。
- **音频保活（备用）**（默认关）：静音音频兜底方案。
- **禁止上滑终止**（默认关）：开启后保持中的应用无法被手动杀掉（重启恢复）。

配置保存在 `/var/mobile/Library/Preferences/com.autobg.autobackground17.plist`。

## 环境要求

- iOS 17.0 – 17.3.1，**无根（rootless）越狱**（如 Dopamine 系列 + ellekit）。
- 依赖包：`mobilesubstrate`（ellekit 提供）、`preferenceloader`。
- 设备架构 arm64 / arm64e（A12 及以上）。

> 说明：iOS 17 各小版本的公开越狱支持情况随发布动态变化；请先确认你的设备/系统有可用的无根越狱。若当前只有半越狱（如 TrollStore/Nugget 类），SpringBoard 侧无法注入，插件只能部分生效。

## 构建

需要 Theos + iPhoneOS SDK（17.x），在 macOS 或 WSL/Linux 上执行：

```sh
# 1. 安装/更新 Theos（rootless 支持需要 2023 年后的版本）
git clone --recursive https://github.com/theos/theos /opt/theos
# 把 iPhoneOS17.x.sdk 放到 /opt/theos/sdks/

# 2. 构建
cd AutoBackground17
export THEOS=/opt/theos
./build.sh
# 或 make package FINALPACKAGE=1
```

产物在 `packages/*.deb`。

## 安装

- 用 Sileo / Zebra 打开 deb，或通过 `make package install THEOS_DEVICE_IP=设备IP` 直接安装。
- 安装后**重启 SpringBoard**（Sileo 会提示）或注销（respring）。
- 设置 → 自动真后台 即可看到面板；若面板不出现，检查是否安装了 `preferenceloader`。

## 验证是否生效

1. 打开任意应用（如视频、下载类），切到后台。
2. 用 CocoaTop / `ps` 观察：进程状态应为 running，而不是 suspended。
3. 也可查看日志确认加载：
   `log stream --predicate 'eventMessage CONTAINS "AutoBackground17"'`

## 注意事项与已知限制

- **耗电明显**：进程持续运行 = 持续耗电，建议用“应用管理”只对需要的应用开启。
- **内存压力**：系统 jetsam 在内存吃紧时仍可能杀掉进程，插件无法完全阻止。
- **私有 API 可能随系统变化**：`-suspend` / `-isFreezingEnabled` / `-killForReason:` 等方法是私有 API。若在某个 iOS 小版本上失效，用 FLEX（FLEX 里查看类方法）或 class-dump 确认当前系统上的真实方法名后，改一下 `src/AutoBGSpringBoardHooks.x.m` 即可。Logos 对不存在的类/方法会自动跳过，不会导致崩溃。
- **冻结机制**：若 `-isFreezingEnabled` 在目标系统不存在，iOS 15+ 的冻结仍可能把后台进程内存回收（进程保留、状态冻结）；此时可开启“音频保活（备用）”维持活跃。
- 只针对应用进程；系统守护进程不受影响。

## 目录结构

```
AutoBackground17/
├── Makefile                              # Theos 构建配置（rootless）
├── control                               # 包信息
├── AutoBackground17.plist                # SpringBoard 过滤
├── AutoBackground17App.plist             # 应用进程过滤（UIApplication 类）
├── build.sh
├── src/
│   ├── AutoBGConfig.h/.m                 # 配置读取（CFPreferences）
│   ├── AutoBGSpringBoardHooks.x.m        # 主方案：防挂起 Hooks
│   └── AutoBGApp.m                       # 备用方案：静音音频保活
├── settings/
│   ├── AutoBGRootListController.m        # 设置面板主页
│   ├── AutoBGAppListController.m         # 应用管理列表
│   └── AutoBackground17Settings.plist    # 静态回退 specifiers
└── layout/var/jb/Library/PreferenceLoader/Preferences/
    └── AutoBackground17.plist            # 设置入口
```
## 开机自启与重载

- 无根越狱（如 Dopamine）下插件是系统级注入，**重启设备后自动生效**，无需任何额外操作。
- 修改设置后无需重启，多数情况下立即生效；若发现未生效，注销一次即可（Sileo 里的 “Respring”，或命令行 `killall -9 SpringBoard`）。
- 卸载插件后，被保持的应用会恢复系统默认的后台挂起行为。

## 设置图标

设置面板图标为 `settings/icon.png`，构建时会随设置包一起打包。
## 云端自动打包（推荐，无需本机工具链）

工程自带 GitHub Actions 工作流（`.github/workflows/build.yml`），在 GitHub 上自动编译并产出 `.deb`：

1. 注册/登录 GitHub，新建一个**私有仓库**（如 `AutoBackground17`）。
2. 把整个工程目录的内容推上去（git init → add → commit → push）。
3. 打开仓库的 **Actions** 页面：推送代码会自动触发，或手动点 **Run workflow**。
4. 构建完成后展开 **AutoBackground17-deb** 产物，下载里面的 `.deb`。
5. 用 Sileo/Zebra 安装下载的 deb，重启 SpringBoard 后生效。

工作流在 `macos-14` 云机器上运行：自动安装 Theos、从 Xcode 提取 iOS SDK、执行 `make package`，无需任何本地环境。