// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：bilateral_filtering_proc_to_hdmi.v
// 主要模块：bilateral_filtering_proc_to_hdmi
// 功能分类：双边滤波算法
// 功能说明：组织颜色转换、邻域缓存、双边核计算和时序对齐，输出可直接显示的滤波视频流。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：bilateral_filtering_Line_buffer.v、bilateral_core.v、RGB_to_YCbCr.v、YCbCr_to_RGB.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns / 1 ps

// -----------------------------------------------------------------------------
// 正文导读：组织颜色转换、邻域缓存、双边核计算和时序对齐，输出可直接显示的滤波视频流。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 bilateral_filtering_proc_to_hdmi：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module bilateral_filtering_proc_to_hdmi #(
    // 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter PIXEL_PER_LINE = 11'd1024
) (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire i_clk,
    input wire i_rst,


    input wire i_hs,
    input wire i_vs,
    input wire i_de,
    input wire [23:0] i_rgb_data,

    // 输出信号直接连接到 HDMI 输出端口
    output wire o_hs,
    output wire o_vs,
    output wire o_de,
    output wire [23:0] o_rgb_data
);
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [23:0] p11, p12, p13;
  wire [23:0] p21, p22, p23;
  wire [23:0] p31, p32, p33;
  wire m_hs, m_vs, m_de;
  wire [23:0] ycrcb_data;

  wire m0_hs, m0_vs, m0_de;
  wire m1_hs, m1_vs, m1_de;
  wire m2_hs, m2_vs, m2_de;
  // 子模块例化 1（RGB_to_YCbCr）：将 RGB888 像素转换为 YCbCr，分离亮度与色度分量，供滤波、增强和分析算法使用。
  RGB_to_YCbCr u_rgb_to_ycbcr (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_hs(i_hs),
      .i_vs(i_vs),
      .i_data_en(i_de),
      .i_rgb(i_rgb_data),

      .o_hs(m0_hs),
      .o_vs(m0_vs),
      .o_data_en(m0_de),
      .o_ycbcr(ycrcb_data)
  );

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [23:0] p22_ycbcr;
  // 子模块例化 2（bilateral_filtering_Line_buffer）：使用行存储构造连续 3×3 像素窗口，并将窗口数据与 HS/VS/DE 信号对齐。
  bilateral_filtering_Line_buffer #(
      .H_TOTAL(11'd1344)
  ) u_line_buffer (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_hs(m0_hs),  // 注意这里用 m0_hs，保持与数据流同步
      .i_vs(m0_vs),  // 注意这里用 m0_vs，保持与数据流同步
      .i_data_en(m0_de),
      .i_rgb_data(ycrcb_data),  // 直接用 YCbCr 数据进行滤波，保持色彩信息更完整

      .o_p11(p11),
      .o_p12(p12),
      .o_p13(p13),
      .o_p21(p21),
      .o_p22(p22_ycbcr),
      .o_p23(p23),
      .o_p31(p31),
      .o_p32(p32),
      .o_p33(p33),

      .o_hs(m1_hs),
      .o_vs(m1_vs),
      .o_data_en(m1_de)
  );

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [23:0] filtered_ycbcr;
  // 子模块例化 3（bilateral_core）：根据空间距离和像素差计算双边权重，对中心像素进行保边平滑。
  bilateral_core u_bilateral_core (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_hs(m1_hs),
      .i_vs(m1_vs),
      .i_data_en(m1_de),

      .i_p11(p11),
      .i_p12(p12),
      .i_p13(p13),
      .i_p21(p21),
      .i_p22(p22_ycbcr),
      .i_p23(p23),
      .i_p31(p31),
      .i_p32(p32),
      .i_p33(p33),

      .o_hs(m2_hs),
      .o_vs(m2_vs),
      .o_data_en(m2_de),
      .o_ycbcr_filtered(filtered_ycbcr) // 直接输出滤波后的 YCbCr 数据，送往 RGB 转换模块
  );
  // 子模块例化 4（YCbCr_to_RGB）：将处理后的 YCbCr 像素恢复为 RGB888，并对齐原始旁路数据与视频同步信号。
  YCbCr_to_RGB u_ycbcr_to_rgb (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_hs(m2_hs),
      .i_vs(m2_vs),
      .i_data_en(m2_de),
      .i_ycbcr(filtered_ycbcr),  // 直接输入滤波后的 YCbCr 数据进行转换

      .o_hs(m_hs),
      .o_vs(m_vs),
      .o_data_en(m_de),
      .o_rgb(p22)
  );
  // 组合连线组 1：从 o_hs 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_hs = m_hs;
  assign o_vs = m_vs;
  assign o_de = m_de;

  /*
assign o_hs = i_hs; // 直接传递输入的同步信号，保持时序一致性
assign o_vs = i_vs;
assign o_de = i_de;
*/
  assign o_rgb_data = o_de?p22:24'h000000; // 直接输出滤波后的中心像素数据，送往 HDMI 输出端口;
endmodule
