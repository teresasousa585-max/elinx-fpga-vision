// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：gesture_recognition.v
// 主要模块：gesture_recognition
// 功能分类：目标识别算法
// 功能说明：对颜色阈值结果进行邻域处理和区域判断，输出手势候选区域及同步视频流。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：rgb2hsv.v、gray_morphology.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 正文导读：对颜色阈值结果进行邻域处理和区域判断，输出手势候选区域及同步视频流。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 gesture_recognition：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module gesture_recognition #(
    // 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter H_ACTIVE  = 1024,
    parameter V_ACTIVE  = 600,
    parameter ROI_X_MIN = 300,
    parameter ROI_X_MAX = 724,
    parameter ROI_Y_MIN = 100,
    parameter ROI_Y_MAX = 500
) (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire clk,
    input wire rst_n,

    input wire        i_vsync,
    input wire        i_hsync,  // 接收原始行同步
    input wire        i_de,
    input wire [23:0] i_ycbcr,

    output reg [ 2:0] o_gesture_id,
    output reg [11:0] o_center_x,
    output reg [11:0] o_center_y,

    output wire o_final_vs,  // 与最终数据准确对齐的场同步
    output wire o_final_hs,  // 与最终数据准确对齐的行同步
    output wire o_final_de,  // 与最终数据准确对齐的数据有效信号

    output wire o_roi_bw_de,
    output wire o_roi_bw_data
);

  // =======================================================
  // 1. 轻量化预处理 (第一级严格打拍)
  // =======================================================
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg bw_q;
  reg vs_d1, hs_d1, de_d1;

  // 时序过程 1：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    // 数据打一拍
    bw_q  <= (i_ycbcr[23:16] > 8'd45);

    // 关键：时序信号必须跟着打一拍！保证进入形态学前绝对对齐
    vs_d1 <= i_vsync;
    hs_d1 <= i_hsync;
    de_d1 <= i_de;
  end

  // =======================================================
  // 2. 级联形态学 (消耗多行+多拍延迟，信号由模块内部自动对齐)
  // =======================================================
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire vs_e, hs_e, de_e;
  wire [7:0] data_e;
  // 子模块例化 1（gray_morphology）：在灰度 3×3 邻域上按子模式执行腐蚀或膨胀，用于目标区域去噪与结构增强。
  gray_morphology #(
      .H_DISP(H_ACTIVE)
  ) m_erode (
      .clk(clk),
      .rst(!rst_n),
      .mode(1'b0),
      .vs_in(vs_d1),
      .hs_in(hs_d1),
      .de_in(de_d1),
      .data_in(bw_q ? 8'hFF : 8'h00),
      .vs_out(vs_e),
      .hs_out(hs_e),
      .de_out(de_e),
      .data_out(data_e)
  );

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire vs_m, hs_m, de_m;
  wire [7:0] data_m;
  // 子模块例化 2（gray_morphology）：在灰度 3×3 邻域上按子模式执行腐蚀或膨胀，用于目标区域去噪与结构增强。
  gray_morphology #(
      .H_DISP(H_ACTIVE)
  ) m_dilate (
      .clk(clk),
      .rst(!rst_n),
      .mode(1'b1),
      .vs_in(vs_e),
      .hs_in(hs_e),
      .de_in(de_e),
      .data_in(data_e),
      .vs_out(vs_m),
      .hs_out(hs_m),
      .de_out(de_m),
      .data_out(data_m)
  );

  // =======================================================
  // 3. 后续逻辑与最终输出 (第二级严格打拍)
  // =======================================================
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg data_m_d;

  // 声明最终输出的寄存器
  reg final_bw_data_reg;
  reg final_vs_reg, final_hs_reg, final_de_reg;

  // 时序过程 2：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    data_m_d <= (data_m > 128);

    // 边缘检测：采用寄存器输出，消灭组合逻辑毛刺，产生 1 拍延迟
    final_bw_data_reg <= (data_m > 128) && !data_m_d;

    // 关键：既然数据又延迟了一拍，最终的同步信号必须继续跟着打拍！
    final_vs_reg <= vs_m;
    final_hs_reg <= hs_m;
    final_de_reg <= de_m;
  end

  // 将完全同步的寄存器值连到输出端口
  // 组合连线组 1：从 o_final_vs 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_final_vs    = final_vs_reg;
  assign o_final_hs    = final_hs_reg;
  assign o_final_de    = final_de_reg;

  assign o_roi_bw_data = final_bw_data_reg;
  assign o_roi_bw_de   = final_de_reg;

  // =======================================================
  // 4. 积分面积统计与特征判别 (保持原样，这部分仅做统计不输出图像)
  // =======================================================
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [11:0] px, py;
  reg vs_md;
  // 时序过程 3：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    vs_md <= vs_m;
    if (vs_m && !vs_md) begin
      px <= 0;
      py <= 0;
    end else if (de_m) begin
      if (px == H_ACTIVE - 1) begin
        px <= 0;
        py <= py + 1;
      end else px <= px + 1;
    end
  end

  // 垂直与水平积分
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [9:0] v_sum[0:1023];
  reg [9:0] v_val, h_val;
  // 时序过程 4：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (de_m) begin
      v_val <= (data_m > 128) ? (v_sum[px] + 1'b1) : 10'd0;
      v_sum[px] <= (data_m > 128) ? (v_sum[px] + 1'b1) : 10'd0;
      h_val <= (data_m > 128) ? (h_val + 1'b1) : 10'd0;
    end
  end

  // 特征统计
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [11:0] xmin, xmax, ymin, ymax;
  reg [23:0] cnt, l_cnt;
  // 时序过程 5：由 clk posedge，rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      xmin <= 1023;
      xmax <= 0;
      ymin <= 599;
      ymax <= 0;
      cnt  <= 0;
    end else if (vs_m && !vs_md) begin
      l_cnt <= cnt;
      o_center_x <= (xmin + xmax) >> 1;
      o_center_y <= (ymin + ymax) >> 1;
      xmin <= 1023;
      xmax <= 0;
      ymin <= 599;
      ymax <= 0;
      cnt <= 0;
    end else if (de_m && data_m > 128) begin
      if (px < xmin) xmin <= px;
      if (px > xmax) xmax <= px;
      if (py < ymin) ymin <= py;
      if (py > ymax) ymax <= py;
      cnt <= cnt + 1;
    end
  end

  // 面积判别与平滑
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [11:0] sy = ymin + ((ymax > ymin) ? ((ymax - ymin) >> 2) : 0);
  wire [11:0] sx = xmin + ((xmax > xmin) ? ((xmax - xmin) >> 1) : 0);

  reg [2:0] fch, fcv, gest, h1, h2;
  reg ih, iv;
  reg [19:0] ah, av, max_ah, max_av;

  // 时序过程 6：由 clk posedge，rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {fch, fcv, ih, iv, ah, av, max_ah, max_av, o_gesture_id, h1, h2} <= 0;
    end else if (vs_m && !vs_md) begin
      {fch, fcv, ih, iv, ah, av, max_ah, max_av} <= 0;
      gest = (fch > fcv) ? fch : fcv;
      if (gest == 1 && (max_ah > (l_cnt >> 1) || max_av > (l_cnt >> 1))) gest = 0;
      if (l_cnt > 2000) begin
        h1 <= gest;
        h2 <= h1;
        if (gest == h1 && h1 == h2) o_gesture_id <= gest;
      end else o_gesture_id <= 0;
    end else if (de_m) begin
      if (py == sy) begin
        if (data_m > 128) begin
          ih <= 1;
          ah <= ah + v_val;
        end else if (ih) begin
          if (ah > (l_cnt >> 5)) begin
            fch <= fch + 1;
            if (ah > max_ah) max_ah <= ah;
          end
          ih <= 0;
          ah <= 0;
        end
      end
      if (px == sx) begin
        if (data_m > 128) begin
          iv <= 1;
          av <= av + h_val;
        end else if (iv) begin
          if (av > (l_cnt >> 5)) begin
            fcv <= fcv + 1;
            if (av > max_av) max_av <= av;
          end
          iv <= 0;
          av <= 0;
        end
      end
    end
  end

endmodule
