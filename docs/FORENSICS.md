# 崩溃取证指南

## 重启后先去哪里找

USB Guardian 自身的全部持久日志位于：

```text
/boot/config/plugins/usb.guardian/logs/
```

目录结构：

```text
logs/
|-- api.log
|-- launcher.log
|-- service.log
|-- ud-adapter.log
`-- transactions/
    `-- <job-id>/
        |-- timeline.jsonl
        |-- active.json                         # 仅未完成事务存在
        |-- interrupted-<time>.json             # 重启恢复后由 active.json 改名
        `-- snapshot-<time>-<stage>.json
```

不存在 `last-job.json`，也不使用 `/boot/logs/usb.guardian`。

## 最推荐的收集方式

重启后，在开始下一次弹出测试之前：

1. 打开 **Settings > USB Guardian**。
2. 点击 **Download diagnostics**。
3. 再到 **Tools > Diagnostics** 生成 Unraid 官方 diagnostics ZIP。
4. 一并保留持久/远程 syslog，并记录点击弹出和实际拔盘的大致时间。

USB Guardian ZIP 会包含保留的事务目录和当前系统快照。发送诊断前请注意其中包含设备 serial、挂载路径、进程状态和部分 udev/syslog 信息。

## 手工查看

```bash
find /boot/config/plugins/usb.guardian/logs/transactions -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' | sort
tail -n 100 /boot/config/plugins/usb.guardian/logs/transactions/<job-id>/timeline.jsonl
ls -lah /boot/config/plugins/usb.guardian/logs/transactions/<job-id>/
```

`timeline.jsonl` 每行是一个完整 JSON 事件。最后一条已落盘事件表示系统崩溃前确认到的最远阶段。重点关注：

- `stage`：当时处于卸载、身份复核、USB remove、settle 还是 `shfs` 检查；
- `type=kernel_uevent`：内核实际发出的 remove 事件；
- `transaction_failed` 和结构化 reason；
- `rollback_before` / `rollback_after` / `rollback_skipped`：屏障释放是否经过身份复核并完整记录；
- `usb_remove_written`：sysfs remove 写入是否已经返回成功；
- `interrupted_by_reboot`：上次事务没有正常终态。

`ud-adapter.log` 中的 `side_effect_before` / `side_effect_after` 记录 UD root marker 取得或释放的持久边界；它们不在事务 `timeline.jsonl` 中。

## 快照包含什么

阶段快照会尽量记录：

- 完整的 `shfs` PID/进程状态集合、各 `fuse.shfs` 连接的 mountinfo 和 `/mnt/user` I/O 探测结果；
- 相关及关键系统进程的 status、wchan、kernel stack、fd 数量、mount namespace；
- `/proc/meminfo`、loadavg、vmstat、diskstats、swaps、mdstat、mountinfo；
- CPU/内存/I/O pressure；
- 目标 block/USB sysfs、holders、slaves、inflight、write cache、udev 数据；
- 有界的 syslog 尾部、kernel tainted 值；
- 若内核提供，`/sys/fs/pstore` 中有界的 oops/panic 记录。

快照在 `preflight`、`pre_remove`、`post_remove`、最终 `shfs`、failure 和 boot recovery 等阶段产生。即使浏览器没有收到响应，flash 上通常仍能看到最后一个已完成阶段。

## 为什么还需要持久 syslog

Unraid 默认 `/var/log/syslog` 在 RAM 中。机器硬锁死或重启后，Guardian 快照之外的最后几秒内核信息可能已经丢失；若崩溃发生在 flash 写入完成前，插件也无法提供绝对保证。

测试前打开 **Settings > Syslog Server**，选择以下至少一种方式：

- mirror syslog to flash；
- 把 syslog 发送到另一台主机。

远程 syslog 的可靠性通常高于把所有信息继续写回发生故障的同一台机器。频繁复现时也应考虑 flash 写入寿命。

## 需要一起提供的信息

- USB Guardian diagnostics ZIP；
- Unraid 官方 diagnostics ZIP；
- 持久或远程 syslog；
- 最新事务的 job ID；
- U 盘/外置盒型号、连接端口，是否经过 USB Hub；
- 点击 Guardian、出现许可、物理拔盘、崩溃/重启的大致时间；
- 当时是否有 Docker、VM、SMB/NFS、Mover、Preclear 或用户脚本在运行。

这些信息可以区分：卸载前占用、UD 屏障/并发操作问题、设备身份竞态、USB bridge 缓存/停止命令异常、sysfs remove 未完成，以及 remove 后 `shfs`/FUSE 健康变化。
