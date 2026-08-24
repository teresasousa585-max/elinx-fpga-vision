// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
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


// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：通过 MDIO 配置 PHY 工作模式，并向系统报告初始化完成状态。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：协议字段、有效脉冲和跨时钟控制必须成组更新，并与上位机及外设时序保持一致。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 phy_reg_config：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module phy_reg_config (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input      clock_50m,
    input      reset_n,
    output     phy_mdc,
    inout      phy_mdio,
    output reg config_done
);

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg clock_20k;
  reg [15:0] clock_20k_cnt;
  reg [1:0] config_step;
  reg [3:0] reg_index;
  reg [23:0] mdio_data;
  reg [23:0] reg_data;
  reg start;

  // [Ethereal注释] 组合连线组 1：从 phy_mdc 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign phy_mdc = clock_20k;


  // [Ethereal注释] 子模块例化 1（mdio_com）：实现 MDC/MDIO 管理接口的寄存器读写时序。
  mdio_com u1 (
      .reset_n(reset_n),
      .mdio_data(mdio_data),
      .start(start),
      .tr_end(tr_end),
      .mdc(clock_20k),
      .mdio(phy_mdio)
  );



  //产生i2c控制时钟-20khz  
  // [Ethereal注释] 时序过程 1：由 clock_50m posedge，reset_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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

  // [Ethereal注释] 时序过程 2：由 clock_20k posedge，reset_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clock_20k or negedge reset_n) begin
    if (!reset_n) begin
      config_step <= 0;
      start <= 0;
      reg_index <= 0;
      config_done <= 1'b0;  // 新增：复位时完成标志为0
    end else begin
      if (reg_index < 12) begin  // 仍在配置过程中
        config_done <= 1'b0;  // 保持完成标志为0
        // [Ethereal注释] 分支选择 1：依据 config_step 选择状态或算法路径；default 覆盖非法或空闲条件。
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


  // [Ethereal注释] 时序过程 3：由 敏感表指定事件 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(reg_index) begin
    // [Ethereal注释] 分支选择 2：依据 reg_index 选择状态或算法路径；default 覆盖非法或空闲条件。
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

