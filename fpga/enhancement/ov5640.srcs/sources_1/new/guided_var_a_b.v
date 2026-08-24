// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：guided_var_a_b.v
// 主要模块：guided_var_a_b
// 功能分类：引导滤波算法
// 功能说明：根据局部统计量计算引导滤波线性系数 a、b。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_line_buffer.v、box_filter_ab.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：根据局部统计量计算引导滤波线性系数 a、b。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 guided_var_a_b：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module guided_var_a_b #(
    // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter EPSILON = 16'd1000  // 平滑强度控制参数
)(
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire        i_clk,
    input  wire        i_rst,
    
    // 来自box_filter_y 的输入
    input  wire [11:0] i_mean_Y,     // 8-bit 的滤波结果扩展
    input  wire [23:0] i_mean_Y2,    // 16-bit 的平方滤波结果扩展
    
    // 中心点旁路对齐信号
    input  wire [23:0] i_ycbcr_sync,
    input  wire [23:0] i_rgb,        // RGB 原数据旁路
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    
    // 输出算好的 a 和 b 
    output wire [11:0] o_a_val,
    output wire [11:0] o_b_val,
    
    // 继续往下传的对齐信号
    output wire [23:0] o_ycbcr_out,
    output wire [23:0] o_rgb,        // RGB 原数据旁路输出
    output wire        o_hs_out,
    output wire        o_vs_out,
    output wire        o_de_out
);

    // T1: 乘法器求 mean_Y 的平方 
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [23:0] mean_y_sq;
    // [Ethereal注释] 子模块例化 1（lpmmult_12_12）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_12_12 u_mean_y_sq (
        .clock  (i_clk),      
        .dataa  (i_mean_Y),   
        .datab  (i_mean_Y),   
        .result (mean_y_sq)   
    );

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [23:0] mean_y_sq_d1;
    reg [23:0] mean_y2_d1, mean_y2_d2;
    reg [11:0] mean_y_d1,  mean_y_d2;

    // [Ethereal注释] 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        mean_y_sq_d1 <= mean_y_sq; 
        mean_y2_d1   <= i_mean_Y2;
        mean_y2_d2   <= mean_y2_d1;
        mean_y_d1    <= i_mean_Y;
        mean_y_d2    <= mean_y_d1;
    end

    // T2: 计算方差 var_Y = mean_Y2 - (mean_Y)^2
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [23:0] var_Y;
    reg [11:0] mean_y_d3;

    // [Ethereal注释] 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        // 防止负数下溢出导致雪花噪点
        if (mean_y2_d2 > mean_y_sq_d1)
            var_Y <= mean_y2_d2 - mean_y_sq_d1;
        else
            var_Y <= 24'd0; 
            
        mean_y_d3 <= mean_y_d2;
    end

    // T3: 计算分母 (var_Y + EPSILON)
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [15:0] den;
    reg [23:0] var_Y_d1;
    reg [11:0] mean_y_d4;
    
    // [Ethereal注释] 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        den <= var_Y[23:8] + EPSILON;
        var_Y_d1  <= var_Y;
        mean_y_d4 <= mean_y_d3;
    end

    // T4 & T5: 查倒数 ROM 表 
    // 地址超限保护，最大钳位到 4095
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [11:0] rom_addr = (den > 16'd4095) ? 12'd4095 : den[11:0]; 
    wire [17:0] inv_w_out;
    
    // [Ethereal注释] 子模块例化 2（rom_reciprocal_guided）：封装只读存储器 IP，提供算法查找表或定点运算常量。
    rom_reciprocal_guided u_recip (
        .address (rom_addr),
        .clock   (i_clk),
        .q       (inv_w_out) // 在 T5 稳定输出
    );

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [23:0] var_Y_d2;
    reg [11:0] mean_y_d5;
    // [Ethereal注释] 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        var_Y_d2  <= var_Y_d1;
        mean_y_d5 <= mean_y_d4; 
    end

    // T5 & T6: 乘法 a = var_Y * inv_w 
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [41:0] a_mult;
    // [Ethereal注释] 子模块例化 3（lpmmult_24_18）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_24_18 u_a_mult (
        .clock  (i_clk),      
        .dataa  (var_Y_d2),   
        .datab  (inv_w_out),  
        .result (a_mult)      // 在 T6 稳定输出
    );

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [11:0] a_val;
    reg [11:0] mean_y_d6, mean_y_d7;
    // [Ethereal注释] 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        mean_y_d6 <= mean_y_d5;
        // T7: 从 42 位结果中截取 12 位定点数，并严格钳位防溢出
        a_val <= (a_mult[41:32] > 0) ? 12'd4095 : ((a_mult[31:20] > 12'd4095) ? 12'd4095 : a_mult[31:20]);
        mean_y_d7 <= mean_y_d6;
    end

    // T7 & T8: 乘法 a * mean_Y (IP核，1拍延迟)
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [23:0] a_mean_mult;
    // [Ethereal注释] 子模块例化 4（lpmmult_12_12）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_12_12 u_a_mean_mult (
        .clock  (i_clk),      
        .dataa  (a_val),      
        .datab  (mean_y_d7),  
        .result (a_mean_mult) // 在 T8 稳定输出
    );

    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [11:0] b_val;
    reg [11:0] mean_y_d8;
    reg [11:0] a_val_d1;
    // [Ethereal注释] 时序过程 6：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        mean_y_d8 <= mean_y_d7;
        a_val_d1  <= a_val;
        
        // T8: 计算 b = mean_Y - (a * mean_Y)
        if(mean_y_d8 >= a_mean_mult[23:12])
            b_val <= mean_y_d8 - a_mean_mult[23:12];
        else
            b_val <= 12'd0; // 下溢强制钳位到 0
    end

    // ==========================================
    // 旁路同步信号延迟：8 拍 RAM IP + 1 拍寄存器
    // ==========================================
    // 拼装：{13'd0, HS(1), VS(1), DE(1), YCbCr(24), RGB(24)} = 64 位，极限利用！
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [63:0] packed_sync_in = {
        13'd0, i_hs, i_vs, i_de, i_ycbcr_sync, i_rgb
    };
    
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [63:0] packed_sync_d8; // IP 输出的 8 拍延迟数据
    
    // 实例化 8 拍延迟的 64 位宽 RAM 移位寄存器
    // [Ethereal注释] 子模块例化 5（shift_delay_64w_8d）：封装移位寄存器 IP，为像素、系数或同步信号提供固定拍数延迟。
    shift_delay_64w_8d u_sync_delay_8 (
        .clock    (i_clk),
        .shiftin  (packed_sync_in),
        .shiftout (packed_sync_d8),
        .taps     () 
    );

    // 手动打 1 拍，凑齐 9 拍
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [63:0] packed_sync_d9;
    // [Ethereal注释] 时序过程 7：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        packed_sync_d9 <= packed_sync_d8;
    end

    // 解包提取延迟了 9 拍的数据
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [23:0] rgb_d9   = packed_sync_d9[23:0];
    wire [23:0] ycbcr_d9 = packed_sync_d9[47:24];
    wire de_d9           = packed_sync_d9[48];
    wire vs_d9           = packed_sync_d9[49];
    wire hs_d9           = packed_sync_d9[50];

    // T9: 最终打拍输出对齐
    reg [11:0] out_a, out_b;
    reg [23:0] out_ycbcr;
    reg [23:0] out_rgb;
    reg out_hs, out_vs, out_de;

    // [Ethereal注释] 时序过程 8：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        out_a     <= a_val_d1;
        out_b     <= b_val;
        
        out_ycbcr <= ycbcr_d9;
        out_rgb   <= rgb_d9;
        out_hs    <= hs_d9;
        out_vs    <= vs_d9;
        out_de    <= de_d9;
    end

    // [Ethereal注释] 组合连线组 1：从 o_a_val 开始的连续赋值随右值立即更新，不增加寄存器延迟。
    assign o_a_val     = out_a;
    assign o_b_val     = out_b;
    assign o_ycbcr_out = out_ycbcr;
    assign o_rgb       = out_rgb;
    assign o_hs_out    = out_hs;
    assign o_vs_out    = out_vs;
    assign o_de_out    = out_de;

endmodule