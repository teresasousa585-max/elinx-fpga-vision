# CNN 独立提取包：详细注释与使用说明

## 1. 这是什么

本目录是从统一 `RAW/RGB/EDGE/CNN/UART` FPGA 工程中提取出的 CNN 独立验证包。它保留了当前工程中实际启用的 CNN 生产 RTL、跨时钟 FIFO 依赖、CNN 专用 testbench、源模型等价参考、`new_capture` RAW 数据集以及 manifest 生成工具。

原统一工程保持不变。本目录中的文件都是提取副本，后续可以在本目录内单独阅读、仿真和修改。

> 重要：这里的“独立”表示 CNN 源码和 CNN 核心验证可以脱离统一工程目录运行；最终上板仍需要统一工程提供 OV5640、SDRAM、视频模式切换、OSD、UART 和时钟约束。CNN 代码本身不包含完整 FPGA 顶层和完整板级约束。

## 2. 提取范围与目录结构

```text
cnn_standalone/
├─ rtl/
│  ├─ cnn/                              # CNN 生产 RTL，8 个文件
│  ├─ rgb/                              # 可选 CNN-RGB-OSD 对齐验证所需的 RGB 依赖
│  └─ video/                            # 可选 CNN-RGB-OSD 对齐验证所需的视频依赖
├─ hdmi_1280x720.srcs/sources_1/ip/
│  ├─ fifo_data/fifo_data.v              # CNN 双向异步 FIFO 的项目定制实现
│  └─ m4k_linebuf_2048x8/m4k_linebuf_2048x8.v
├─ tb/cnn/
│  ├─ *.sv                               # CNN 核心/系统/跨层 testbench
│  ├─ *.do                               # ModelSim/eLinx 仿真脚本
│  └─ source_reference/                  # 未改名的源 classifier/weight，仅用于等价比较
├─ sim/input/cnn/                        # 163 样本 manifest、10 样本 smoke manifest、摘要
├─ new_capture/                          # 163 个完整 RAW8 样本，约 150 MB
├─ tools/cnn/build_new_capture_manifest.py
└─ CNN详细注释与使用说明.md
```

没有复制以下内容：`db/`、`incremental_db/`、ModelSim `work/`、旧 bitstream、后端 run 输出、失败的 UART 流、PNG/分析派生物以及统一工程中与 CNN 无关的 OV5640/SDRAM/UART 顶层。这样可以避免把机器相关生成物误当成 CNN 源码。

## 3. CNN 数据通路总览

```text
75 MHz RAW8 视频流
    │  in_de + raw8 + x/y
    ▼
cnn_feature_32x32
    │  32×32 = 1024 个 6-bit density token
    ▼
cnn_frontend_75m
    │  帧边界准入、busy 整帧丢弃、session 编号
    ▼
75 MHz → 25 MHz forward fifo_data
    ▼
cnn_classifier_session_25m
    │  RESET / START / FEATURE
    ▼
cnn_flat_classifier + cnn_weight_rom
    │  1 个 1024-feature session 的推理结果
    ▼
25 MHz → 75 MHz return fifo_data
    ▼
cnn_frontend_75m
    │  session 校验、结果过滤、稳定器、帧边界显示提交
    ▼
cnn_digit_stabilizer / cnn_digit_valid / cnn_digit
```

CNN 只读取 RAW8，不依赖 RGB 或 EDGE 的像素结果。CNN 显示底图、ROI/MASK 叠加和 OSD 属于统一视频层；本目录只保留了运行 `cnn_rgb_osd_alignment_tb` 所需的最小 RGB/视频验证依赖。

## 4. RTL 文件逐个说明

