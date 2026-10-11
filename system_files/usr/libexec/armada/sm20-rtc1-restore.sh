#!/bin/bash
# m2381: 开机从 PMIC RTC(rtc1) 还原系统时钟（rtc0=rtc-efi EIO 废件，不可用）
Y=$(cut -d- -f1 /sys/class/rtc/rtc1/date 2>/dev/null || echo 0)
if [ "$Y" -ge 2026 ] 2>/dev/null; then
    hwclock --hctosys --rtc /dev/rtc1
else
    logger -t sm20-rtc1 "rtc1 date implausible (${Y}), skip restore"
fi
