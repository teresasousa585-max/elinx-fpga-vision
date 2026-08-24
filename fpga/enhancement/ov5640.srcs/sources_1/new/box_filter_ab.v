// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：box_filter_ab.v
// 主要模块：box_filter_ab
// 功能分类：引导滤波算法
// 功能说明：对线性系数 a、b 执行盒式均值滤波，并对齐中心像素旁路。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_line_buffer_a_b.v、guided_final_rebuild.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：对线性系数 a、b 执行盒式均值滤波，并对齐中心像素旁路。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 box_filter_ab：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module box_filter_ab(
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire        i_clk,
    input  wire        i_rst,
    
    // 来自上一个模块的列求和数据与中心信号
    input  wire [14:0] i_col_sum_a,   
    input  wire [14:0] i_col_sum_b,  
    input  wire [23:0] i_center_ycbcr, 
    input  wire [23:0] i_rgb,         // 【新增】原数据旁路输入
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    
    // 输出：最终的 5x5 窗口均值
    output wire [11:0]  o_mean_a,      
    output wire [11:0]  o_mean_b,      
    
    // 输出：再次对齐延迟后的中心像素
    output wire [23:0] o_ycbcr_sync,
    output wire [23:0] o_rgb,         // 【新增】原数据旁路输出
    output wire        o_hs_sync,
    output wire        o_vs_sync,
    output wire        o_de_sync
    );

    // 1. 缓存最近 5 列的和 
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [14:0] col_a_d0, col_a_d1, col_a_d2, col_a_d3, col_a_d4;
    reg [14:0] col_b_d0, col_b_d1, col_b_d2, col_b_d3, col_b_d4;

    // [Ethereal注释] 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (i_rst) begin
            {col_a_d0, col_a_d1, col_a_d2, col_a_d3, col_a_d4} <= 0;
            {col_b_d0, col_b_d1, col_b_d2, col_b_d3, col_b_d4} <= 0;
        end else begin
            // 移位流水线 A
            col_a_d0 <= i_col_sum_a;
            col_a_d1 <= col_a_d0;
            col_a_d2 <= col_a_d1;
            col_a_d3 <= col_a_d2;
            col_a_d4 <= col_a_d3;
            
            // 移位流水线 B
            col_b_d0 <= i_col_sum_b;
            col_b_d1 <= col_b_d0;
            col_b_d2 <= col_b_d1;
            col_b_d3 <= col_b_d2;
            col_b_d4 <= col_b_d3;
        end
    end
    
    // 2. 计算 5 个列和的总和
    // Stage 1
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [15:0] sum_a_s1_01, sum_a_s1_23; reg [14:0] sum_a_s1_4;
    reg [15:0] sum_b_s1_01, sum_b_s1_23; reg [14:0] sum_b_s1_4;
    
    // [Ethereal注释] 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        sum_a_s1_01 <= col_a_d0 + col_a_d1;
        sum_a_s1_23 <= col_a_d2 + col_a_d3;
        sum_a_s1_4  <= col_a_d4;
        
        sum_b_s1_01 <= col_b_d0 + col_b_d1;
        sum_b_s1_23 <= col_b_d2 + col_b_d3;
        sum_b_s1_4  <= col_b_d4;
    end

    // Stage 2
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [16:0] sum_a_s2_0123; reg [14:0] sum_a_s2_4;
    reg [16:0] sum_b_s2_0123; reg [14:0] sum_b_s2_4;
    
    // [Ethereal注释] 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        sum_a_s2_0123 <= sum_a_s1_01 + sum_a_s1_23;
        sum_a_s2_4    <= sum_a_s1_4;
        
        sum_b_s2_0123 <= sum_b_s1_01 + sum_b_s1_23;
        sum_b_s2_4    <= sum_b_s1_4;
    end

    // Stage 3 
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [17:0] window_sum_a; 
    reg [17:0] window_sum_b; 
    
    // [Ethereal注释] 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        window_sum_a <= sum_a_s2_0123 + sum_a_s2_4;
        window_sum_b <= sum_b_s2_0123 + sum_b_s2_4;
    end

    // 3. 计算均值 
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [30:0] mult_a;
    wire [30:0] mult_b;

    // [Ethereal注释] 子模块例化 1（lpmmult_18_13）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_18_13 u_mult_a (
        .clock  (i_clk),             
        .dataa  (window_sum_a),      
        .datab  (13'd2621),          
        .result (mult_a)             
    );

    // [Ethereal注释] 子模块例化 2（lpmmult_18_13）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_18_13 u_mult_b (
        .clock  (i_clk),             
        .dataa  (window_sum_b),      
        .datab  (13'd2621),          
        .result (mult_b)             
    );

    // 取高位作为定点数还原
    // [Ethereal注释] 组合连线组 1：从 o_mean_a 开始的连续赋值随右值立即更新，不增加寄存器延迟。
    assign o_mean_a = mult_a[27:16];
    assign o_mean_b = mult_b[27:16];

    // ==========================================
    // 4. 延迟信号 (拓宽为 51 位，加入 RGB)
    // ==========================================
    // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [50:0] sync_d1, sync_d2, sync_d3, sync_d4, sync_d5, sync_d6, sync_d7;
    
    // 拼装顺序：HS(1) + VS(1) + DE(1) + YCbCr(24) + RGB(24) = 51位
    wire [50:0] sync_in = {i_hs, i_vs, i_de, i_center_ycbcr, i_rgb};

    // [Ethereal注释] 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (i_rst) begin
            {sync_d1, sync_d2, sync_d3, sync_d4, sync_d5, sync_d6, sync_d7} <= 0;
        end else begin
            sync_d1 <= sync_in;
            sync_d2 <= sync_d1;
            sync_d3 <= sync_d2;
            sync_d4 <= sync_d3;
            sync_d5 <= sync_d4;
            sync_d6 <= sync_d5;
            sync_d7 <= sync_d6; // 第 7 拍出站
        end
    end

    // 按照拼装顺序解包输出
    // [Ethereal注释] 组合连线组 1：从 o_hs_sync 开始的连续赋值随右值立即更新，不增加寄存器延迟。
    assign o_hs_sync    = sync_d7[50];
    assign o_vs_sync    = sync_d7[49];
    assign o_de_sync    = sync_d7[48];
    assign o_ycbcr_sync = sync_d7[47:24];
    assign o_rgb        = sync_d7[23:0];

endmodule