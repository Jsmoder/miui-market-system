#!/system/bin/sh
# KernelSU / Magisk install-time script.

ui_print "- Installing GuoXing Xiaomi Market as a system app"
ui_print "- Package: com.xiaomi.market"

set_perm_recursive "$MODPATH/system" 0 0 0755 0644

if [ -f "$MODPATH/system/app/com.xiaomi.market/com.xiaomi.market.apk" ]; then
    ui_print "- APK found"
else
    ui_print "! APK missing, module will do nothing"
fi

if [ -d "$MODPATH/system/app/com.xiaomi.market/lib/arm64" ]; then
    ui_print "- Native libs present"
else
    ui_print "! Native libs missing, the store may crash at launch"
fi
