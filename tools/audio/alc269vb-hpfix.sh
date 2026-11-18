#!/bin/bash
# ALC269VB (Infinix INBook X1 Pro) headphone fix for macOS.
# AppleALC/AppleHDA never set coef 0x04 bit 11 ("power up output pin"), which Linux sets for every
# ALC269VB (alc269vb_toggle_power_output). Without it the headphone amp stays off: the jack is detected
# and routed, but there is no sound. Requires boot-arg alcverbs=1 (or HDEF alc-verbs) for alc-verb access.
# Run by /Library/LaunchDaemons/com.infinix.alc269vb-hpfix.plist at boot and every 60 s (no-op when already set).
AV=/usr/local/libexec/alc-verb
LOG=/var/log/alc269vb-hpfix.log

v() { "$AV" "$@" 2>/dev/null | tail -1; }

for _ in $(seq 1 30); do
    v 0x20 SET_COEF_INDEX 0x04 >/dev/null && cur=$(v 0x20 GET_PROC_COEF 0) && [[ $cur == 0x* ]] && break
    sleep 2
done
[[ ${cur:-} == 0x* ]] || { echo "$(date '+%F %T') codec not reachable (alcverbs=1 missing?)" >>"$LOG"; exit 1; }

if (( (cur & 0x800) == 0 )); then
    new=$(printf '0x%x' $(( (cur & 0xffff) | 0x800 )))
    v 0x20 SET_COEF_INDEX 0x04 >/dev/null
    v 0x20 SET_PROC_COEF "$new" >/dev/null
    v 0x20 SET_COEF_INDEX 0x04 >/dev/null
    echo "$(date '+%F %T') coef04 $cur -> $(v 0x20 GET_PROC_COEF 0)" >>"$LOG"
fi
