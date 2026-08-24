// =============================================================================
// 文件名称：top.v
// 主要模块：top
// 功能说明：系统顶层集成，连接摄像头、图像处理、存储、显示与通信通路。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module top (
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
  wire clk_sys;  // 100MHz (主时钟&I2C)
  wire clk_hdmi;  //50MHz
  wire clk_hdmi_n;  // 50MHz, 180度相位差给 SiI9134
  wire clk_24m;  // 24MHz 给 OV5640 XCLK
  wire clk_sdram;  // 125MHz 给 SDRAM 芯片
  wire clk_sdram_shift;  // 125MHz 给 SDRAM 控制器，相偏202.5°(不确定是否为最优，但已经满足时序要求)
  wire locked;

  assign HDMI_CLK = clk_hdmi_n;

  pll_1 pll_inst (
      .areset(!rst_n),
      .inclk0(clk),
      .c0    (clk_sys),     // 100MHz 主时钟，供系统逻辑和 I2C 使用
      .c1    (clk_24m),     // 24MHz 摄像头时钟，直接送给摄像头硬件引脚
      .c2    (clk_hdmi),    // 50MHz 给 HDMI
      .c3    (clk_hdmi_n),  // 50MHz 180度相位差送给 HDMI_CLK 引脚
      .locked(locked)
  );

  assign CAM_XCLK = clk_24m;  // 把 24MHz 送给摄像头硬件引脚

  wire locked_sdram;
  pll_sdram pll_sdram_inst (
      .areset(!rst_n),
      .inclk0(clk),
      .c0    (clk_sdram),        //125MHz 给 SDRAM 芯片
      .c1    (clk_sdram_shift),  //125MHz 给 SDRAM 控制器，相偏202.5°
      .locked(locked_sdram)
  );

  // ---------- 高电平复位桥 ----------
  wire rst_sync = (!rst_n) || (!locked) || (!locked_sdram);
  reg r_rst_d1, r_rst_d2;

  always @(posedge clk_sys) begin
    r_rst_d1 <= rst_sync;
    r_rst_d2 <= r_rst_d1;
  end
  wire sys_rst = r_rst_d2;

  assign HDMI_NRESET = !sys_rst;  // HDMI 复位信号，低电平有效

  wire i2c_done;
  wire i2c_err;
  assign led_hdmi_i2c_done = !i2c_done;

  // ---------- I2C 初始化 (SiI9134) ----------
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

  reg [23:0] cam_pwr_cnt = 0;
  reg r_cam_pwdn = 1'b1;  // 初始处于 Power Down 状态
  reg r_cam_reset = 1'b0;  // 初始处于硬件复位状态
  reg r_cam_init_en = 1'b0;  // 允许 I2C 初始化的使能标志

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
  assign CAM_PWDN  = r_cam_pwdn;
  assign CAM_RESET = r_cam_reset;

  wire ov5640_i2c_done;
  reg [23:0] pclk_cnt = 0;
  always @(posedge CAM_PCLK) begin
    pclk_cnt <= pclk_cnt + 1'b1;
  end
  assign led_cam_pclk = pclk_cnt[23];

  // Cam_I2C 复位信号：系统复位 OR 尚未到达 I2C 启动时间
  wire cam_i2c_rst = sys_rst || (!r_cam_init_en);

  // ---------- I2C 初始化 (OV5640) ----------
  ov5640_i2c_init #(
      .CLK_FRE(100)
  ) u_cam_i2c (
      .i_clk      (clk_sys),
      .i_rst      (cam_i2c_rst),     // 使用受控的 I2C 专属复位
      .io_i2c_scl (CAM_SCL),
      .io_i2c_sda (CAM_SDA),
      .o_init_done(ov5640_i2c_done)
  );

  assign led_cam_i2c_done = !ov5640_i2c_done;

  // ---------- OV5640 图像捕获 ----------
  wire        cam_wr_en;
  wire [15:0] cam_rgb565;
  wire        cam_frame_vsync;  // 一帧开始的脉冲，用于清空写 FIFO

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
  wire        hdmi_rd_req;  // 提前一拍的读请求
  wire [23:0] hdmi_rgb888;
  wire        hdmi_frame_vsync;  // 一帧开始的脉冲，用于清空读 FIFO
  wire h_hs, h_vs, h_de;  // HDMI 的同步信号
  wire [23:0] h_rgb;  // HDMI 的像素数据
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
  wire [7:0] rx_data;
  wire       rx_done;

  // 1. 例化 UART 接收模块
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
  wire [3:0] target_main_mode;
  wire [7:0] target_sub_mode;
  wire       mode_valid;

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
  wire [11:0] sync_mode_data;
  wire        sync_mode_valid;
  wire        tx_busy;

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
  reg [3:0] al_main_hdmi;
  reg [7:0] al_sub_hdmi;

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
  wire [15:0] sdram_rd_data;
  wire O_sdram_init_done;
  assign led_sdram_init_done = !O_sdram_init_done;
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
  assign hdmi_rgb888 = rgb888_data;


  // 例化UART TX 模块
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
