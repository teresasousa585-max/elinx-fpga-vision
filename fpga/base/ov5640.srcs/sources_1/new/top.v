// =============================================================================
// 文件名称：top.v
// 主要模块：top
// 功能说明：系统顶层集成，连接摄像头、图像处理、存储、显示与通信通路。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module top (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    output wire uart_tx,

    output wire       CAM_XCLK,
    input  wire       CAM_PCLK,
    input  wire       CAM_VSYNC,
    input  wire       CAM_HREF,
    input  wire [7:0] CAM_DATA,
    inout  wire       CAM_SCL,
    inout  wire       CAM_SDA,
    output wire       CAM_PWDN,
    output wire       CAM_RESET,

    output wire        HDMI_NRESET,
    inout  wire        HDMI_SCL,
    inout  wire        HDMI_SDA,
    output wire        HDMI_CLK,
    output wire        HDMI_VS,
    output wire        HDMI_HS,
    output wire        HDMI_DE,
    output wire [23:0] HDMI_D,

    output wire        O_sdram_clk,
    output wire        O_sdram_cke,
    output wire        O_sdram_cs_n,
    output wire        O_sdram_ras_n,
    output wire        O_sdram_cas_n,
    output wire        O_sdram_we_n,
    output wire [ 1:0] O_sdram_bank,
    output wire [12:0] O_sdram_addr,
    inout  wire [15:0] IO_sdram_dq,

    // LED
    output wire led_hdmi_i2c_done,
    output wire led_cam_i2c_done,
    output wire led_cam_pclk,
    output wire led_sdram_init_done,

    // 千兆以太网接口
    output wire       E_GTXC,  // 125MHz 发送时钟
    output wire       E_TXEN,  // 发送使能信号
    output wire [7:0] E_TXD,   // 发送数据总线
    output wire       E_MDC,   // MDIO 时钟
    inout  wire       E_MDIO,  // MDIO 数据
    output wire       E_RESET  // PHY 复位
);

  wire clk_sys, clk_hdmi, clk_hdmi_n, clk_24m, clk_sdram, clk_sdram_shift;
  wire locked, locked_sdram;

  wire clk_125m;


  pll_1 pll_inst (
      .areset(!rst_n),
      .inclk0(clk),
      .c0(clk_sys),
      .c1(clk_24m),
      .c2(clk_hdmi),
      .c3(clk_hdmi_n),
      .locked(locked)
  );
  pll_sdram pll_sdram_inst (
      .areset(!rst_n),
      .inclk0(clk),
      .c0(clk_sdram),
      .c1(clk_sdram_shift),
      .c2(clk_125m),
      .c3(E_GTXC),
      .locked(locked_sdram)
  );

  assign HDMI_CLK = clk_hdmi_n;
  assign CAM_XCLK = clk_24m;

  wire rst_sync = (!rst_n) || (!locked) || (!locked_sdram);
  reg r_rst_d1, r_rst_d2;
  always @(posedge clk_sys) begin
    r_rst_d1 <= rst_sync;
    r_rst_d2 <= r_rst_d1;
  end
  wire sys_rst = r_rst_d2;
  assign HDMI_NRESET = !sys_rst;
  // 映射千兆网时钟与复位
  assign E_RESET = rst_n;

  wire rx_done;
  wire [7:0] rx_data;
  uart_rx #(
      .CLK_FRE(100),
      .BAUD_RATE(1000000),
      .DATA_WIDTH(8)
  ) u_uart_rx (
      .i_clk_sys(clk_sys),
      .i_rst(sys_rst),
      .i_uart_rx(uart_rx),
      .o_uart_data(rx_data),
      .o_rx_done(rx_done)
  );

  wire [3:0] target_main;
  wire [7:0] target_sub;
  wire mode_valid;
  uart_cmd_parser u_parser (
      .clk(clk_sys),
      .rst(sys_rst),
      .rx_done(rx_done),
      .rx_data(rx_data),
      .target_main_mode(target_main),
      .target_sub_mode(target_sub),
      .mode_valid(mode_valid)
  );

  wire [11:0] combined_tx = {target_main, target_sub};
  wire hdmi_mode_rx_valid;
  wire [11:0] hdmi_mode_data;
  cdc_handshake #(
      .DATA_WIDTH(12)
  ) u_cdc_hdmi (
      .rst(sys_rst),
      .tx_clk(clk_sys),
      .tx_req_in(mode_valid),
      .tx_data_in(combined_tx),
      .tx_busy(),
      .rx_clk(clk_hdmi),
      .rx_valid(hdmi_mode_rx_valid),
      .rx_data_out(hdmi_mode_data)
  );

  wire pclk_mode_rx_valid;
  wire [11:0] pclk_mode_data;
  cdc_handshake #(
      .DATA_WIDTH(12)
  ) u_cdc_pclk (
      .rst(sys_rst),
      .tx_clk(clk_sys),
      .tx_req_in(mode_valid),
      .tx_data_in(combined_tx),
      .tx_busy(),
      .rx_clk(CAM_PCLK),
      .rx_valid(pclk_mode_rx_valid),
      .rx_data_out(pclk_mode_data)
  );

  wire hdmi_frame_vsync, cam_frame_vsync;

  // HDMI 读端更新
  reg [3:0] al_main_hdmi;
  reg [7:0] al_sub_hdmi;
  reg [23:0] safe_rd_end_addr;
  reg mode_update_pending_hdmi;
  reg [11:0] pending_mode_hdmi;

  always @(posedge clk_hdmi or posedge sys_rst) begin
    if (sys_rst) begin
      al_main_hdmi <= 4'd0;
      al_sub_hdmi <= 8'd0;
      safe_rd_end_addr <= 24'd614400;
      mode_update_pending_hdmi <= 1'b0;
    end else begin
      if (hdmi_mode_rx_valid) begin
        pending_mode_hdmi <= hdmi_mode_data;
        mode_update_pending_hdmi <= 1'b1;
      end
      if (hdmi_frame_vsync) begin
        if (mode_update_pending_hdmi) begin
          al_main_hdmi <= pending_mode_hdmi[11:8];
          al_sub_hdmi <= pending_mode_hdmi[7:0];
          mode_update_pending_hdmi <= 1'b0;

          if ((pending_mode_hdmi[11:8] == 3 && pending_mode_hdmi[7:0] == 1) || (pending_mode_hdmi[11:8] == 4 && pending_mode_hdmi[7:0] == 0))
            safe_rd_end_addr <= 24'd153600;
          else if ((pending_mode_hdmi[11:8] == 3 && pending_mode_hdmi[7:0] == 0) || (pending_mode_hdmi[11:8] == 4 && pending_mode_hdmi[7:0] == 1))
            safe_rd_end_addr <= 24'd38400;
          else safe_rd_end_addr <= 24'd614400;
        end else begin
          if ((al_main_hdmi == 3 && al_sub_hdmi == 1) || (al_main_hdmi == 4 && al_sub_hdmi == 0))
            safe_rd_end_addr <= 24'd153600;
          else if ((al_main_hdmi == 3 && al_sub_hdmi == 0) || (al_main_hdmi == 4 && al_sub_hdmi == 1))
            safe_rd_end_addr <= 24'd38400;
          else safe_rd_end_addr <= 24'd614400;
        end
      end
    end
  end

  // CAM 写端更新
  reg [3:0] al_main_pclk;
  reg [7:0] al_sub_pclk;
  reg [23:0] safe_wr_end_addr;
  reg mode_update_pending_pclk;
  reg [11:0] pending_mode_pclk;

  always @(posedge CAM_PCLK or posedge sys_rst) begin
    if (sys_rst) begin
      al_main_pclk <= 4'd0;
      al_sub_pclk <= 8'd0;
      safe_wr_end_addr <= 24'd614400;
      mode_update_pending_pclk <= 1'b0;
    end else begin
      if (pclk_mode_rx_valid) begin
        pending_mode_pclk <= pclk_mode_data;
        mode_update_pending_pclk <= 1'b1;
      end
      if (cam_frame_vsync) begin
        if (mode_update_pending_pclk) begin
          al_main_pclk <= pending_mode_pclk[11:8];
          al_sub_pclk <= pending_mode_pclk[7:0];
          mode_update_pending_pclk <= 1'b0;
          if ((pending_mode_pclk[11:8] == 3 && pending_mode_pclk[7:0] == 1) || (pending_mode_pclk[11:8] == 4 && pending_mode_pclk[7:0] == 0))
            safe_wr_end_addr <= 24'd153600;
          else if ((pending_mode_pclk[11:8] == 3 && pending_mode_pclk[7:0] == 0) || (pending_mode_pclk[11:8] == 4 && pending_mode_pclk[7:0] == 1))
            safe_wr_end_addr <= 24'd38400;
          else safe_wr_end_addr <= 24'd614400;
        end else begin
          if ((al_main_pclk == 3 && al_sub_pclk == 1) || (al_main_pclk == 4 && al_sub_pclk == 0))
            safe_wr_end_addr <= 24'd153600;
          else if ((al_main_pclk == 3 && al_sub_pclk == 0) || (al_main_pclk == 4 && al_sub_pclk == 1))
            safe_wr_end_addr <= 24'd38400;
          else safe_wr_end_addr <= 24'd614400;
        end
      end
    end
  end

  // I2C 初始化
  wire i2c_done, ov5640_i2c_done;
  assign led_hdmi_i2c_done = !i2c_done;
  assign led_cam_i2c_done  = !ov5640_i2c_done;
  sii9134_i2c_init #(
      .CLK_FRE(100)
  ) u_hdmi_i2c (
      .i_clk(clk_sys),
      .i_rst(sys_rst),
      .io_i2c_scl(HDMI_SCL),
      .io_i2c_sda(HDMI_SDA),
      .o_init_done(i2c_done)
  );

  reg [23:0] cam_pwr_cnt = 0;
  reg r_cam_pwdn = 1'b1, r_cam_reset = 1'b0, r_cam_init_en = 1'b0;
  always @(posedge clk_sys) begin
    if (sys_rst) begin
      cam_pwr_cnt <= 24'd0;
      r_cam_pwdn <= 1'b1;
      r_cam_reset <= 1'b0;
      r_cam_init_en <= 1'b0;
    end else begin
      if (cam_pwr_cnt < 24'd4_000_000) begin
        cam_pwr_cnt <= cam_pwr_cnt + 1'b1;
        if (cam_pwr_cnt == 24'd500_000) r_cam_pwdn <= 1'b0;
        if (cam_pwr_cnt == 24'd1_000_000) r_cam_reset <= 1'b1;
      end else r_cam_init_en <= 1'b1;
    end
  end
  assign CAM_PWDN  = r_cam_pwdn;
  assign CAM_RESET = r_cam_reset;

  reg [23:0] pclk_cnt = 0;
  always @(posedge CAM_PCLK) pclk_cnt <= pclk_cnt + 1'b1;
  assign led_cam_pclk = pclk_cnt[23];

  ov5640_i2c_init #(
      .CLK_FRE(100)
  ) u_cam_i2c (
      .i_clk(clk_sys),
      .i_rst(sys_rst || !r_cam_init_en),
      .i_flip_en(al_main_pclk == 4'd5 && al_sub_pclk == 8'd0),
      .io_i2c_scl(CAM_SCL),
      .io_i2c_sda(CAM_SDA),
      .o_init_done(ov5640_i2c_done)
  );

  wire cam_wr_en;
  wire [15:0] cam_rgb565;
  ov5640_capture u_ov5640_capture (
      .i_pclk(CAM_PCLK),
      .i_rst(sys_rst || !ov5640_i2c_done),
      .i_vsync(CAM_VSYNC),
      .i_href(CAM_HREF),
      .i_data(CAM_DATA),
      .o_frame_vsync(cam_frame_vsync),
      .o_data_en(cam_wr_en),
      .o_rgb565(cam_rgb565)
  );

  reg href_d1, href_d2;
  always @(posedge CAM_PCLK) begin
    href_d1 <= CAM_HREF;
    href_d2 <= href_d1;
  end
  // 完全使用同步域内的寄存器进行逻辑运算
  wire href_falling = href_d2 && !href_d1;

  reg [10:0] cam_x;
  reg [9:0] cam_y;
  always @(posedge CAM_PCLK) begin
    if (cam_frame_vsync) begin
      cam_x <= 0;
      cam_y <= 0;
    end else begin
      if (href_falling) begin
        cam_x <= 0;
        cam_y <= cam_y + 1'b1;  // 严格确保换行时 X清零 Y累加
      end else if (cam_wr_en) begin
        cam_x <= cam_x + 1'b1;
      end
    end
  end

  reg coord_valid_comb, coord_valid_stable;
  always @(*) begin
    if (al_main_pclk == 3 && al_sub_pclk == 0)
      coord_valid_comb = (cam_x[1:0] == 2'b00 && cam_y[1:0] == 2'b00);  // 缩4
    else if (al_main_pclk == 3 && al_sub_pclk == 1)
      coord_valid_comb = (cam_x[0] == 0 && cam_y[0] == 0);  // 缩2
    else if (al_main_pclk == 4 && al_sub_pclk == 0)
      coord_valid_comb = (cam_x >= 256 && cam_x < 768 && cam_y >= 150 && cam_y < 450);  // 放2
    else if (al_main_pclk == 4 && al_sub_pclk == 1)
      coord_valid_comb = (cam_x >= 384 && cam_x < 640 && cam_y >= 225 && cam_y < 375);  // 放4
    else if (al_main_pclk == 5 && al_sub_pclk != 0)
      coord_valid_comb = 1'b0;  // 旋转 90/仿射/45禁用写入
    else coord_valid_comb = 1'b1;
  end
  always @(posedge CAM_PCLK) coord_valid_stable <= coord_valid_comb;
  wire final_cam_wr_en = cam_wr_en & coord_valid_stable;

  // SDRAM 控制器
  wire [15:0] sdram_rd_data;
  wire O_sdram_init_done, sdram_rd_req;
  assign led_sdram_init_done = !O_sdram_init_done;

  sdram_top u_sdram_top (
      .I_ref_clk(clk_sdram),
      .I_out_clk(clk_sdram_shift),
      .I_rst_n(!sys_rst),
      .I_fifo_wr_clk(CAM_PCLK),
      .I_fifo_wr_req(final_cam_wr_en),
      .I_fifo_wr_data(cam_rgb565),
      .I_fifo_wr_load(cam_frame_vsync),
      .I_wr_burst(12'd256),
      .I_wr_saddr(24'h000000),
      .I_wr_eaddr(safe_wr_end_addr),

      .I_fifo_rd_clk(clk_hdmi),
      .I_fifo_rd_req(sdram_rd_req),
      .O_fifo_rd_data(sdram_rd_data),
      .I_fifo_rd_load(hdmi_frame_vsync),
      .I_rd_burst(12'd256),
      .I_rd_saddr(24'h000000),
      .I_rd_eaddr(safe_rd_end_addr),
      .I_sdram_rd_valid(1'b1),
      .I_sdram_pingpang_en(1'b1),

      .O_sdram_init_done(O_sdram_init_done),
      .O_sdram_clk(O_sdram_clk),
      .O_sdram_cke(O_sdram_cke),
      .O_sdram_cs_n(O_sdram_cs_n),
      .O_sdram_ras_n(O_sdram_ras_n),
      .O_sdram_cas_n(O_sdram_cas_n),
      .O_sdram_we_n(O_sdram_we_n),
      .O_sdram_bank(O_sdram_bank),
      .O_sdram_addr(O_sdram_addr),
      .IO_sdram_dq(IO_sdram_dq)
  );

  // HDMI 视频流预处理 (窗控与原版放大逻辑)
  wire [10:0] hdmi_x;
  wire [9:0] hdmi_y;
  wire hdmi_pre_de;

  wire is_win_1_2 = (hdmi_x >= 256 && hdmi_x < 768) && (hdmi_y >= 150 && hdmi_y < 450);
  wire is_win_1_4 = (hdmi_x >= 384 && hdmi_x < 640) && (hdmi_y >= 225 && hdmi_y < 375);

  assign sdram_rd_req =
      (al_main_hdmi == 3 && al_sub_hdmi == 1) ? (hdmi_pre_de && is_win_1_2) :
      (al_main_hdmi == 3 && al_sub_hdmi == 0) ? (hdmi_pre_de && is_win_1_4) :
      (al_main_hdmi == 4 && al_sub_hdmi == 0) ? (hdmi_pre_de && hdmi_y[0]==0 && hdmi_x[0]==0) :
      (al_main_hdmi == 4 && al_sub_hdmi == 1) ? (hdmi_pre_de && hdmi_y[1:0]==0 && hdmi_x[1:0]==0) :
      (al_main_hdmi == 5 && al_sub_hdmi != 0) ? 1'b0 :
      hdmi_pre_de;

  wire [15:0] ram_q;
  line_buffer u_line_buf (
      .clock(clk_hdmi),
      .data(sdram_rd_data),
      .rdaddress((al_main_hdmi == 4 && al_sub_hdmi == 1) ? hdmi_x[10:2] : hdmi_x[10:1]),
      .wraddress((al_main_hdmi == 4 && al_sub_hdmi == 1) ? hdmi_x[10:2] : hdmi_x[10:1]),
      .wren((al_main_hdmi == 4) ? sdram_rd_req : 1'b0),
      .q(ram_q)
  );

  wire bram_wr_en = (al_main_pclk == 5 && al_sub_pclk != 0) && cam_wr_en && (cam_x[1:0] == 0) && (cam_y[1:0] == 0);
  wire rotator_de;
  wire [15:0] rotator_rgb;
  video_rotator_bram u_video_rotator (
      .wr_clk(CAM_PCLK),
      .rd_clk(clk_hdmi),
      .rst(sys_rst),
      .rot_mode((al_main_hdmi == 5 && al_sub_hdmi == 1) ? 2'd2 : (al_main_hdmi == 5 && al_sub_hdmi == 2) ? 2'd3 : (al_main_hdmi == 5 && al_sub_hdmi == 3) ? 2'd1 : 2'd0),
      .i_vsync(cam_frame_vsync),
      .i_de(bram_wr_en),
      .i_rgb(cam_rgb565),
      .o_h_cnt(hdmi_x),
      .o_v_cnt(hdmi_y),
      .o_de(rotator_de),
      .o_rgb(rotator_rgb)
  );

  // 延迟对齐与缝合 (与 top(1).v 丝毫不差)
  wire [15:0] current_pixel_d1 =
      (al_main_hdmi == 4 && al_sub_hdmi == 0) ? (hdmi_y[0]==0 ? sdram_rd_data : ram_q) :
      (al_main_hdmi == 4 && al_sub_hdmi == 1) ? (hdmi_y[1:0]==0 ? sdram_rd_data : ram_q) :
      sdram_rd_data;

  reg [15:0] current_pixel_d2, current_pixel_d3, current_pixel_d4;
  reg is_win_1_2_d1, is_win_1_2_d2, is_win_1_2_d3, is_win_1_2_d4;
  reg is_win_1_4_d1, is_win_1_4_d2, is_win_1_4_d3, is_win_1_4_d4;

  always @(posedge clk_hdmi) begin
    current_pixel_d2 <= current_pixel_d1;
    current_pixel_d3 <= current_pixel_d2;
    current_pixel_d4 <= current_pixel_d3;
    is_win_1_2_d1 <= is_win_1_2;
    is_win_1_2_d2 <= is_win_1_2_d1;
    is_win_1_2_d3 <= is_win_1_2_d2;
    is_win_1_2_d4 <= is_win_1_2_d3;
    is_win_1_4_d1 <= is_win_1_4;
    is_win_1_4_d2 <= is_win_1_4_d1;
    is_win_1_4_d3 <= is_win_1_4_d2;
    is_win_1_4_d4 <= is_win_1_4_d3;
  end

  wire [15:0] masked_pixel =
      (al_main_hdmi == 3 && al_sub_hdmi == 1) ? (is_win_1_2_d4 ? current_pixel_d4 : 16'h0000) :
      (al_main_hdmi == 3 && al_sub_hdmi == 0) ? (is_win_1_4_d4 ? current_pixel_d4 : 16'h0000) :
      (al_main_hdmi == 5 && al_sub_hdmi != 0) ? rotator_rgb :
      current_pixel_d4;

  wire [23:0] rgb888_in = {
    masked_pixel[15:11],
    masked_pixel[15:13],
    masked_pixel[10:5],
    masked_pixel[10:9],
    masked_pixel[4:0],
    masked_pixel[4:2]
  };

  // 生成基础时序
  wire raw_hs, raw_vs, raw_de;
  wire [23:0] raw_rgb;
  hdmi u_hdmi (
      .i_pclk(clk_hdmi),
      .i_rst(sys_rst),
      .i_rgb(rgb888_in),
      .o_frame_vsync(hdmi_frame_vsync),
      .o_hs(raw_hs),
      .o_vs(raw_vs),
      .o_de(raw_de),
      .o_rgb_out(raw_rgb),
      .o_h_cnt(hdmi_x),
      .o_v_cnt(hdmi_y),
      .o_pre_de(hdmi_pre_de)
  );

  // 纯净图像管线独立管理
  image_process_pipe u_pipe (
      .clk_hdmi(clk_hdmi),
      .sys_rst(sys_rst),
      .al_main_hdmi(al_main_hdmi),
      .al_sub_hdmi(al_sub_hdmi),
      .raw_hs(raw_hs),
      .raw_vs(raw_vs),
      .raw_de(raw_de),
      .raw_rgb(raw_rgb),

      .final_hs (HDMI_HS),
      .final_vs (HDMI_VS),
      .final_de (HDMI_DE),
      .final_rgb(HDMI_D)
  );

  //千兆以太网上位机图传模块 (发送算法处理后的图像)
  //1. PHY 芯片寄存器配置
  wire phy_config_done;
  phy_reg_config u_phy_config (
      .clock_50m  (clk_sys),
      .reset_n    (!sys_rst),
      .phy_mdc    (E_MDC),
      .phy_mdio   (E_MDIO),
      .config_done(phy_config_done)
  );

  // 2. 提取算法管线输出的 VSYNC，作为以太网的全新帧起点！
  // 因为算法处理会有几拍延迟，必须以管线出来的 HDMI_VS 为准，绝对不能用原始的 hdmi_frame_vsync
  reg algo_vs_d1, algo_vs_d2;
  always @(posedge clk_hdmi) begin
    if (sys_rst) begin
      algo_vs_d1 <= 1'b0;
      algo_vs_d2 <= 1'b0;
    end else begin
      algo_vs_d1 <= HDMI_VS;  // 🌟 抓取算法输出的最终场同步
      algo_vs_d2 <= algo_vs_d1;
    end
  end
  // 提取上升沿作为算法帧起点
  wire       algo_frame_vsync = algo_vs_d1 && !algo_vs_d2;

  // 3. 在 50MHz 域生成展宽的安全复位脉冲 (消灭时序违规和错位)
  reg  [4:0] safe_rst_cnt;
  reg        safe_fifo_aclr;
  always @(posedge clk_hdmi) begin
    if (sys_rst) begin
      safe_rst_cnt   <= 5'd0;
      safe_fifo_aclr <= 1'b1;
    end else if (algo_frame_vsync) begin
      safe_rst_cnt   <= 5'd15;  // 展宽 15 个周期
      safe_fifo_aclr <= 1'b1;
    end else if (safe_rst_cnt > 0) begin
      safe_rst_cnt   <= safe_rst_cnt - 1'b1;
      safe_fifo_aclr <= 1'b1;
    end else begin
      safe_fifo_aclr <= 1'b0;
    end
  end

  // 4. 在 125MHz 域生成 UDP 状态机的单周期帧清空脉冲
  reg eth_vs_d1, eth_vs_d2, eth_vs_d3;
  always @(posedge clk_125m) begin
    if (sys_rst) begin
      eth_vs_d1 <= 1'b0;
      eth_vs_d2 <= 1'b0;
      eth_vs_d3 <= 1'b0;
    end else begin
      eth_vs_d1 <= algo_frame_vsync;  // 🌟 同步刚刚提取的算法帧起点
      eth_vs_d2 <= eth_vs_d1;
      eth_vs_d3 <= eth_vs_d2;
    end
  end
  wire eth_frame_vsync = eth_vs_d2 && !eth_vs_d3;

  // 5. 降维打击：将算法输出的 24位 RGB888 压缩为 16位 RGB565
  wire [15:0] algo_rgb565 = {
    HDMI_D[23:19],  // R 取高 5 位
    HDMI_D[15:10],  // G 取高 6 位
    HDMI_D[7:3]  // B 取高 5 位
  };

  // 6. 例化 16bit 异步 FIFO
  wire [15:0] eth_16b_data;
  wire eth_16b_empty;
  wire eth_16b_rdreq;

  fifo_async_16b u_fifo_16b (
      .aclr   (safe_fifo_aclr),
      .data   (algo_rgb565),     // 🌟 写入算法处理后并降维的数据
      .wrclk  (clk_hdmi),
      .wrreq  (HDMI_DE),         // 🌟 严格使用算法管线输出的数据有效信号
      .rdclk  (clk_125m),
      .rdreq  (eth_16b_rdreq),
      .q      (eth_16b_data),
      .rdempty(eth_16b_empty)
  );

  // 7. 125MHz 千兆网读取与拆包逻辑
  reg       eth_16b_rdreq_reg;
  reg       rdreq_d1;
  reg       sending_high;
  reg [7:0] eth_fifo_data;
  reg       eth_fifo_wrreq;

  always @(posedge clk_125m) begin
    if (sys_rst || eth_frame_vsync) begin
      eth_16b_rdreq_reg <= 1'b0;
    end else begin
      if (!eth_16b_empty && !eth_16b_rdreq_reg && !rdreq_d1) eth_16b_rdreq_reg <= 1'b1;
      else eth_16b_rdreq_reg <= 1'b0;
    end
  end
  assign eth_16b_rdreq = eth_16b_rdreq_reg;

  always @(posedge clk_125m) begin
    if (sys_rst || eth_frame_vsync) begin
      rdreq_d1 <= 1'b0;
      eth_fifo_wrreq <= 1'b0;
      sending_high <= 1'b0;
    end else begin
      rdreq_d1 <= eth_16b_rdreq_reg;
      if (rdreq_d1) begin
        eth_fifo_data  <= eth_16b_data[7:0];  // 先发低 8 位
        eth_fifo_wrreq <= 1'b1;
        sending_high   <= 1'b1;
      end else if (sending_high) begin
        eth_fifo_data  <= eth_16b_data[15:8];  // 再发高 8 位
        eth_fifo_wrreq <= 1'b1;
        sending_high   <= 1'b0;
      end else begin
        eth_fifo_wrreq <= 1'b0;
        sending_high   <= 1'b0;
      end
    end
  end

  // 8. 核心单播 UDP 发送
  wire [12:0] eth_wrusedw;
  UDP_Send u_udp_send (
      .Clk        (clk_125m),
      .Rst_n      (!sys_rst),
      .frame_vsync(eth_frame_vsync),

      // 🌟 必须是你电脑 Realtek 网卡的真实 MAC
      .des_mac(48'hB0_25_AA_64_A0_3F),
      .src_mac(48'h00_0A_35_01_FE_C0),

      .des_port(16'd8080),
      .src_port(16'd8080),

      // 🌟 必须是你电脑 Realtek 网卡的真实 IPv4
      .des_ip({8'd192, 8'd168, 8'd1, 8'd100}),
      .src_ip({8'd192, 8'd168, 8'd1, 8'd10}),

      .data_length(16'd1200),
      .GMII_GTXC  (),
      .GMII_TXD   (E_TXD),
      .GMII_TXEN  (E_TXEN),
      .wrclk      (clk_125m),
      .wrreq      (eth_fifo_wrreq),
      .wrdata     (eth_fifo_data),
      .wrusedw    (eth_wrusedw)
  );


  // uart_tx #(
  //     .CLK_FRE(100),
  //     .BAUD_RATE(1000000),
  //     .DATA_WIDTH(8)
  // ) u_tx (
  //     .i_clk_sys(clk_sys),
  //     .i_rst(sys_rst),
  //     .i_tx_data(8'd0),
  //     .i_tx_en(1'b0),
  //     .o_uart_tx(uart_tx),
  //     .o_tx_busy()
  // );

endmodule
