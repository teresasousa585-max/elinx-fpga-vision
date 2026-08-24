# 2026 年集创赛国奖项目：eLinex FPGA 实时视觉处理系统

本仓库为 **2026 年全国大学生集成电路创新创业大赛国奖项目**的开源整理版。系统以 OV5640 摄像头采集视频，在 eLinex FPGA 上完成颜色空间转换、几何变换、空间滤波、边缘检测和图像增强，并通过 HDMI 与 UDP 图传输出；PyQt6 上位机负责串口算法切换、实时预览、截图和录像。

仓库重点保留获奖作品的 RTL 数据通路、板级工程、上位机和协议文档，同时统一为 UTF-8 中文注释，便于后续学习、复现与二次开发。

**项目作者：Ethereal**

## 功能概览

- OV5640 摄像头采集与初始化
- RGB / YCbCr / HSV 颜色空间转换
- 图像缩放、90°/180° 旋转、形态学操作与 Sobel 边缘检测
- 直方图均衡、HDR、双边滤波、引导滤波、暗光增强与磨皮美颜
- SDRAM 帧缓存、HDMI 显示、UDP RGB565 图传
- 串口算法控制、实时预览、截图与录像

## 仓库结构

```text
.
├── host/
│   └── main.py                 # PyQt6 中文上位机
├── fpga/
│   ├── base/                   # 基础图像处理工程
│   └── enhancement/            # 暗光/引导滤波/美颜增强工程
├── docs/
│   ├── ARCHITECTURE.md         # 系统结构与通信协议
│   ├── ALGORITHM_INDEX.md      # 算法、模式、文件与模块索引
│   ├── HOST_SOFTWARE.md        # 上位机代码结构说明
│   └── COMMENT_STYLE.md        # 中文注释规范
├── requirements.txt
├── THIRD_PARTY_NOTICES.md
└── LICENSE
```

FPGA 工程保留 `ov5640.qpf`、`ov5640.qsf`、约束、RTL、初始化数据及必要的厂商 IP 生成文件；综合数据库、布局布线结果、日志和可执行程序未纳入仓库。

## 上位机运行

推荐 Python 3.10 或更高版本。

```bash
python -m venv .venv

# Windows
.venv\Scripts\activate

python -m pip install -r requirements.txt
python host/main.py
```

使用步骤：

1. 将 FPGA 板卡串口连接到电脑，在上位机中选择串口并连接；默认波特率为 `1,000,000`。
2. 将电脑网卡配置到与板卡相同的局域网，上位机监听 UDP `8080` 端口。
3. 选择算法。上位机通过串口发送 `AA 主模式 子模式 55` 四字节指令。
4. 基础工程算法执行后会进入图传页；可在图传页截图或录制视频。

> 上位机按 `1024 × 600`、RGB565、30 FPS 处理画面。若修改 FPGA 输出格式，请同步修改 `host/main.py` 中的图像参数和解码逻辑。

## FPGA 工程

两套工程目标器件均为 `EP1S80F1508C6`。工程配置中的源码引用已改为相对路径，可从仓库内直接打开：

- `fpga/base/ov5640.qpf`
- `fpga/enhancement/ov5640.qpf`

工程依赖 eLinex/eHiWay 工具链及其器件库。部分 `ip/` 内容为工具生成文件，不属于本项目 MIT 许可范围；使用前请确认已取得相应工具和 IP 授权，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 开发说明

- 手写 RTL 位于各工程的 `ov5640.srcs/sources_1/new/` 与 `imports/`。
- 厂商生成 IP 位于 `ov5640.srcs/sources_1/ip/`，请优先通过工具重新生成，不要手工修改。
- 每个 RTL 文件均包含中文正文导读，并在参数、端口、内部信号、组合赋值、时序过程、状态分支和子模块例化处提供就地说明。
- 代码注释统一采用中文职责说明，信号、模块与协议名称保留英文标识；项目作者及中文注释维护者为 Ethereal。
- 全部文本文件采用 UTF-8（无 BOM）编码和 LF 换行。
- 提交前至少运行 Python 语法检查，并确认 QSF 中不存在本机绝对路径。

各算法对应的模式编码、顶层入口、核心 RTL 和辅助文件详见 [算法与文件索引](docs/ALGORITHM_INDEX.md)。上位机类、线程及通信职责详见 [上位机代码说明](docs/HOST_SOFTWARE.md)。

## 开源许可

项目自有代码采用 [MIT License](LICENSE)。第三方代码和厂商生成 IP 继续遵循各自原有许可，MIT 许可不会覆盖或替代这些条款。
