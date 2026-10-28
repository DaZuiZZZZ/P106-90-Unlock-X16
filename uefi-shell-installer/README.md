# P106-090 本机 EFI 安装器（UEFI Shell 版）

`bcdedit /copy {bootmgr}` 创建的 BCD 条目不是可靠的固件 NVRAM 启动项。
很多主板会显示这个名字，但不会真正把它当 UEFI Application 启动。

这个版本改用 UEFI Shell 自带的 `bcfg boot add`，把真正的固件启动项写入
NVRAM。

## 第一次安装

1. 准备一个 FAT32 U 盘。
2. 在 Windows 上双击 `make-installer-usb.cmd`。
3. 输入 U 盘盘符，等待复制完成。
4. 重启并从该 U 盘进入 UEFI Shell。
5. `startup.nsh` 会自动执行 `install-local.nsh`。

安装器会：

```text
查找 Windows ESP
创建 \EFI\NVPermissive\
复制 BOOTX64.EFI
复制 NVPermissiveEFI.efi
复制 startup.nsh 到 ESP 根目录和 \EFI\NVPermissive\
bcfg boot add 0 ... "NVPermissive P106-090 x16"
```

完成后：

```text
关机
拔掉 U 盘
重新开机
进入 BIOS
把 NVPermissive P106-090 x16 设为第一启动项
```

这次它是由 `bcfg` 写入的真实固件启动项，主板会直接启动
`\EFI\NVPermissive\BOOTX64.EFI`。

## 正常启动

每次开机顺序：

```text
固件启动 \EFI\NVPermissive\BOOTX64.EFI
Shell 执行 startup.nsh
NVPermissiveEFI.efi pcie-gen2-x16
Shell 扫描 fs0..fs9 并启动 Windows Boot Manager
```

`startup.nsh` 同时放在 ESP 根目录和 `\EFI\NVPermissive\`，兼容不同主板
Shell 的启动脚本搜索路径。

## 卸载

进 UEFI Shell 后执行：

```text
bcfg boot dump
```

找到 `NVPermissive P106-090 x16` 对应的编号，例如 `Boot0003`，然后：

```text
bcfg boot rm 3
```

再删除 ESP 上的：

```text
\EFI\NVPermissive\
\startup.nsh
```

`\startup.nsh` 仅在这个方案中由我们创建；删除前确认它不是主板原有文件。
