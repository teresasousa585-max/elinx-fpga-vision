// =============================================================================
// 文件名称：sdram_fifo_ctrl.v
// 主要模块：sdram_fifo_ctrl
// 功能说明：协调 SDRAM 读写 FIFO 与帧地址切换。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module sdram_fifo_ctrl (
    input wire I_ref_clk,  // �ο�ʱ��
    input wire I_rst_n,    // ϵͳ��λ,�͵�ƽ��Ч

    // д����:�ⲿ-->FIFO
    input wire        I_fifo_wr_clk,   // fifoдʱ��
    input wire        I_fifo_wr_req,   // д��fifo����
    input wire [15:0] I_fifo_wr_data,  // д��fifo������
    input wire [23:0] I_wr_saddr,      // д��sdram����ʼ��ַ
    input wire [23:0] I_wr_eaddr,      // д��sdram����ֹ��ַ
    input wire [11:0] I_wr_brust,      // д��sdram��ͻ������
    input wire        I_fifo_wr_load,  // д��fifo�������

    // wr_fifo:FIFO(д)-->SDRAM(��)
    output reg         O_sdram_wr_req,   // ����д��sdramд����
    input  wire        I_sdram_wr_ack,   // ����д��sdramд��Ӧ
    output reg  [23:0] O_sdram_wr_addr,  // д���ݽ�sdram�ĵ�ַ
    output wire [15:0] O_sdram_wr_data,  // д��sdram������

    // rd_fifo:SDRAM(д)-->FIFO(��)
    output reg         O_sdram_rd_req,   // ���ݶ���sdram������
    input  wire        I_sdram_rd_ack,   // ���ݶ���sdram����Ӧ
    output reg  [23:0] O_sdram_rd_addr,  // �����ݽ�fifo�ĵ�ַ
    input  wire [15:0] I_sdram_rd_data,  // ����fifo������

    // ������:FIFO-->�ⲿ
    input  wire        I_fifo_rd_clk,   // ���ݶ���fifo��ʱ��
    input  wire        I_fifo_rd_req,   // ���ݶ���fifo������
    output wire [15:0] O_fifo_rd_data,  // ����fifo������
    input  wire [23:0] I_rd_saddr,      // ����sdram����ʼ��ַ
    input  wire [23:0] I_rd_eaddr,      // ����sdram����ֹ��ַ
    input  wire [11:0] I_rd_brust,      // ����sdram��ͻ������
    input  wire        I_fifo_rd_load,  // ����fifo�������

    // sdram
    input wire I_sdram_init_done,   // sdram��ʼ�����
    input wire I_sdram_rd_valid,    // sdram���ݶ�ʹ��
    input wire I_sdram_pingpang_en  // sdramƹ�Ҳ���ʹ��
);

  // дfifo��������źŻ���
  reg fifo_wr_load_r1;
  reg fifo_wr_load_r2;
  // ��fifo������ջ���
  reg fifo_rd_load_r1;
  reg fifo_rd_load_r2;
  // sdramд��Ӧ�źŻ���
  reg sdram_wr_ack1;
  reg sdram_wr_ack2;
  // sdram����Ӧ�źŻ���
  reg sdram_rd_ack1;
  reg sdram_rd_ack2;
  // sdram��ʹ���ź�
  reg sdram_rd_valid1;
  reg sdram_rd_valid2;

  // дfifo��������ź�������
  wire fifo_wr_load_p;
  // ��fifo��������ź�������
  wire fifo_rd_load_p;
  // дsdram��Ӧ�ź��½���
  wire sdram_wr_ack_n;
  // ��sdram��Ӧ�ź��½���
  wire sdram_rd_ack_n;

  // sdram_wr_fifo
  wire [11:0] wr_fifo_use;
  // sdram_rd_fifo
  wire [11:0] rd_fifo_use;

  // -------------------------------------------------------------
  // �źŴ�������ؼ��
  // -------------------------------------------------------------
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      fifo_wr_load_r1 <= 1'b0;
      fifo_wr_load_r2 <= 1'b0;
    end else begin
      fifo_wr_load_r1 <= I_fifo_wr_load;
      fifo_wr_load_r2 <= fifo_wr_load_r1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      fifo_rd_load_r1 <= 1'b0;
      fifo_rd_load_r2 <= 1'b0;
    end else begin
      fifo_rd_load_r1 <= I_fifo_rd_load;
      fifo_rd_load_r2 <= fifo_rd_load_r1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_wr_ack1 <= 1'b0;
      sdram_wr_ack2 <= 1'b0;
    end else begin
      sdram_wr_ack1 <= I_sdram_wr_ack;
      sdram_wr_ack2 <= sdram_wr_ack1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_rd_ack1 <= 1'b0;
      sdram_rd_ack2 <= 1'b0;
    end else begin
      sdram_rd_ack1 <= I_sdram_rd_ack;
      sdram_rd_ack2 <= sdram_rd_ack1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_rd_valid1 <= 1'b0;
      sdram_rd_valid2 <= 1'b0;
    end else begin
      sdram_rd_valid1 <= I_sdram_rd_valid;
      sdram_rd_valid2 <= sdram_rd_valid1;
    end
  end

  // ������ȡ��ֵ
  assign fifo_wr_load_p = (~fifo_wr_load_r2) & fifo_wr_load_r1;
  assign fifo_rd_load_p = (~fifo_rd_load_r2) & fifo_rd_load_r1;
  assign sdram_wr_ack_n = sdram_wr_ack2 & (~sdram_wr_ack1);
  assign sdram_rd_ack_n = sdram_rd_ack2 & (~sdram_rd_ack1);

  // =========================================================================
  // ? ����ʱ���Ż������ӼĴ���ն�Ϲ���������߼�
  // ��ǰ�����������������������һ����ʱ������ȥ�㣬������� 8.0ns Υ�棡
  // =========================================================================
  reg [23:0] wr_end_threshold;
  reg [23:0] rd_end_threshold;
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      wr_end_threshold <= 24'd0;
      rd_end_threshold <= 24'd0;
    end else begin
      wr_end_threshold <= I_wr_eaddr - I_wr_brust;
      rd_end_threshold <= I_rd_eaddr - I_rd_brust;
    end
  end

  // ƹ�Ҳ��� - д���ַ�߼� (����֡����ǿ���л�)
  reg rw_bank_flag;  // 0:дBank0, 1:дBank1

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      O_sdram_wr_addr <= 24'd0;
      rw_bank_flag    <= 1'b0;
    end else if (fifo_wr_load_p) begin
      // �յ�����ͷ��һ֡����˲�䣬ǿ�Ʒ�תBank��־
      if (I_sdram_pingpang_en) begin
        O_sdram_wr_addr <= {~rw_bank_flag, I_wr_saddr[22:0]};
        rw_bank_flag    <= ~rw_bank_flag;
      end else begin
        O_sdram_wr_addr <= I_wr_saddr;
      end
    end else if (sdram_wr_ack_n) begin
      // ? �����޸ģ�ʹ����ǰ��õļĴ��� wr_end_threshold�����涯̬����
      if (O_sdram_wr_addr[22:0] < wr_end_threshold[22:0]) begin
        O_sdram_wr_addr <= O_sdram_wr_addr + I_wr_brust;
      end else begin
        // ��֡�����ǰд������ַ�ؾ�����ǰBank��ͷ���ȴ���һ֡
        O_sdram_wr_addr <= {O_sdram_wr_addr[23], I_wr_saddr[22:0]};
      end
    end
  end

  // ƹ�Ҳ��� - ��ȡ��ַ�߼�
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      O_sdram_rd_addr <= 24'd0;
    end else if (fifo_rd_load_p) begin
      // �յ�HDMI��֡���ʱ��ȥ������ͷ��һ������д���Bank����������д��Bank��
      if (I_sdram_pingpang_en) begin
        O_sdram_rd_addr <= {~rw_bank_flag, I_rd_saddr[22:0]};
      end else begin
        O_sdram_rd_addr <= I_rd_saddr;
      end
    end else if (sdram_rd_ack_n) begin
      // ???? �����޸ģ�ʹ����ǰ��õļĴ��� rd_end_threshold�����涯̬����
      if (O_sdram_rd_addr[22:0] < rd_end_threshold[22:0]) begin
        O_sdram_rd_addr <= O_sdram_rd_addr + I_rd_brust;
      end else begin
        O_sdram_rd_addr <= {O_sdram_rd_addr[23], I_rd_saddr[22:0]};
      end
    end
  end

  // sdram��д�������ģ�� 
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      O_sdram_wr_req <= 1'b0;
      O_sdram_rd_req <= 1'b0;
    end else if (I_sdram_init_done) begin
      // ��������(HDMI)���ڵ�һλ,���Ա�֤��Ƶ�����Ϲ�
      //ע�⣺���������γ��ԣ�����rd_fifo_use < I_wr_brust�������κ��޸ģ�
      if ((rd_fifo_use < I_wr_brust) && sdram_rd_valid2) begin
        O_sdram_rd_req <= 1'b1;
        O_sdram_wr_req <= 1'b0;
      end  // ����������󣬲Ŵ���д����(����ͷ)
      else if (wr_fifo_use >= I_wr_brust) begin
        O_sdram_wr_req <= 1'b1;
        O_sdram_rd_req <= 1'b0;
      end else begin
        O_sdram_wr_req <= 1'b0;
        O_sdram_rd_req <= 1'b0;
      end
    end else begin
      O_sdram_wr_req <= 1'b0;
      O_sdram_rd_req <= 1'b0;
    end
  end

  // ����ʱ���Ż������Ĵ���ֱ���ĵ������첽��λ
  // ���� D ���������첽��λ������ȫ�� I_rst_n����������߼�����ţ� BY Ethereal��
  reg wr_fifo_aclr_reg;
  reg rd_fifo_aclr_reg;

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      // 1. ȫ��Ӳ����λʱ���Ĵ������첽�� 1�����ݸ� FIFO
      wr_fifo_aclr_reg <= 1'b1;
      rd_fifo_aclr_reg <= 1'b1;
    end else begin
      // 2. ��������ʱ��ץȡ 1 �����ڵĵ����� (��չ������������)
      wr_fifo_aclr_reg <= fifo_wr_load_p;
      rd_fifo_aclr_reg <= fifo_rd_load_p;
    end
  end

  wire wr_fifo_aclr_global;
  wire rd_fifo_aclr_global;

  //ʹ�� Altera/�ں�΢ ��ϵ��ȫ���ź�ԭ��
  GLOBAL u_global_wr (
      .in (wr_fifo_aclr_reg),
      .out(wr_fifo_aclr_global)
  );

  GLOBAL u_global_rd (
      .in (rd_fifo_aclr_reg),
      .out(rd_fifo_aclr_global)
  );

  // FIFO ������ֻ����������ļĴ�����
  sdram_wr_fifo sdram_wr_fifo_inst (
      .wrclk  (I_fifo_wr_clk),
      .wrreq  (I_fifo_wr_req),
      .data   (I_fifo_wr_data),
      .rdclk  (I_ref_clk),
      .rdreq  (I_sdram_wr_ack),
      .q      (O_sdram_wr_data),
      .aclr   (wr_fifo_aclr_global),  // ������߼�
      .rdusedw(wr_fifo_use)
  );

  sdram_rd_fifo sdram_rd_fifo_inst (
      .wrclk  (I_ref_clk),
      .wrreq  (I_sdram_rd_ack),
      .data   (I_sdram_rd_data),
      .rdclk  (I_fifo_rd_clk),
      .rdreq  (I_fifo_rd_req),
      .q      (O_fifo_rd_data),
      .aclr   (rd_fifo_aclr_global),  // ������߼�
      .wrusedw(rd_fifo_use)
  );