| 文件 | 时钟域 | 作用与阅读重点 |
|---|---:|---|
| `rtl/cnn/cnn_system.v` | 75/25 MHz | CNN 子系统顶层。建立共同 reset island、两条异步 FIFO、75 MHz 前端和 25 MHz session wrapper。它的输入是 RAW8 视频 bundle 的必要字段，输出是识别结果和调试状态。 |
| `rtl/cnn/cnn_frontend_75m.v` | 75 MHz | CNN 前端控制核心。只在 `frame_prefetch_start` 做整帧 ACCEPT/DROP；发送 RESET、START 和 FEATURE；给每次 session 加 4-bit session id；过滤 stale ACK/FAULT/RESULT；在 `frame_epoch` 提交显示结果。 |
| `rtl/cnn/cnn_feature_32x32.v` | 75 MHz | 固定 ROI 的特征提取器。把 RAW8 ROI 划成 32×32 个 cell，使用 dark-pixel 数量生成 6-bit density，并带有 active/pending 两槽输出缓存、ready/backpressure、overflow sticky 标志和 cell bbox。 |
| `rtl/cnn/cnn_fifo_pop.v` | 读时钟域 | 适配 `fifo_data` 的一拍读数据返回语义，把 FIFO `rdreq/q` 转换成安全的 `pop_valid/pop_data`。 |
| `rtl/cnn/cnn_classifier_session_25m.v` | 25 MHz | 分类器会话协议 wrapper。状态为 `IDLE → COLLECT → INFER → RESULT_WAIT → IDLE`，严格检查 session、feature index 和 final/done，只允许 COLLECT 写入分类器；结果在返回端阻塞时保持稳定。 |
| `rtl/cnn/cnn_flat_classifier.v` | 25 MHz | 定点 CNN 推理状态机。收集 1024 个 feature，执行卷积/全连接计算并输出 digit、unknown、distance；`soft_reset` 用于协议故障和新 session 恢复。 |
| `rtl/cnn/cnn_weight_rom.v` | 25 MHz | 当前工程实际使用的卷积/全连接权重和 bias ROM。数据保持原模型身份，没有重新训练或替换。 |
| `rtl/cnn/cnn_digit_stabilizer.v` | 75 MHz | 结果稳定器。默认连续 3 个相同有效结果才显示；连续未知结果达到默认 10 帧后显示 unknown；`clear` 用于退出/重入 CNN 时清除旧状态。 |
| `hdmi_1280x720.srcs/sources_1/ip/fifo_data/fifo_data.v` | 75/25 MHz | 项目定制 Gray-pointer 异步 FIFO，深度和位宽由参数决定；内部双时钟 M4K RAM、三拍 Gray pointer 同步、异步置位/本地域同步释放。 |

### 4.1 固定图像和特征参数

- 输入图像：RAW8，1280×720，约 60 fps。
- ROI：`x=320, y=104, width=640, height=512`。
- ROI 内每个 cell：`20×16` 像素。
- dark 判定：`raw8 <= 112`。
- density：`dark_count >> 3`，输出 6 bit，最多 1024 个 token。
- token index：`{cell_y[4:0], cell_x[4:0]}`，顺序为 0 到 1023。
- index 1023 的 token 带 `feature_frame_done=1`。
- 分类器工作时钟：25 MHz；完整推理约 249900 个 25 MHz 周期，约 10 ms。
- 因为下一帧 ROI 间隔小于一次完整推理时间，当前设计采用“整帧准入”：分类器 busy 时整帧丢弃，不覆盖正在推理的 feature memory、bbox 或累加和。

### 4.2 跨时钟协议位定义

75 MHz → 25 MHz 的 forward FIFO 为 23 bit：

```text
{ cmd_type[22:21], session[20:17], done[16], index[15:6], value[5:0] }
```

`cmd_type`：`0=RESET`、`1=START`、`2=FEATURE`。

25 MHz → 75 MHz 的 return FIFO 为 26 bit：

```text
{ is_result[25], session[24:21], fault_or_unknown[20], digit[19:16], payload[15:0] }
```

`is_result=0` 时是 RESET_ACK 或 FAULT；`is_result=1` 时是分类结果，bit 20 表示 unknown，bit 19:16 是 digit，低 16 bit 是 distance/margin 等结果字段。

两个 FIFO 共用异步断言的 reset island，但 75 MHz 和 25 MHz 各自使用两级本地同步释放。不要把某一个时钟域已经同步过的 reset release 信号拿去驱动另一个时钟域。

## 5. 验证文件说明

