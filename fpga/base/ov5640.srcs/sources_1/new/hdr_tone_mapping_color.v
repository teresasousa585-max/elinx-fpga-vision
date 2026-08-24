// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：hdr_tone_mapping_color.v
// 主要模块：hdr_tone_mapping_color
// 功能分类：图像增强算法
// 功能说明：根据亮度分量执行定点色调映射，并保持彩色信息，实现硬件 HDR 动态范围压缩。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：rgb2ycbcr.v、rom_reciprocal IP、video_algo_manager.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps
module hdr_tone_mapping_color (
    input wire clk,
    input wire rst,

    // 输入视频流
    input wire        hs,
    input wire        vsync,
    input wire        de,
    input wire [ 7:0] din_Y,   // 亮度通道
    input wire [23:0] din_rgb, // 色彩通道

    // 输出视频流
    output reg        hs_out,
    output reg        vsync_out,
    output reg        de_out,
    output reg [23:0] dout_rgb
);

  // --- 1. 全局均值计算 (保持不变) ---
  reg [35:0] frame_sum;
  reg [ 7:0] l_avg;
  reg vs_d1, vs_d2;
  wire eof = (vs_d1 && !vs_d2);

  always @(posedge clk) begin
    if (rst) begin
      vs_d1 <= 0;
      vs_d2 <= 0;
      frame_sum <= 0;
      l_avg <= 128;
    end else begin
      vs_d1 <= vsync;
      vs_d2 <= vs_d1;
      if (de) frame_sum <= frame_sum + din_Y;
      if (eof) begin
        l_avg <= (frame_sum * 36'd109) >> 26;
        frame_sum <= 0;
      end
    end
  end

  // 计算全局增益与方向
  reg [7:0] gain_val;
  reg is_dark;
  always @(posedge clk) begin
    if (l_avg < 128) begin
      is_dark  <= 1'b1;
      gain_val <= (128 - l_avg);
    end else begin
      is_dark  <= 1'b0;
      gain_val <= (l_avg - 128);
    end
  end

  // 提取各通道原值
  wire [7:0] R_in = din_rgb[23:16];
  wire [7:0] G_in = din_rgb[15:8];
  wire [7:0] B_in = din_rgb[7:0];

  // --- 同步信号与原始色彩的延迟线 (Shift Registers) ---
  // 因为流水线有6级，原始信号也要跟着走6步
  // --- 同步信号与原始色彩的延迟线 (Shift Registers) ---
  // 强制 Quartus 使用普通逻辑寄存器，不要去抢占 BRAM！
  (* ramstyle = "logic" *) reg [23:0] rgb_d1, rgb_d2, rgb_d3, rgb_d4, rgb_d5;
  (* ramstyle = "logic" *) reg hs_d1, hs_d2, hs_d3, hs_d4, hs_d5;
  (* ramstyle = "logic" *) reg de_d1, de_d2, de_d3, de_d4, de_d5;
  (* ramstyle = "logic" *) reg vs_d_sync1, vs_d_sync2, vs_d_sync3, vs_d_sync4, vs_d_sync5;
  (* ramstyle = "logic" *) reg is_dark_d1, is_dark_d2, is_dark_d3, is_dark_d4;

  always @(posedge clk) begin
    // RGB Data
    rgb_d1 <= din_rgb;
    rgb_d2 <= rgb_d1;
    rgb_d3 <= rgb_d2;
    rgb_d4 <= rgb_d3;
    rgb_d5 <= rgb_d4;
    // Syncs
    hs_d1 <= hs;
    hs_d2 <= hs_d1;
    hs_d3 <= hs_d2;
    hs_d4 <= hs_d3;
    hs_d5 <= hs_d4;
    de_d1 <= de;
    de_d2 <= de_d1;
    de_d3 <= de_d2;
    de_d4 <= de_d3;
    de_d5 <= de_d4;
    vs_d_sync1 <= vsync;
    vs_d_sync2 <= vs_d_sync1;
    vs_d_sync3 <= vs_d_sync2;
    vs_d_sync4 <= vs_d_sync3;
    vs_d_sync5 <= vs_d_sync4;
    // Dark Flag
    is_dark_d1 <= is_dark;
    is_dark_d2 <= is_dark_d1;
    is_dark_d3 <= is_dark_d2;
    is_dark_d4 <= is_dark_d3;
  end

  // ================= 核心处理 6 级流水线 =================

  // --- Pipeline Stage 1: 预计算减法 ---
  reg [7:0] inv_R, inv_G, inv_B;
  always @(posedge clk) begin
    inv_R <= 8'd255 - R_in;
    inv_G <= 8'd255 - G_in;
    inv_B <= 8'd255 - B_in;
  end

  // --- Pipeline Stage 2: 第一级乘法 (算抛物线) ---
  // Quartus 专属属性，强制使用 DSP
  (* multstyle = "dsp" *) reg [15:0] diff_mult_r, diff_mult_g, diff_mult_b;
  always @(posedge clk) begin
    diff_mult_r <= rgb_d1[23:16] * inv_R;
    diff_mult_g <= rgb_d1[15:8] * inv_G;
    diff_mult_b <= rgb_d1[7:0] * inv_B;
  end

  // --- Pipeline Stage 3: 第二级乘法 (算最终偏移) ---
  (* multstyle = "dsp" *) reg [23:0] offset_r_full, offset_g_full, offset_b_full;
  always @(posedge clk) begin
    offset_r_full <= {16'd0, gain_val} * {8'd0, diff_mult_r};
    offset_g_full <= {16'd0, gain_val} * {8'd0, diff_mult_g};
    offset_b_full <= {16'd0, gain_val} * {8'd0, diff_mult_b};
  end

  // 提取偏移量高 8 位 (相当于除以 32768)
  wire [7:0] offset_r = offset_r_full[23:15];
  wire [7:0] offset_g = offset_g_full[23:15];
  wire [7:0] offset_b = offset_b_full[23:15];

  // --- Pipeline Stage 4: 加减法 (使用 9-bit 容纳溢出位) ---
  // 最高位 [8] 用于后续 Stage 5 的饱和判断
  reg [8:0] R_sum, G_sum, B_sum;
  always @(posedge clk) begin
    if (is_dark_d3) begin  // 暗环境：做加法
      R_sum <= {1'b0, rgb_d3[23:16]} + {1'b0, offset_r};
      G_sum <= {1'b0, rgb_d3[15:8]} + {1'b0, offset_g};
      B_sum <= {1'b0, rgb_d3[7:0]} + {1'b0, offset_b};
    end else begin  // 亮环境：做减法
      R_sum <= {1'b0, rgb_d3[23:16]} - {1'b0, offset_r};
      G_sum <= {1'b0, rgb_d3[15:8]} - {1'b0, offset_g};
      B_sum <= {1'b0, rgb_d3[7:0]} - {1'b0, offset_b};
    end
  end

  // --- Pipeline Stage 5: 饱和截断逻辑 ---
  reg [7:0] R_final, G_final, B_final;
  always @(posedge clk) begin
    if (is_dark_d4) begin
      // 加法溢出判断：如果第9位为1，说明超出了255
      R_final <= R_sum[8] ? 8'd255 : R_sum[7:0];
      G_final <= G_sum[8] ? 8'd255 : G_sum[7:0];
      B_final <= B_sum[8] ? 8'd255 : B_sum[7:0];
    end else begin
      // 减法下溢判断：如果第9位为1 (借位产生负数)，强制设为0
      R_final <= R_sum[8] ? 8'd0 : R_sum[7:0];
      G_final <= G_sum[8] ? 8'd0 : G_sum[7:0];
      B_final <= B_sum[8] ? 8'd0 : B_sum[7:0];
    end
  end

  // --- Pipeline Stage 6: 数据输出 ---
  always @(posedge clk) begin
    if (rst) begin
      hs_out    <= 0;
      vsync_out <= 0;
      de_out    <= 0;
      dout_rgb  <= 0;
    end else begin
      hs_out    <= hs_d5;
      vsync_out <= vs_d_sync5;
      de_out    <= de_d5;
      if (de_d5) begin
        dout_rgb <= {R_final, G_final, B_final};
      end else begin
        dout_rgb <= 24'd0;
      end
    end
  end

endmodule
