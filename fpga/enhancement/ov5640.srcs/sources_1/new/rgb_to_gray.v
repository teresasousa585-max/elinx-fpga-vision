// =============================================================================
// 文件名称：rgb_to_gray.v
// 主要模块：rgb_to_gray
// 功能说明：将 RGB 像素转换为灰度数据。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps
// 灰度的标准公式是浮点运算：Y = 0.299*R + 0.587*G + 0.114*B。
// 但在 FPGA 里严禁使用浮点数除法，标准做法是整数乘法 + 移位（右移 8 位等于除以 256）：
// Y = (R*76 + G*150 + B*30) >> 8  (注：76+150+30=256)。

module rgb_to_gray (
    input wire clk,  // 像素时钟 (与 capture 模块同频)
    input wire rst,  // 高电平同步复位信号

    // 上游输入 (来自 ov5640_capture)
    input wire        i_data_en,
    input wire [15:0] i_rgb565,

    // 下游输出 (送往 SDRAM FIFO)
    output reg        o_data_en,
    output reg [15:0] o_gray565
);

  // 1. 拆分 RGB 通道，并补齐到 8 bit (高位复制补偿法，保证亮度不丢)
  wire [7:0] r_8 = {i_rgb565[15:11], i_rgb565[15:13]};
  wire [7:0] g_8 = {i_rgb565[10:5], i_rgb565[10:9]};
  wire [7:0] b_8 = {i_rgb565[4:0], i_rgb565[4:2]};

  // 2. 流水线第一拍：并行计算乘法
  reg [15:0] mult_r, mult_g, mult_b;
  reg en_d1;

  always @(posedge clk) begin
    if (rst) begin
      mult_g <= 16'd0;
      mult_b <= 16'd0;
      en_d1  <= 1'b0;
    end else begin
      mult_r <= r_8 * 8'd76;  // 0.299 * 256 ≈ 76
      mult_g <= g_8 * 8'd150;  // 0.587 * 256 ≈ 150
      mult_b <= b_8 * 8'd30;  // 0.114 * 256 ≈ 30
      en_d1  <= i_data_en;  // 控制信号陪跑一拍
    end
  end

  // 3. 流水线第二拍：累加、移位、并组装回 RGB565 格式
  reg [15:0] sum_y;

  // 高电平同步复位
  always @(posedge clk) begin
    if (rst) begin
      o_gray565 <= 16'd0;
      o_data_en <= 1'b0;
    end else begin
      // 累加
      sum_y = mult_r + mult_g + mult_b;

      // 右移 8 位就是除以 256，得到 8 bit 的灰度值 Y
      // 将 Y 拆分回 RGB565 格式：R=Y[7:3], G=Y[7:2], B=Y[7:3]
      o_gray565 <= {sum_y[15:11], sum_y[15:10], sum_y[15:11]};

      o_data_en <= en_d1;  // 控制信号再跑一拍，与数据严格对齐输出
    end
  end

endmodule
