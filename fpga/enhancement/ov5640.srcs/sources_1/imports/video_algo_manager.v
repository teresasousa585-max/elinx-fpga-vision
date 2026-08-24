// =============================================================================
// 文件名称：video_algo_manager.v
// 主要模块：image_process_pipe
// 功能说明：根据串口模式选择图像处理支路，并统一输出视频时序。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module image_process_pipe (
    input wire clk_hdmi,
    input wire sys_rst,

    // ��λ���·���ģʽָ��
    input wire [3:0] al_main_hdmi,
    input wire [7:0] al_sub_hdmi,

    // ���� hdmi.v �Ļ�������ͼ����ʱ��
    input wire        raw_hs,
    input wire        raw_vs,
    input wire        raw_de,
    input wire [23:0] raw_rgb,

    // �����������ʾ���������ŵ�ͼ����ʱ��
    output reg        final_hs,
    output reg        final_vs,
    output reg        final_de,
    output reg [23:0] final_rgb
);
  //�����˲�
  wire guide_hs, guide_vs, guide_de;
  wire [23:0] guide_rgb;
  //�����˲�������ĥƤ
  guided_to_hdmi u_guided_filtering (
      .i_clk     (clk_hdmi),
      .i_rst     (sys_rst),
      .i_mode    (al_sub_hdmi == 1),  // 0: ȫ�ִ������˲�,  1: ����ĥƤ
      .i_hs      (raw_hs),
      .i_vs      (raw_vs),
      .i_de      (raw_de),
      .i_rgb_data(raw_rgb),           // �� HDMI ����� RGB888 ����

      .o_hs(guide_hs),
	  .o_vs(guide_vs),
      .o_de(guide_de),
      .o_rgb_data(guide_rgb)
  );
	//���⴦��
  wire anguang_hs, anguang_vs, anguang_de;
  wire [23:0] anguang_rgb;
  anguang_tohdmi u_anguang_proc (
      .i_clk     (clk_hdmi),
      .i_rst     (sys_rst),
      .i_hs      (raw_hs),
      .i_vs      (raw_vs),
      .i_de      (raw_de),
      .i_rgb_data(raw_rgb),           // �� HDMI ����� RGB888 ����
	  
      .o_hs(anguang_hs),
	  .o_vs(anguang_vs),
      .o_de(anguang_de),
      .o_rgb_data(anguang_rgb)
  );
  // �ռ�����·�� (MUX)����֤��ģʽ��ʱ����԰�ȫ����
  always @(posedge clk_hdmi) begin
    case (al_main_hdmi)
      4'd10: begin
        final_hs  <= guide_hs;
        final_vs  <= guide_vs;
        final_de  <= guide_de;
        final_rgb <= guide_de ? guide_rgb : 24'd0;
      end
	  4'd11: begin
        final_hs  <= anguang_hs;
        final_vs  <= anguang_vs;
        final_de  <= anguang_de;
        final_rgb <= anguang_de ? anguang_rgb : 24'd0;
      end
      default: begin
        final_hs  <= guide_hs;
        final_vs  <= guide_vs;
        final_de  <= guide_de;
        final_rgb <= 24'd0;
      end
    endcase
  end

endmodule
