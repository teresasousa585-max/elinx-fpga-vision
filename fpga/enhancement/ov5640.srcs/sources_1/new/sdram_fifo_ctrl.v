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
      if (O_sdram_wr_addr[22:0] < (I_wr_eaddr - I_wr_brust)) begin
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
      if (O_sdram_rd_addr[22:0] < (I_rd_eaddr - I_rd_brust)) begin
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
// -------------------------------------------------------------
  // ����ʱ���Ż������Ĵ���ֱ�� + ��ˮ�ߴ��Ļ�����ȳ�
  // -------------------------------------------------------------
  reg wr_fifo_aclr_reg_d1;
  reg rd_fifo_aclr_reg_d1;
  
  // �������ռ��Ĵ�����ȥ��ԭ��ñ������Զ��Ż���������λ�ã�
  reg wr_fifo_aclr_reg_final;
  reg rd_fifo_aclr_reg_final;

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      // 1. ȫ��Ӳ����λʱ���Ĵ������첽�� 1
      wr_fifo_aclr_reg_d1 <= 1'b1;
      rd_fifo_aclr_reg_d1 <= 1'b1;
      
      wr_fifo_aclr_reg_final <= 1'b1;
      rd_fifo_aclr_reg_final <= 1'b1;
    end else begin
      // 2. ��һ�ģ�ץȡ������ (����ǰ�������߼�)
      wr_fifo_aclr_reg_d1 <= fifo_wr_load_p;
      rd_fifo_aclr_reg_d1 <= fifo_rd_load_p;
      
      // 3. �ڶ��ģ��м̴��ģ�����Ϊ��������ȡ���� 1 ��ʱ�����ڵĲ���ʱ��
      wr_fifo_aclr_reg_final <= wr_fifo_aclr_reg_d1;
      rd_fifo_aclr_reg_final <= rd_fifo_aclr_reg_d1;
    end
  end

  // ==========================================
  // FIFO �������������մ���ĵļĴ���
  // ==========================================
  sdram_wr_fifo sdram_wr_fifo_inst (
      .wrclk  (I_fifo_wr_clk),
      .wrreq  (I_fifo_wr_req),
      .data   (I_fifo_wr_data),
      .rdclk  (I_ref_clk),
      .rdreq  (I_sdram_wr_ack),
      .q      (O_sdram_wr_data),
      .aclr   (wr_fifo_aclr_reg_final),  // <--- ���� final �Ĵ���
      .rdusedw(wr_fifo_use)
  );

  sdram_rd_fifo sdram_rd_fifo_inst (
      .wrclk  (I_ref_clk),
      .wrreq  (I_sdram_rd_ack),
      .data   (I_sdram_rd_data),
      .rdclk  (I_fifo_rd_clk),
      .rdreq  (I_fifo_rd_req),
      .q      (O_fifo_rd_data),
      .aclr   (rd_fifo_aclr_reg_final),  // <--- ���� final �Ĵ���
      .wrusedw(rd_fifo_use)
  );
endmodule
