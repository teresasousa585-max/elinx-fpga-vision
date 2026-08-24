// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：mdio_com.v
// 主要模块：mdio_com
// 功能分类：以太网 PHY
// 功能说明：实现 MDC/MDIO 管理接口的寄存器读写时序。
// 输入概述：视频/协议载荷、发送触发、PHY 管理数据及系统时钟。
// 输出概述：以太网发送数据、CRC、MDIO 控制或 PHY 初始化状态。
// 时序约束：发送状态机与 PHY 接口时钟同步；帧边界和 CRC 覆盖范围不得随意修改。
// 关联文件：phy_reg_config.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ps / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07-04-2025 21:11:58
// Design Name:
// Module Name: mdio_com
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


//mdc, mdio数据传输时序代码
module mdio_com (
    input             mdc,        // mdc控制接口传输所需时钟，此处为20khz
    inout             mdio,
    input             reset_n,
    input      [23:0] mdio_data,  // mdio接口传输的24位数据
    input             start,      // 开始传输标志
    output reg        tr_end      // 传输结束标志
);

  reg [5:0] cyc_count;
  reg       reg_mdio;

  // 当reg_mdio为0时，驱动MDIO线为低电平；为1时，释放总线（高阻态'bz'）
  // 外部的上拉电阻会将总线拉高，形成逻辑'1'
  assign mdio = reg_mdio ? 1'bz : 1'b0;

  always @(posedge mdc or negedge reset_n) begin
    if (!reset_n) cyc_count <= 6'b111111;
    else begin
      if (start == 0) cyc_count <= 0;
      else if (cyc_count < 6'b111111) cyc_count <= cyc_count + 1;
    end
  end

  always @(negedge mdc or negedge reset_n) begin
    if (!reset_n) begin
      tr_end   <= 0;
      reg_mdio <= 1;  // 默认释放总线
    end else
      case (cyc_count)
        0: begin
          tr_end   <= 0;
          reg_mdio <= 1;
        end
        1: reg_mdio <= 1'b0;  // 开始传输 Start Bit 0
        2: reg_mdio <= 1'b1;  // Start Bit 1
        3: reg_mdio <= 1'b0;  // OP CODE 01=write
        4: reg_mdio <= 1'b1;

        // --- 地址修正 ---
        // 根据原理图，PHY地址为00001
        5: reg_mdio <= 1'b0;  // PHY ADDRESS [4] = 0
        6: reg_mdio <= 1'b0;  // PHY ADDRESS [3] = 0
        7: reg_mdio <= 1'b0;  // PHY ADDRESS [2] = 0
        8: reg_mdio <= 1'b0;  // PHY ADDRESS [1] = 0
        9: reg_mdio <= 1'b1;  // PHY ADDRESS [0] = 1

        10:      reg_mdio <= mdio_data[20];  // reg adress 5bit
        11:      reg_mdio <= mdio_data[19];
        12:      reg_mdio <= mdio_data[18];
        13:      reg_mdio <= mdio_data[17];
        14:      reg_mdio <= mdio_data[16];
        15:      reg_mdio <= 1'b1;  // turn around
        16:      reg_mdio <= 1'b0;
        17:      reg_mdio <= mdio_data[15];  // reg data
        18:      reg_mdio <= mdio_data[14];
        19:      reg_mdio <= mdio_data[13];
        20:      reg_mdio <= mdio_data[12];
        21:      reg_mdio <= mdio_data[11];
        22:      reg_mdio <= mdio_data[10];
        23:      reg_mdio <= mdio_data[9];
        24:      reg_mdio <= mdio_data[8];
        25:      reg_mdio <= mdio_data[7];
        26:      reg_mdio <= mdio_data[6];
        27:      reg_mdio <= mdio_data[5];
        28:      reg_mdio <= mdio_data[4];
        29:      reg_mdio <= mdio_data[3];
        30:      reg_mdio <= mdio_data[2];
        31:      reg_mdio <= mdio_data[1];
        32:      reg_mdio <= mdio_data[0];
        33: begin
          reg_mdio <= 1'b1;
          tr_end   <= 1;
        end
        default: reg_mdio <= 1'b1;  // 传输结束后，保持总线释放
      endcase
  end
endmodule