endmodule

// `timescale 1ns / 1ps

// module sdram_fifo_ctrl (
//     input wire I_ref_clk,  // �ο�ʱ�� [cite: 1]
//     input wire I_rst_n,    // ϵͳ��λ,�͵�ƽ��Ч [cite: 1]

//     // д����:�ⲿ-->FIFO [cite: 1]
//     input wire        I_fifo_wr_clk,   // fifoдʱ�� [cite: 1]
//     input wire        I_fifo_wr_req,   // д��fifo���� [cite: 1]
//     input wire [15:0] I_fifo_wr_data,  // д��fifo������ [cite: 1]
//     input wire [23:0] I_wr_saddr,      // д��sdram����ʼ��ַ [cite: 1]
//     input wire [23:0] I_wr_eaddr,      // д��sdram����ֹ��ַ [cite: 1, 2]
//     input wire [11:0] I_wr_brust,      // д��sdram��ͻ������ [cite: 2]
//     input wire        I_fifo_wr_load,  // д��fifo������� [cite: 2]

//     // wr_fifo:FIFO(д)-->SDRAM(��) [cite: 2]
//     output reg         O_sdram_wr_req,   // ����д��sdramд���� [cite: 2]
//     input  wire        I_sdram_wr_ack,   // ����д��sdramд��Ӧ [cite: 2]
//     output reg  [23:0] O_sdram_wr_addr,  // д���ݽ�sdram�ĵ�ַ [cite: 2]
//     output wire [15:0] O_sdram_wr_data,  // д��sdram������ [cite: 2]

