# Changelog

## 1.0.0 — 2026-11-24

Initial release.

* Mounts `com.xiaomi.market` at `/system/app/com.xiaomi.market/` via a KernelSU module,
  restoring the system-app identity the store needs for silent install.
* Ships the native libraries (`lib/arm64`, `lib/arm`) as required by
  `extractNativeLibs=true`.
* `post-fs-data.sh` forces `u:object_r:system_file:s0` on the module tree, fixing the
  "package unknown after boot" failure caused by `adb_data_file` labels.
* `tools/build.sh` / `tools/build.ps1` build the flashable zip from a user-supplied APK.

Verified on:

* Xiaomi HyperOS `3.0.301.0.WOLTWXM` (global), Android 16, KernelSU
* Xiaomi Market `4.130.s.00` (versionCode `40007740`)

Result:

```
pm path com.xiaomi.market  -> /system/app/com.xiaomi.market/com.xiaomi.market.apk
flags = [ SYSTEM ... ]
INSTALL_PACKAGES: granted=true
silent install: works
```
