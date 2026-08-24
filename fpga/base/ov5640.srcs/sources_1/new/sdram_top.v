// =============================================================================
// 文件名称：sdram_top.v
// 主要模块：sdram_top
// 功能说明：封装 SDRAM 控制与跨时钟域帧缓存接口。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

module sdram_top (
    input   wire    I_ref_clk,  // sdram �������ο�ʱ��
    input   wire    I_out_clk,  // sdram ��λƫ������ʱ��
    input   wire    I_rst_n,    // ��λ�źţ��͵�ƽ��Ч
    // д����
    input   wire    I_fifo_wr_clk,  // дfifo:дʱ��
    input   wire    I_fifo_wr_req,  // дfifo:дʹ��
    input   wire    [15:0]I_fifo_wr_data, // дfifo:д�������
    input   wire    I_fifo_wr_load, // дfifo:���

    input wire [11:0] I_wr_burst,  // д����ͻ������
    input wire [23:0] I_wr_saddr,  // д������ʼλ��
    input wire [23:0] I_wr_eaddr,  // д������ֹλ��

    // ������
    input   wire    I_fifo_rd_clk,  // ��fifo:��ʱ��
    input   wire    I_fifo_rd_req,  // ��fifo:��ʹ��
    output  wire    [15:0]O_fifo_rd_data, // ��fifo:����������
    input   wire    I_fifo_rd_load, // ��fifo:�����

    input wire [11:0] I_rd_burst,  // ������ͻ������
    input wire [23:0] I_rd_saddr,  // ��������ʼλ��
    input wire [23:0] I_rd_eaddr,  // ��������ֹλ��

    // ʹ�ܶ˿�
    input   wire    I_sdram_rd_valid, // SDRAM ��ʹ��
    input   wire    I_sdram_pingpang_en,    // SDRAM ƹ�Ҳ���ʹ��
    output  wire    O_sdram_init_done,  // SDRAM ��ʼ����ɱ�־

    // SDRAM оƬ�ӿ�
    output  wire    O_sdram_clk,    // SDRAM ����ʱ��
    output  wire    O_sdram_cke,    // SDRAM ʱ��ʹ���ź�
    output  wire    O_sdram_cs_n,   // SDRAM Ƭѡ�ź�
    output  wire    O_sdram_ras_n,  // SDRAM ��ѡ�ź�
    output  wire    O_sdram_cas_n,  // SDRAM ��ѡ�ź�
    output  wire    O_sdram_we_n,   // SDRAM дʹ���ź�
    output  wire    [1:0]O_sdram_bank,   // SDRAM Bank��ַ��
    output  wire    [12:0]O_sdram_addr,   // SDRAM ��ַ����
    inout   wire    [15:0]IO_sdram_dq,   // SDRAM ��������
    output  wire    [1:0]O_sdram_dqm    // SDRAM ��������
);

  //sdram_fifo_ctrl
  wire sdram_wr_req;
  wire [23:0] sdram_wr_addr;
  wire [15:0] sdram_wr_data;

  wire sdram_rd_req;
  wire [23:0] sdram_rd_addr;

  // sdram_control
  wire sdram_wr_ack;

  wire sdram_rd_ack;
  wire [15:0] sdram_rd_data;

  assign O_sdram_dqm = 2'b00;
  assign O_sdram_clk = I_out_clk;

  //sdram_fifo_ctrl
  sdram_fifo_ctrl sdram_fifo_ctrl (
      .I_ref_clk(I_ref_clk),  // �ο�ʱ��
      .I_rst_n  (I_rst_n),    // ϵͳ��λ,�͵�ƽ��Ч

      // д����:�ⲿ-->FIFO
      .I_fifo_wr_clk (I_fifo_wr_clk),   // fifoдʱ��
      .I_fifo_wr_req (I_fifo_wr_req),   // д��fifo����
      .I_fifo_wr_data(I_fifo_wr_data),  // д��fifo������
      .I_wr_saddr    (I_wr_saddr),      // д��sdram����ʼ��ַ
      .I_wr_eaddr    (I_wr_eaddr),      // д��sdram����ֹ��ַ
      .I_wr_brust    (I_wr_burst),      // д��sdram��ͻ������
      .I_fifo_wr_load(I_fifo_wr_load),  // д��fifo�������

      // wr_fifo:FIFO(д)-->SDRAM(��)
      .O_sdram_wr_req (sdram_wr_req),   // ����д��sdramд����
      .I_sdram_wr_ack (sdram_wr_ack),   // ����д��sdramд��Ӧ
      .O_sdram_wr_addr(sdram_wr_addr),  // д���ݽ�sdram�ĵ�ַ
      .O_sdram_wr_data(sdram_wr_data),  // д��sdram������

      // rd_fifo:SDRAM(д)-->FIFO(��)
      .O_sdram_rd_req (sdram_rd_req),   // ���ݶ���sdram������
      .I_sdram_rd_ack (sdram_rd_ack),   // ���ݶ���sdram����Ӧ
      .O_sdram_rd_addr(sdram_rd_addr),  // �����ݽ�fifo�ĵ�ַ
      .I_sdram_rd_data(sdram_rd_data),  // ����fifo������

      // ������:FIFO-->�ⲿ
      .I_fifo_rd_clk (I_fifo_rd_clk),   // ���ݶ���fifo��ʱ��
      .I_fifo_rd_req (I_fifo_rd_req),   // ���ݶ���fifo������
      .O_fifo_rd_data(O_fifo_rd_data),  // ����fifo������
      .I_rd_saddr    (I_rd_saddr),      // ����sdram����ʼ��ַ
      .I_rd_eaddr    (I_rd_eaddr),      // ����sdram����ֹ��ַ
      .I_rd_brust    (I_rd_burst),      // ����sdram��ͻ������
      .I_fifo_rd_load(I_fifo_rd_load),  // ����fifo�������

      // SDRAM
      .I_sdram_init_done  (O_sdram_init_done),  // sdram��ʼ�����
      .I_sdram_rd_valid   (I_sdram_rd_valid),    // sdram���ݶ�ʹ��
      .I_sdram_pingpang_en (I_sdram_pingpang_en)// sdramƹ�Ҳ���ʹ��
  );

  // sdram_control
  sdram_control sdram_control (
      .I_ref_clk(I_ref_clk),  // �ο�ʱ��
      .I_rst_n  (I_rst_n),    // ��λ�źţ��͵�ƽ��Ч

      // SDRAM ������д�˿�
      .I_sdram_wr_req  (sdram_wr_req),   // дsdram�����ź�
      .O_sdram_wr_ack  (sdram_wr_ack),   // дsdram��Ӧ�ź�
      .I_sdram_wr_addr (sdram_wr_addr),  // дsdramʱ��ַ
      .I_sdram_wr_burst(I_wr_burst),     // дsdramʱ����ͻ������
      .I_sdram_wr_data (sdram_wr_data),  // д��sdram������

      // SDRAM ���������˿�
      .I_sdram_rd_req  (sdram_rd_req),   // ��sdram�����ź�
      .O_sdram_rd_ack  (sdram_rd_ack),   // ��sdram��Ӧ�ź�
      .I_sdram_rd_addr (sdram_rd_addr),  // ��sdramʱ��ַ
      .I_sdram_rd_burst(I_rd_burst),     // ��sdramʱ����ͻ������
      .O_sdram_rd_data (sdram_rd_data),  // ����sdram������

      .O_sdram_init_done(O_sdram_init_done),  // SDRAM��ʼ�����

      // SDRAM PHY
      .O_sdram_cke  (O_sdram_cke),    // SDRAM ʱ����Ч�ź�
      .O_sdram_cs_n (O_sdram_cs_n),   // SDRAM Ƭѡ�ź�
      .O_sdram_ras_n(O_sdram_ras_n),  // SDRAM ��ѡ�ź�
      .O_sdram_cas_n(O_sdram_cas_n),  // SDRAM ��ѡ�ź�
      .O_sdram_we_n (O_sdram_we_n),   // SDRAM дʹ���ź�
      .O_sdram_bank (O_sdram_bank),   // SDRAM Bank��ַ��
      .O_sdram_addr (O_sdram_addr),   // SDRAM ��ַ����
      .IO_sdram_dq  (IO_sdram_dq)     // SDRAM ��������
  );

endmodule