| 脚本 | 覆盖内容 |
|---|---|
| `run_cnn_feature_backpressure_tb.do` | 随机 bounded ready、1024 token、顺序、bbox 和无 overflow。 |
| `run_cnn_feature_collision_tb.do` | active/pending 同拍碰撞、真实双槽溢出和 frame clear 恢复。 |
| `run_cnn_fifo_async_tb.do` | FIFO 满/空、顺序、任一侧 reset、读钟停止、flush 和旧地址不可见。需要官方 eLinx 库与 `fifo_data.v`。 |
| `run_cnn_classifier_session_25m_tb.do` | index/done 协议、FAULT 背压、完整推理、RESET 和 RESULT_WAIT。需要官方 eLinx 库。 |
| `run_cnn_system_async_tb.do` | 真实 RAW8 帧、75/25 MHz CDC、物理帧 ACCEPT/DROP、session wrap、stale result 和双域 reset。需要官方 eLinx 库及 RAW 样本。 |
| `run_cnn_new_capture_feature_equiv_tb.do` | 用 manifest 中的 RAW 逐像素重放 ROI，与独立 golden oracle 比较 1024 个 feature token。默认使用 10 样本 smoke manifest。 |
| `run_cnn_new_capture_classifier_equiv_tb.do` | 未修改源 classifier/weight 与当前目标 classifier/session wrapper 的逐样本等价比较。默认使用全部 163 个 RAW。需要官方 eLinx 库。 |
| `run_cnn_rgb_osd_alignment_tb.do` | 可选跨层测试：RGB pipeline、模式 mux、ROI/MASK、OSD 和 CNN 显示延迟对齐。它不是纯 CNN 单元测试。 |

历史验证记录显示：feature backpressure、collision、异步 FIFO、session wrapper、系统异步链路和 163 样本等价回归均曾通过；这些记录是提取时的来源证据，不代替在本目录重新运行。当前目录没有复制旧的 `sim/out` 日志。

## 6. ModelSim/eLinx 使用步骤

### 6.1 环境准备

最终仿真应使用项目规定的官方 eLinx 仿真库：

```text
C:\work\eHiWay\eLinx3.0\Simulation\elinx_lib
```

在 PowerShell 中进入本目录，并设置库路径：

```powershell
Set-Location '<你的工作区>\cnn_standalone'
$env:ELINX_LIB = 'C:\work\eHiWay\eLinx3.0\Simulation\elinx_lib'
```

确认 `ELINX_LIB` 下至少存在 `altera_primitives.v`、`220model.v`、`stratix_atoms.v` 和 `altera_mf.v`。如果只做不依赖厂商原语的 feature 单元测试，可以不设置该变量。

### 6.2 运行单项测试

```powershell
vsim -c -do tb/cnn/run_cnn_feature_backpressure_tb.do
vsim -c -do tb/cnn/run_cnn_feature_collision_tb.do
vsim -c -do tb/cnn/run_cnn_fifo_async_tb.do
vsim -c -do tb/cnn/run_cnn_classifier_session_25m_tb.do
vsim -c -do tb/cnn/run_cnn_system_async_tb.do
```

脚本会在 `sim/out/` 下生成本次运行的临时 ModelSim library 和日志；这些是可删除的生成物，不要加入 RTL 源集。

### 6.3 运行数据集回归

先确认数据集路径和 manifest 一致：

```powershell
python tools/cnn/build_new_capture_manifest.py --workspace .
```

运行 10 样本 smoke：

```powershell
$env:CNN_MANIFEST = (Resolve-Path sim/input/cnn/new_capture_smoke_manifest.txt).Path
vsim -c -do tb/cnn/run_cnn_new_capture_feature_equiv_tb.do
```

运行完整 163 样本 feature 和 classifier 回归：

```powershell
$env:CNN_MANIFEST = (Resolve-Path sim/input/cnn/new_capture_manifest.txt).Path
vsim -c -do tb/cnn/run_cnn_new_capture_feature_equiv_tb.do
vsim -c -do tb/cnn/run_cnn_new_capture_classifier_equiv_tb.do
```

