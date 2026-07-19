# USB Guardian

Safely eject supported USB storage devices managed by Unassigned Devices directly from the Unraid web UI.

USB Guardian does not treat an ordinary unmount as permission to unplug. It verifies device identity and usage, performs a strict normal unmount, flushes caches, requests logical USB removal, and checks `shfs` health before it displays **Safe to unplug**.

## Install

### Unraid Community Applications

In Unraid, go to **Apps** and search for:

```text
USB Guardian
```

### Unraid Plugin Manager

In Unraid, go to **Plugins > Install Plugin** and paste:

```text
https://raw.githubusercontent.com/xO-ox-ai/unraid-usb-guardian/main/usb.guardian.plg
```

USB Guardian requires Unraid `7.2.4` or newer and the Unassigned Devices plugin.

## Basic Usage

1. Open **Main > Unassigned Devices** and mount a supported USB drive normally.
2. Click the static eject icon next to the UD disk name. Merely displaying the icon does not run eligibility checks.
3. The plugin checks current state after the click. If blocked, the dialog shows the exact reason and suggested action.
4. Leave the device connected while the guarded eject transaction is running.
5. Physically unplug the device only after the green **Safe to unplug** message appears.

> **Important:** An unmounted status by itself is not permission to unplug. USB Guardian never uses forced or lazy unmounting and never kills processes automatically. If safety cannot be proven, it stops and leaves the device connected.

The current beta supports only USB mass-storage devices whose complete identity and state can be verified. Unsupported layouts, active shares or scripts, busy files, passthrough assignments, multiple active mounts, and other unsafe states are blocked with an explanation.

## Uninstall

Make sure no safe-eject job is running. Open USB Guardian on the Unraid **Plugins** page and click **Remove**, or run:

```bash
removeplg /boot/config/plugins/usb.guardian.plg
```

Configuration and forensic logs are retained under `/boot/config/plugins/usb.guardian/` after a normal uninstall.

## Troubleshooting

If the eject icon does not appear, confirm that the device is a mounted USB mass-storage device supported by the current beta, then refresh the **Main** page.

If USB Guardian refuses to eject a device, review the reason dialog and resolve the reported process, share, script, mount, passthrough, or device-layout condition. Do not work around the refusal with a forced or lazy unmount.

If the UI looks stale after an update, perform a hard refresh with `Ctrl+Shift+R`.

For crashes, hangs, or unexpected reboots, enable flash-mirrored or remote syslog before testing. Download the USB Guardian diagnostics bundle from **Settings > User Programs > USB Guardian > Download diagnostics** after the system returns.

After retaining any evidence you need, use **Settings > User Programs > USB Guardian > Clear logs** to remove existing plugin logs. Cleanup is blocked while an eject, recovery, log write, or diagnostics archive is active.

Persistent plugin logs are stored at:

```text
/boot/config/plugins/usb.guardian/logs/
```

USB Guardian is beta software. It does not modify or claim to fix `shfs`, libfuse, the Linux kernel, or the Unassigned Devices unmount implementation.

## Support

- Forum: [USB Guardian on the Unraid forum](https://forums.unraid.net/topic/199897-plugin-usb-guardian-safe-usb-eject-for-unraid/)
- Issues: [GitHub Issues](https://github.com/xO-ox-ai/unraid-usb-guardian/issues)
- Documentation: [GitHub repository](https://github.com/xO-ox-ai/unraid-usb-guardian)
- Release: [v2026.07.19a](https://github.com/xO-ox-ai/unraid-usb-guardian/releases/tag/v2026.07.19a)

---

# USB Guardian（中文）

直接在 Unraid Web 界面中安全弹出由 Unassigned Devices 管理且受支持的 USB 存储设备。

USB Guardian 不会把普通卸载等同于可以拔盘。它会核对设备身份和占用状态，执行严格的常规卸载、刷新缓存、请求 USB 逻辑移除并检查 `shfs` 健康状态，全部通过后才显示 **Safe to unplug**。

## 安装

### Unraid Community Applications

进入 Unraid **Apps** 并搜索：

```text
USB Guardian
```

### Unraid 插件管理器

进入 **Plugins > Install Plugin** 并粘贴：

```text
https://raw.githubusercontent.com/xO-ox-ai/unraid-usb-guardian/main/usb.guardian.plg
```

USB Guardian 要求 Unraid `7.2.4` 或更高版本，并依赖 Unassigned Devices 插件。

## 基本使用

1. 打开 **Main > Unassigned Devices**，按正常方式挂载受支持的 USB 设备。
2. 点击 UD 磁盘名称旁的静态弹出图标；仅显示图标不会执行资格检查。
3. 点击后插件才检查当前状态；若被阻止，弹窗会显示准确原因和处理建议。
4. 安全弹出事务运行期间保持设备连接，不要直接拔盘。
5. 只有看到绿色 **Safe to unplug** 提示后，才物理拔出设备。

> **重要：** 仅显示已卸载并不代表可以拔盘。USB Guardian 不使用强制卸载或延迟卸载，也不会自动终止进程。无法证明安全时，它会停止操作并保持设备连接。

当前 Beta 只支持能够完整验证身份和状态的 USB 大容量存储设备。遇到不支持的布局、活动共享或脚本、文件占用、直通配置、多个活动挂载或其他不安全状态时，插件会拒绝弹出并给出说明。

## 卸载

确认没有安全弹出任务正在运行，然后在 Unraid **Plugins** 页面打开 USB Guardian 并点击 **Remove**，或执行：

```bash
removeplg /boot/config/plugins/usb.guardian.plg
```

正常卸载后，配置和取证日志会保留在 `/boot/config/plugins/usb.guardian/`。

## 故障排查

如果没有显示弹出图标，请确认目标是当前 Beta 支持且已经挂载的 USB 大容量存储设备，然后刷新 **Main** 页面。

如果插件拒绝弹出，请查看原因弹窗并处理其中列出的进程、共享、脚本、挂载、直通或设备布局问题。不要使用强制卸载或延迟卸载绕过警告。

更新后界面显示陈旧时，使用 `Ctrl+Shift+R` 强制刷新。

测试崩溃、卡死或意外重启问题前，请先启用写入启动盘或远程服务器的 syslog。系统恢复后，进入 **设置 > 用户程序 > USB安全弹出 > 下载诊断** 下载诊断包。

保存好需要的证据后，可通过 **设置 > 用户程序 > USB安全弹出 > 清除日志** 删除现有插件日志；弹出、恢复、日志写入或诊断打包仍在进行时会拒绝清理。

插件持久日志位于：

```text
/boot/config/plugins/usb.guardian/logs/
```

USB Guardian 仍是 Beta 软件。它不会修改或声称修复 `shfs`、libfuse、Linux 内核或 Unassigned Devices 的卸载实现。

## 支持

- 支持论坛：[Unraid 论坛 USB Guardian 主题](https://forums.unraid.net/topic/199897-plugin-usb-guardian-safe-usb-eject-for-unraid/)
- 问题报告：[GitHub Issues](https://github.com/xO-ox-ai/unraid-usb-guardian/issues)
- 项目文档：[GitHub 仓库](https://github.com/xO-ox-ai/unraid-usb-guardian)
- 发布版本：[v2026.07.19a](https://github.com/xO-ox-ai/unraid-usb-guardian/releases/tag/v2026.07.19a)
