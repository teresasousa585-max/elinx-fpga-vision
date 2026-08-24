// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：phy_reg_config.v
// 主要模块：phy_reg_config
// 功能分类：以太网 PHY
// 功能说明：通过 MDIO 配置 PHY 工作模式，并向系统报告初始化完成状态。
// 输入概述：视频/协议载荷、发送触发、PHY 管理数据及系统时钟。
// 输出概述：以太网发送数据、CRC、MDIO 控制或 PHY 初始化状态。
// 时序约束：发送状态机与 PHY 接口时钟同步；帧边界和 CRC 覆盖范围不得随意修改。
// 关联文件：mdio_com.v、UDP_Send.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ps / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07-04-2025 21:11:31
// Design Name:
// Module Name: phy_reg_config
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module phy_reg_config (
    input      clock_50m,
    input      reset_n,
    output     phy_mdc,
    inout      phy_mdio,
    output reg config_done
);

  reg clock_20k;
  reg [15:0] clock_20k_cnt;
  reg [1:0] config_step;
  reg [3:0] reg_index;
  reg [23:0] mdio_data;
  reg [23:0] reg_data;
  reg start;

  assign phy_mdc = clock_20k;


  mdio_com u1 (
      .reset_n(reset_n),
      .mdio_data(mdio_data),
      .start(start),
      .tr_end(tr_end),
      .mdc(clock_20k),
      .mdio(phy_mdio)
  );



  //产生i2c控制时钟-20khz  
  always @(posedge clock_50m or negedge reset_n) begin
    if (!reset_n) begin
      clock_20k <= 0;
      clock_20k_cnt <= 0;
    end else if (clock_20k_cnt < 2499) clock_20k_cnt <= clock_20k_cnt + 1;
    else begin
      clock_20k <= !clock_20k;
      clock_20k_cnt <= 0;
    end
  end

  always @(posedge clock_20k or negedge reset_n) begin
    if (!reset_n) begin
      config_step <= 0;
      start <= 0;
      reg_index <= 0;
      config_done <= 1'b0;  // 新增：复位时完成标志为0
    end else begin
      if (reg_index < 12) begin  // 仍在配置过程中
        config_done <= 1'b0;  // 保持完成标志为0
        case (config_step)
          0: begin
            mdio_data <= reg_data;
            start <= 1;
            config_step <= 1;
          end
          1: begin
            if (tr_end) begin
              config_step <= 2;
              start <= 0;
            end
          end
          2: begin
            reg_index   <= reg_index + 1;
            config_step <= 0;
          end
        endcase
      end else begin  // reg_index 已达到12，说明所有寄存器配置完成
        config_done <= 1'b1;  // 新增：置位完成标志
      end
    end
  end


  always @(reg_index) begin
    case (reg_index)
      0:       reg_data <= 24'h1f0005;  //Reg31 = 0x0005(disable EEE)
      1:       reg_data <= 24'h058b85;  //Reg5 = 0x8B85(disable EEE)
      2:       reg_data <= 24'h060ae2;  //Reg6 = 0x0AE2(disable EEE)
      3:       reg_data <= 24'h1f0007;  //Reg31 =0x0007(disable EEE)	  
      4:       reg_data <= 24'h1e0020;  //Reg30 =0x0020(disable EEE)	  
      5:       reg_data <= 24'h151008;  //Reg21 =0x1008(disable EEE)
      6:       reg_data <= 24'h1e0000;  //Reg30 =0x0000(disable EEE)
      7:       reg_data <= 24'h0d0007;  //Reg13 =0x0007(disable EEE)
      8:       reg_data <= 24'h0e003c;  //Reg14 =0x003C(disable EEE)
      9:       reg_data <= 24'h0d4007;  //Reg13 =0x4007(disable EEE)	
      10:      reg_data <= 24'h0e0000;  //Reg14 =0x0000(disable EEE)			  
      //  11:reg_data<=24'h090000; 		  //Reg9 =0x0000
      11:      reg_data <= 24'h001340;  //Reg0 =0x1340(restart auto-negatiation)
      default: reg_data <= 24'h000000;
    endcase
  end
endmodule

