<style>
.usb-guardian-plugin-description-zh { display: none; }
html:lang(zh) .usb-guardian-plugin-description-en { display: none; }
html:lang(zh) .usb-guardian-plugin-description-zh { display: inline; }
</style>
<span class="usb-guardian-plugin-description-en"><strong>USB Guardian</strong><br>Provides a conservative safe-eject workflow for supported USB mass-storage devices managed by Unassigned Devices. It verifies device identity and usage, performs a normal unmount, flushes caches, requests logical USB removal, and checks shfs health before granting permission to unplug.<br><br><strong>Important:</strong> An unmounted status alone does not mean the device is safe to unplug. Unplug it only after USB Guardian explicitly displays <em>Safe to unplug</em>. The plugin never forces or lazily unmounts a device and never terminates processes automatically; when safety cannot be proven, it leaves the device connected.</span>
<span class="usb-guardian-plugin-description-zh"><strong>USB安全弹出</strong><br>为 Unassigned Devices 管理的受支持 USB 大容量存储设备提供保守的安全弹出流程。插件会核对设备身份和占用状态，执行常规卸载、刷新缓存、请求 USB 逻辑移除并检查 shfs 健康状态，全部通过后才允许拔出设备。<br><br><strong>注意：</strong>仅显示“已卸载”并不代表可以安全拔出。请务必等到 USB Guardian 明确显示“可以安全拔出”后再拔盘。插件不会强制卸载、延迟卸载或自动终止进程；无法确认安全时，设备会保持连接。</span>
