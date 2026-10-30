# P106-090 PCIe x16 持久化 USB 启动方案

## 方案是什么

这个 U 盘启动后会自动执行：

```text
NVPermissiveEFI.efi pcie-gen2-x16
```

其中 `pcie-gen2-x16` 是 NVPermissive 的模式名；本项目目标是 x16 宽度，
不独立承诺 Gen2 速率。EFI 完成宽度事务后，UEFI Shell 会自动扫描：

```text
fs0:\EFI\Microsoft\Boot\bootmgfw.efi
fs1:\EFI\Microsoft\Boot\bootmgfw.efi
...
fs9:\EFI\Microsoft\Boot\bootmgfw.efi
```

找到第一个 Windows Boot Manager 就直接启动。这样只要 U 盘保持第一启动项，
每次冷启动都会先解锁 x16，再进入 Windows。

## 制作 U 盘

在 Windows 上，准备一个已经格式化为 FAT32 的 U 盘。

双击：

```text
make-p106-090-x16-persist-usb.bat
```

输入 U 盘盘符。脚本不会格式化 U 盘，只复制并校验：

```text
\EFI\BOOT\BOOTX64.EFI
\NVPermissiveEFI.efi
\startup.nsh
\README-FIRST.txt
```

如果 U 盘被 Windows 报告为 `Fixed`，先确认盘符后运行：

```text
make-p106-090-x16-persist-usb.bat --allow-fixed
```

## 设置开机顺序

1. 重启进入主板 UEFI/Boot Menu。
2. 把这个 U 盘的 UEFI 启动项设为第一项。
3. 关闭 Secure Boot。
4. 保存并重启。

以后只要 U 盘插着，并且第一启动项没有变，就会自动完成解锁。

## 注意事项

- 这是 USB 持久化，不是写入主板 NVRAM。U 盘拔出或启动顺序改变后不会生效。
- EFI 成功后会直接启动 `bootmgfw.efi`，不会停在 Shell。
- 如果找不到 Windows Boot Manager，Shell 会停在提示处。
- 如果链路没有恢复，先完全断电再重启，不要热重启。
- 不要在同一轮混用其它 `pcie-*` 命令。

## 下一步可选

如果以后想去掉 U 盘，需要把 UEFI Shell 和 `NVPermissiveEFI.efi` 放到
Windows ESP，再通过 `bcfg boot add` 或主板引导工具添加一个固定启动项。
那一步会动到 ESP，风险更高，建议先在 U 盘方案稳定运行后再做。
