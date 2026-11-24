# 国行小米应用商店 · 系统化模块（KernelSU）

> [English](README.en.md) | 中文

把**国行小米应用商店**（`com.xiaomi.market`）变成**国际版 HyperOS / MIUI** 上的
**预装系统应用**，恢复**静默安装**（下载即装、不弹确认框）。

商店 APK **已内置**在仓库里（`apk/com.xiaomi.market.apk`，版本 `4.130.s.00`），
下载即刷，不需要自己找安装包。

> 实测环境：小米 HyperOS `3.0.301.0.WOLTWXM`（国际版）+ Android 16 + KernelSU

---

## 适用人群

```
✅ 用国际版 / 海外版 HyperOS、MIUI 的手机，想用国行应用商店
✅ 已经能装国行商店，但每次下载都要手动点"安装"很烦
✅ 希望商店以系统应用身份运行（静默安装、后台更新）
```

**不适用**：

```
❌ 国行 ROM —— 本来就自带商店，不需要这个模块
❌ 没有 root / KernelSU 的设备 —— 模块无法生效
```

---

## 安装

### 1. 先清理旧的同类模块

如果你之前用「爱玩机工具箱」的"固化 / 转系统应用"做过同样的事，
它会生成一个 id 为 `com.xiaomi.market` 的模块。

```
KernelSU → 模块 → 找到「應用商店」(id: com.xiaomi.market) → 禁用或删除
```

**两个模块挂同一路径会冲突**，必须先处理。

### 2. 刷入

从 Releases 下载 `miui_market_cn.zip`：

> 国内直连 GitHub 可能较慢，附件下载可用任意 GitHub 加速服务。

```
KernelSU → 模块 → 从本地安装 → 选择 miui_market_cn.zip
```

### 3. 重启手机

### 4. 打开商店

```
登录小米账号 → 下载任意应用 → 应该直接安装，不再弹确认框
```

---

## 原理（为什么"转系统应用"就能静默安装）

### 静默安装需要两个条件

| 条件 | 国际版 ROM 上的状态 |
|---|---|
| `INSTALL_PACKAGES` 权限 | **已经给了**——APK 是小米官方签名（`CN=MIUI, O=Xiaomi`），ROM 里的 `signature-permissions-miui-system.xml` 按签名直接授予 |
| **系统应用身份** | **缺的就是这个** ← 本模块解决它 |

### 商店是怎么判断的

商店会检查自己的安装位置：

```
codePath = /data/app/...   →  判定为"用户安装"  →  走普通安装（弹确认框）
codePath = /system/...     →  判定为"预装应用"  →  走静默安装
```

用普通方式安装 APK 后，代码路径在 `/data`，所以商店会退回"普通安装"流程。

### 为什么不能直接写 /system

```
/system 是 erofs 只读文件系统，root 也写不进去
```

所以模块用 KernelSU 的 overlay（magic mount），在**开机时**把 APK 呈现到
`/system/app/com.xiaomi.market/`，包管理器扫描时就会把它当成预装应用。
文件实际一直待在 `/data/adb/modules/` 里。

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

商店自己可以原地更新；如果你想让**系统副本**也换成新版本：

1. 用新版 APK 替换 `apk/com.xiaomi.market.apk`
2. 重新构建 zip：

   ```bash
   ./tools/build.sh
   powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
   ```

3. 在 KernelSU 里重新刷入，重启

只要签名不变，登录状态和下载记录都会保留。

---

## 排错

### 包完全没被识别（最常见）

现象：

```
adb shell pm path com.xiaomi.market      # 空
logcat: Couldn't determine stopped state for unknown package: com.xiaomi.market
```

原因：**SELinux 标签错误**。

如果你用 `adb push` 把文件推到 `/data/local/tmp` 再 `cp` 进模块目录，
文件的标签会变成 `u:object_r:adb_data_file:s0`。
`system_server` 读不了这种标签的文件，包管理器扫描时**直接跳过**这个 APK。

检查：

```bash
adb shell su -c 'ls -Z /system/app/com.xiaomi.market/com.xiaomi.market.apk'
# 必须是：u:object_r:system_file:s0
```

修复（模块的 `post-fs-data.sh` 已自动执行）：

```bash
adb shell su -c 'chcon -R u:object_r:system_file:s0 /data/adb/modules/miui_market_cn/system'
```

然后重启。

### 商店能开，但还是弹确认框

* 确认没有 `/data/app` 副本：

  ```bash
  adb shell pm uninstall com.xiaomi.market
  ```

  （回退到系统版；数据是否保留取决于 ROM）

* 再查 `codePath`，必须是 `/system/app` 开头

### 刷完开不了机

通过 adb 禁用模块：

```bash
adb shell su -c 'touch /data/adb/modules/miui_market_cn/disable'
```

或删除 `/data/adb/modules/miui_market_cn`。

### 商店能装应用，但部分功能不可用

国际版 ROM 缺少国内的账号 / 推送 / 支付相关服务，属于正常现象：

```
· 小米推送（mipush）可能不完整 → 下载完成通知可能延迟
· 部分国内支付方式不可用
· 游戏中心等联运功能可能提示"当前地区不支持"
```

这些都不影响"下载 + 静默安装"这条主链路。

---

## 构建（可选）

仓库自带 APK，**不需要参数**：

```bash
./tools/build.sh                     # 生成 miui_market_cn.zip
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

换用更新版本的 APK：

```bash
./tools/build.sh /path/to/newer.apk my_build.zip
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1 -Apk C:\path\to\newer.apk
```

---

## 许可与声明

代码与脚本：MIT，见 LICENSE。

**内置的 APK 属于小米的专有软件**，仅为"开箱即用"而附带，一切权利归小米所有。
如果你不希望仓库包含它，删除 `apk/com.xiaomi.market.apk` 并自备即可。

本项目与小米公司无关，仅供个人设备研究与使用。