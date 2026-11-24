# 国行小米应用商店 · 系统化模块

把**国行小米应用商店**（`com.xiaomi.market`）变成**国际版 HyperOS / MIUI** 上的
**系统应用**，从而恢复**静默安装**能力。

> 实测环境：小米 HyperOS `3.0.301.0.WOLTWXM`（国际版）+ Android 16 + KernelSU

---

## 原理

静默安装需要**两个**条件：

| 条件 | 国际版 ROM 上的状态 |
|---|---|
| `INSTALL_PACKAGES` 权限 | **已经给了**——APK 是小米官方签名（`CN=MIUI, O=Xiaomi`），ROM 里的 `signature-permissions-miui-system.xml` 按签名直接授予 |
| **系统应用身份** | **缺的就是这个** ← 模块解决它 |

商店会检查自己的安装位置：

```
codePath = /data/app/...   ->  判定为"用户安装"  ->  走普通安装（弹确认框）
codePath = /system/...     ->  判定为"预装应用"  ->  走静默安装
```

普通安装后，`flags` 里虽然会带 `SYSTEM`（因为没有系统底座时的特殊标记），
但代码路径仍在 `/data`，商店就退回普通安装流程。

`/system` 是 **erofs 只读**，写不进去。模块利用 KernelSU 的 overlay（magic mount），
在开机时把 APK 呈现到 `/system/app/com.xiaomi.market/`，
包管理器扫描时就会把它当成预装应用。

---

## 模块结构

```
system/app/com.xiaomi.market/
├── com.xiaomi.market.apk
└── lib/
    ├── arm64/*.so      （来自 APK 的 lib/arm64-v8a）
    └── arm/*.so        （来自 APK 的 lib/armeabi-v7a）
```

**原生库必须一起放**：该 APK 声明了 `extractNativeLibs=true`，
作为系统应用扫描时，加载器会去 `app目录/lib/<abi>/` 找 so，缺了会启动崩溃。

---

## 构建

你需要一份商店 APK（小米签名）。可以从国行设备提取，或用可信来源。

### Linux / macOS

```bash
./tools/build.sh /path/to/miuistore.apk miui_market_cn.zip
```

### Windows（PowerShell）

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1 -Apk C:\path\to\miuistore.apk -Out .\miui_market_cn.zip
```

脚本会自动解出原生库、组装模块目录、打包成可刷入的 zip。

---

## 安装

1. **先禁用/删除任何同样提供 `com.xiaomi.market` 的模块**
   （例如"爱玩机工具箱"的"转系统应用"生成的模块）。
   两个模块挂同一路径会冲突。

2. 刷入：

   ```
   KernelSU -> 模块 -> 从本地安装 -> miui_market_cn.zip
   ```

3. 重启手机。

4. 打开商店、登录、下载任意应用 —— 应该**不再弹安装确认框**。

---

## 验证

```bash
adb shell pm path com.xiaomi.market
# package:/system/app/com.xiaomi.market/com.xiaomi.market.apk

adb shell dumpsys package com.xiaomi.market | grep -E 'codePath|flags'
# codePath=/system/app/com.xiaomi.market
# flags=[ SYSTEM HAS_CODE ALLOW_CLEAR_USER_DATA LARGE_HEAP ]

adb shell dumpsys package com.xiaomi.market | grep -E 'INSTALL_PACKAGES:|DELETE_PACKAGES:'
# android.permission.INSTALL_PACKAGES: granted=true
# android.permission.DELETE_PACKAGES: granted=true
```

---

## 排错

### 包完全没被识别

现象：

```
adb shell pm path com.xiaomi.market      # 空
logcat: Couldn't determine stopped state for unknown package: com.xiaomi.market
```

原因：**SELinux 标签错误**。如果模块文件是从 `/data/local/tmp`
（`adb push` 后再 `cp`）来的，标签会变成 `u:object_r:adb_data_file:s0`，
`system_server` 读不了，包管理器扫描时**直接跳过**这个 APK。

检查：

```bash
adb shell su -c 'ls -Z /system/app/com.xiaomi.market/com.xiaomi.market.apk'
# 必须是：u:object_r:system_file:s0
```

修复（模块已内置在 `post-fs-data.sh` 里自动执行）：

```bash
adb shell su -c 'chcon -R u:object_r:system_file:s0 /data/adb/modules/miui_market_cn/system'
```

然后重启。

### 商店能开，但还是弹确认框

* 确认没有 `/data/app` 的副本：`adb shell pm uninstall com.xiaomi.market`
  （回退到系统版，数据视 ROM 而定）
* 再查 `codePath`，必须是 `/system/app` 开头

### 刷完开不了机

进入恢复模式或 adb 禁用模块：

```bash
adb shell su -c 'touch /data/adb/modules/miui_market_cn/disable'
```

或直接删除 `/data/adb/modules/miui_market_cn`。

---

## 升级商店

1. 拿到新版 APK
2. 用 `tools/build.*` 重新生成模块
3. 替换 `/data/adb/modules/miui_market_cn` 里的内容（或重新刷 zip）
4. 重启

---

## 许可

MIT，见 [LICENSE](LICENSE)。

**仓库不包含 APK 本体**。小米应用商店是专有软件，请自行获取并遵守其许可协议。
