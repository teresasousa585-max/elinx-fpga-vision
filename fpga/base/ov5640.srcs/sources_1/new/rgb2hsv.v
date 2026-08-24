// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：rgb2hsv.v
// 主要模块：rgb2hsv
// 功能分类：颜色空间转换
// 功能说明：完成 RGB 到 HSV 的定点转换，为肤色区域识别等基于色调和饱和度的处理提供数据。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：video_algo_manager.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
// HSV 模型（Hue 色相, Saturation 饱和度, Value 亮度）比 RGB 更接近人类视觉对颜色的感知

`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 正文导读：完成 RGB 到 HSV 的定点转换，为肤色区域识别等基于色调和饱和度的处理提供数据。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 rgb2hsv：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module rgb2hsv (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire clk,
    input wire rst,

    input wire        i_hs,
    input wire        i_vs,
    input wire        i_de,
    input wire [23:0] i_rgb,

    output reg        o_hs,
    output reg        o_vs,
    output reg        o_de,
    output reg [23:0] o_hsv,
    output reg [23:0] o_raw_rgb
);

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] r = i_rgb[23:16];
  wire [7:0] g = i_rgb[15:8];
  wire [7:0] b = i_rgb[7:0];


  // 全局同步信号伴随延迟线 ( 11 拍)
  // 因为：极值计算(1) + 分子准备(1) + IP核除法(8) + 输出锁存(1) = 11
  // 定义 11 位宽的移位寄存器，用于存储每一拍的同步状态

  reg [10:0] hs_d, vs_d, de_d;
  // 定义二维数组，用于存储原图 RGB
  reg [23:0] raw_rgb_d[10:0];

  integer k;
  // 时序过程 1：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    // 将输入信号推入移位寄存器的最低位，其余位左移
    hs_d <= {hs_d[9:0], i_hs};
    vs_d <= {vs_d[9:0], i_vs};
    de_d <= {de_d[9:0], i_de};

    // RGB 数据的延迟线处理
    raw_rgb_d[0] <= i_rgb;
    for (k = 1; k <= 10; k = k + 1) begin
      raw_rgb_d[k] <= raw_rgb_d[k-1];
    end
  end

  // 第 1 级：求极值 MAX, MIN 和差值 Delta
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] max_rg = (r > g) ? r : g;
  wire [7:0] max_rgb = (max_rg > b) ? max_rg : b;
  wire [7:0] min_rg = (r < g) ? r : g;
  wire [7:0] min_rgb = (min_rg < b) ? min_rg : b;

  reg [7:0] max_val, delta, r_d1, g_d1, b_d1;

  // 时序过程 2：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    max_val <= max_rgb;
    delta <= max_rgb - min_rgb;
    r_d1 <= r;
    g_d1 <= g;
    b_d1 <= b;
  end

  // 第 2 级：准备 IP 核需要的分子 (Numerator)
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [15:0] s_num, h_num;
  reg [7:0] h_offset;
  reg       h_sign;
  reg [7:0] v_d2;

  // 时序过程 3：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    v_d2  <= max_val;
    s_num <= delta * 8'd255;

    if (delta == 0) begin
      h_num <= 0;
      h_offset <= 0;
      h_sign <= 0;
    end else if (max_val == r_d1) begin
      h_offset <= (g_d1 >= b_d1) ? 8'd0 : 8'd255;
      h_sign   <= (g_d1 >= b_d1) ? 1'b0 : 1'b1;
      h_num    <= (g_d1 >= b_d1) ? ((g_d1 - b_d1) * 8'd43) : ((b_d1 - g_d1) * 8'd43);
    end else if (max_val == g_d1) begin
      h_offset <= 8'd85;
      h_sign   <= (b_d1 >= r_d1) ? 1'b0 : 1'b1;
      h_num    <= (b_d1 >= r_d1) ? ((b_d1 - r_d1) * 8'd43) : ((r_d1 - b_d1) * 8'd43);
    end else begin
      h_offset <= 8'd171;
      h_sign   <= (r_d1 >= g_d1) ? 1'b0 : 1'b1;
      h_num    <= (r_d1 >= g_d1) ? ((r_d1 - g_d1) * 8'd43) : ((g_d1 - r_d1) * 8'd43);
    end
  end


  // 第 3~10 级：IP 核除法运算 (耗时 8 拍)
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [15:0] s_quo, h_quo;

  // 调用除法 IP 核 
  // 子模块例化 1（hsv_divide）：封装定点除法器 IP，输出商与余数供颜色空间转换使用。
  hsv_divide u_div_s (
      .clock   (clk),
      .numer   (s_num),
      .denom   (v_d2 == 0 ? 8'd1 : v_d2),  // 防止分母为 0 导致 IP 核异常
      .quotient(s_quo),
      .remain  ()
  );

  // 子模块例化 2（hsv_divide）：封装定点除法器 IP，输出商与余数供颜色空间转换使用。
  hsv_divide u_div_h (
      .clock   (clk),
      .numer   (h_num),
      .denom   (delta == 0 ? 8'd1 : delta),  // 防止分母为 0
      .quotient(h_quo),
      .remain  ()
  );

  // 除法器在算的这 8 拍里，V、h_offset、h_sign 也必须打 8 拍跟着一起走
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg     [7:0] v_delay       [7:0];
  reg     [7:0] h_offset_delay[7:0];
  reg           h_sign_delay  [7:0];

  integer       j;
  // 时序过程 4：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    v_delay[0] <= v_d2;
    h_offset_delay[0] <= h_offset;
    h_sign_delay[0] <= h_sign;
    for (j = 1; j < 8; j = j + 1) begin
      v_delay[j] <= v_delay[j-1];
      h_offset_delay[j] <= h_offset_delay[j-1];
      h_sign_delay[j] <= h_sign_delay[j-1];
    end
  end


  // 第 11 级：合并输出
  // 时序过程 5：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      o_hs <= 0;
      o_vs <= 0;
      o_de <= 0;
      o_raw_rgb <= 0;
      o_hsv <= 0;
    end else begin
      // 取出伴随了 10 拍的时序和原图 (第 11 拍输出)
      o_hs        <= hs_d[9];
      o_vs        <= vs_d[9];
      o_de        <= de_d[9];
      o_raw_rgb   <= raw_rgb_d[9];

      // 取出伴随了 8 拍的保留变量
      o_hsv[7:0]  <= v_delay[7];  // V = 亮度
      o_hsv[15:8] <= s_quo[7:0];  // S = 饱和度 (IP核输出的低8位)

      // H = 根据符号进行加减
      if (h_sign_delay[7]) o_hsv[23:16] <= h_offset_delay[7] - h_quo[7:0];
      else o_hsv[23:16] <= h_offset_delay[7] + h_quo[7:0];
    end
  end

endmodule