如果从命令行直接启动 `vsim`，必须在本目录执行；脚本中的 `$prj_root` 由当前工作目录解析，不要从上级统一工程目录启动。

### 6.4 数据集标签规则

当前数据集共 163 个 RAW 文件，每个严格为 `1280×720=921600` bytes。分类标签以文件名 `raw8_digit_<label>_...raw` 为准，不以父目录为准。共有 6 个文件位于 `new_capture/0/`，但文件名标签是 digit 9；manifest 保留这个事实并按文件名标为 9。不要手工重命名或移动这些样本。

`new_capture` 中只提取了可作为 CNN 输入的完整 `.raw` 文件；失败 UART 流和分析 PNG/TXT/JSON 没有放进独立包。`new_capture_manifest.json` 记录样本数量、类别分布、错位样本列表和 manifest SHA-256。

## 7. 如何把 CNN 接回统一工程

如果要回到板级工程，而不是只做本目录仿真，建议按以下顺序接入：

1. 把 `rtl/cnn/*.v` 和 `fifo_data.v` 加入当前工作区副本的活动 source set；不要改动四个只读参考工程。
2. 在 75 MHz 视频域给 `cnn_system` 提供帧边界 `frame_prefetch_start`、帧 epoch、`in_de`、RAW8、x/y 和当前 active mode。
3. 只在完整帧边界切换 CNN mode；退出或重入 CNN 时让前端生成新 session，丢弃旧 ACK/FAULT/RESULT。
4. 将 `cnn_digit_valid/cnn_digit` 接到统一视频层；若叠加 ROI/MASK/OSD，必须按完整 `{valid/DE/HS/VS/x/y/RGB/raw}` bundle 做延迟对齐。
5. 保持 25 MHz/75 MHz CDC 为异步 FIFO，不逐 bit 同步 feature 总线。
6. 先运行 CNN 专用 ModelSim 回归，再运行统一顶层官方库 elaboration、CDC/约束检查，最后由用户在 eLinx GUI 中对当前工作区副本执行 fresh Implementation。

本提取包不包含统一工程的 QSF/EDC，因此不能单独宣称板级时序签核。特别是 `fifo_data` 的 Gray-pointer CDC 例外、25 MHz 和 75 MHz 时钟约束、复位同步释放以及最终视频延迟，必须在接回统一工程后重新检查。

## 8. 已知限制与注意事项

- `cnn_weight_rom.v` 是综合/仿真使用的巨大 Verilog ROM，不要用文本编辑器批量重排或重新生成其中的权重数据。
- `cnn_flat_classifier.v` 的计算是定点实现；不能仅凭 Python 浮点结果替代 RTL 等价回归。
- 识别结果不是每个视频帧都更新：分类器 busy 时整帧丢弃，目标结果更新速率约 30 次/秒。
- `cnn_digit_stabilizer` 的连续帧确认逻辑与分类器推理结果不同，测试分类器时不要把稳定器输出误认为单次分类结果。
- `run_cnn_rgb_osd_alignment_tb.do` 使用了 RGB/视频依赖和 `m4k_linebuf` wrapper，若只研究 CNN 核心可跳过。
- 本目录没有执行自动后端实现，也没有复制旧后端报告；任何 Fmax、slack、资源占用或板测结论都必须以当前目标工程 fresh run 为准。

## 9. 来源对应关系

| 独立包内容 | 统一工程原路径 |
|---|---|
| `rtl/cnn/*.v` | `rtl/cnn/*.v` |
| `fifo_data.v` | `hdmi_1280x720.srcs/sources_1/ip/fifo_data/fifo_data.v` |
| CNN testbench 与 `.do` | `tb/cnn/` |
| 源等价 classifier/weight | `tb/cnn/source_reference/` |
| CNN manifest | `sim/input/cnn/` |
| RAW 数据 | `new_capture/**/*.raw` |
| manifest 工具 | `tools/cnn/build_new_capture_manifest.py` |

提取副本的目标是便于学习、审阅和独立回归；任何功能改动都应先在本目录验证，再有选择地回移到统一工程，并同步更新其 source set、CDC 清单、仿真证据和时序记录。
