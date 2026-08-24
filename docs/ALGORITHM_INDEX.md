# 算法、模式与 RTL 文件索引

本文档给出 2026 年集创赛国奖项目中“界面算法名称—串口模式—FPGA 工程—实现文件”的对应关系。路径均相对于仓库根目录。

## 模式编码总表

上位机发送 `AA 主模式 子模式 55`。基础算法位于 `fpga/base`，增强算法位于 `fpga/enhancement`。

| 界面功能 | 主模式 | 子模式 | 工程 | 主要实现文件 |
| --- | ---: | ---: | --- | --- |
| 原图直出 | 0 | 0 | base | `video_algo_manager.v`、`hdmi.v` |
| RGB → YCbCr/灰度 | 1 | 1 | base | `rgb2ycbcr.v`、`video_algo_manager.v` |
| RGB → HSV/肤色二值化 | 2 | 0 | base | `rgb2hsv.v`、`video_algo_manager.v` |
| 缩小 4 倍 | 3 | 0 | base | `top.v`、`sdram_top.v` |
| 缩小 2 倍 | 3 | 1 | base | `top.v`、`sdram_top.v` |
| 放大 2 倍 | 4 | 0 | base | `top.v`、`line_buffer` IP、`mean_filter_3x3.v` |
| 放大 4 倍 | 4 | 1 | base | `top.v`、`line_buffer` IP、`mean_filter_3x3.v` |
| 旋转 180° | 5 | 0 | base | `ov5640_i2c_init.v`、`top.v` |
| 旋转 90° | 5 | 1 | base | `video_rotator_bram.v`、`ram_large_192k.v`、`top.v` |
| 仿射错切 | 5 | 2 | base | `video_rotator_bram.v`、`ram_large_192k.v`、`top.v` |
| 直方图均衡化 | 6 | 0 | base | `histogram_equalization.v`、`hist_ram` IP |
| 灰度腐蚀 | 7 | 0 | base | `gray_morphology.v`、`video_algo_manager.v` |
| 灰度膨胀 | 7 | 1 | base | `gray_morphology.v`、`video_algo_manager.v` |
| HDR 色调映射 | 8 | 0 | base | `hdr_tone_mapping_color.v`、`rom_reciprocal` IP |
| 双边滤波 | 9 | 0 | base | `bilateral_filtering_proc_to_hdmi.v`、`bilateral_filtering_Line_buffer.v`、`bilateral_core.v` |
| Sobel 边缘检测 | 10 | 0 | base | `sobel_line_buffer.v`、`sobel_calc.v`、`video_algo_manager.v` |
| 引导滤波 | 10 | 0 | enhancement | `guided_to_hdmi.v` 及 `guided_*`、`box_filter_*` |
| 磨皮美颜 | 10 | 1 | enhancement | `guided_to_hdmi.v`、`meiyan_rebuild.v`、`meiyan_bilateral_core.v` |
| 暗光增强 | 11 | 0 | enhancement | `anguang_tohdmi.v`、`anguang_guided.v`、`anguang_enhance_apply.v` |

> 主模式 `10` 在两套独立 FPGA 工程中含义不同：base 工程对应 Sobel，enhancement 工程对应引导滤波/磨皮。烧录工程必须与上位机选择的项目分区一致。

## 基础算法实现

### 颜色空间转换

- `fpga/base/ov5640.srcs/sources_1/new/rgb2ycbcr.v`：流水线 RGB888 → YCbCr 转换，并输出延迟对齐的原始 RGB 旁路。
- `fpga/base/ov5640.srcs/sources_1/new/rgb2hsv.v`：定点 RGB → HSV；`video_algo_manager.v` 使用 H、S 阈值生成肤色二值图。
- `RGB_to_YCbCr.v` 与 `YCbCr_to_RGB.v`：为双边滤波等复合算法提供前后颜色空间转换。

### 图像缩放与几何变换

- `fpga/base/ov5640.srcs/sources_1/new/top.v`：根据模式对摄像头像素坐标抽样、裁剪，控制 SDRAM 有效帧地址和 HDMI 读请求，实现 2/4 倍缩小与放大。
- `fpga/base/ov5640.srcs/sources_1/ip/line_buffer/line_buffer.v`：放大时缓存行像素，用于重复输出和行间补点。
- `fpga/base/ov5640.srcs/sources_1/new/mean_filter_3x3.v`：对放大结果执行 3×3 平滑，降低锯齿和块效应。
- `fpga/base/ov5640.srcs/sources_1/new/ov5640_i2c_init.v`：模式 5/0 动态修改摄像头翻转寄存器，实现全画幅 180° 旋转。
- `fpga/base/ov5640.srcs/sources_1/new/video_rotator_bram.v`：对抽样帧执行 BRAM 地址重映射，模式 5/1 实现 90° 旋转，模式 5/2 实现仿射错切。
- `fpga/base/ov5640.srcs/sources_1/new/ram_large_192k.v`：为旋转/错切提供级联片上帧缓存。

