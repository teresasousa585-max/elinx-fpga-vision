// =============================================================================
// 文件名称：sdram_param.v
// 主要模块：参数与辅助定义
// 功能说明：集中定义 SDRAM 时序和地址相关参数。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

// SDRAM ��ʼ������״̬
`define I_NOP 5'd0  // �ȴ��ϵ�200us�ȶ�
`define I_PCH 5'd1  // Ԥ�������
`define I_TRP 5'd2  // Ԥ�����̵ȴ�
`define I_ARF 5'd3  // ��ˢ������
`define I_TRF 5'd4  // ��ˢ�¹��̵ȴ�
`define I_LMR 5'd5  // ģʽ�Ĵ�����������
`define I_TRSC 5'd6 // ģʽ�Ĵ������ù��̵ȴ�
`define I_DONE 5'd7 // ��ʼ�����

// SDRAM ��������״̬
`define IDLE 4'd0   // ����״̬
`define ACT 4'd1  // �м�����Ч״̬
`define TRCD 4'd2   // �м�����̵ȴ�
`define WR 4'd3     // д����
`define WR_BE 4'd4  // д����
`define TWR 4'd5    // д��
`define RD 4'd6     // ������
`define CL 4'd7     // ��Ǳ����
`define RD_BE 4'd8  // ������
`define PCH 4'd9    // Ԥ���״̬
`define TRP 4'd10   // Ԥ�����̵ȴ�
`define ARF 4'd11   // �Զ�ˢ��
`define TRFC 4'd12  // �Զ�ˢ�¹��̵ȴ�

// ��ʱ����
`define end_trp     O_cnt_clk == TRP  // Ԥ�����̵ȴ�����
`define end_trf    O_cnt_clk == TRC  // �Զ�ˢ�¹��̵ȴ�����
`define end_trsc    O_cnt_clk == TRSC // ģʽ�Ĵ������ù��̵ȴ�����
`define end_trcd    O_cnt_clk == TRCD-1  // 
`define end_cl     O_cnt_clk == TCL-1
`define end_wrburst O_cnt_clk == I_sdram_wr_burst - 1
`define end_twrite  O_cnt_clk == I_sdram_wr_burst - 1
`define end_rdburst O_cnt_clk == I_sdram_rd_burst - 4
`define end_tread   O_cnt_clk == I_sdram_rd_burst + 2
`define end_twr     O_cnt_clk == TWR

// SDRAM �������� {CKE,CS_N,RAS_N,CAS_N,WE_N}
`define CMD_INIT    5'b01111    // INIT
`define CMD_NOP     5'b10111    // NOP
`define CMD_PCH     5'b10010    // PCH
`define CMD_ARF     5'b10001    // ARF
`define CMD_LMR     5'b10000    // LMR
`define CMD_ACT     5'b10011    // ACT
`define CMD_WR      5'b10100    // WR
`define CMD_RD      5'b10101    // RD
`define CMD_BT      5'b10110    // BT