//     // rd_fifo:SDRAM(д)-->FIFO(��) [cite: 2]
//     output reg         O_sdram_rd_req,   // ���ݶ���sdram������ [cite: 3]
//     input  wire        I_sdram_rd_ack,   // ���ݶ���sdram����Ӧ [cite: 3]
//     output reg  [23:0] O_sdram_rd_addr,  // �����ݽ�fifo�ĵ�ַ [cite: 3]
//     input  wire [15:0] I_sdram_rd_data,  // ����fifo������ [cite: 3]

//     // ������:FIFO-->�ⲿ [cite: 3]
//     input  wire        I_fifo_rd_clk,   // ���ݶ���fifo��ʱ�� [cite: 3]
//     input  wire        I_fifo_rd_req,   // ���ݶ���fifo������ [cite: 3]
//     output wire [15:0] O_fifo_rd_data,  // ����fifo������ [cite: 4]
//     input  wire [23:0] I_rd_saddr,      // ����sdram����ʼ��ַ [cite: 4]
//     input  wire [23:0] I_rd_eaddr,      // ����sdram����ֹ��ַ [cite: 4]
//     input  wire [11:0] I_rd_brust,      // ����sdram��ͻ������ [cite: 4]
//     input  wire        I_fifo_rd_load,  // ����fifo������� [cite: 4]