### 直方图均衡化

- `histogram_equalization.v`：按帧统计灰度直方图，处理读写冲突并生成均衡化亮度。
- `hist_ram` IP：保存灰度级统计与映射数据。
- `rgb2ycbcr.v`：提供 Y 亮度输入；`video_algo_manager.v` 将均衡化 Y 复制到 RGB 三通道显示。

### 形态学处理

- `gray_morphology.v`：构造灰度邻域；子模式 0 取局部最小值实现腐蚀，子模式 1 取局部最大值实现膨胀。
- `video_algo_manager.v`：根据 `al_sub_hdmi` 选择腐蚀/膨胀并路由同步信号。

### Sobel 边缘检测

- `sobel_line_buffer.v`：从连续灰度流构造 3×3 窗口。
- `sobel_calc.v`：计算水平/垂直梯度和边缘幅值，并按阈值输出二值边缘。
- `video_algo_manager.v`：为 Sobel 输入增加寄存器隔离级，并选择其输出通路。

### HDR 色调映射

- `hdr_tone_mapping_color.v`：根据亮度执行动态范围压缩，并结合对齐后的原始 RGB 保留色彩。
- `rom_reciprocal` IP 与 `rom_reciprocal.mif`：提供定点倒数查找数据，减少实时除法资源消耗。

### 双边滤波

- `bilateral_filtering_proc_to_hdmi.v`：复合算法顶层，组织颜色转换、窗口、滤波核和显示时序。
- `bilateral_filtering_Line_buffer.v`：构造 RGB/YCbCr 3×3 邻域并对齐同步信号。
- `bilateral_core.v`：计算空间权重与像素差权重，执行保边加权平均。
- `range_weight.mif`：灰度差权重查找表。

## 图像增强算法实现

### 引导滤波

主入口为 `fpga/enhancement/ov5640.srcs/sources_1/new/guided_to_hdmi.v`，流水线顺序如下：

1. `RGB_to_YCbCr.v`：生成引导亮度 Y 和色度旁路。
2. `guided_line_buffer.v`：计算 Y、Y² 的列窗口和中心像素。
3. `box_filter_y.v`：生成局部均值 `mean(Y)`、`mean(Y²)`。
4. `guided_var_a_b.v`：由局部方差和 `EPSILON` 计算线性系数 a、b。
5. `guided_line_buffer_a_b.v`：构造 a、b 的局部窗口。
6. `box_filter_ab.v`：计算 `mean(a)`、`mean(b)`。
7. `guided_final_rebuild.v`：按 `q = mean(a) × I + mean(b)` 重建亮度。
8. `YCbCr_to_RGB.v`：恢复 RGB888 并输出对齐的视频同步信号。

### 磨皮美颜

- `guided_to_hdmi.v`：子模式 1 选择磨皮重建支路。
- `meiyan_rebuild.v`：融合引导系数、原始亮度与局部平滑结果，输出磨皮后的 YCbCr。
- `bilateral_filtering_Line_buffer_1.v`：构造磨皮双边滤波使用的邻域。
- `meiyan_bilateral_core.v`：执行保边平滑，抑制皮肤高频纹理。
- `meiyan_rom_scurve`、`meiyan_rom_reciprocal` IP：提供曲线和倒数查表数据。

### 暗光增强

- `anguang_tohdmi.v`：暗光增强复合顶层，连接照度估计、增益应用与视频输出。
- `anguang_guided.v`：通过引导滤波估计平滑照度分量。
- `anguang_enhance_apply.v`：计算增强增益，提升暗部并限制输出范围。
- `anguang_gain` IP、`lowlight_combined_rom.mif`：提供增益/映射查找数据。

## 公共基础设施文件

| 功能 | 文件 | 职责 |
| --- | --- | --- |
| 板级集成 | `top.v` | 连接摄像头、SDRAM、HDMI、UART、算法和网络通路 |
| 摄像头 | `ov5640_i2c_init.v`、`ov5640_capture.v` | 初始化寄存器并采集 RGB565 |
| HDMI | `i2c_sll9134.v`、`hdmi.v` | 初始化发送器并生成显示扫描时序 |
| 帧缓存 | `sdram_top.v`、`sdram_fifo_ctrl.v`、`sdram_control.v`、`sdram_param.v` | 跨时钟 FIFO、帧地址、突发访问和刷新 |
| 串口控制 | `uart_rx.v`、`uart_cmd_parser.v`、`cdc_handshake.v` | 接收四字节命令并跨域同步模式 |
| UDP 图传 | `UDP_Send.v`、`CRC32_D8.v` | 生成以太网/IPv4/UDP 帧和 CRC32 |
| PHY 配置 | `phy_reg_config.v`、`mdio_com.v` | 通过 MDIO 初始化以太网 PHY |
| 算法路由 | `video_algo_manager.v` | 实例化算法支路并按模式选择最终视频输出 |

