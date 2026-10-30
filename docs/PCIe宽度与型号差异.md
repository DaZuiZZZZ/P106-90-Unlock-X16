# PCIe 宽度判断与型号差异

## 先只看宽度

GPU-Z 常见格式：

```text
PCIe x16 2.0 @ x4 2.0
      ^^^^       ^^^
      能力       当前宽度
```

本项目只关心 `@` 后面的宽度：

```text
@ x4   -> 宽度未解锁
@ x16  -> 宽度解锁成功
```

前面的 `x16 2.0` 是能力栏，不能证明当前已经跑在 x16。

## 正确判据

读取 PCIe 能力结构中的 `LNKSTA`：

```text
当前宽度 = (LNKSTA >> 4) & 0x3F
```

端点 GPU 和上游根端口都要满足：

```text
GPU LNKSTA WIDTH = 16
RP  LNKSTA WIDTH = 16
```

仅看 EFI 返回成功、`LNKCTL2` 目标值或 `LNKCAP` 能力字段都不够。

## 为什么宽度可能卡在 x4

1. GPU 的 `LNKCAP.MAXWIDTH` 仍是 4；
2. PCB 只布了 4 条 lane；
3. PCIe 金手指的 lane 4-15 未连接或被遮挡；
4. AC 耦合电容/端接不完整；
5. 主板插槽 bifurcation 成 `x4x4x4x4`；
6. 使用了 x4 延长线、转接卡或矿机转接板；
7. 上游根端口只有 x4；
8. 链路训练因信号完整性失败。

## 型号差异

P104-100 和 P106-090 存在不同 PCB 版本。不要因为同为 Pascal 或同叫
P104/P106，就认为 lane 走线、耦合电容和 strap 完全相同。

EFI 只能执行寄存器宽度事务，不能补出物理上不存在的 lane。

## 结论

本项目的成功标准是：

```text
GPU/根端口的 LNKSTA 宽度都达到 x16
```

不是 Gen2/Gen3 速率，也不是 GPU-Z 左侧的能力栏。
