// =============================================================================
// 文件名称：ov5640_i2c_init.v
// 主要模块：ov5640_i2c_init
// 功能说明：通过 I2C 配置 OV5640 工作模式和图像参数。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module ov5640_i2c_init #(
    parameter CLK_FRE = 100  // 系统时钟频率，默认 100MHz
) (
    input wire i_clk,
    input wire i_rst,

    // 动态翻转控制端 (0:正常, 1:180度全画幅翻转)
    input wire i_flip_en,

    inout  wire io_i2c_scl,
    inout  wire io_i2c_sda,
    output reg  o_init_done
);

  localparam DEV_ADDR = 8'h78;  // OV5640 写地址
  localparam REG_NUM = 251;  // 初始化寄存器总数

  localparam DIV_CNT_MAX = (CLK_FRE * 1_000_000) / 400_000 - 1;
  localparam DELAY_MAX = 800;

  reg [15:0] clk_cnt;
  reg i2c_tick;

  always @(posedge i_clk) begin
    if (i_rst) begin
      clk_cnt  <= 0;
      i2c_tick <= 0;
    end else if (clk_cnt >= DIV_CNT_MAX) begin
      clk_cnt  <= 0;
      i2c_tick <= 1'b1;
    end else begin
      clk_cnt  <= clk_cnt + 1'b1;
      i2c_tick <= 1'b0;
    end
  end

  // 翻转信号边沿检测与动态更新请求
  reg flip_en_d1, flip_en_d2;
  reg flip_req;  // 动态更新请求标志
  reg [1:0] flip_step;

  always @(posedge i_clk) begin
    if (i_rst) begin
      flip_en_d1 <= 0;
      flip_en_d2 <= 0;
      flip_req   <= 0;
    end else begin
      flip_en_d1 <= i_flip_en;
      flip_en_d2 <= flip_en_d1;

      // 当初始化完成后，检测到跳变，发起动态修改请求
      if (o_init_done && (flip_en_d1 != flip_en_d2)) begin
        flip_req <= 1'b1;
      end  // 当动态发送完成(flip_step==2)且处于空闲状态时，清除请求
      else if (state == S_IDLE && flip_step == 2'd2) begin
        flip_req <= 1'b0;
      end
    end
  end

  // I2C 状态机
  localparam S_IDLE = 0, S_START = 1, S_SEND_BYTE = 2, S_ACK = 3, S_STOP = 4;
  reg [2:0] state;
  reg [1:0] step;
  reg [3:0] bit_cnt;
  reg [1:0] byte_cnt;
  reg [7:0] tx_data;
  reg r_scl, r_sda;
  reg [31:0] delay_cnt;
  reg [ 8:0] lut_index;

  assign io_i2c_scl = r_scl;
  assign io_i2c_sda = r_sda ? 1'bz : 1'b0;

  reg [23:0] lut_data;  // 传统 LUT 输出
  reg [23:0] current_config;  // 真正送进 I2C 总线的数据

  always @(posedge i_clk) begin
    if (i_rst) begin
      state       <= S_IDLE;
      step        <= 0;
      bit_cnt     <= 0;
      byte_cnt    <= 0;
      r_scl       <= 1'b1;
      r_sda       <= 1'b1;
      delay_cnt   <= 0;
      lut_index   <= 0;
      o_init_done <= 1'b0;
      flip_step   <= 2'd0;
    end else begin
      if (i2c_tick) begin
        case (state)
          S_IDLE: begin
            r_scl <= 1'b1;
            r_sda <= 1'b1;

            if (lut_index < REG_NUM) begin
              // 阶段1：开机初始化 (读取传统的 LUT)
              if (delay_cnt < DELAY_MAX) begin
                delay_cnt <= delay_cnt + 1'b1;
              end else begin
                delay_cnt <= 0;
                current_config <= lut_data;  // 装载静态 LUT 数据
                state <= S_START;
              end
            end else begin
              o_init_done <= 1'b1;
              // 阶段2：监听动态翻转请求
              if (flip_req) begin
                if (flip_step == 2'd0) begin
                  // 第一步：发送 V-Flip 寄存器
                  current_config <= i_flip_en ? 24'h382041 : 24'h382047;
                  state <= S_START;
                end else if (flip_step == 2'd1) begin
                  // 第二步：发送 H-Mirror 寄存器
                  current_config <= i_flip_en ? 24'h382100 : 24'h382106;
                  state <= S_START;
                end
              end else begin
                flip_step <= 2'd0;  // 没请求时复位步骤
              end
            end
          end

          S_START: begin
            case (step)
              0: begin
                r_scl <= 1'b1;
                r_sda <= 1'b1;
                step  <= 1;
              end
              1: begin
                r_scl <= 1'b1;
                r_sda <= 1'b0;
                step  <= 2;
              end
              2: begin
                r_scl <= 1'b0;
                r_sda <= 1'b0;
                step  <= 3;
              end
              3: begin
                step <= 0;
                state <= S_SEND_BYTE;
                byte_cnt <= 0;
                bit_cnt <= 0;
                tx_data <= DEV_ADDR;
              end
            endcase
          end

          S_SEND_BYTE: begin
            case (step)
              0: begin
                r_scl <= 1'b0;
                r_sda <= tx_data[7-bit_cnt];
                step  <= 1;
              end
              1: begin
                r_scl <= 1'b1;
                step  <= 2;
              end
              2: begin
                r_scl <= 1'b1;
                step  <= 3;
              end
              3: begin
                r_scl <= 1'b0;
                if (bit_cnt == 7) begin
                  bit_cnt <= 0;
                  state   <= S_ACK;
                end else begin
                  bit_cnt <= bit_cnt + 1'b1;
                end
                step <= 0;
              end
            endcase
          end

          S_ACK: begin
            case (step)
              0: begin
                r_scl <= 1'b0;
                r_sda <= 1'b1;
                step  <= 1;
              end
              1: begin
                r_scl <= 1'b1;
                step  <= 2;
              end
              2: begin
                r_scl <= 1'b1;
                step  <= 3;
              end
              3: begin
                r_scl <= 1'b0;
                step  <= 0;
                // 使用装载好的 current_config 拆包发送
                if (byte_cnt == 0) begin
                  tx_data <= current_config[23:16];
                  byte_cnt <= 1;
                  state <= S_SEND_BYTE;
                end else if (byte_cnt == 1) begin
                  tx_data <= current_config[15:8];
                  byte_cnt <= 2;
                  state <= S_SEND_BYTE;
                end else if (byte_cnt == 2) begin
                  tx_data <= current_config[7:0];
                  byte_cnt <= 3;
                  state <= S_SEND_BYTE;
                end else begin
                  state <= S_STOP;
                end
              end
            endcase
          end

          S_STOP: begin
            case (step)
              0: begin
                r_scl <= 1'b0;
                r_sda <= 1'b0;
                step  <= 1;
              end
              1: begin
                r_scl <= 1'b1;
                r_sda <= 1'b0;
                step  <= 2;
              end
              2: begin
                r_scl <= 1'b1;
                r_sda <= 1'b1;
                step  <= 3;
              end
              3: begin
                step  <= 0;
                state <= S_IDLE;
                if (!o_init_done) begin
                  lut_index <= lut_index + 1'b1;  // 初始化阶段索引递增
                end else if (flip_req) begin
                  flip_step <= flip_step + 1'b1;  // 动态更新阶段步骤递增
                end
              end
            endcase
          end
        endcase
      end
    end
  end

  //LUT表
  always @(*) begin
    case (lut_index)
      10'd0:   lut_data = 24'h310311;
      10'd1:   lut_data = 24'h300882;
      10'd2:   lut_data = 24'h300842;
      10'd3:   lut_data = 24'h310303;
      10'd4:   lut_data = 24'h3017ff;
      10'd5:   lut_data = 24'h3018ff;
      10'd6:   lut_data = 24'h30341A;
      10'd7:   lut_data = 24'h303713;
      10'd8:   lut_data = 24'h310801;
      10'd9:   lut_data = 24'h363036;
      10'd10:  lut_data = 24'h36310e;
      10'd11:  lut_data = 24'h3632e2;
      10'd12:  lut_data = 24'h363312;
      10'd13:  lut_data = 24'h3621e0;
      10'd14:  lut_data = 24'h3704a0;
      10'd15:  lut_data = 24'h37035a;
      10'd16:  lut_data = 24'h371578;
      10'd17:  lut_data = 24'h371701;
      10'd18:  lut_data = 24'h370b60;
      10'd19:  lut_data = 24'h37051a;
      10'd20:  lut_data = 24'h390502;
      10'd21:  lut_data = 24'h390610;
      10'd22:  lut_data = 24'h39010a;
      10'd23:  lut_data = 24'h373112;
      10'd24:  lut_data = 24'h360008;
      10'd25:  lut_data = 24'h360133;
      10'd26:  lut_data = 24'h302d60;
      10'd27:  lut_data = 24'h362052;
      10'd28:  lut_data = 24'h371b20;
      10'd29:  lut_data = 24'h471c50;
      10'd30:  lut_data = 24'h3a1343;
      10'd31:  lut_data = 24'h3a1800;
      10'd32:  lut_data = 24'h3a19f8;
      10'd33:  lut_data = 24'h363513;
      10'd34:  lut_data = 24'h363603;
      10'd35:  lut_data = 24'h363440;
      10'd36:  lut_data = 24'h362201;
      10'd37:  lut_data = 24'h3c0134;
      10'd38:  lut_data = 24'h3c0428;
      10'd39:  lut_data = 24'h3c0598;
      10'd40:  lut_data = 24'h3c0600;
      10'd41:  lut_data = 24'h3c0708;
      10'd42:  lut_data = 24'h3c0800;
      10'd43:  lut_data = 24'h3c091c;
      10'd44:  lut_data = 24'h3c0a9c;
      10'd45:  lut_data = 24'h3c0b40;
      10'd46:  lut_data = 24'h381000;
      10'd47:  lut_data = 24'h381110;
      10'd48:  lut_data = 24'h381200;
      10'd49:  lut_data = 24'h370864;
      10'd50:  lut_data = 24'h400102;
      10'd51:  lut_data = 24'h40051a;
      10'd52:  lut_data = 24'h300000;
      10'd53:  lut_data = 24'h3004ff;
      10'd54:  lut_data = 24'h300e58;
      10'd55:  lut_data = 24'h302e00;
      10'd56:  lut_data = 24'h430061;
      10'd57:  lut_data = 24'h501f01;
      10'd58:  lut_data = 24'h440e00;
      10'd59:  lut_data = 24'h5000a7;
      10'd60:  lut_data = 24'h3a0f30;
      10'd61:  lut_data = 24'h3a1028;
      10'd62:  lut_data = 24'h3a1b30;
      10'd63:  lut_data = 24'h3a1e26;
      10'd64:  lut_data = 24'h3a1160;
      10'd65:  lut_data = 24'h3a1f14;
      10'd66:  lut_data = 24'h580023;
      10'd67:  lut_data = 24'h580114;
      10'd68:  lut_data = 24'h58020f;
      10'd69:  lut_data = 24'h58030f;
      10'd70:  lut_data = 24'h580412;
      10'd71:  lut_data = 24'h580526;
      10'd72:  lut_data = 24'h58060c;
      10'd73:  lut_data = 24'h580708;
      10'd74:  lut_data = 24'h580805;
      10'd75:  lut_data = 24'h580905;
      10'd76:  lut_data = 24'h580a08;
      10'd77:  lut_data = 24'h580b0d;
      10'd78:  lut_data = 24'h580c08;
      10'd79:  lut_data = 24'h580d03;
      10'd80:  lut_data = 24'h580e00;
      10'd81:  lut_data = 24'h580f00;
      10'd82:  lut_data = 24'h581003;
      10'd83:  lut_data = 24'h581109;
      10'd84:  lut_data = 24'h581207;
      10'd85:  lut_data = 24'h581303;
      10'd86:  lut_data = 24'h581400;
      10'd87:  lut_data = 24'h581501;
      10'd88:  lut_data = 24'h581603;
      10'd89:  lut_data = 24'h581708;
      10'd90:  lut_data = 24'h58180d;
      10'd91:  lut_data = 24'h581908;
      10'd92:  lut_data = 24'h581a05;
      10'd93:  lut_data = 24'h581b06;
      10'd94:  lut_data = 24'h581c08;
      10'd95:  lut_data = 24'h581d0e;
      10'd96:  lut_data = 24'h581e29;
      10'd97:  lut_data = 24'h581f17;
      10'd98:  lut_data = 24'h582011;
      10'd99:  lut_data = 24'h582111;
      10'd100: lut_data = 24'h582215;
      10'd101: lut_data = 24'h582328;
      10'd102: lut_data = 24'h582446;
      10'd103: lut_data = 24'h582526;
      10'd104: lut_data = 24'h582608;
      10'd105: lut_data = 24'h582726;
      10'd106: lut_data = 24'h582864;
      10'd107: lut_data = 24'h582926;
      10'd108: lut_data = 24'h582a24;
      10'd109: lut_data = 24'h582b22;
      10'd110: lut_data = 24'h582c24;
      10'd111: lut_data = 24'h582d24;
      10'd112: lut_data = 24'h582e06;
      10'd113: lut_data = 24'h582f22;
      10'd114: lut_data = 24'h583040;
      10'd115: lut_data = 24'h583142;
      10'd116: lut_data = 24'h583224;
      10'd117: lut_data = 24'h583326;
      10'd118: lut_data = 24'h583424;
      10'd119: lut_data = 24'h583522;
      10'd120: lut_data = 24'h583622;
      10'd121: lut_data = 24'h583726;
      10'd122: lut_data = 24'h583844;
      10'd123: lut_data = 24'h583924;
      10'd124: lut_data = 24'h583a26;
      10'd125: lut_data = 24'h583b28;
      10'd126: lut_data = 24'h583c42;
      10'd127: lut_data = 24'h583dce;
      10'd128: lut_data = 24'h5180ff;
      10'd129: lut_data = 24'h5181f2;
      10'd130: lut_data = 24'h518200;
      10'd131: lut_data = 24'h518314;
      10'd132: lut_data = 24'h518425;
      10'd133: lut_data = 24'h518524;
      10'd134: lut_data = 24'h518609;
      10'd135: lut_data = 24'h518709;
      10'd136: lut_data = 24'h518809;
      10'd137: lut_data = 24'h518975;
      10'd138: lut_data = 24'h518a54;
      10'd139: lut_data = 24'h518be0;
      10'd140: lut_data = 24'h518cb2;
      10'd141: lut_data = 24'h518d42;
      10'd142: lut_data = 24'h518e3d;
      10'd143: lut_data = 24'h518f56;
      10'd144: lut_data = 24'h519046;
      10'd145: lut_data = 24'h5191f8;
      10'd146: lut_data = 24'h519204;
      10'd147: lut_data = 24'h519370;
      10'd148: lut_data = 24'h5194f0;
      10'd149: lut_data = 24'h5195f0;
      10'd150: lut_data = 24'h519603;
      10'd151: lut_data = 24'h519701;
      10'd152: lut_data = 24'h519804;
      10'd153: lut_data = 24'h519912;
      10'd154: lut_data = 24'h519a04;
      10'd155: lut_data = 24'h519b00;
      10'd156: lut_data = 24'h519c06;
      10'd157: lut_data = 24'h519d82;
      10'd158: lut_data = 24'h519e38;
      10'd159: lut_data = 24'h548001;
      10'd160: lut_data = 24'h548108;
      10'd161: lut_data = 24'h548214;
      10'd162: lut_data = 24'h548328;
      10'd163: lut_data = 24'h548451;
      10'd164: lut_data = 24'h548565;
      10'd165: lut_data = 24'h548671;
      10'd166: lut_data = 24'h54877d;
      10'd167: lut_data = 24'h548887;
      10'd168: lut_data = 24'h548991;
      10'd169: lut_data = 24'h548a9a;
      10'd170: lut_data = 24'h548baa;
      10'd171: lut_data = 24'h548cb8;
      10'd172: lut_data = 24'h548dcd;
      10'd173: lut_data = 24'h548edd;
      10'd174: lut_data = 24'h548fea;
      10'd175: lut_data = 24'h54901d;
      10'd176: lut_data = 24'h53811e;
      10'd177: lut_data = 24'h53825b;
      10'd178: lut_data = 24'h538308;
      10'd179: lut_data = 24'h53840a;
      10'd180: lut_data = 24'h53857e;
      10'd181: lut_data = 24'h538688;
      10'd182: lut_data = 24'h53877c;
      10'd183: lut_data = 24'h53886c;
      10'd184: lut_data = 24'h538910;
      10'd185: lut_data = 24'h538a01;
      10'd186: lut_data = 24'h538b98;
      10'd187: lut_data = 24'h558006;
      10'd188: lut_data = 24'h558340;
      10'd189: lut_data = 24'h558410;
      10'd190: lut_data = 24'h558910;
      10'd191: lut_data = 24'h558a00;
      10'd192: lut_data = 24'h558bf8;
      10'd193: lut_data = 24'h501d40;
      10'd194: lut_data = 24'h530008;
      10'd195: lut_data = 24'h530130;
      10'd196: lut_data = 24'h530210;
      10'd197: lut_data = 24'h530300;
      10'd198: lut_data = 24'h530408;
      10'd199: lut_data = 24'h530530;
      10'd200: lut_data = 24'h530608;
      10'd201: lut_data = 24'h530716;
      10'd202: lut_data = 24'h530908;
      10'd203: lut_data = 24'h530a30;
      10'd204: lut_data = 24'h530b04;
      10'd205: lut_data = 24'h530c06;
      10'd206: lut_data = 24'h502500;
      // 1024x600 (WSVGA) 分辨率开窗设置
      10'd207: lut_data = 24'h300802;  // wake up from standby
      10'd208: lut_data = 24'h303511;  // PLL
      //  PLL 倍频， 50，黄金点，不要随便改
      10'd209: lut_data = 24'h303650;
      10'd210: lut_data = 24'h3c0708;
      10'd211: lut_data = i_flip_en ? 24'h382041 : 24'h382047;
      10'd212: lut_data = i_flip_en ? 24'h382100 : 24'h382106;
      10'd213: lut_data = 24'h381431;

      // PCLK 极性设置，如需反相可改为 h381501
      10'd214: lut_data = 24'h381531;

      // Window 设置 (保持全视场取景，ISP 自动缩放)
      10'd215: lut_data = 24'h380000;
      10'd216: lut_data = 24'h380100;
      10'd217: lut_data = 24'h380200;
      10'd218: lut_data = 24'h380300;  // X_ADDR_ST_L
      10'd219: lut_data = 24'h38040a;  // X_ADDR_END_H
      10'd220: lut_data = 24'h38053f;  // X_ADDR_END_L (2591)
      10'd221: lut_data = 24'h380607;  // Y_ADDR_END_H
      10'd222: lut_data = 24'h38079f;  // Y_ADDR_END_L (1951)

      // Output Size 设置 (1024x600) 
      10'd223: lut_data = 24'h380804;  // X_OUTPUT_SIZE_H (1024 -> 0x0400)
      10'd224: lut_data = 24'h380900;  // X_OUTPUT_SIZE_L (00)
      10'd225: lut_data = 24'h380a02;  // Y_OUTPUT_SIZE_H (600 -> 0x0258)
      10'd226: lut_data = 24'h380b58;  // Y_OUTPUT_SIZE_L (58)

      // Total Size 设置 (控制帧率和消隐期)
      // 多次尝试后的最佳值，别给我随便改
      10'd227: lut_data = 24'h380c0a;
      10'd228: lut_data = 24'h380d00;

      10'd229: lut_data = 24'h380e03;  // VTS_H
      10'd230: lut_data = 24'h380fd8;  // VTS_L (984)
      10'd231: lut_data = 24'h381306;
      10'd232: lut_data = 24'h361800;
      10'd233: lut_data = 24'h361229;
      10'd234: lut_data = 24'h370952;
      10'd235: lut_data = 24'h370c03;
      10'd236: lut_data = 24'h3a0217;
      10'd237: lut_data = 24'h3a0310;
      10'd238: lut_data = 24'h3a1417;
      10'd239: lut_data = 24'h3a1510;
      10'd240: lut_data = 24'h400402;
      10'd241: lut_data = 24'h30021c;
      10'd242: lut_data = 24'h3006c3;
      10'd243: lut_data = 24'h471303;
      10'd244: lut_data = 24'h440704;
      10'd245: lut_data = 24'h460b35;
      10'd246: lut_data = 24'h460c22;
      10'd247: lut_data = 24'h483722;
      10'd248: lut_data = 24'h382402;
      10'd249: lut_data = 24'h5001a3;
      10'd250: lut_data = 24'h350300;
      default: lut_data = 24'h000000;
    endcase
  end

endmodule
