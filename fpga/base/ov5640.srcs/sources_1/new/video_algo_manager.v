// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：video_algo_manager.v
// 主要模块：image_process_pipe
// 功能分类：算法调度
// 功能说明：实例化算法支路，根据主模式和子模式选择输出，并保证像素数据与 HS/VS/DE 同步。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：uart_cmd_parser.v、top.v、各算法顶层模块
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：实例化算法支路，根据主模式和子模式选择输出，并保证像素数据与 HS/VS/DE 同步。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 image_process_pipe：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module image_process_pipe (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire clk_hdmi,
    input wire sys_rst,

    // 上位机下发的模式指令
    input wire [3:0] al_main_hdmi,
    input wire [7:0] al_sub_hdmi,

    // 来自 hdmi.v 的基准图像流与同步时序
    input wire        raw_hs,
    input wire        raw_vs,
    input wire        raw_de,
    input wire [23:0] raw_rgb,

    // 最终输出到显示器物理引脚的图像与时序
    output reg        final_hs,
    output reg        final_vs,
    output reg        final_de,
    output reg [23:0] final_rgb
);

  // 算法 1：RGB 转 YCbCr (延迟 3 拍)
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire sync_ycbcr_hs, sync_ycbcr_vs, sync_ycbcr_de;
  wire [23:0] ycbcr_data, sync_raw_rgb_ycbcr;
  // [Ethereal注释] 子模块例化 1（rgb2ycbcr）：以流水线方式完成 RGB 到 YCbCr 的定点转换，同时延迟原始 RGB 旁路以保持时序一致。
  rgb2ycbcr u_rgb2ycbcr (
      .clk(clk_hdmi),
      .rst(sys_rst),
      .i_hs(raw_hs),
      .i_vs(raw_vs),
      .i_de(raw_de),
      .i_rgb(raw_rgb),
      .o_hs(sync_ycbcr_hs),
      .o_vs(sync_ycbcr_vs),
      .o_de(sync_ycbcr_de),
      .o_ycbcr(ycbcr_data),
      .o_raw_rgb(sync_raw_rgb_ycbcr)
  );
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] algo_Y = ycbcr_data[23:16];

  // 算法 2：RGB 转 HSV 肤色提取 (延迟 3 拍)
  wire sync_hsv_hs, sync_hsv_vs, sync_hsv_de;
  wire [23:0] hsv_data;
  // [Ethereal注释] 子模块例化 2（rgb2hsv）：完成 RGB 到 HSV 的定点转换，为肤色区域识别等基于色调和饱和度的处理提供数据。
  rgb2hsv u_rgb2hsv (
      .clk(clk_hdmi),
      .rst(sys_rst),
      .i_hs(raw_hs),
      .i_vs(raw_vs),
      .i_de(raw_de),
      .i_rgb(raw_rgb),
      .o_hs(sync_hsv_hs),
      .o_vs(sync_hsv_vs),
      .o_de(sync_hsv_de),
      .o_hsv(hsv_data),
      .o_raw_rgb()
  );
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] H = hsv_data[23:16], S = hsv_data[15:8];
  wire is_skin = (H > 8'd2 && H < 8'd25 && S > 8'd40);

  // 算法 6：直方图均衡化
  wire equ_hs, equ_vs, equ_de;
  wire [7:0] equ_Y;
  // [Ethereal注释] 子模块例化 3（histogram_equalization）：统计灰度直方图并生成均衡化映射，提高低对比度画面的灰度分布范围。
  histogram_equalization u_hist_eq (
      .clk(clk_hdmi),
      .rst(sys_rst),
      .hs(sync_ycbcr_hs),
      .vsync(sync_ycbcr_vs),
      .de(sync_ycbcr_de),
      .din(algo_Y),
      .hs_out(equ_hs),
      .vsync_out(equ_vs),
      .de_out(equ_de),
      .dout(equ_Y)
  );

  // 算法 8：硬件级 HDR
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire hdr_hs, hdr_vs, hdr_de;
  wire [23:0] hdr_rgb;
  // [Ethereal注释] 子模块例化 4（hdr_tone_mapping_color）：根据亮度分量执行定点色调映射，并保持彩色信息，实现硬件 HDR 动态范围压缩。
  hdr_tone_mapping_color u_hdr_color (
      .clk(clk_hdmi),
      .rst(sys_rst),
      .hs(sync_ycbcr_hs),
      .vsync(sync_ycbcr_vs),
      .de(sync_ycbcr_de),
      .din_Y(algo_Y),
      .din_rgb(sync_raw_rgb_ycbcr),
      .hs_out(hdr_hs),
      .vsync_out(hdr_vs),
      .de_out(hdr_de),
      .dout_rgb(hdr_rgb)
  );

  // 算法 9：双边滤波平滑
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire bil_hs, bil_vs, bil_de;
  wire [23:0] bil_rgb;
  // [Ethereal注释] 子模块例化 5（bilateral_filtering_proc_to_hdmi）：组织颜色转换、邻域缓存、双边核计算和时序对齐，输出可直接显示的滤波视频流。
  bilateral_filtering_proc_to_hdmi #(
      .PIXEL_PER_LINE(11'd1024)
  ) u_bilateral (
      .i_clk(clk_hdmi),
      .i_rst(sys_rst),
      .i_hs(raw_hs),
      .i_vs(raw_vs),
      .i_de(raw_de),
      .i_rgb_data(raw_rgb),
      .o_hs(bil_hs),
      .o_vs(bil_vs),
      .o_de(bil_de),
      .o_rgb_data(bil_rgb)
  );

  // 算法 7：形态学操作 (腐蚀/膨胀)
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire morph_hs, morph_vs, morph_de;
  wire [7:0] morph_Y;
  // [Ethereal注释] 子模块例化 6（gray_morphology）：在灰度 3×3 邻域上按子模式执行腐蚀或膨胀，用于目标区域去噪与结构增强。
  gray_morphology #(
      .H_DISP(1024)
  ) u_morphology (
      .clk(clk_hdmi),
      .rst(sys_rst),
      .mode(al_sub_hdmi == 8'd1),  // 0:腐蚀, 1:膨胀
      .vs_in(sync_ycbcr_vs),
      .hs_in(sync_ycbcr_hs),
      .de_in(sync_ycbcr_de),
      .data_in(algo_Y),
      .vs_out(morph_vs),
      .hs_out(morph_hs),
      .de_out(morph_de),
      .data_out(morph_Y)
  );


  // 放大模式辅助支路：3×3 均值滤波用于抑制像素复制产生的锯齿与块效应。
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire smooth_hs, smooth_vs, smooth_de;
  wire [23:0] smooth_rgb;
  // [Ethereal注释] 子模块例化 7（mean_filter_3x3）：对 RGB 3×3 邻域执行均值滤波，用于图像放大后的平滑和锯齿抑制。
  mean_filter_3x3 u_smooth (
      .i_clk(clk_hdmi),
      .i_rst(sys_rst),
      .i_hs (raw_hs),
      .i_vs (raw_vs),
      .i_de (raw_de),
      .i_rgb(raw_rgb),
      .o_hs (smooth_hs),
      .o_vs (smooth_vs),
      .o_de (smooth_de),
      .o_rgb(smooth_rgb)
  );

  // 算法 10：Sobel 边缘检测
  // =========================================================================
  // 输入寄存器隔离级：防止 Sobel 较长的组合路径影响前级时序收敛
  // =========================================================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg sobel_in_hs, sobel_in_vs, sobel_in_de;
  reg [7:0] sobel_in_Y;

  // [Ethereal注释] 时序过程 1：由 clk_hdmi posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk_hdmi) begin
    sobel_in_hs <= sync_ycbcr_hs;
    sobel_in_vs <= sync_ycbcr_vs;
    sobel_in_de <= sync_ycbcr_de;
    sobel_in_Y  <= algo_Y;
  end

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire sobel_lb_hs, sobel_lb_vs, sobel_lb_de;
  wire [7:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;

  wire sobel_hs, sobel_vs, sobel_de;
  wire [23:0] sobel_rgb;

  // 1. 实例化 3x3 行缓存窗口
  // [Ethereal注释] 子模块例化 8（sobel_line_buffer）：缓存三行灰度像素并输出 3×3 邻域，同时对齐窗口有效信号与行场同步。
  sobel_line_buffer #(
      .H_TOTAL(11'd1344)
  ) u_sobel_lb (
      .i_clk      (clk_hdmi),
      .i_rst      (sys_rst),
      .i_hs       (sobel_in_hs),
      .i_vs       (sobel_in_vs),
      .i_data_en  (sobel_in_de),
      .i_gray_data(sobel_in_Y),   // 输入灰度数据

      // 3x3 窗口输出
      .o_p11(p11),
      .o_p12(p12),
      .o_p13(p13),
      .o_p21(p21),
      .o_p22(p22),
      .o_p23(p23),
      .o_p31(p31),
      .o_p32(p32),
      .o_p33(p33),

      // 窗口对齐的时序
      .o_hs     (sobel_lb_hs),
      .o_vs     (sobel_lb_vs),
      .o_data_en(sobel_lb_de)
  );

  // 2. 实例化 Sobel 计算模块
  // [Ethereal注释] 子模块例化 9（sobel_calc）：计算 Sobel 水平与垂直梯度，依据阈值生成二值边缘图。
  sobel_calc u_sobel_calc (
      .clk(clk_hdmi),
      .rst(sys_rst),

      // 来自 Line Buffer 的时序和窗口
      .i_hs(sobel_lb_hs),
      .i_vs(sobel_lb_vs),
      .i_de(sobel_lb_de),
      .p11 (p11),
      .p12 (p12),
      .p13 (p13),
      .p21 (p21),
      .p22 (p22),
      .p23 (p23),
      .p31 (p31),
      .p32 (p32),
      .p33 (p33),

      // 动态阈值：复用上位机的 8 位子模式指令
      .i_threshold(8'd80),

      // 最终的二值化边缘输出
      .o_hs        (sobel_hs),
      .o_vs        (sobel_vs),
      .o_de        (sobel_de),
      .o_rgb_binary(sobel_rgb)
  );

  // 输出通道路由 (MUX)：保证各模式下时序绝对安全对齐
  // [Ethereal注释] 时序过程 2：由 clk_hdmi posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk_hdmi) begin
    // [Ethereal注释] 分支选择 1：依据 al_main_hdmi 选择状态或算法路径；default 覆盖非法或空闲条件。
    case (al_main_hdmi)
      4'd0: begin  // 原图直出
        final_hs  <= sync_ycbcr_hs;
        final_vs  <= sync_ycbcr_vs;
        final_de  <= sync_ycbcr_de;
        final_rgb <= sync_ycbcr_de ? sync_raw_rgb_ycbcr : 24'd0;
      end

      4'd1: begin
        final_hs <= sync_ycbcr_hs;
        final_vs <= sync_ycbcr_vs;
        final_de <= sync_ycbcr_de;
        final_rgb <= sync_ycbcr_de ? (al_sub_hdmi == 8'd1 ? {algo_Y, algo_Y, algo_Y} : sync_raw_rgb_ycbcr) : 24'd0;
      end  // 色域转换 (提取灰度)


      4'd2: begin  // HSV肤色 (时序走HSV通道)
        final_hs  <= sync_hsv_hs;
        final_vs  <= sync_hsv_vs;
        final_de  <= sync_hsv_de;
        final_rgb <= sync_hsv_de ? (is_skin ? 24'hFFFFFF : 24'h000000) : 24'd0;
      end

      4'd3, 4'd5: begin
        final_hs  <= sync_ycbcr_hs;
        final_vs  <= sync_ycbcr_vs;
        final_de  <= sync_ycbcr_de;
        // 缩放缩小、旋转模式 (图像在前端BRAM和SDRAM已处理，这里直接透传)
        final_rgb <= sync_ycbcr_de ? sync_raw_rgb_ycbcr : 24'd0;

      end
      4'd4: begin  // 缩放放大 (走平滑滤波通道抗锯齿)
        final_hs  <= smooth_hs;
        final_vs  <= smooth_vs;
        final_de  <= smooth_de;
        final_rgb <= smooth_de ? smooth_rgb : 24'd0;
      end

      4'd6: begin  // 直方图
        final_hs  <= equ_hs;
        final_vs  <= equ_vs;
        final_de  <= equ_de;
        final_rgb <= equ_de ? {equ_Y, equ_Y, equ_Y} : 24'd0;
      end

      4'd7: begin  // 形态学
        final_hs  <= morph_hs;
        final_vs  <= morph_vs;
        final_de  <= morph_de;
        final_rgb <= morph_de ? {morph_Y, morph_Y, morph_Y} : 24'd0;
      end

      4'd8: begin  // HDR
        final_hs  <= hdr_hs;
        final_vs  <= hdr_vs;
        final_de  <= hdr_de;
        final_rgb <= hdr_de ? hdr_rgb : 24'd0;
      end

      4'd9: begin  // 双边滤波
        final_hs  <= bil_hs;
        final_vs  <= bil_vs;
        final_de  <= bil_de;
        final_rgb <= bil_de ? bil_rgb : 24'd0;
      end

      4'd10: begin  // Sobel 边缘检测
        final_hs  <= sobel_hs;
        final_vs  <= sobel_vs;
        final_de  <= sobel_de;
        final_rgb <= sobel_de ? sobel_rgb : 24'd0;
      end

      default: begin
        final_hs  <= sync_ycbcr_hs;
        final_vs  <= sync_ycbcr_vs;
        final_de  <= sync_ycbcr_de;
        final_rgb <= 24'd0;
      end
    endcase
  end

endmodule