//     // sdram [cite: 4]
//     input wire I_sdram_init_done,   // sdram��ʼ����� [cite: 4]
//     input wire I_sdram_rd_valid,    // sdram���ݶ�ʹ�� [cite: 4]
//     input wire I_sdram_pingpang_en  // sdramƹ�Ҳ���ʹ�� [cite: 5]
// );

//   // �źŴ�������ؼ��Ĵ��� [cite: 5, 6, 7]
//   reg fifo_wr_load_r1, fifo_wr_load_r2;
//   reg fifo_rd_load_r1, fifo_rd_load_r2;
//   reg sdram_wr_ack1, sdram_wr_ack2;
//   reg sdram_rd_ack1, sdram_rd_ack2;
//   reg sdram_rd_valid1, sdram_rd_valid2;

//   wire fifo_wr_load_p = (~fifo_wr_load_r2) & fifo_wr_load_r1;
//   wire fifo_rd_load_p = (~fifo_rd_load_r2) & fifo_rd_load_r1;
//   wire sdram_wr_ack_n = sdram_wr_ack2 & (~sdram_wr_ack1);
//   wire sdram_rd_ack_n = sdram_rd_ack2 & (~sdram_rd_ack1);

//   wire [11:0] wr_fifo_use;
//   wire [11:0] rd_fifo_use;

