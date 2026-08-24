// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：meiyan_bilateral_core.v
// 主要模块：meiyan_bilateral_core
// 功能分类：磨皮美颜算法
// 功能说明：对肤色/亮度数据执行保边双边平滑，为磨皮融合提供去噪结果。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：bilateral_filtering_Line_buffer_1.v、meiyan_rebuild.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：对肤色/亮度数据执行保边双边平滑，为磨皮融合提供去噪结果。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 meiyan_bilateral_core：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module meiyan_bilateral_core #(
    // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter NORM_SHIFT = 25 // 根据实际情况微调
)(
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire        i_clk,
    input  wire        i_rst,
    
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_data_en,
    
    input  wire [23:0] i_p11, i_p12, i_p13,
    input  wire [23:0] i_p21, i_p22, i_p23,
    input  wire [23:0] i_p31, i_p32, i_p33,
    
    output wire        o_hs,
    output wire        o_vs,
    output wire        o_data_en,
    output wire [23:0] o_ycbcr_filtered
);

    // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    localparam [7:0] W_SP_CENTER = 8'd128;
    localparam [7:0] W_SP_EDGE   = 8'd78;
    localparam [7:0] W_SP_CORNER = 8'd47;

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [7:0] y11 = i_p11[23:16]; wire [7:0] y12 = i_p12[23:16]; wire [7:0] y13 = i_p13[23:16];
    wire [7:0] y21 = i_p21[23:16]; wire [7:0] y22 = i_p22[23:16]; wire [7:0] y23 = i_p23[23:16];
    wire [7:0] y31 = i_p31[23:16]; wire [7:0] y32 = i_p32[23:16]; wire [7:0] y33 = i_p33[23:16];

    wire hidden_mask = i_p22[8]; 
    
    // ==========================================
    // 旁路信号：被 RAM IP 强制延迟 16 拍
    // ==========================================
    // 1. 打包：高位补 4 个 0，硬凑成标准的 32 位
    wire [31:0] packet_in = {4'd0, hidden_mask, i_hs, i_vs, i_data_en, i_p22[15:0], y22};
    wire [31:0] packet_out;

    // 2. 实例化 16 拍深度的 RAM 移位寄存器
    // [Ethereal注释] 子模块例化 1（shift_delay_32w_16d）：封装移位寄存器 IP，为像素、系数或同步信号提供固定拍数延迟。
    shift_delay_32w_16d u_16_cycles_delay (
        .clock    (i_clk),
        .shiftin  (packet_in),
        .shiftout (packet_out),
        .taps     ()
    );

    // 3. 解包：提取出我们在 T16 需要用到的 28 位原数据
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [27:0] delay_16_val = packet_out[27:0];

    // ==========================================
    // T1 - T8 : 绝对差值与权重查表
    // ==========================================
    reg [7:0] d11, d12, d13, d21, d23, d31, d32, d33;
    reg [7:0] y11_d1, y12_d1, y13_d1, y21_d1, y22_d1, y23_d1, y31_d1, y32_d1, y33_d1;
    // [Ethereal注释] 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        d11 <= (y11 > y22) ? (y11 - y22) : (y22 - y11); d12 <= (y12 > y22) ? (y12 - y22) : (y22 - y12);
        d13 <= (y13 > y22) ? (y13 - y22) : (y22 - y13); d21 <= (y21 > y22) ? (y21 - y22) : (y22 - y21);
        d23 <= (y23 > y22) ? (y23 - y22) : (y22 - y23); d31 <= (y31 > y22) ? (y31 - y22) : (y22 - y31);
        d32 <= (y32 > y22) ? (y32 - y22) : (y22 - y32); d33 <= (y33 > y22) ? (y33 - y22) : (y22 - y33);
        {y11_d1,y12_d1,y13_d1, y21_d1,y22_d1,y23_d1, y31_d1,y32_d1,y33_d1} <= {y11, y12, y13, y21, y22, y23, y31, y32, y33};
    end

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg[7:0] d11_w, d12_w, d13_w, d21_w, d23_w, d31_w, d32_w, d33_w;
    reg [7:0] y11_d2, y12_d2, y13_d2, y21_d2, y22_d2, y23_d2, y31_d2, y32_d2, y33_d2;
    // [Ethereal注释] 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        d11_w <= d11; d12_w <= d12; d13_w <= d13; d21_w <= d21;
        d23_w <= d23; d31_w <= d31; d32_w <= d32; d33_w <= d33;
        {y11_d2,y12_d2,y13_d2, y21_d2,y22_d2,y23_d2, y31_d2,y32_d2,y33_d2} <= {y11_d1,y12_d1,y13_d1, y21_d1,y22_d1,y23_d1, y31_d1,y32_d1,y33_d1};
    end

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [7:0] wr11_w, wr12_w, wr13_w, wr21_w, wr23_w, wr31_w, wr32_w, wr33_w;
    reg [7:0] wr22_w; 
    reg [7:0] wr11, wr12, wr13, wr21, wr22, wr23, wr31, wr32, wr33;
    // [Ethereal注释] 子模块例化 2（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r11 (.address(d11_w), .clock(i_clk), .q(wr11_w));
    // [Ethereal注释] 子模块例化 3（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r12 (.address(d12_w), .clock(i_clk), .q(wr12_w));
    // [Ethereal注释] 子模块例化 4（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r13 (.address(d13_w), .clock(i_clk), .q(wr13_w)); 
    // [Ethereal注释] 子模块例化 5（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r21 (.address(d21_w), .clock(i_clk), .q(wr21_w));
    // [Ethereal注释] 子模块例化 6（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r23 (.address(d23_w), .clock(i_clk), .q(wr23_w)); 
    // [Ethereal注释] 子模块例化 7（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r31 (.address(d31_w), .clock(i_clk), .q(wr31_w));
    // [Ethereal注释] 子模块例化 8（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r32 (.address(d32_w), .clock(i_clk), .q(wr32_w)); 
    // [Ethereal注释] 子模块例化 9（rom_8_256）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_8_256 u_r33 (.address(d33_w), .clock(i_clk), .q(wr33_w));
    
    // [Ethereal注释] 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) wr22_w <= 8'd255; 
    
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [7:0] y11_d3, y12_d3, y13_d3, y21_d3, y22_d3, y23_d3, y31_d3, y32_d3, y33_d3;
    reg [7:0] y11_d4, y12_d4, y13_d4, y21_d4, y22_d4, y23_d4, y31_d4, y32_d4, y33_d4;
    // [Ethereal注释] 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        wr11 <= wr11_w; wr12 <= wr12_w; wr13 <= wr13_w; wr21 <= wr21_w; wr22 <= wr22_w; wr23 <= wr23_w;
        wr31 <= wr31_w; wr32 <= wr32_w; wr33 <= wr33_w;
        {y11_d3,y12_d3,y13_d3, y21_d3,y22_d3,y23_d3, y31_d3,y32_d3,y33_d3} <= {y11_d2,y12_d2,y13_d2, y21_d2,y22_d2,y23_d2, y31_d2,y32_d2,y33_d2};
        {y11_d4,y12_d4,y13_d4, y21_d4,y22_d4,y23_d4, y31_d4,y32_d4,y33_d4} <= {y11_d3,y12_d3,y13_d3, y21_d3,y22_d3,y23_d3, y31_d3,y32_d3,y33_d3};
    end

    // 权重计算乘法器 IP (1拍延迟)
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [15:0] wt11, wt12, wt13, wt21, wt22, wt23, wt31, wt32, wt33;
    reg [7:0]  y11_d5, y12_d5, y13_d5, y21_d5, y22_d5, y23_d5, y31_d5, y32_d5, y33_d5;
    
    // [Ethereal注释] 子模块例化 10（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt11 (.clock(i_clk), .dataa(wr11), .datab(W_SP_CORNER), .result(wt11));
    // [Ethereal注释] 子模块例化 11（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt12 (.clock(i_clk), .dataa(wr12), .datab(W_SP_EDGE),   .result(wt12));
    // [Ethereal注释] 子模块例化 12（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt13 (.clock(i_clk), .dataa(wr13), .datab(W_SP_CORNER), .result(wt13));
    // [Ethereal注释] 子模块例化 13（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt21 (.clock(i_clk), .dataa(wr21), .datab(W_SP_EDGE),   .result(wt21));
    // [Ethereal注释] 子模块例化 14（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt22 (.clock(i_clk), .dataa(wr22), .datab(W_SP_CENTER), .result(wt22));
    // [Ethereal注释] 子模块例化 15（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt23 (.clock(i_clk), .dataa(wr23), .datab(W_SP_EDGE),   .result(wt23));
    // [Ethereal注释] 子模块例化 16（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt31 (.clock(i_clk), .dataa(wr31), .datab(W_SP_CORNER), .result(wt31));
    // [Ethereal注释] 子模块例化 17（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt32 (.clock(i_clk), .dataa(wr32), .datab(W_SP_EDGE),   .result(wt32));
    // [Ethereal注释] 子模块例化 18（lpmmult_8_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_8_8 u_wt33 (.clock(i_clk), .dataa(wr33), .datab(W_SP_CORNER), .result(wt33));
    
    // [Ethereal注释] 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        {y11_d5,y12_d5,y13_d5, y21_d5,y22_d5,y23_d5, y31_d5,y32_d5,y33_d5} <= {y11_d4,y12_d4,y13_d4, y21_d4,y22_d4,y23_d4, y31_d4,y32_d4,y33_d4};
    end

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [15:0]  wt11_r, wt12_r, wt13_r, wt21_r, wt22_r, wt23_r, wt31_r, wt32_r, wt33_r;
    reg [7:0]  y11_d6, y12_d6, y13_d6, y21_d6, y22_d6, y23_d6, y31_d6, y32_d6, y33_d6;
    // [Ethereal注释] 时序过程 6：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        wt11_r <= wt11; wt12_r <= wt12; wt13_r <= wt13; wt21_r <= wt21; wt22_r <= wt22; wt23_r <= wt23;
        wt31_r <= wt31; wt32_r <= wt32; wt33_r <= wt33;
        {y11_d6,y12_d6,y13_d6, y21_d6,y22_d6,y23_d6, y31_d6,y32_d6,y33_d6} <= {y11_d5,y12_d5,y13_d5, y21_d5,y22_d5,y23_d5, y31_d5,y32_d5,y33_d5};
    end

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [23:0] pwt11, pwt12, pwt13, pwt21, pwt22, pwt23, pwt31, pwt32, pwt33;
    reg [17:0] w_sum_l1_1, w_sum_l1_2, w_sum_l1_3;
    
    // 像素加权乘法器 IP (1拍延迟)
    // [Ethereal注释] 子模块例化 19（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt11 (.clock(i_clk), .dataa(wt11_r), .datab(y11_d6), .result(pwt11));
    // [Ethereal注释] 子模块例化 20（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt12 (.clock(i_clk), .dataa(wt12_r), .datab(y12_d6), .result(pwt12));
    // [Ethereal注释] 子模块例化 21（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt13 (.clock(i_clk), .dataa(wt13_r), .datab(y13_d6), .result(pwt13));
    // [Ethereal注释] 子模块例化 22（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt21 (.clock(i_clk), .dataa(wt21_r), .datab(y21_d6), .result(pwt21));
    // [Ethereal注释] 子模块例化 23（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt22 (.clock(i_clk), .dataa(wt22_r), .datab(y22_d6), .result(pwt22));
    // [Ethereal注释] 子模块例化 24（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt23 (.clock(i_clk), .dataa(wt23_r), .datab(y23_d6), .result(pwt23));
    // [Ethereal注释] 子模块例化 25（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt31 (.clock(i_clk), .dataa(wt31_r), .datab(y31_d6), .result(pwt31));
    // [Ethereal注释] 子模块例化 26（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt32 (.clock(i_clk), .dataa(wt32_r), .datab(y32_d6), .result(pwt32));
    // [Ethereal注释] 子模块例化 27（lpmmult_16_8）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_16_8 u_pwt33 (.clock(i_clk), .dataa(wt33_r), .datab(y33_d6), .result(pwt33));
    
    // [Ethereal注释] 时序过程 7：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        w_sum_l1_1 <= wt11_r + wt12_r + wt13_r;
        w_sum_l1_2 <= wt21_r + wt22_r + wt23_r;
        w_sum_l1_3 <= wt31_r + wt32_r + wt33_r;
    end

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [23:0] pwt11_r, pwt12_r, pwt13_r, pwt21_r, pwt22_r, pwt23_r, pwt31_r, pwt32_r, pwt33_r;
    reg [17:0] w_sum_l1_1_r, w_sum_l1_2_r, w_sum_l1_3_r;
    // [Ethereal注释] 时序过程 8：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
       {pwt11_r, pwt12_r, pwt13_r, pwt21_r, pwt22_r, pwt23_r, pwt31_r, pwt32_r, pwt33_r}<={pwt11, pwt12, pwt13, pwt21, pwt22, pwt23, pwt31, pwt32, pwt33};
       {w_sum_l1_1_r, w_sum_l1_2_r, w_sum_l1_3_r}<={w_sum_l1_1, w_sum_l1_2, w_sum_l1_3};
    end

    // T9 & 10: 加法树累加
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [25:0] p_sum_l1_1, p_sum_l1_2, p_sum_l1_3;
    reg [18:0] w_sum_l2;
    reg [17:0] w_sum_l1_3_rr; 
    reg [27:0] p_sum_final; 
    reg [19:0] w_sum_final; 

    // [Ethereal注释] 时序过程 9：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        // T9
        p_sum_l1_1 <= pwt11_r + pwt12_r + pwt13_r;
        p_sum_l1_2 <= pwt21_r + pwt22_r+ pwt23_r;
        p_sum_l1_3 <= pwt31_r + pwt32_r+ pwt33_r;
        w_sum_l2   <= w_sum_l1_1_r + w_sum_l1_2_r;
        w_sum_l1_3_rr <= w_sum_l1_3_r; 
        
        // T10
        p_sum_final <= p_sum_l1_1 + p_sum_l1_2 + p_sum_l1_3;
        w_sum_final <= w_sum_l2 + w_sum_l1_3_rr; 
    end

    // T11: 倒数 ROM 查表 (1拍延迟)
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [11:0] rec_addr = (w_sum_final+128)>>8;
    wire [17:0] inv_w_w; 
    // [Ethereal注释] 子模块例化 28（meiyan_rom_reciprocal）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    meiyan_rom_reciprocal u_reciprocal (.address(rec_addr), .clock(i_clk), .q(inv_w_w));

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [27:0] p_sum_final_d1;
    // [Ethereal注释] 时序过程 10：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin    
        p_sum_final_d1 <= p_sum_final;   
    end
    
    // ==========================================
    // T12: 超大位宽乘法器 IP 核 (28位 × 18位, 1拍延迟)
    // ==========================================
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [45:0] norm_mult_reg; 
    
    // [Ethereal注释] 子模块例化 29（lpmmult_28_18）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_28_18 u_norm_mult_super (
        .clock  (i_clk),
        .dataa  (p_sum_final_d1),  // 28-bit
        .datab  (inv_w_w),         // 18-bit
        .result (norm_mult_reg)    // 46-bit
    );
    
    // ==========================================
    // T13: 防爆移位与钳位 (此时计算只花费了 13 拍)
    // ==========================================
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [7:0] y_out;
    wire [45:0] shifted_val = norm_mult_reg >> NORM_SHIFT;

    // [Ethereal注释] 时序过程 11：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (shifted_val > 46'd255) begin
            y_out <= 8'd255;  
        end else begin
            y_out <= shifted_val[7:0]; 
        end
    end

    // ==========================================
    // T14, T15, T16: ★陪跑等候室★
    // 让 y_out 手动多等 3 拍，准确对齐 16 拍的旁路信号！
    // ==========================================
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [7:0] y_out_d1, y_out_d2, y_out_d3;
    // [Ethereal注释] 时序过程 12：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        y_out_d1 <= y_out;
        y_out_d2 <= y_out_d1;
        y_out_d3 <= y_out_d2; // 在第 16 拍准备就绪
    end

    // ==========================================
    // T17: 提取第 16 拍的数据并拼接
    // ==========================================
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [23:0] o_data;
    reg ohs, ovs, ode;

    // [Ethereal注释] 时序过程 13：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_data <= 24'd0;
            {ohs, ovs, ode} <= 3'd0;
        end else begin
            // 直接读取从 RAM IP 解包出来的第 16 拍旁路信号
            if (delay_16_val[24] == 1'b0) begin  // i_data_en
                o_data <= 24'd0; 
            end else begin
                if (delay_16_val[27] == 1'b1) begin // hidden_mask
                    // 使用打满 3 拍对齐后的 y_out_d3
                    o_data <= {y_out_d3, delay_16_val[23:8]}; 
                end else begin
                    o_data <= {delay_16_val[7:0], delay_16_val[23:8]}; 
                end
            end
            
            ohs <= delay_16_val[26];
            ovs <= delay_16_val[25];
            ode <= delay_16_val[24];
        end
    end

    // [Ethereal注释] 组合连线组 1：从 o_hs 开始的连续赋值随右值立即更新，不增加寄存器延迟。
    assign o_hs        = ohs;
    assign o_vs        = ovs;
    assign o_data_en   = ode;
    assign o_ycbcr_filtered = o_data;

endmodule