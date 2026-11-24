#!/system/bin/sh
# Runs as root during the post-fs-data stage, before PackageManager scans /system.
#
# Why this is needed:
# If the module files were copied from /data/local/tmp (adb push + cp), their
# SELinux label is u:object_r:adb_data_file:s0. system_server cannot read files
# with that label, so PackageManager silently skips the APK and the package
# appears "unknown" after boot.
# Forcing system_file on the module tree fixes that.

MODDIR=${0%/*}

chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null

# Belt and braces: make sure the APK is readable.
chmod 0755 "$MODDIR/system" 2>/dev/null
chmod 0755 "$MODDIR/system/app" 2>/dev/null
chmod 0755 "$MODDIR/system/app/com.xiaomi.market" 2>/dev/null
chmod 0644 "$MODDIR/system/app/com.xiaomi.market/com.xiaomi.market.apk" 2>/dev/null
