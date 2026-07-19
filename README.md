# Unraid USB Guardian

[English](#english) | [简体中文](#简体中文)

## English

USB Guardian is a conservative safe-eject plugin for Unassigned Devices (UD). It does not treat a successful unmount as permission to unplug. **Safe to unplug** is shown only after normal unmounting, a second usage scan, cache flushing, logical USB removal, and `shfs` stability checks have all passed.

### Current status

- Version: `2026.07.19a`
- Release naming: `YYYY.MM.DD` plus a lowercase sequence letter for additional releases on the same day
- Minimum Unraid version: `7.2.4`
- Architecture: x86_64
- Validated UD versions: official releases `2025.08.07` and `2025.11.18`
- Not yet tested on a physical Unraid host; this beta must not be treated as a proven fix for the underlying `shfs/libfuse` defect

The plugin only supports USB mass-storage devices that can be fully verified and that contain a single disk. Only one target mount may be active at a time. LUKS, ZFS, RAID/LVM members, multi-LUN enclosures, composite USB devices with non-storage interfaces, and devices whose identity or system state cannot be proven are blocked with a reason and a suggested action.

This beta also requires UD Share to be disabled for the target partition, UD Destructive Mode to be off, and no disk, partition, User Script, or Common Script configuration to be present. The plugin does not remove shares or execute scripts on the user's behalf. If these settings are found, it explains what is blocking ejection and asks the user to disable the share and Destructive Mode, disconnect clients, and remove the relevant script configuration in UD.

### User flow

1. Mount the USB drive normally in UD.
2. Click the static eject icon next to the UD disk name. USB Guardian performs no eligibility request merely to display this icon.
3. The click refreshes the current device state. If ejection is blocked, a dialog shows the reason, involved processes, and suggested action.
4. Do not use UD mount controls or physically unplug the drive while the eject job is running.
5. Physically unplug the device only after the green **Safe to unplug** message appears.

The plugin never uses lazy or forced unmounting and never kills processes automatically. If usage cannot be released safely, it stops and leaves the device connected.

### Interface languages

English (`en_US`) and Simplified Chinese (`zh_CN`) language files are included. The plugin follows the current Unraid interface language automatically. Its Settings tile is named **USB Guardian** in English and **USB安全弹出** in Simplified Chinese. Change the Unraid locale and refresh the Main page or **Settings > User Programs > USB Guardian**; no separate language patch is required.

Buttons, progress, safe-removal permission, failure reasons, and suggested actions are translated. PIDs, device paths, process names, and raw kernel diagnostics remain unchanged so that translation cannot damage forensic evidence.

USB Guardian is enabled by default. Use **Settings > User Programs > USB Guardian > General > Enable USB Guardian** to hide its Main-page controls and reject new list/eject requests. The setting cannot be turned off while a safe-eject transaction is active.

### Safety sequence

1. Lock the target identity using an HMAC token, major/minor numbers, `diskseq`, USB topology, and USB identity. The web UI cannot submit an arbitrary `/dev/sdX` path.
2. Reject the Unraid boot device, array disks, pool members, swap, holders, VM/Docker USB passthrough, active SMB/NFS clients, Preclear, and references from other mount namespaces.
3. Ask the validated UD adapter to confirm that shares and scripts are not configured and Destructive Mode is off. Establish only a root-device operation barrier, then perform a normal `umount(2)`.
4. Immediately verify that UD has observed the removed mount, then release the barrier. The adapter does not run UD scripts or modify share tables or mounted JSON.
5. Rescan every process fd/cwd/root/map, mount namespace, loop device, swap entry, and block holder. Confirm that the complete `shfs` PID set, its distinct `fuse.shfs` connections, and directory I/O under `/mnt/user` remain healthy. This includes Unraid 7.3.2 hosts that run separate `/mnt/user0` and `/mnt/user` processes.
6. Open the block device exclusively, call `fsync`, and make best-effort SCSI `SYNCHRONIZE CACHE` and `START STOP UNIT` requests.
7. Revalidate the exclusive fd, `diskseq`, physical USB device, and all block identities, then write `remove` to the physical USB parent's sysfs node.
8. Wait for block, udev, by-id, and USB nodes to disappear, then observe another `shfs` stability window. The browser must obtain a short-lived authoritative lease before it displays the green permission message.

See [docs/DESIGN.md](docs/DESIGN.md) for the detailed design.

### Build

The local Go, PHP, and Node.js toolchains live under `.tools/`, with caches under `.cache/`; they do not modify the global system environment.

```powershell
.\scripts\check.ps1
.\scripts\build.ps1
```

Release files:

- `dist/usb.guardian.plg`
- `dist/usb.guardian-2026.07.19a-x86_64-1.txz`
- `usb.guardian.plg` (stable entry point for Community Applications and the Plugins page)

### Install and uninstall

#### Install from Community Applications

After the submission is accepted, search for **USB Guardian** in Unraid **Apps** and click **Install**. CA reads the stable PLG from the repository root, and the PLG automatically downloads and verifies the versioned TXZ. No second file needs to be prepared manually.

#### Online installation before CA acceptance

Paste this URL into **Plugins > Install Plugin**:

```text
https://raw.githubusercontent.com/xO-ox-ai/unraid-usb-guardian/main/usb.guardian.plg
```

The equivalent Unraid web-terminal command is:

```bash
installplg https://raw.githubusercontent.com/xO-ox-ai/unraid-usb-guardian/main/usb.guardian.plg
```

#### Offline installation

Download the PLG and TXZ from the [v2026.07.19a release](https://github.com/xO-ox-ai/unraid-usb-guardian/releases/tag/v2026.07.19a). Without network access, place the TXZ in the plugin's private directory and the PLG in the root `/boot/config/plugins` directory:

```bash
mkdir -p /boot/config/plugins/usb.guardian
cp usb.guardian-2026.07.19a-x86_64-1.txz /boot/config/plugins/usb.guardian/
cp usb.guardian.plg /boot/config/plugins/usb.guardian.plg
installplg /boot/config/plugins/usb.guardian.plg
```

With every method, the plugin manager verifies the TXZ SHA-256. The PLG then confirms that `/boot` is a writable FAT boot-flash mount, installs the private static binary, and runs reboot recovery. Refresh the Unraid web interface after the command succeeds. USB Guardian should appear on the **Plugins** page; settings and diagnostic downloads are under **Settings > User Programs > USB Guardian**, and the safe-eject control appears next to the device name under **Main > Unassigned Devices**.

#### Uninstall

Make sure no safe-eject job is running. The recommended method is to open USB Guardian on the Unraid **Plugins** page and click **Remove**. The equivalent web-terminal command is:

```bash
removeplg /boot/config/plugins/usb.guardian.plg
```

The uninstaller refuses to proceed while a transaction is running, the transaction lock is busy, recovery markers remain, or `/boot` is not the expected writable FAT boot-flash mount. It prints the specific reason. Do not bypass a refusal by deleting `/usr/local/emhttp/plugins/usb.guardian`; stop the related activity and, when necessary, reboot to allow recovery to finish before trying again.

A successful uninstall removes the runtime program and installation package but intentionally retains configuration and forensic logs under `/boot/config/plugins/usb.guardian/`. After confirming that the diagnostic evidence is no longer needed, remove the retained data with:

```bash
rm -rf /boot/config/plugins/usb.guardian
rm -f /boot/config/plugins/usb.guardian.plg
```

The last two commands are irreversible. Run them only after `removeplg` succeeds; they permanently delete logs that may be needed for crash investigation.

### Support and issue reports

For usage support and discussion, use the [USB Guardian topic on the Unraid forum](https://forums.unraid.net/topic/199897-plugin-usb-guardian-safe-usb-eject-for-unraid/). Report reproducible defects through [GitHub Issues](https://github.com/xO-ox-ai/unraid-usb-guardian/issues), using the issue template and including the Unraid version, Unassigned Devices version, USB identity, failure stage, and reproducible steps. For crashes or reboots, attach the diagnostics bundle exported from **Settings > User Programs > USB Guardian > Download diagnostics**.

Review diagnostics before uploading them. Do not publish passwords, access tokens, private keys, personal filenames, or other sensitive data. Follow the [security policy](SECURITY.md) and use GitHub private vulnerability reporting instead of publishing exploitable details.

### Persistent logs after reboot

All forensic logs are stored on the Unraid boot flash:

```text
/boot/config/plugins/usb.guardian/logs/
```

The key files for each job are:

```text
/boot/config/plugins/usb.guardian/logs/transactions/<job-id>/timeline.jsonl
/boot/config/plugins/usb.guardian/logs/transactions/<job-id>/snapshot-*.json
```

If a transaction is interrupted by a crash or reboot, the next startup appends an `interrupted_by_reboot` event and a `boot_recovery` snapshot. The easiest collection method is **Settings > User Programs > USB Guardian > Download diagnostics**.

Use **Settings > User Programs > USB Guardian > Clear logs** to remove existing diagnostic logs after confirming they are no longer needed. The action is refused while a safe-eject transaction, recovery state, log writer, or diagnostics download is active. New events are logged normally after cleanup.

A hard lockup can occur before the final flash `fsync` completes, and Unraid stores syslog in memory by default. Before testing, enable flash mirroring or remote syslog under **Settings > Syslog Server**. See [docs/FORENSICS.md](docs/FORENSICS.md) for the complete evidence-collection guide.

### Safety boundary

USB Guardian does not modify `shfs`, libfuse, the Linux kernel, or UD's unmount implementation, and it does not claim to eliminate every crash path. Its purpose is to avoid the dangerous window where the UI reports an unmounted device that is still referenced by the kernel or another process, and to refuse unplug permission whenever safety cannot be proven.

### License

This project is licensed under the [MIT License](LICENSE).

---

## 简体中文

USB Guardian 是一个面向 Unassigned Devices（UD）的保守型安全弹出插件。它不会把“卸载成功”等同于“可以拔出”，而是在普通卸载、占用复查、缓存落盘、USB 逻辑移除和 `shfs` 稳定性检查全部通过后，才显示 **Safe to unplug**。

## 当前状态

- 版本：`2026.07.19a`
- 版本命名：`年.月.日` 加当天的小写发布序号字母；同一天再次发布时依次递增
- 最低系统：Unraid `7.2.4`
- 架构：x86_64
- 已认证 UD：官方版 `2025.08.07`、`2025.11.18`
- 尚未在真实 Unraid 主机上验证，不能把此 Beta 视为已经证明修复了 `shfs/libfuse` 缺陷

插件只支持可被完整验证的单磁盘 USB 大容量存储设备，而且同一时间只能有一个活动目标挂载。LUKS、ZFS、RAID/LVM 成员、多 LUN 外置盒、带非存储接口的复合 USB 设备，以及任何身份或系统状态无法确认的设备都会被阻止，并在界面中说明原因和建议。

当前 Beta 还要求目标分区没有启用 UD Share、UD Destructive Mode 已关闭，且磁盘、分区、User Script 和 Common Script 均未配置。插件不会替用户删除共享或运行脚本；发现这些设置时会给出阻止原因，用户需要先在 UD 中关闭共享和 Destructive Mode、断开客户端并清理脚本设置。

## 用户流程

1. 在 UD 中正常挂载 U 盘。
2. 在 UD 磁盘名称旁点击静态弹出图标。仅显示该图标不会触发任何资格检查请求。
3. 点击后插件才刷新当前设备状态；如果不能弹出，弹窗会显示阻止原因、占用进程和处理建议。
4. 弹出任务运行期间不要操作 UD 的挂载按钮，也不要直接拔盘。
5. 只有看到绿色 **Safe to unplug** 提示后，才物理拔出设备。

插件不会使用 lazy/force unmount，也不会自动杀进程。占用无法安全解除时，它会停止操作并保留设备连接状态。

## 界面语言

插件内置英文（`en_US`）和简体中文（`zh_CN`）语言文件，并自动跟随 Unraid 当前界面语言。设置图标在英文界面中显示为 **USB Guardian**，在简体中文界面中显示为 **USB安全弹出**。将 Unraid 的区域语言设置为简体中文后，刷新主界面或 **设置 > 用户程序 > USB安全弹出** 页面即可切换，不需要单独安装中文补丁。

中文界面会翻译按钮、进度、安全许可、失败原因和处理建议。PID、设备路径、进程名及内核返回的诊断细节保留原始内容，避免翻译破坏排障信息。

USB Guardian 默认启用。可在 **设置 > 用户程序 > USB安全弹出 > 常规 > 启用 USB Guardian** 中关闭；关闭后主界面按钮会隐藏，后端也会拒绝新的设备列表和弹出请求。安全弹出事务正在运行时不允许关闭插件。

## 安全流程

核心流程包括：

1. 用 HMAC 令牌、major/minor、`diskseq`、USB 拓扑和 USB 身份锁定目标，网页不能提交任意 `/dev/sdX`。
2. 拒绝 Unraid 启动盘、阵列盘、池成员、swap、holder、VM/Docker USB 直通、活动 SMB/NFS 客户端、Preclear 和其他挂载命名空间引用。
3. 让已认证的 UD 适配器确认共享/脚本均未配置、Destructive Mode 已关闭，只建立根设备操作屏障，再执行普通 `umount(2)`。
4. 普通卸载后立即确认 UD 已观察到目标挂载消失并释放屏障；适配器不运行 UD 脚本，也不改共享表或 mounted JSON。
5. 重新扫描全部进程的 fd/cwd/root/map、挂载命名空间、loop、swap 和 block holder，并确认完整的 `shfs` PID 集合、各自独立的 `fuse.shfs` 连接和 `/mnt/user` 目录 I/O 正常。这包括分别运行 `/mnt/user0` 与 `/mnt/user` 进程的 Unraid 7.3.2 主机。
6. 独占打开块设备，执行 `fsync`，并尽力发送 SCSI `SYNCHRONIZE CACHE` / `START STOP UNIT`。
7. 最后一次核对独占 fd、`diskseq`、物理 USB 和所有块设备身份，然后写入物理 USB 父设备的 sysfs `remove`。
8. 等待 block、udev、by-id 和 USB 节点全部消失，再观察 `shfs` 稳定窗口；浏览器还要取得短期权威 lease，才会显示绿色许可。

详细设计见 [docs/DESIGN.md](docs/DESIGN.md)。

## 构建

本地 Go、PHP 和 Node.js 工具链位于仓库的 `.tools/`，缓存位于 `.cache/`，不会写入系统全局环境。

```powershell
.\scripts\check.ps1
.\scripts\build.ps1
```

发布文件：

- `dist/usb.guardian.plg`
- `dist/usb.guardian-2026.07.19a-x86_64-1.txz`
- `usb.guardian.plg`（供 Community Applications 和 Plugins 页面使用的稳定入口）

## 安装与卸载

### Community Applications 安装

审核收录后，在 Unraid **Apps** 中搜索 **USB Guardian** 并点击 **Install**。CA 会读取仓库根目录的稳定 PLG，PLG 再自动下载并校验对应版本的 TXZ；不需要手工准备第二个文件。

### 提交审核前在线安装

在 **Plugins > Install Plugin** 中粘贴以下 URL：

```text
https://raw.githubusercontent.com/xO-ox-ai/unraid-usb-guardian/main/usb.guardian.plg
```

也可以在 Unraid Web 终端执行：

```bash
installplg https://raw.githubusercontent.com/xO-ox-ai/unraid-usb-guardian/main/usb.guardian.plg
```

### 离线安装

从 [v2026.07.19a Release](https://github.com/xO-ox-ai/unraid-usb-guardian/releases/tag/v2026.07.19a) 下载 PLG 和 TXZ。没有网络连接时，把 TXZ 放进插件私有目录，把 PLG 放到 `/boot/config/plugins` 根目录：

```bash
mkdir -p /boot/config/plugins/usb.guardian
cp usb.guardian-2026.07.19a-x86_64-1.txz /boot/config/plugins/usb.guardian/
cp usb.guardian.plg /boot/config/plugins/usb.guardian.plg
installplg /boot/config/plugins/usb.guardian.plg
```

无论使用哪种方式，插件管理器都会验证 TXZ 的 SHA-256。PLG 随后确认 `/boot` 是可写的 FAT 启动闪存挂载、安装私有静态二进制并运行重启恢复检查。命令成功后刷新 Unraid Web 界面；**插件**页面应显示 USB Guardian，设置和诊断下载位于 **设置 > 用户程序 > USB安全弹出**，安全弹出按钮位于 **主界面 > 未分配的设备** 的设备名称附近。

### 卸载

开始前确认没有正在运行的安全弹出任务。推荐进入 Unraid Web 界面的 **Plugins** 页面，打开 USB Guardian 并点击 **Remove**。也可以在 Web 终端执行：

```bash
removeplg /boot/config/plugins/usb.guardian.plg
```

卸载器会在事务仍在运行、事务锁被占用、存在待恢复标记或 `/boot` 不是预期的可写 FAT 启动盘挂载时拒绝操作，并打印明确原因。遇到拒绝时不要直接删除 `/usr/local/emhttp/plugins/usb.guardian`；先结束相关操作，必要时重启让恢复流程完成，再重新卸载。

正常卸载会删除运行时程序和安装包，但有意保留 `/boot/config/plugins/usb.guardian/` 下的配置与取证日志。确认不再需要诊断记录后，可执行以下命令彻底清除这些保留数据：

```bash
rm -rf /boot/config/plugins/usb.guardian
rm -f /boot/config/plugins/usb.guardian.plg
```

最后两条命令不可恢复；必须在 `removeplg` 成功后执行，而且会永久删除崩溃排查所需的日志。

## 支持与问题报告

使用咨询和一般讨论请前往 [Unraid 论坛的 USB Guardian 主题](https://forums.unraid.net/topic/199897-plugin-usb-guardian-safe-usb-eject-for-unraid/)。可重复的缺陷请在 [GitHub Issues](https://github.com/xO-ox-ai/unraid-usb-guardian/issues) 报告，选择问题模板并填写 Unraid 版本、Unassigned Devices 版本、USB 设备身份、失败阶段和可重复的操作步骤；崩溃或重启问题请附上 **设置 > 用户程序 > USB安全弹出 > 下载诊断** 导出的诊断包。

提交前请检查诊断内容，不要公开上传密码、访问令牌、私钥、个人文件名或其他敏感数据。安全漏洞请按照 [安全策略](SECURITY.md) 使用 GitHub 私密漏洞报告，不要创建包含可利用细节的公开 Issue。

## 重启后的日志位置

所有插件取证日志都在 Unraid 启动盘：

```text
/boot/config/plugins/usb.guardian/logs/
```

每次任务的关键文件是：

```text
/boot/config/plugins/usb.guardian/logs/transactions/<job-id>/timeline.jsonl
/boot/config/plugins/usb.guardian/logs/transactions/<job-id>/snapshot-*.json
```

若事务被崩溃或重启打断，下次启动会追加 `interrupted_by_reboot` 事件和 `boot_recovery` 快照。最方便的收集方式是进入 **设置 > 用户程序 > USB安全弹出 > 下载诊断**。

确认不再需要旧记录后，可在 **设置 > 用户程序 > USB安全弹出 > 清除日志** 中删除现有诊断日志。安全弹出事务、恢复状态、日志写入或诊断下载仍在进行时，插件会拒绝清理；清理后发生的新事件仍会正常记录。

硬锁死可能发生在最后一次 flash `fsync` 完成之前，而且 Unraid 默认 syslog 位于内存。测试前务必在 **Settings > Syslog Server** 启用镜像到 flash 或远程 syslog。完整取证说明见 [docs/FORENSICS.md](docs/FORENSICS.md)。

## 安全边界

USB Guardian 不修改 `shfs`、libfuse、Linux 内核或 UD 的卸载实现，也不会声称消除了所有崩溃路径。它的目标是绕开“界面已经卸载但物理 USB 仍被内核/进程引用”的危险窗口，并在无法证明安全时拒绝给出拔盘许可。

## 许可证

本项目使用 [MIT License](LICENSE)。
