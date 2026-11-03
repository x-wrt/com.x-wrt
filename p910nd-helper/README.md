# p910nd-helper 固件支持

这里的固件用于打印机上电后加载到 RAM。它与客户端打印驱动、打印数据
转换插件、写入 Flash 的固件升级包是不同的东西。`p910nd` 仍然只负责转发
客户端生成的打印数据。

## 自动加载的型号

热插拔脚本先匹配 USB VID/PID，再通过已经打开的打印机设备查询 IEEE 1284
`MDL` / `MODEL` 字段。型号必须与固件相符；已经包含 `FWVER` 字段的设备
不会再次加载。USB 的 `bcdDevice` 版本号不用于选择固件。

| HP LaserJet 型号 | USB VID:PID | 本包固件 |
| --- | --- | --- |
| 1000 | 03f0:0517 | `sihp1000.dl` |
| 1005 / 1005 series | 03f0:1317 | `sihp1005.dl` |
| 1018 / 1018s | 03f0:4117 | `sihp1018.dl` |
| 1020 / 1020 Plus | 03f0:2b17 | `sihp1020.dl` |
| P1005 | 03f0:3d17 | `sihpP1005.dl` |
| P1006 | 03f0:3e17 | `sihpP1006.dl` |
| P1007 | 03f0:4817 | `sihpP1007.dl` |
| P1008 | 03f0:4917 | `sihpP1008.dl` |
| **P1009** | **03f0:3e17** | **复用 `sihpP1008.dl`** |
| P1505 | 03f0:3f17 | `sihpP1505.dl` |

### P1009 的依据

核对了 HPLIP 3.26.4 的 `models.dat`、插件包 `plugin.spec` 及实际固件：

- `hp_laserjet_p1009` 标记 `fw-download=True`，USB ID 为 `03f0:3e17`。
- 插件包确实为 P1009 提供 `hp_laserjet_p1009.fw.gz`。
- 解压后的 222571 字节与本包的 `sihpP1008.dl` **逐字节相同**，无需新增
  二进制文件。该版本插件中的 P1006、P1008、P1009 固件解压后也完全相同。
- 当前本包的 `sihpP1006.dl` 是另一版本，因此 P1009 根据型号明确选择已经
  核对的 P1008 文件，不直接沿用 P1006 的默认映射。

解压后固件的 SHA-256：

```text
dcb23baee83d463f7f8fa8d3235302280535ee7c673d4f21cdbe2146d446ec33
```

核对所用插件包来自 [OpenPrinting 镜像](https://www.openprinting.org/download/printdriver/auxfiles/HP/plugins/hplip-3.26.4-plugin.run)。
下载后验证了归档长度和内嵌 MD5。完整 `.run` 文件的 SHA-256 为：

```text
199f78f8af7f36894d7180e9090963ce2550a75ec701f8a4ba37665a9746fdf0
```

只读取、解包了归档中的数据，没有执行插件安装程序。HPLIP 3.10.6 的相同
固件也作了交叉比较，P1009 的解压内容一致。

## 复查后排除的型号

| 型号 | 处理及依据 |
| --- | --- |
| M1005 MFP，03f0:3b17 | 移除误用 `sihp1005.dl` 的映射。M1005 与 1005 是不同产品；HPLIP 标记 `fw-download=False`，插件清单不为 M1005 安装固件，HP 技术参考手册说明其固件保存在设备中并通过 Flash 升级。 |
| 1022 / 1022n / 1022nw，03f0:2c17 / 2d17 / 3017 | 移除误用 `sihp1020.dl` 的映射。HPLIP 三者均标记 `fw-download=False`，插件清单没有为其安装固件；foo2zjs 的标准开机固件名单也不包含它们。 |
| P1505n，03f0:4017 | 移除误用 P1505 固件的映射。foo2zjs 的 USB 映射明确区分 P1505 与 P1505n；HPLIP 对 P1505n 标记 `fw-download=False`，插件清单不安装固件。 |
| P1102 / P1102w | 不加入自动加载。HPLIP 的固件下载标记为 `False`；实际插件包里这两个名字下的固件与 P1005/P1007 的固件完全相同，存在文件不能证明应向 P1102 系列发送。 |
| P1566 / P1567 / P1568 / P1569 | 不加入自动加载。HPLIP 虽标记 `True`，但 HP 将这些型号归为 P1560 系列，其维修手册明确记载 NAND Flash 保存固件；插件内 P1566 文件与 P1505 固件完全相同，也没有 P1567/8/9 独立文件。缺少可信的开机加载依据，不能据此发送 P1505 固件。 |

P1566 的核对修正了仅凭 `fw-download=True` 和固件文件清单就将它列为优先
补充对象的初步判断。这里的排除结论针对自动加载 RAM 固件，不影响客户端
选用相应打印驱动，也不禁止用户按厂商流程升级设备固件。

### 资料来源

- [HPLIP 3.26.4 `models.dat` 源码镜像](https://github.com/arembez/hplip/blob/v3.26.4/hplip-3.26.4-sources/data/models/models.dat)：下载标记、型号别名及 P1009 的 USB ID。该数据库部分 USB ID 明显复用，不能直接用它替代型号检查。
- [OpenPrinting/foo2zjs `hplj1000`](https://github.com/OpenPrinting/foo2zjs/blob/main-fixes/hplj1000)：原有型号的 USB ID、固件及 `FWVER` 判断。
- [OpenPrinting/foo2zjs `INSTALL.in`](https://github.com/OpenPrinting/foo2zjs/blob/main-fixes/INSTALL.in)：需要每次上电加载固件的标准型号名单。
- [HPLIP 插件下载目录](https://www.openprinting.org/download/printdriver/auxfiles/HP/plugins/)：实际固件与 `plugin.spec`。
- [HP M1005 软件技术参考手册](https://www.hp.com/ctg/Manual/c00742663.pdf)：固件升级及 Flash 写入说明。
- [HP P1560/P1600 维修手册（厂商原文镜像）](https://manualzz.com/doc/6295939/hp-laserjet-p1560-p1600-service-manual)：CE663-90939，Formatter-control system / Memory use，纸面第 5 页；P1566 的 Certificate of Volatility，纸面第 198 页，记载 64 MB NAND Flash 保存驱动和固件。
- [HP 型号系列对应表](https://support.hp.com/in-en/document/c02639296)：P1566/P1567/P1568/P1569 均属 P1560 系列。

## 验证

```sh
python3 -B -m unittest discover -s p910nd-helper/tests -v
busybox ash -n p910nd-helper/25-usb-printer-helper.hotplug
```

测试包括 P1009 固件选择及可信负载哈希、共享 USB ID 下的型号校验、已加载
固件跳过、错误机型不加载、USB 热插拔竞争和失败重试。这些是模拟设备测试，
不代表已经完成打印机实机验证。
