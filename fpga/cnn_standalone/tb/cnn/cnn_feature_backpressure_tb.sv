`timescale 1ns/1ps
module cnn_feature_backpressure_tb;
reg clk=0,rst_n=0,clr=0,de=0,ready=0,force_ready=0; reg[7:0] raw=0;reg[10:0] x=0,y=0;wire v,done,ov,back;wire[9:0] idx;wire[5:0] val;wire bv;wire[6:0] bl,br,bt,bb;integer got,expected_i,checks,cyc,xx,yy;reg[15:0] lfsr;
always #5 clk=~clk;
cnn_feature_32x32 d(.clk(clk),.rst_n(rst_n),.frame_clr(clr),.in_de(de),.in_raw(raw),.in_xpos(x),.in_ypos(y),.feature_ready(ready),.feature_valid(v),.feature_frame_done(done),.feature_index(idx),.feature_value(val),.bbox_valid(bv),.bbox_left(bl),.bbox_right(br),.bbox_top(bt),.bbox_bottom(bb),.feature_overflow(ov),.feature_backlog(back));
task ck;input c;input[8*80-1:0]m;begin checks=checks+1;if(!c)$fatal(1,"%0s",m);end endtask
always @(posedge clk) if(rst_n&&v&&ready)begin ck(idx==expected_i[9:0],"missing/duplicate/reordered feature");ck(val==6'd40,"all-dark density wrong");ck(done==(expected_i==1023),"done wrong");expected_i=expected_i+1;got=got+1;end
always @(negedge clk) begin lfsr={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};ready=force_ready||(lfsr[2:0]!=0);end
initial begin checks=0;got=0;expected_i=0;cyc=0;lfsr=16'h1;repeat(3)@(posedge clk);rst_n=1;@(negedge clk);clr=1;@(negedge clk);clr=0;
for(yy=104;yy<616;yy=yy+1)for(xx=320;xx<960;xx=xx+1)begin @(negedge clk);de=1;x=xx;y=yy;raw=0;end @(negedge clk);de=0;while(got<1024)@(posedge clk);force_ready=1;repeat(4)@(posedge clk);ck(!ov&&!back,"bounded backpressure left overflow/backlog");ck(bv&&bl==0&&br==63&&bt==0&&bb==63,"active bbox lost during pending advancement");$display("cnn_feature_backpressure_tb PASS checks=%0d tokens=%0d",checks,got);$finish;end
endmodule
