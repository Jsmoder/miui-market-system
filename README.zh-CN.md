# 国行小米应用商店 · 系统化模块

把**国行小米应用商店**（`com.xiaomi.market`）变成**国际版 HyperOS / MIUI** 上的
**系统应用**，恢复**静默安装**能力。

商店 APK **已内置**在仓库里（`apk/com.xiaomi.market.apk`，版本 `4.130.s.00`），
下载即刷。

> 实测环境：小米 HyperOS `3.0.301.0.WOLTWXM`（国际版）+ Android 16 + KernelSU

---

## 安装

1. **先禁用/删除任何同样提供 `com.xiaomi.market` 的模块**
   （例如"爱玩机工具箱"的"转系统应用"生成的模块）。
   两个模块挂同一路径会冲突。

2. 从 [Releases](../../releases) 下载 `miui_market_cn.zip`，刷入：

   ```
   KernelSU -> 模块 -> 从本地安装 -> miui_market_cn.zip
   ```

   （也可以自己构建，见 [构建](#构建)）

3. 重启手机。

4. 打开商店、登录、下载应用 —— 应该**不再弹安装确认框**。

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

普通方式安装后，代码路径仍在 `/data`，即使 `flags` 带 `SYSTEM`，商店也会退回普通安装流程。

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

仓库自带 APK，**不需要参数**：

```bash
./tools/build.sh                     # 生成 miui_market_cn.zip
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

换用更新版本：

```bash
./tools/build.sh /path/to/newer.apk my_build.zip
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1 -Apk C:\path\to\newer.apk
```

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

## 更新商店

商店自身可以原地更新；如果你想让**系统副本**也换成新版本：

1. 用新版 APK 替换 `apk/com.xiaomi.market.apk`（或通过 `-Apk` / 第一个参数传入）
2. 重新构建 zip
3. 在 KernelSU 里重新刷入并重启

只要签名不变，登录状态和下载记录都会保留。

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

通过 adb 或恢复模式禁用模块：

```bash
adb shell su -c 'touch /data/adb/modules/miui_market_cn/disable'
```

或删除 `/data/adb/modules/miui_market_cn`。

---

## 许可与声明

代码与脚本：MIT，见 [LICENSE](LICENSE)。

**内置的 APK 属于小米的专有软件**，仅为"开箱即用"而附带，一切权利归小米所有。
如果你不希望仓库包含它，删除 `apk/com.xiaomi.market.apk` 并自备即可。
