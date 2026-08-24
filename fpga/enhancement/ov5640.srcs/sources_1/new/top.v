// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：top.v
// 主要模块：top
// 功能分类：系统集成
// 功能说明：集成时钟、摄像头、SDRAM、HDMI、串口控制、算法流水线和网络输出，完成板级信号连接。
// 输入概述：板级时钟、按键、摄像头、串口、SDRAM 与 PHY 信号。
// 输出概述：HDMI、SDRAM、摄像头控制、网络和状态指示等板级信号。
// 时序约束：各时钟域通过 FIFO 或握手机制连接；引脚与时钟约束由 ov5640.edc 定义。
// 关联文件：ov5640_capture.v、sdram_top.v、hdmi.v、video_algo_manager.v、uart_cmd_parser.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：集成时钟、摄像头、SDRAM、HDMI、串口控制、算法流水线和网络输出，完成板级信号连接。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：板级端口、时钟域和模式编码变更必须同步更新约束文件、子模块例化及协议文档。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 top：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module top (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire clk,   // 外部晶振 50MHz 
    input wire rst_n, //异步复位时钟，SW1

    // OV5640 摄像头接口
    output wire       CAM_XCLK,   // 24MHz 摄像头时钟
    input  wire       CAM_PCLK,   // 摄像头像素时钟输入
    input  wire       CAM_VSYNC,  // 场同步信号
    input  wire       CAM_HREF,   // 行有效信号
    input  wire [7:0] CAM_DATA,   // 8位像素数据
    inout  wire       CAM_SCL,    // 摄像头 I2C 时钟
    inout  wire       CAM_SDA,    // 摄像头 I2C 数据
    output wire       CAM_PWDN,   // 电源控制信号
    output wire       CAM_RESET,  // 硬件复位信号

    // HDMI (SiI9134) 接口
    output wire        HDMI_NRESET,
    inout  wire        HDMI_SCL,
    inout  wire        HDMI_SDA,
    output wire        HDMI_CLK,     // M18
    output wire        HDMI_VS,      // B22
    output wire        HDMI_HS,      // R20
    output wire        HDMI_DE,      // M21
    output wire [23:0] HDMI_D,

    // SDRAM 物理接口
    output wire        O_sdram_clk,    // SDRAM 芯片时钟
    output wire        O_sdram_cke,    // SDRAM 时钟使能
    output wire        O_sdram_cs_n,   // SDRAM 片选信号
    output wire        O_sdram_ras_n,  // SDRAM 行选通
    output wire        O_sdram_cas_n,  // SDRAM 列选通
    output wire        O_sdram_we_n,   // SDRAM 写使能
    output wire [ 1:0] O_sdram_bank,   // SDRAM Bank地址
    output wire [12:0] O_sdram_addr,   // SDRAM 地址总线
    inout  wire [15:0] IO_sdram_dq,    // SDRAM 数据总线

    // 使用 TX 进行主动状态打印
    output wire uart_tx,
    input  wire uart_rx,

    //LED测试接口
    output wire led_hdmi_i2c_done,  //LED4
    output wire led_cam_i2c_done,  //LED3
    output wire led_cam_pclk,  //LED6
    output wire led_sdram_init_done  //LED5
);

  // ---------- PLL 例化 ----------
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire clk_sys;  // 100MHz (主时钟&I2C)
  wire clk_hdmi;  //50MHz
  wire clk_hdmi_n;  // 50MHz, 180度相位差给 SiI9134
  wire clk_24m;  // 24MHz 给 OV5640 XCLK
  wire clk_sdram;  // 125MHz 给 SDRAM 芯片
  wire clk_sdram_shift;  // 125MHz 给 SDRAM 控制器，相偏202.5°(不确定是否为最优，但已经满足时序要求)
  wire locked;

  // [Ethereal注释] 组合连线组 1：从 HDMI_CLK 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign HDMI_CLK = clk_hdmi_n;

  // [Ethereal注释] 子模块例化 1（pll_1）：封装锁相环 IP，生成指定频率与相位关系的内部时钟。
  pll_1 pll_inst (
      .areset(!rst_n),
      .inclk0(clk),
      .c0    (clk_sys),     // 100MHz 主时钟，供系统逻辑和 I2C 使用
      .c1    (clk_24m),     // 24MHz 摄像头时钟，直接送给摄像头硬件引脚
      .c2    (clk_hdmi),    // 50MHz 给 HDMI
      .c3    (clk_hdmi_n),  // 50MHz 180度相位差送给 HDMI_CLK 引脚
      .locked(locked)
  );

  // [Ethereal注释] 组合连线组 1：从 CAM_XCLK 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign CAM_XCLK = clk_24m;  // 把 24MHz 送给摄像头硬件引脚

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire locked_sdram;
  // [Ethereal注释] 子模块例化 2（pll_sdram）：由参考时钟生成 SDRAM 控制器及相位补偿所需时钟。
  pll_sdram pll_sdram_inst (
      .areset(!rst_n),
      .inclk0(clk),
      .c0    (clk_sdram),        //125MHz 给 SDRAM 芯片
      .c1    (clk_sdram_shift),  //125MHz 给 SDRAM 控制器，相偏202.5°
      .locked(locked_sdram)
  );

  // ---------- 高电平复位桥 ----------
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire rst_sync = (!rst_n) || (!locked) || (!locked_sdram);
  reg r_rst_d1, r_rst_d2;

  // [Ethereal注释] 时序过程 1：由 clk_sys posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk_sys) begin
    r_rst_d1 <= rst_sync;
    r_rst_d2 <= r_rst_d1;
  end
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire sys_rst = r_rst_d2;

  // [Ethereal注释] 组合连线组 1：从 HDMI_NRESET 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign HDMI_NRESET = !sys_rst;  // HDMI 复位信号，低电平有效

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire i2c_done;
  wire i2c_err;
  // [Ethereal注释] 组合连线组 1：从 led_hdmi_i2c_done 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign led_hdmi_i2c_done = !i2c_done;

  // ---------- I2C 初始化 (SiI9134) ----------
  // [Ethereal注释] 子模块例化 3（sii9134_i2c_init）：通过 I2C 初始化 SII9134 HDMI 发送器寄存器。
  sii9134_i2c_init #(
      .CLK_FRE(100)
  ) u_hdmi_i2c (
      .i_clk      (clk_sys),
      .i_rst      (sys_rst),
      .io_i2c_scl (HDMI_SCL),
      .io_i2c_sda (HDMI_SDA),
      .o_init_done(i2c_done),
      .o_err      (i2c_err)
  );

  // ---------- OV5640 严格上电与复位时序 (遵循 Datasheet) ----------
  // 100MHz 系统时钟下，1ms = 100,000 个时钟周期
  // 时序规范：
  // 1. PLL 锁定，XCLK 输出稳定后，保持 PWDN=1, RESET=0
  // 2. 等待至少 1ms 后，拉低 PWDN (唤醒)
  // 3. PWDN 拉低至少 1ms 后，拉高 RESET (释放复位)
  // 4. RESET 拉高至少 20ms 后，才允许 I2C 发送数据

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [23:0] cam_pwr_cnt = 0;
  reg r_cam_pwdn = 1'b1;  // 初始处于 Power Down 状态
  reg r_cam_reset = 1'b0;  // 初始处于硬件复位状态
  reg r_cam_init_en = 1'b0;  // 允许 I2C 初始化的使能标志

  // [Ethereal注释] 时序过程 2：由 clk_sys posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk_sys) begin
    if (sys_rst) begin
      // 系统总复位期间（PLL可能未锁定，XCLK不稳定）
      cam_pwr_cnt   <= 24'd0;
      r_cam_pwdn    <= 1'b1; // 强行进入休眠
      r_cam_reset   <= 1'b0; // 强行保持复位
      r_cam_init_en <= 1'b0; // 严禁 I2C 启动
    end else begin
      // PLL 锁定，XCLK 稳定后，启动总计 40ms 的唤醒状态机
      if (cam_pwr_cnt < 24'd4_000_000) begin
        cam_pwr_cnt <= cam_pwr_cnt + 1'b1;

        // 第 5ms (500,000周期)：将 PWDN 拉低，唤醒芯片电源
        if (cam_pwr_cnt == 24'd500_000) begin
          r_cam_pwdn <= 1'b0;
        end

        // 第 10ms (1,000,000周期)：将 RESET 拉高，释放数字逻辑复位
        // (满足 PWDN 到 RESET 至少 1ms 的要求)
        if (cam_pwr_cnt == 24'd1_000_000) begin
          r_cam_reset <= 1'b1;
        end

      end else begin
        // 40ms 以后：芯片彻底就绪，允许 I2C 开始发送数据
        // (满足 RESET 到 I2C 至少 20ms 的要求)
        r_cam_init_en <= 1'b1;
      end
    end
  end

  // 将内部寄存器信号输出到物理引脚
  // [Ethereal注释] 组合连线组 1：从 CAM_PWDN 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign CAM_PWDN  = r_cam_pwdn;
  assign CAM_RESET = r_cam_reset;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire ov5640_i2c_done;
  reg [23:0] pclk_cnt = 0;
  // [Ethereal注释] 时序过程 3：由 CAM_PCLK posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge CAM_PCLK) begin
    pclk_cnt <= pclk_cnt + 1'b1;
  end
  // [Ethereal注释] 组合连线组 1：从 led_cam_pclk 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign led_cam_pclk = pclk_cnt[23];

  // Cam_I2C 复位信号：系统复位 OR 尚未到达 I2C 启动时间
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire cam_i2c_rst = sys_rst || (!r_cam_init_en);

  // ---------- I2C 初始化 (OV5640) ----------
  // [Ethereal注释] 子模块例化 4（ov5640_i2c_init）：通过 I2C 寄存器序列初始化 OV5640 的分辨率、像素格式和输出时序。
  ov5640_i2c_init #(
      .CLK_FRE(100)
  ) u_cam_i2c (
      .i_clk      (clk_sys),
      .i_rst      (cam_i2c_rst),     // 使用受控的 I2C 专属复位
      .io_i2c_scl (CAM_SCL),
      .io_i2c_sda (CAM_SDA),
      .o_init_done(ov5640_i2c_done)
  );

  // [Ethereal注释] 组合连线组 1：从 led_cam_i2c_done 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign led_cam_i2c_done = !ov5640_i2c_done;

  // ---------- OV5640 图像捕获 ----------
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire        cam_wr_en;
  wire [15:0] cam_rgb565;
  wire        cam_frame_vsync;  // 一帧开始的脉冲，用于清空写 FIFO

  // [Ethereal注释] 子模块例化 5（ov5640_capture）：在像素时钟域采集 OV5640 RGB565 数据及同步信号，形成内部视频流。
  ov5640_capture u_ov5640_capture (
      .i_pclk       (CAM_PCLK),
      .i_rst        (sys_rst || !ov5640_i2c_done),  // 没配完不工作
      .i_vsync      (CAM_VSYNC),
      .i_href       (CAM_HREF),
      .i_data       (CAM_DATA),
      .o_frame_vsync(cam_frame_vsync),
      .o_data_en    (cam_wr_en),
      .o_rgb565     (cam_rgb565)
  );
  // ---------- HDMI 视频时序与读取 ----------
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire        hdmi_rd_req;  // 提前一拍的读请求
  wire [23:0] hdmi_rgb888;
  wire        hdmi_frame_vsync;  // 一帧开始的脉冲，用于清空读 FIFO
  wire h_hs, h_vs, h_de;  // HDMI 的同步信号
  wire [23:0] h_rgb;  // HDMI 的像素数据
  // [Ethereal注释] 子模块例化 6（hdmi）：生成显示扫描时序，从帧缓存读取像素并形成 RGB888、HS、VS、DE 基准视频流。
  hdmi u_hdmi (
      .i_pclk       (clk_hdmi),
      .i_rst        (sys_rst),
      .i_rgb        (hdmi_rgb888),       // 从逻辑中送入转换后的数据
      .o_fifo_rd_req(hdmi_rd_req),       // 送给 SDRAM 的读请求
      .o_frame_vsync(hdmi_frame_vsync),  // 送给 SDRAM 的读清空信号
      .o_hs         (h_hs),
      .o_vs         (h_vs),
      .o_de         (h_de),
      .o_rgb_out    (h_rgb)              // 送给屏幕的对其后数据
  );

  // 串口接收与指令解析 (运行在 clk_sys 100MHz)
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] rx_data;
  wire       rx_done;

  // 1. 例化 UART 接收模块
  // [Ethereal注释] 子模块例化 7（uart_rx）：按设定波特率完成 UART 起始位检测、数据采样和字节有效指示。
  uart_rx #(
      .CLK_FRE(100),
      .BAUD_RATE(1000000),
      .DATA_WIDTH(8)
  ) u_rx (
      .i_clk_sys  (clk_sys),
      .i_rst      (sys_rst),
      .i_uart_rx  (uart_rx),
      .o_uart_data(rx_data),
      .o_rx_done  (rx_done)
  );


  // 2. 例化指令解析器：捕获 AA -> Main -> Sub -> 55 协议
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [3:0] target_main_mode;
  wire [7:0] target_sub_mode;
  wire       mode_valid;

  // [Ethereal注释] 子模块例化 8（uart_cmd_parser）：识别 0xAA/0x55 帧界定符，解析主模式与子模式并产生更新脉冲。
  uart_cmd_parser u_cmd_parser (
      .clk             (clk_sys),
      .rst             (sys_rst),
      .rx_done         (rx_done),
      .rx_data         (rx_data),
      .target_main_mode(target_main_mode),
      .target_sub_mode (target_sub_mode),
      .mode_valid      (mode_valid)
  );

  // 跨时钟域传输：100MHz (SYS) -> 40MHz (HDMI)
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [11:0] sync_mode_data;
  wire        sync_mode_valid;
  wire        tx_busy;

  // [Ethereal注释] 子模块例化 9（cdc_handshake）：采用请求/应答握手在异步时钟域间可靠传递多位模式控制数据。
  cdc_handshake #(
      .DATA_WIDTH(12)  // 4位 main + 8位 sub
  ) u_cdc_mode (
      .rst(sys_rst),

      // 发送端 (100MHz)
      .tx_clk    (clk_sys),
      .tx_req_in (mode_valid),
      .tx_data_in({target_main_mode, target_sub_mode}),  // 拼接为12位发送
      .tx_busy   (tx_busy),

      // 接收端 (40MHz HDMI时钟)
      .rx_clk     (clk_hdmi),
      .rx_valid   (sync_mode_valid),  // 收到新数据的单拍脉冲
      .rx_data_out(sync_mode_data)
  );

  // HDMI时钟域：锁存模式数据并送入视频处理管线
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [3:0] al_main_hdmi;
  reg [7:0] al_sub_hdmi;

  // [Ethereal注释] 时序过程 4：由 clk_hdmi posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk_hdmi) begin
    if (sys_rst) begin
      al_main_hdmi <= 4'd10;  // 默认给一个安全模式，如 10 (原图直出)
      al_sub_hdmi  <= 8'd0;
    end else if (sync_mode_valid) begin
      // 当握手模块提示有新指令到达时，更新状态
      al_main_hdmi <= sync_mode_data[11:8];
      al_sub_hdmi  <= sync_mode_data[7:0];
    end
  end

  // [Ethereal注释] 子模块例化 10（image_process_pipe）：实例化引导滤波/磨皮和暗光增强支路，根据主模式 10、11 选择最终输出视频流。
  image_process_pipe u_pipe (
      .clk_hdmi(clk_hdmi),
      .sys_rst (sys_rst),

      // 接入锁存后的模式寄存器
      .al_main_hdmi(al_main_hdmi),
      .al_sub_hdmi (al_sub_hdmi),

      .raw_hs (h_hs),
      .raw_vs (h_vs),
      .raw_de (h_de),
      .raw_rgb(h_rgb),

      .final_hs (HDMI_HS),
      .final_vs (HDMI_VS),
      .final_de (HDMI_DE),
      .final_rgb(HDMI_D)
  );

  // ---------- SDRAM 控制器 ----------
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [15:0] sdram_rd_data;
  wire O_sdram_init_done;
  // [Ethereal注释] 组合连线组 1：从 led_sdram_init_done 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign led_sdram_init_done = !O_sdram_init_done;
  // [Ethereal注释] 子模块例化 11（sdram_top）：封装 SDRAM 控制器和读写 FIFO，提供视频帧缓存的统一顶层接口。
  sdram_top u_sdram_top (
      .I_ref_clk(clk_sdram),  // 使用专门产生的 SDRAM 时钟，保证时序要求
      .I_out_clk(clk_sdram_shift),  // 125MHz 相移 -90度
      .I_rst_n(!sys_rst),  // 低电平复位

      // ---------------- 写端口 (接摄像头) ---------------- 
      .I_fifo_wr_clk (CAM_PCLK),         // 摄像头像素时钟
      .I_fifo_wr_req (cam_wr_en),        // 原始
      .I_fifo_wr_data(cam_rgb565),       // 摄像头的 16位 RGB565 数据
      .I_fifo_wr_load(cam_frame_vsync),  // 利用摄像头的 VSYNC 触发写 FIFO 清空同步
      .I_wr_burst    (12'd512),          // 写突发长度 512
      .I_wr_saddr    (24'h000000),       // 图像起始地址
      .I_wr_eaddr    (24'd614400),       // 图像终止地址


      // ---------------- 读端口 (接 HDMI) ---------------- 
      .I_fifo_rd_clk(clk_hdmi),  // HDMI 像素时钟 (50MHz)
      .I_fifo_rd_req(hdmi_rd_req),  // HDMI 的数据使能信号 (拉高时去 SDRAM 取像素)
      .O_fifo_rd_data(sdram_rd_data),  // 吐给 HDMI 的 RGB565 数据
      .I_fifo_rd_load(hdmi_frame_vsync),  // 利用 HDMI 的 VSYNC 触发读 FIFO 清空同步
      .I_rd_burst(12'd512),  // 读突发长度 512
      .I_rd_saddr(24'h000000),  // 图像起始地址
      .I_rd_eaddr(24'd614400),  // 图像终止地址

      // ---------------- 控制与状态 ---------------- 
      .I_sdram_rd_valid   (1'b1),              // 恒定允许读出
      .I_sdram_pingpang_en(1'b1),              // 开启乒乓操作 (防撕裂)
      .O_sdram_init_done  (O_sdram_init_done), // SDRAM 初始化完成信号

      // ---------------- 物理接口连线 ---------------- 
      .O_sdram_clk  (O_sdram_clk),
      .O_sdram_cke  (O_sdram_cke),
      .O_sdram_cs_n (O_sdram_cs_n),
      .O_sdram_ras_n(O_sdram_ras_n),
      .O_sdram_cas_n(O_sdram_cas_n),
      .O_sdram_we_n (O_sdram_we_n),
      .O_sdram_bank (O_sdram_bank),
      .O_sdram_addr (O_sdram_addr),
      .IO_sdram_dq  (IO_sdram_dq),
      .O_sdram_dqm  ()
  );

  // ---------- RGB565 转 RGB888 ----------

  // 截取 16位数据中的 R、G、B 分量
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [4:0] R_5 = sdram_rd_data[15:11];
  wire [5:0] G_6 = sdram_rd_data[10:5];
  wire [4:0] B_5 = sdram_rd_data[4:0];

  // 高位复制补偿法：将原分量的最高几位复制到低位，保证颜色饱满 (白依然是白)
  wire [23:0] rgb888_data = {
    R_5,
    R_5[4:2],  // 拼接出 8 位红色
    G_6,
    G_6[5:4],  // 拼接出 8 位绿色
    B_5,
    B_5[4:2]  // 拼接出 8 位蓝色
  };

  // 将校验逻辑转移到了 hdmi_rgb888
  // [Ethereal注释] 组合连线组 1：从 hdmi_rgb888 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign hdmi_rgb888 = rgb888_data;


  // 例化UART TX 模块
  // [Ethereal注释] 子模块例化 12（uart_tx）：将并行字节按 UART 帧格式和设定波特率串行发送。
  uart_tx #(
      .CLK_FRE(100),
      .BAUD_RATE(1000000),
      .DATA_WIDTH(8)
  ) u_tx (
      .i_clk_sys(clk_sys),
      .i_rst    (sys_rst),
      .i_tx_data(),
      .i_tx_en  (),
      .o_uart_tx(uart_tx),
      .o_tx_busy()
  );
endmodule
