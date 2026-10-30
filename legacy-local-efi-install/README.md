# P106-090 PCIe x16 本机 EFI 安装

这套脚本会把 UEFI Shell 和 `NVPermissiveEFI.efi` 写入 Windows 的 EFI System
Partition，并通过 BCD 添加一个固件启动项。以后开机不需要 U 盘。

## 安装

右键 `install.cmd`，选择“以管理员身份运行”。

脚本会：

1. 校验包内两个 EFI 文件的 SHA256；
2. 备份当前 BCD；
3. 临时挂载 ESP；
4. 复制文件到 `\EFI\NVPermissive\`；
5. 新建 BCD 固件启动项，并设为第一项；
6. 卸载 ESP。

启动项名称为：

```text
NVPermissive P106-090 x16
```

## 卸载

右键 `uninstall.cmd`，选择“以管理员身份运行”。

脚本会删除之前记录的 BCD 启动项，并删除 `\EFI\NVPermissive\` 目录。

## 重要前提

- Windows 必须安装在 UEFI 模式。
- 运行前关闭 Secure Boot。
- 需要管理员权限。
- 如果杀毒软件拦截 `mountvol` 或 `bcdedit`，需要允许。

## 工作原理

固件先启动：

```text
\EFI\NVPermissive\BOOTX64.EFI
```

UEFI Shell 自动执行同目录的 `startup.nsh`：

```text
NVPermissiveEFI.efi pcie-gen2-x16
```

`pcie-gen2-x16` 是二进制模式名；本项目目标是 x16 宽度，不独立承诺 Gen2
速率。成功后扫描并启动：

```text
\EFI\Microsoft\Boot\bootmgfw.efi
```

从而进入 Windows。

## 失败恢复

如果安装后无法进入系统：

1. 开机进入主板 Boot Menu。
2. 手动选择 Windows Boot Manager 启动。
3. 进入 Windows 后运行 `uninstall.cmd`。
4. 如果系统完全进不去，使用 Windows 安装 U 盘进入恢复环境，手动删除
   `\EFI\NVPermissive\`，或恢复 BCD。

安装脚本会在临时目录保留 BCD 备份文件，路径会在安装结束时打印。