//   // -------------------------------------------------------------
//   // �źŴ����߼� [cite: 9-18]
//   // -------------------------------------------------------------
//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       fifo_wr_load_r1 <= 1'b0;
//       fifo_wr_load_r2 <= 1'b0;
//       fifo_rd_load_r1 <= 1'b0;
//       fifo_rd_load_r2 <= 1'b0;
//       sdram_wr_ack1   <= 1'b0;
//       sdram_wr_ack2   <= 1'b0;
//       sdram_rd_ack1   <= 1'b0;
//       sdram_rd_ack2   <= 1'b0;
//       sdram_rd_valid1 <= 1'b0;
//       sdram_rd_valid2 <= 1'b0;
//     end else begin
//       fifo_wr_load_r1 <= I_fifo_wr_load;
//       fifo_wr_load_r2 <= fifo_wr_load_r1;
//       fifo_rd_load_r1 <= I_fifo_rd_load;
//       fifo_rd_load_r2 <= fifo_rd_load_r1;
//       sdram_wr_ack1   <= I_sdram_wr_ack;
//       sdram_wr_ack2   <= sdram_wr_ack1;
//       sdram_rd_ack1   <= I_sdram_rd_ack;
//       sdram_rd_ack2   <= sdram_rd_ack1;
//       sdram_rd_valid1 <= I_sdram_rd_valid;
//       sdram_rd_valid2 <= sdram_rd_valid1;
//     end
//   end

//   // -------------------------------------------------------------
//   // �����Ż� 1����ֵԤ���� (�Ĵ������������) [cite: 21]
//   // -------------------------------------------------------------
//   reg [23:0] wr_end_threshold;
//   reg [23:0] rd_end_threshold;

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       wr_end_threshold <= 24'd0;
//       rd_end_threshold <= 24'd0;
//     end else begin
//       wr_end_threshold <= I_wr_eaddr - I_wr_brust;
//       rd_end_threshold <= I_rd_eaddr - I_rd_brust;
//     end
//   end

//   // -------------------------------------------------------------
//   // �����Ż� 2��ȫ��ַԤ���� (Next-Address Look-ahead)
//   // ��ǰ��á���һ������ַ������ ack_n ���嵽��ʱ�ıȽϺͼӷ��ӳ�
//   // -------------------------------------------------------------
//   reg [23:0] next_wr_addr;
//   reg [23:0] next_rd_addr;

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       next_wr_addr <= 24'd0;
//     end else if (O_sdram_wr_addr[22:0] < wr_end_threshold[22:0]) begin
//       next_wr_addr <= O_sdram_wr_addr + I_wr_brust;
//     end else begin
//       next_wr_addr <= {O_sdram_wr_addr[23], I_wr_saddr[22:0]};
//     end
//   end

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       next_rd_addr <= 24'd0;
//     end else if (O_sdram_rd_addr[22:0] < rd_end_threshold[22:0]) begin
//       next_rd_addr <= O_sdram_rd_addr + I_rd_brust;
//     end else begin
//       next_rd_addr <= {O_sdram_rd_addr[23], I_rd_saddr[22:0]};
//     end
//   end

