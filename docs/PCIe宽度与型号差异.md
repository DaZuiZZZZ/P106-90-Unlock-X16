# PCIe 宽度与型号差异

## 先区分速度与宽度

GPU-Z 的 Bus Interface 常见格式是：

```text
PCIe x16 2.0 @ x4 2.0
      ^^^^^       ^^^^
      能力         当前
```

- 左边 `x16`：驱动或能力表报告的最大宽度；
- 右边 `@ x4`：当前实际训练宽度；
- `2.0`：链路速率代际。

看到“PCIe x16 2.0”不等于当前已经跑在 x16。

## 本机实测

注意：P104-100 存在不同板卡版本。2026-10-29 的实机 EFI 日志显示，
当前测试的这张 P104 报告：

```text
GPU LnkCap = 0x00453D01  -> 最大 x16
GPU LnkSta = 0x00001041  -> 当前 Gen1 x4
RP  LnkCap = 0x0261AD03  -> 最大 x16
RP  LnkSta = 0x00005041  -> 当前 Gen1 x4
```

因此这张 P104 不属于“能力声明固定 x4”的版本。其宽度事务已经进入 EFI
核心，但第一次 x16 尝试没有通过验证。下面的 P104 x4 基线只适用于原始
P104-100 组合包记录的那张卡，不能覆盖所有批次。

2026-10-29 的 P106-090 `pcie-gen2-x16` 日志：

```text
BOOT0      = 0x136000A1
GPU LnkCap = 0x00453D02  -> Gen2 / 最大 x16
GPU LnkSta = 0x00001042  -> Gen2 / 当前 x4
RP  LnkCap = 0x0261AD03  -> Gen3 / 最大 x16
RP  LnkSta = 0x0000D042  -> Gen2 / 当前 x4
```

EFI 返回：

```text
WARNING actual Gen2 x4; GPU max x16, RP max x16; target Gen2 x16;
configuration completed, actual link remains narrower
```

这证明速度从 Gen1 提升到了 Gen2，但 x16 宽度没有建立。两端能力都为 x16
时仍训练成 x4，应优先检查：

1. BIOS 是否把该 x16 槽 bifurcation 成 `x4x4x4x4`；
2. 是否使用 x4 电气延长线/转接卡；
3. 主板槽位是否只有 x4 走线；
4. 显卡 PCB 是否只布了 4 条 lane；
5. GPU lane strap/PCIe 核是否在初始化后把宽度限制为 x4。

P106-090 探针读数：

```text
LNKCAP = 0x00453C41
LNKSTA = 0x00001021
```

解码：

```text
LNKCAP MAXWIDTH = (LNKCAP >> 4) & 0x3F = 4
LNKSTA WIDTH    = (LNKSTA >> 4) & 0x3F = 2
```

含义：P106-090 自己声明最大只有 x4，当前训练为 x2。

P104-100 基线同样声明最大 x4：

```text
LNKCAP = 0x00463C41
MAXWIDTH = 4
```

Gen2 解锁后低四位从 `1` 变为 `2`，扩展的是速率，不是宽度。

## 为什么软件不能把 x4 变成 x16

PCIe 链路宽度取端点、上游端口、物理布线和交换机能力的共同结果。至少需要：

1. GPU 的 PCIe 核声明最大 x16；
2. GPU PCB 完整连接 16 条 lane，并安装对应的 AC 耦合电容和端接；
3. 金手指、转接卡、延长线、插槽和主板端口均为 x16 电气连接；
4. 上行根端口支持 x16；
5. 链路训练成功。

当前卡的端点 `LNKCAP.MAXWIDTH` 已经是 4。只要这一项仍为 4，重训、写 `LNKCTL` 或持续按住 GEN2 使能位都不可能超过 x4。

## “别人的 P104 是 x16”可能是什么情况

1. **不同 PCB/SKU 版本**：存在完整 x16 走线和不同初始化 strap 的版本。
2. **GPU-Z 误读位置**：对方可能只是能力栏显示 x16，而 `@` 后仍是 x4。
3. **主板或转接卡只提供 x4**：即使卡能力是 x16，也会降到 x4。
4. **对方做了硬件改板**：补 AC 耦合电容、移除 lane 限制、修改 strap 或使用不同 VBIOS。
5. **显示的是另一张显卡**：多卡机器上 GPU-Z 选错了设备。

## 需要对比的证据

对比 x16 版本和自己的卡时，至少记录：

```text
GPU-Z Bus Interface 完整字符串
PCI 设备 ID / SUBSYS ID
LNKCAP 原始值及 MAXWIDTH
LNKSTA 原始值及 WIDTH
显卡正面、背面和金手指照片
VBIOS 头摘要、MD5、SHA256
主板插槽电气宽度
```

不要仅凭“同叫 P104”就跨刷 VBIOS。不同 PCB 的供电、显存、风道和 lane strap 可能不同；刷错会导致不启动，且 x16 VBIOS 也无法补出 PCB 上不存在的走线和耦合电容。

## 结论

当前 P104-100 / P106-090 的实测硬件声明上限是 x4。Gen2 已可解锁；Gen3 被 8GT/s 能力位阻止；x16 需要先证明手上的卡和通路本身具备 x16 物理及声明能力，单靠现有寄存器工具无法实现。