//   // -------------------------------------------------------------
//   // ��ַ�����߼���ֱ��ʹ��Ԥ����õ� next_addr
//   // -------------------------------------------------------------
//   reg rw_bank_flag;  // 0:дBank0, 1:дBank1 [cite: 24, 25]

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       O_sdram_wr_addr <= 24'd0;
//       rw_bank_flag    <= 1'b0;
//     end else if (fifo_wr_load_p) begin
//       if (I_sdram_pingpang_en) begin
//         O_sdram_wr_addr <= {~rw_bank_flag, I_wr_saddr[22:0]};
//         rw_bank_flag    <= ~rw_bank_flag;
//       end else begin
//         O_sdram_wr_addr <= I_wr_saddr;
//       end
//     end else if (sdram_wr_ack_n) begin
//       // ��ʱû���καȽϺͼӷ���ֱ�ӼĴ�����ֵ��ʱ�����ԣ
//       O_sdram_wr_addr <= next_wr_addr;
//     end
//   end

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       O_sdram_rd_addr <= 24'd0;
//     end else if (fifo_rd_load_p) begin
//       if (I_sdram_pingpang_en) begin
//         O_sdram_rd_addr <= {~rw_bank_flag, I_rd_saddr[22:0]};
//       end else begin
//         O_sdram_rd_addr <= I_rd_saddr;
//       end
//     end else if (sdram_rd_ack_n) begin
//       O_sdram_rd_addr <= next_rd_addr;
//     end
//   end

//   // -------------------------------------------------------------
//   // sdram ��д������� [cite: 37-42]
//   // -------------------------------------------------------------
//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       O_sdram_wr_req <= 1'b0;
//       O_sdram_rd_req <= 1'b0;
//     end else if (I_sdram_init_done) begin
//       if ((rd_fifo_use < I_wr_brust) && sdram_rd_valid2) begin
//         O_sdram_rd_req <= 1'b1;
//         O_sdram_wr_req <= 1'b0;
//       end else if (wr_fifo_use >= I_wr_brust) begin
//         O_sdram_wr_req <= 1'b1;
//         O_sdram_rd_req <= 1'b0;
//       end else begin
//         O_sdram_wr_req <= 1'b0;
//         O_sdram_rd_req <= 1'b0;
//       end
//     end else begin
//       O_sdram_wr_req <= 1'b0;
//       O_sdram_rd_req <= 1'b0;
//     end
//   end

//   // -------------------------------------------------------------
//   // FIFO ��λ������ [cite: 43-50]
//   // -------------------------------------------------------------
//   reg wr_fifo_aclr_reg, rd_fifo_aclr_reg;
//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       wr_fifo_aclr_reg <= 1'b1;
//       rd_fifo_aclr_reg <= 1'b1;
//     end else begin
//       wr_fifo_aclr_reg <= fifo_wr_load_p;
//       rd_fifo_aclr_reg <= fifo_rd_load_p;
//     end
//   end

//   wire wr_fifo_aclr_global, rd_fifo_aclr_global;
//   GLOBAL u_global_wr (
//       .in (wr_fifo_aclr_reg),
//       .out(wr_fifo_aclr_global)
//   );
//   GLOBAL u_global_rd (
//       .in (rd_fifo_aclr_reg),
//       .out(rd_fifo_aclr_global)
//   );

//   sdram_wr_fifo sdram_wr_fifo_inst (
//       .wrclk(I_fifo_wr_clk),
//       .wrreq(I_fifo_wr_req),
//       .data(I_fifo_wr_data),
//       .rdclk(I_ref_clk),
//       .rdreq(I_sdram_wr_ack),
//       .q(O_sdram_wr_data),
//       .aclr(wr_fifo_aclr_global),
//       .rdusedw(wr_fifo_use)
//   );

//   sdram_rd_fifo sdram_rd_fifo_inst (
//       .wrclk(I_ref_clk),
//       .wrreq(I_sdram_rd_ack),
//       .data(I_sdram_rd_data),
//       .rdclk(I_fifo_rd_clk),
//       .rdreq(I_fifo_rd_req),
//       .q(O_fifo_rd_data),
//       .aclr(rd_fifo_aclr_global),
//       .wrusedw(rd_fifo_use)
//   );

// endmodule
