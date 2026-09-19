`timescale 1ns/1ns

module video_osd_overlay
#(
    parameter [23:0] OSD_COLOR = 24'hFFFFFF
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  active_mode,
    input  wire [3:0]  fps_tens,
    input  wire [3:0]  fps_ones,
    input  wire        status_setting,
    input  wire        status_snapshot,
    input  wire        status_error,
    input  wire [1:0]  rgb_color_mode,
    input  wire [3:0]  rgb_stage_view,
    input  wire [1:0]  rgb_skin_level,
    input  wire [1:0]  rgb_color_temp,
    input  wire [1:0]  edge_mode,
    input  wire [3:0]  edge_threshold_index,
    input  wire        edge_filter,
    input  wire [1:0]  gesture_view,
    input  wire        cnn_digit_valid,
    input  wire [3:0]  cnn_digit,
    input  wire        in_frame_start,
    input  wire        in_frame_end,
    input  wire        in_hs,
    input  wire        in_vs,
    input  wire        in_de,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,
    input  wire [7:0]  in_raw8,
    input  wire [23:0] in_rgb888,
    output wire        out_frame_start,
    output wire        out_frame_end,
    output wire        out_hs,
    output wire        out_vs,
    output wire        out_de,
    output wire [10:0] out_x,
    output wire [10:0] out_y,
    output wire [7:0]  out_raw8,
    output wire [23:0] out_rgb888
);

localparam integer OSD_LATENCY = 6;
localparam [10:0] STATUS_MODE_X      = 11'd16;
localparam [10:0] STATUS_CODE_X      = 11'd100;
localparam [10:0] PARAM_X0           = 11'd148;
localparam [10:0] PARAM_X1           = 11'd232;
localparam [10:0] PARAM_X2           = 11'd316;
localparam [10:0] PARAM_X3           = 11'd400;
localparam [10:0] OSD_ROW_Y          = 11'd16;
localparam [10:0] OSD_ROW_Y_END      = 11'd30;
localparam [10:0] STATUS_MODE_X_END  = 11'd88;
localparam [10:0] STATUS_CODE_X_END  = 11'd136;
localparam [10:0] PARAM_X0_END       = 11'd218;
localparam [10:0] PARAM_X1_END       = 11'd302;
localparam [10:0] PARAM_X2_END       = 11'd386;
localparam [10:0] PARAM_X3_END       = 11'd470;
localparam [23:0] CNN_ROI_COLOR = 24'h00FF00;
localparam [23:0] CNN_MASK_COLOR = 24'hFF0000;
localparam [10:0] CNN_ROI_X0 = 11'd320;
localparam [10:0] CNN_ROI_Y0 = 11'd104;
localparam [10:0] CNN_ROI_X1 = 11'd959;
localparam [10:0] CNN_ROI_Y1 = 11'd615;
localparam [7:0]  CNN_DARK_TH = 8'd112;

reg frame_start_pipe_r [0:OSD_LATENCY];
reg frame_end_pipe_r   [0:OSD_LATENCY];
reg hs_pipe_r          [0:OSD_LATENCY];
reg vs_pipe_r          [0:OSD_LATENCY];
reg de_pipe_r          [0:OSD_LATENCY];
reg [10:0] x_pipe_r    [0:OSD_LATENCY];
reg [10:0] y_pipe_r    [0:OSD_LATENCY];
reg [7:0] raw8_pipe_r  [0:OSD_LATENCY];
reg [23:0] rgb_pipe_r  [0:OSD_LATENCY];

localparam [3:0] REGION_NONE          = 4'd0;
localparam [3:0] REGION_STATUS_LEFT   = 4'd1;
localparam [3:0] REGION_STATUS_CODE   = 4'd2;
localparam [3:0] REGION_RGB_STAGE     = 4'd3;
localparam [3:0] REGION_RGB_COLOR     = 4'd4;
localparam [3:0] REGION_RGB_SKIN      = 4'd5;
localparam [3:0] REGION_RGB_TEMP      = 4'd6;
localparam [3:0] REGION_EDGE_MODE     = 4'd7;
localparam [3:0] REGION_EDGE_FILTER   = 4'd8;
localparam [3:0] REGION_EDGE_THRESHOLD = 4'd9;
localparam [3:0] REGION_CNN_DIGIT     = 4'd10;
localparam [3:0] REGION_CNN_VIEW      = 4'd11;

reg [3:0]  region_s1_c;
reg [10:0] rel_x_s1_c;
reg [10:0] rel_y_s1_c;
reg [6:0]  glyph_x_decode_s2_c;

reg [3:0]  region_s1_r;
reg [10:0] rel_x_s1_r;
reg [10:0] rel_y_s1_r;
reg [3:0]  region_s2_r;
reg        geom_valid_s2_r;
reg [2:0]  char_slot_s2_r;
reg [2:0]  glyph_row_s2_r;
reg [2:0]  glyph_col_s2_r;

/* The complete profile is captured with the pixel token and follows the
 * geometry stages.  This prevents a frame-boundary profile commit from
 * changing characters or CNN overlays for pixels already in flight. */
reg [35:0] profile_s0_r;
reg [35:0] profile_s1_r;
reg [35:0] profile_s2_r;

reg [7:0]  char_code_s3_c;
reg        char_valid_s3_r;
reg [7:0]  char_code_s3_r;
reg [2:0]  glyph_row_s3_r;
reg [2:0]  glyph_col_s3_r;
reg        glyph_valid_s4_r;
reg [4:0]  glyph_bits_s4_r;
reg [2:0]  glyph_col_s4_r;
reg        glyph_on_s5_r;
reg        overlay_s6_r;

wire [1:0] status_code_w = status_error    ? 2'd3
                            : status_snapshot ? 2'd2
                            : status_setting  ? 2'd1 : 2'd0;
wire [1:0] profile_s0_mode_w = profile_s0_r[35:34];
wire [1:0] profile_s0_gesture_w = profile_s0_r[6:5];

wire [1:0] profile_s2_mode_w = profile_s2_r[35:34];
wire [3:0] profile_s2_fps_tens_w = profile_s2_r[33:30];
wire [3:0] profile_s2_fps_ones_w = profile_s2_r[29:26];
wire [1:0] profile_s2_status_w = profile_s2_r[25:24];
wire [1:0] profile_s2_rgb_color_w = profile_s2_r[23:22];
wire [3:0] profile_s2_rgb_stage_w = profile_s2_r[21:18];
wire [1:0] profile_s2_rgb_skin_w = profile_s2_r[17:16];
wire [1:0] profile_s2_rgb_temp_w = profile_s2_r[15:14];
wire [1:0] profile_s2_edge_mode_w = profile_s2_r[13:12];
wire [3:0] profile_s2_edge_th_w = profile_s2_r[11:8];
wire       profile_s2_edge_filter_w = profile_s2_r[7];
wire [1:0] profile_s2_gesture_w = profile_s2_r[6:5];
wire       profile_s2_digit_valid_w = profile_s2_r[4];
wire [3:0] profile_s2_digit_w = profile_s2_r[3:0];

wire cnn_roi_inside_s0_w = de_pipe_r[0]
                         && (x_pipe_r[0] >= CNN_ROI_X0) && (x_pipe_r[0] <= CNN_ROI_X1)
                         && (y_pipe_r[0] >= CNN_ROI_Y0) && (y_pipe_r[0] <= CNN_ROI_Y1);
wire cnn_roi_border_s0_w = cnn_roi_inside_s0_w
                         && ((x_pipe_r[0] == CNN_ROI_X0) || (x_pipe_r[0] == CNN_ROI_X1)
                          || (y_pipe_r[0] == CNN_ROI_Y0) || (y_pipe_r[0] == CNN_ROI_Y1));
wire cnn_show_roi_s0_w = (profile_s0_mode_w == 2'd3) && (profile_s0_gesture_w >= 2'd1);
wire cnn_show_mask_s0_w = (profile_s0_mode_w == 2'd3) && (profile_s0_gesture_w == 2'd2);
wire [23:0] cnn_base_rgb_s1_w = (cnn_show_roi_s0_w && cnn_roi_border_s0_w)
                              ? CNN_ROI_COLOR
                              : (cnn_show_mask_s0_w && cnn_roi_inside_s0_w
                                && (raw8_pipe_r[0] <= CNN_DARK_TH))
                              ? CNN_MASK_COLOR : rgb_pipe_r[0];

integer i_ctrl;
integer i_data;

function [7:0] mode_char;
    input [1:0] mode;
    input [2:0] index;
    begin
        case (mode)
            2'd0: case (index) 0:mode_char="R"; 1:mode_char="A"; default:mode_char="W"; endcase
            2'd1: case (index) 0:mode_char="R"; 1:mode_char="G"; default:mode_char="B"; endcase
            2'd2: case (index) 0:mode_char="E"; 1:mode_char="D"; default:mode_char="G"; endcase
            default: case (index) 0:mode_char="C"; 1:mode_char="N"; default:mode_char="N"; endcase
        endcase
    end
endfunction

function [7:0] status_char;
    input [1:0] status;
    input [1:0] index;
    begin
        case (status)
            2'd1: case(index) 0:status_char="S"; 1:status_char="E"; default:status_char="T"; endcase
            2'd2: case(index) 0:status_char="S"; 1:status_char="N"; default:status_char="P"; endcase
            2'd3: case(index) 0:status_char="E"; 1:status_char="R"; default:status_char="R"; endcase
            default: case(index) 0:status_char="R"; 1:status_char="D"; default:status_char="Y"; endcase
        endcase
    end
endfunction

function [7:0] stage_char;
    input [3:0] stage;
    input [1:0] index;
    begin
        case (stage)
            4'd0:  case(index) 0:stage_char="R"; 1:stage_char="A"; default:stage_char="W"; endcase
            4'd1:  case(index) 0:stage_char="R"; 1:stage_char="P"; default:stage_char="G"; endcase
            4'd2:  case(index) 0:stage_char="D"; 1:stage_char="E"; default:stage_char="B"; endcase
            4'd3:  case(index) 0:stage_char="A"; 1:stage_char="W"; default:stage_char="B"; endcase
            4'd4:  case(index) 0:stage_char="C"; 1:stage_char="C"; default:stage_char="M"; endcase
            4'd5:  case(index) 0:stage_char="P"; 1:stage_char="C"; default:stage_char="G"; endcase
            4'd6:  case(index) 0:stage_char="F"; 1:stage_char="C"; default:stage_char="D"; endcase
            4'd7:  case(index) 0:stage_char="G"; 1:stage_char="M"; default:stage_char="A"; endcase
            4'd8:  case(index) 0:stage_char="T"; 1:stage_char="O"; default:stage_char="N"; endcase
            4'd9:  case(index) 0:stage_char="L"; 1:stage_char="B"; default:stage_char="F"; endcase
            4'd10: case(index) 0:stage_char="P"; 1:stage_char="C"; default:stage_char="C"; endcase
            4'd11: case(index) 0:stage_char="T"; 1:stage_char="U"; default:stage_char="N"; endcase
            default: case(index) 0:stage_char="F"; 1:stage_char="I"; default:stage_char="N"; endcase
        endcase
    end
endfunction

function [7:0] rgb_color_char;
    input [1:0] value; input [1:0] index;
    begin
        case(value)
            2'd0: case(index) 0:rgb_color_char="L"; 1:rgb_color_char="I"; default:rgb_color_char="T"; endcase
            2'd2: case(index) 0:rgb_color_char="V"; 1:rgb_color_char="I"; default:rgb_color_char="V"; endcase
            default: case(index) 0:rgb_color_char="B"; 1:rgb_color_char="A"; default:rgb_color_char="L"; endcase
        endcase
    end
endfunction

function [7:0] rgb_skin_char;
    input [1:0] value; input [1:0] index;
    begin
        case(value)
            2'd1: case(index) 0:rgb_skin_char="S"; 1:rgb_skin_char="T"; default:rgb_skin_char="R"; endcase
            2'd2: case(index) 0:rgb_skin_char="V"; 1:rgb_skin_char="H"; default:rgb_skin_char="I"; endcase
            default: case(index) 0:rgb_skin_char="O"; 1:rgb_skin_char="F"; default:rgb_skin_char="F"; endcase
        endcase
    end
endfunction

function [7:0] rgb_temp_char;
    input [1:0] value; input [1:0] index;
    begin
        case(value)
            2'd1: case(index) 0:rgb_temp_char="C"; 1:rgb_temp_char="L"; default:rgb_temp_char="D"; endcase
            2'd2: case(index) 0:rgb_temp_char="W"; 1:rgb_temp_char="R"; default:rgb_temp_char="M"; endcase
            default: case(index) 0:rgb_temp_char="N"; 1:rgb_temp_char="E"; default:rgb_temp_char="U"; endcase
        endcase
    end
endfunction

function [7:0] edge_mode_char;
    input [1:0] value; input [1:0] index;
    begin
        case(value)
            2'd0: case(index) 0:edge_mode_char="B"; 1:edge_mode_char="A"; default:edge_mode_char="S"; endcase
            2'd1: case(index) 0:edge_mode_char="H"; 1:edge_mode_char="E"; default:edge_mode_char="B"; endcase
            default: case(index) 0:edge_mode_char="S"; 1:edge_mode_char="U"; default:edge_mode_char="P"; endcase
        endcase
    end
endfunction

function [7:0] gesture_char;
    input [1:0] value; input [1:0] index;
    begin
        case(value)
            2'd0: case(index) 0:gesture_char="C"; 1:gesture_char="L"; default:gesture_char="N"; endcase
            2'd1: case(index) 0:gesture_char="R"; 1:gesture_char="O"; default:gesture_char="I"; endcase
            default: case(index) 0:gesture_char="M"; 1:gesture_char="S"; default:gesture_char="K"; endcase
        endcase
    end
endfunction

function [7:0] threshold_char;
    input [3:0] value; input [1:0] index;
    reg [7:0] hundreds; reg [7:0] tens; reg [7:0] ones;
    begin
        case(value)
            4'd0: begin hundreds="0"; tens="6"; ones="4"; end
            4'd1: begin hundreds="0"; tens="7"; ones="2"; end
            4'd2: begin hundreds="0"; tens="8"; ones="0"; end
            4'd3: begin hundreds="0"; tens="9"; ones="0"; end
            4'd4: begin hundreds="0"; tens="9"; ones="6"; end
            4'd5: begin hundreds="1"; tens="0"; ones="4"; end
            4'd6: begin hundreds="1"; tens="1"; ones="2"; end
            4'd7: begin hundreds="1"; tens="4"; ones="4"; end
            4'd8: begin hundreds="1"; tens="7"; ones="6"; end
            4'd9: begin hundreds="2"; tens="0"; ones="8"; end
            // Keep diagnostic rendering consistent with edge_video_pipeline:
            // unsupported threshold indices are clamped to index 3 / 090.
            default: begin hundreds="0"; tens="9"; ones="0"; end
        endcase
        case(index) 0:threshold_char=hundreds; 1:threshold_char=tens; default:threshold_char=ones; endcase
    end
endfunction

/* Fixed-width x decoder for 10-pixel glyphs on a 12-pixel character pitch.
 * The packed result is {valid, slot[2:0], glyph_col[2:0]}.  Explicit
 * constant offsets avoid the old integer multiply/remainder cone. */
function [6:0] glyph_x_decode;
    input [10:0] rel_x;
    reg [10:0] glyph_offset;
    begin
        glyph_x_decode = 7'd0;
        glyph_offset = 11'd0;
        if (rel_x < 11'd10) begin
            glyph_offset = rel_x;
            glyph_x_decode = {1'b1, 3'd0, glyph_offset[3:1]};
        end else if ((rel_x >= 11'd12) && (rel_x < 11'd22)) begin
            glyph_offset = rel_x - 11'd12;
            glyph_x_decode = {1'b1, 3'd1, glyph_offset[3:1]};
        end else if ((rel_x >= 11'd24) && (rel_x < 11'd34)) begin
            glyph_offset = rel_x - 11'd24;
            glyph_x_decode = {1'b1, 3'd2, glyph_offset[3:1]};
        end else if ((rel_x >= 11'd36) && (rel_x < 11'd46)) begin
            glyph_offset = rel_x - 11'd36;
            glyph_x_decode = {1'b1, 3'd3, glyph_offset[3:1]};
        end else if ((rel_x >= 11'd48) && (rel_x < 11'd58)) begin
            glyph_offset = rel_x - 11'd48;
            glyph_x_decode = {1'b1, 3'd4, glyph_offset[3:1]};
        end else if ((rel_x >= 11'd60) && (rel_x < 11'd70)) begin
            glyph_offset = rel_x - 11'd60;
            glyph_x_decode = {1'b1, 3'd5, glyph_offset[3:1]};
        end
    end
endfunction

function [4:0] font_row;
    input [7:0] ch; input [2:0] row;
    begin
        font_row = 5'b00000;
        case (ch)
            "0": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10011;3:font_row=5'b10101;4:font_row=5'b11001;5:font_row=5'b10001;6:font_row=5'b01110;default:font_row=0;endcase
            "1": case(row) 0:font_row=5'b00100;1:font_row=5'b01100;2:font_row=5'b00100;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00100;6:font_row=5'b01110;default:font_row=0;endcase
            "2": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b00001;3:font_row=5'b00010;4:font_row=5'b00100;5:font_row=5'b01000;6:font_row=5'b11111;default:font_row=0;endcase
            "3": case(row) 0:font_row=5'b11110;1:font_row=5'b00001;2:font_row=5'b00001;3:font_row=5'b01110;4:font_row=5'b00001;5:font_row=5'b00001;6:font_row=5'b11110;default:font_row=0;endcase
            "4": case(row) 0:font_row=5'b00010;1:font_row=5'b00110;2:font_row=5'b01010;3:font_row=5'b10010;4:font_row=5'b11111;5:font_row=5'b00010;6:font_row=5'b00010;default:font_row=0;endcase
            "5": case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b00001;5:font_row=5'b00001;6:font_row=5'b11110;default:font_row=0;endcase
            "6": case(row) 0:font_row=5'b01110;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b01110;default:font_row=0;endcase
            "7": case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00010;3:font_row=5'b00100;4:font_row=5'b01000;5:font_row=5'b01000;6:font_row=5'b01000;default:font_row=0;endcase
            "8": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b01110;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b01110;default:font_row=0;endcase
            "9": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b01111;4:font_row=5'b00001;5:font_row=5'b00001;6:font_row=5'b01110;default:font_row=0;endcase
            "A": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b10001;default:font_row=0;endcase
            "B": case(row) 0:font_row=5'b11110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11110;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b11110;default:font_row=0;endcase
            "C": case(row) 0:font_row=5'b01111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b10000;4:font_row=5'b10000;5:font_row=5'b10000;6:font_row=5'b01111;default:font_row=0;endcase
            "D": case(row) 0:font_row=5'b11110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10001;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b11110;default:font_row=0;endcase
            "E": case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;6:font_row=5'b11111;default:font_row=0;endcase
            "F": case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;6:font_row=5'b10000;default:font_row=0;endcase
            "G": case(row) 0:font_row=5'b01111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b10111;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b01111;default:font_row=0;endcase
            "H": case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b10001;default:font_row=0;endcase
            "I": case(row) 0:font_row=5'b11111;1:font_row=5'b00100;2:font_row=5'b00100;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00100;6:font_row=5'b11111;default:font_row=0;endcase
            "K": case(row) 0:font_row=5'b10001;1:font_row=5'b10010;2:font_row=5'b10100;3:font_row=5'b11000;4:font_row=5'b10100;5:font_row=5'b10010;6:font_row=5'b10001;default:font_row=0;endcase
            "L": case(row) 0:font_row=5'b10000;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b10000;4:font_row=5'b10000;5:font_row=5'b10000;6:font_row=5'b11111;default:font_row=0;endcase
            "M": case(row) 0:font_row=5'b10001;1:font_row=5'b11011;2:font_row=5'b10101;3:font_row=5'b10101;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b10001;default:font_row=0;endcase
            "N": case(row) 0:font_row=5'b10001;1:font_row=5'b11001;2:font_row=5'b11001;3:font_row=5'b10101;4:font_row=5'b10011;5:font_row=5'b10011;6:font_row=5'b10001;default:font_row=0;endcase
            "O": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10001;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b01110;default:font_row=0;endcase
            "P": case(row) 0:font_row=5'b11110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;6:font_row=5'b10000;default:font_row=0;endcase
            "R": case(row) 0:font_row=5'b11110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11110;4:font_row=5'b10100;5:font_row=5'b10010;6:font_row=5'b10001;default:font_row=0;endcase
            "S": case(row) 0:font_row=5'b01111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b01110;4:font_row=5'b00001;5:font_row=5'b00001;6:font_row=5'b11110;default:font_row=0;endcase
            "T": case(row) 0:font_row=5'b11111;1:font_row=5'b00100;2:font_row=5'b00100;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00100;6:font_row=5'b00100;default:font_row=0;endcase
            "U": case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10001;4:font_row=5'b10001;5:font_row=5'b10001;6:font_row=5'b01110;default:font_row=0;endcase
            "V": case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10001;4:font_row=5'b10001;5:font_row=5'b01010;6:font_row=5'b00100;default:font_row=0;endcase
            "W": case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10101;4:font_row=5'b10101;5:font_row=5'b11011;6:font_row=5'b10001;default:font_row=0;endcase
            "Y": case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b01010;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00100;6:font_row=5'b00100;default:font_row=0;endcase
            "?": case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b00010;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00000;6:font_row=5'b00100;default:font_row=0;endcase
            default: font_row=5'b00000;
        endcase
    end
endfunction

/* Stage 1 performs region selection and fixed-offset subtraction from the
 * registered stage-0 pixel/profile token.  Status regions have priority;
 * mode-specific regions are kept in short independent branches. */
always @* begin
    region_s1_c = REGION_NONE;
    rel_x_s1_c = 11'd0;
    rel_y_s1_c = 11'd0;

    if (de_pipe_r[0]) begin
        if ((y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)
         && (x_pipe_r[0] >= STATUS_MODE_X) && (x_pipe_r[0] < STATUS_MODE_X_END)) begin
            region_s1_c = REGION_STATUS_LEFT;
            rel_x_s1_c = x_pipe_r[0] - STATUS_MODE_X;
            rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
        end else if ((y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)
                  && (x_pipe_r[0] >= STATUS_CODE_X) && (x_pipe_r[0] < STATUS_CODE_X_END)) begin
            region_s1_c = REGION_STATUS_CODE;
            rel_x_s1_c = x_pipe_r[0] - STATUS_CODE_X;
            rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
        end else begin
            case (profile_s0_mode_w)
                2'd1: begin
                    if ((y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)
                     && (x_pipe_r[0] >= PARAM_X0) && (x_pipe_r[0] < PARAM_X0_END)) begin
                        region_s1_c = REGION_RGB_STAGE;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X0;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end else if ((x_pipe_r[0] >= PARAM_X1) && (x_pipe_r[0] < PARAM_X1_END)
                              && (y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)) begin
                        region_s1_c = REGION_RGB_COLOR;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X1;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end else if ((x_pipe_r[0] >= PARAM_X2) && (x_pipe_r[0] < PARAM_X2_END)
                              && (y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)) begin
                        region_s1_c = REGION_RGB_SKIN;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X2;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end else if ((x_pipe_r[0] >= PARAM_X3) && (x_pipe_r[0] < PARAM_X3_END)
                              && (y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)) begin
                        region_s1_c = REGION_RGB_TEMP;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X3;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end
                end
                2'd2: begin
                    if ((x_pipe_r[0] >= PARAM_X0) && (x_pipe_r[0] < PARAM_X0_END)
                     && (y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)) begin
                        region_s1_c = REGION_EDGE_MODE;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X0;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end else if ((x_pipe_r[0] >= PARAM_X1) && (x_pipe_r[0] < PARAM_X1_END)
                              && (y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)) begin
                        region_s1_c = REGION_EDGE_FILTER;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X1;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end else if ((x_pipe_r[0] >= PARAM_X2) && (x_pipe_r[0] < PARAM_X2_END)
                              && (y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)) begin
                        region_s1_c = REGION_EDGE_THRESHOLD;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X2;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end
                end
                2'd3: begin
                    if ((y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)
                     && (x_pipe_r[0] >= PARAM_X0) && (x_pipe_r[0] < PARAM_X0_END)) begin
                        region_s1_c = REGION_CNN_DIGIT;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X0;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end else if ((y_pipe_r[0] >= OSD_ROW_Y) && (y_pipe_r[0] < OSD_ROW_Y_END)
                              && (x_pipe_r[0] >= PARAM_X1) && (x_pipe_r[0] < PARAM_X1_END)) begin
                        region_s1_c = REGION_CNN_VIEW;
                        rel_x_s1_c = x_pipe_r[0] - PARAM_X1;
                        rel_y_s1_c = y_pipe_r[0] - OSD_ROW_Y;
                    end
                end
                default: begin
                    region_s1_c = REGION_NONE;
                    rel_x_s1_c = 11'd0;
                    rel_y_s1_c = 11'd0;
                end
            endcase
        end
    end
end

/* Stage 2 decodes only the registered relative x coordinate. */
always @* begin
    glyph_x_decode_s2_c = glyph_x_decode(rel_x_s1_r);
end

/* Stage 3 is a small region/profile character mux. */
always @* begin
    char_code_s3_c = " ";
    case (region_s2_r)
        REGION_STATUS_LEFT: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "0" + profile_s2_fps_tens_w;
                3'd1: char_code_s3_c = "0" + profile_s2_fps_ones_w;
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = mode_char(profile_s2_mode_w, 2'd0);
                3'd4: char_code_s3_c = mode_char(profile_s2_mode_w, 2'd1);
                default: char_code_s3_c = mode_char(profile_s2_mode_w, 2'd2);
            endcase
        end
        REGION_STATUS_CODE:
            char_code_s3_c = status_char(profile_s2_status_w, char_slot_s2_r[1:0]);
        REGION_RGB_STAGE: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "S";
                3'd1: char_code_s3_c = "T";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = stage_char(profile_s2_rgb_stage_w, 2'd0);
                3'd4: char_code_s3_c = stage_char(profile_s2_rgb_stage_w, 2'd1);
                default: char_code_s3_c = stage_char(profile_s2_rgb_stage_w, 2'd2);
            endcase
        end
        REGION_RGB_COLOR: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "C";
                3'd1: char_code_s3_c = "M";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = rgb_color_char(profile_s2_rgb_color_w, 2'd0);
                3'd4: char_code_s3_c = rgb_color_char(profile_s2_rgb_color_w, 2'd1);
                default: char_code_s3_c = rgb_color_char(profile_s2_rgb_color_w, 2'd2);
            endcase
        end
        REGION_RGB_SKIN: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "S";
                3'd1: char_code_s3_c = "K";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = rgb_skin_char(profile_s2_rgb_skin_w, 2'd0);
                3'd4: char_code_s3_c = rgb_skin_char(profile_s2_rgb_skin_w, 2'd1);
                default: char_code_s3_c = rgb_skin_char(profile_s2_rgb_skin_w, 2'd2);
            endcase
        end
        REGION_RGB_TEMP: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "T";
                3'd1: char_code_s3_c = "P";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = rgb_temp_char(profile_s2_rgb_temp_w, 2'd0);
                3'd4: char_code_s3_c = rgb_temp_char(profile_s2_rgb_temp_w, 2'd1);
                default: char_code_s3_c = rgb_temp_char(profile_s2_rgb_temp_w, 2'd2);
            endcase
        end
        REGION_EDGE_MODE: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "M";
                3'd1: char_code_s3_c = "D";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = edge_mode_char(profile_s2_edge_mode_w, 2'd0);
                3'd4: char_code_s3_c = edge_mode_char(profile_s2_edge_mode_w, 2'd1);
                default: char_code_s3_c = edge_mode_char(profile_s2_edge_mode_w, 2'd2);
            endcase
        end
        REGION_EDGE_FILTER: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "F";
                3'd1: char_code_s3_c = "L";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = profile_s2_edge_filter_w ? "B" : "G";
                default: char_code_s3_c = " ";
            endcase
        end
        REGION_EDGE_THRESHOLD: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "T";
                3'd1: char_code_s3_c = "H";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = threshold_char(profile_s2_edge_th_w, 2'd0);
                3'd4: char_code_s3_c = threshold_char(profile_s2_edge_th_w, 2'd1);
                default: char_code_s3_c = threshold_char(profile_s2_edge_th_w, 2'd2);
            endcase
        end
        REGION_CNN_DIGIT: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "D";
                3'd1: char_code_s3_c = "G";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = (profile_s2_digit_valid_w && (profile_s2_digit_w <= 4'd9))
                                           ? ("0" + profile_s2_digit_w) : "?";
                default: char_code_s3_c = " ";
            endcase
        end
        REGION_CNN_VIEW: begin
            case (char_slot_s2_r)
                3'd0: char_code_s3_c = "V";
                3'd1: char_code_s3_c = "W";
                3'd2: char_code_s3_c = " ";
                3'd3: char_code_s3_c = gesture_char(profile_s2_gesture_w, 2'd0);
                3'd4: char_code_s3_c = gesture_char(profile_s2_gesture_w, 2'd1);
                default: char_code_s3_c = gesture_char(profile_s2_gesture_w, 2'd2);
            endcase
        end
        default: char_code_s3_c = " ";
    endcase
end

/* Only validity/control bits use asynchronous reset.  Pixel data registers
 * are intentionally reset-free; de_pipe masks them until the six-cycle
 * pipeline is filled after reset. */
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i_ctrl=0;i_ctrl<=OSD_LATENCY;i_ctrl=i_ctrl+1) begin
            frame_start_pipe_r[i_ctrl] <= 1'b0; frame_end_pipe_r[i_ctrl] <= 1'b0;
            hs_pipe_r[i_ctrl] <= 1'b0; vs_pipe_r[i_ctrl] <= 1'b0; de_pipe_r[i_ctrl] <= 1'b0;
        end
        geom_valid_s2_r <= 1'b0;
        char_valid_s3_r <= 1'b0;
        glyph_valid_s4_r <= 1'b0;
        glyph_on_s5_r <= 1'b0;
        overlay_s6_r <= 1'b0;
    end else begin
        frame_start_pipe_r[0] <= in_frame_start; frame_end_pipe_r[0] <= in_frame_end;
        hs_pipe_r[0] <= in_hs; vs_pipe_r[0] <= in_vs; de_pipe_r[0] <= in_de;
        for (i_ctrl=1;i_ctrl<=OSD_LATENCY;i_ctrl=i_ctrl+1) begin
            frame_start_pipe_r[i_ctrl] <= frame_start_pipe_r[i_ctrl-1]; frame_end_pipe_r[i_ctrl] <= frame_end_pipe_r[i_ctrl-1];
            hs_pipe_r[i_ctrl] <= hs_pipe_r[i_ctrl-1]; vs_pipe_r[i_ctrl] <= vs_pipe_r[i_ctrl-1]; de_pipe_r[i_ctrl] <= de_pipe_r[i_ctrl-1];
        end
        geom_valid_s2_r <= (region_s1_r != REGION_NONE) && glyph_x_decode_s2_c[6];
        char_valid_s3_r <= geom_valid_s2_r;
        glyph_valid_s4_r <= char_valid_s3_r;
        glyph_on_s5_r <= glyph_valid_s4_r && glyph_bits_s4_r[4-glyph_col_s4_r];
        overlay_s6_r <= glyph_on_s5_r;
    end
end

always @(posedge clk) begin
    x_pipe_r[0] <= in_x;
    y_pipe_r[0] <= in_y;
    raw8_pipe_r[0] <= in_raw8;
    rgb_pipe_r[0] <= in_rgb888;
    for (i_data=1;i_data<=OSD_LATENCY;i_data=i_data+1) begin
        x_pipe_r[i_data] <= x_pipe_r[i_data-1]; y_pipe_r[i_data] <= y_pipe_r[i_data-1];
        raw8_pipe_r[i_data] <= raw8_pipe_r[i_data-1];
    end
    rgb_pipe_r[1] <= cnn_base_rgb_s1_w;
    for (i_data=2;i_data<=OSD_LATENCY;i_data=i_data+1)
        rgb_pipe_r[i_data] <= rgb_pipe_r[i_data-1];

    profile_s0_r <= {active_mode, fps_tens, fps_ones, status_code_w,
                     rgb_color_mode, rgb_stage_view, rgb_skin_level,
                     rgb_color_temp, edge_mode, edge_threshold_index,
                     edge_filter, gesture_view, cnn_digit_valid, cnn_digit};
    profile_s1_r <= profile_s0_r;
    profile_s2_r <= profile_s1_r;

    region_s1_r <= region_s1_c;
    rel_x_s1_r <= rel_x_s1_c;
    rel_y_s1_r <= rel_y_s1_c;

    region_s2_r <= region_s1_r;
    char_slot_s2_r <= glyph_x_decode_s2_c[5:3];
    glyph_col_s2_r <= glyph_x_decode_s2_c[2:0];
    glyph_row_s2_r <= rel_y_s1_r[3:1];

    char_code_s3_r <= char_code_s3_c;
    glyph_row_s3_r <= glyph_row_s2_r;
    glyph_col_s3_r <= glyph_col_s2_r;

    glyph_bits_s4_r <= font_row(char_code_s3_r, glyph_row_s3_r);
    glyph_col_s4_r <= glyph_col_s3_r;
end

assign out_frame_start = frame_start_pipe_r[OSD_LATENCY];
assign out_frame_end   = frame_end_pipe_r[OSD_LATENCY];
assign out_hs          = hs_pipe_r[OSD_LATENCY];
assign out_vs          = vs_pipe_r[OSD_LATENCY];
assign out_de          = de_pipe_r[OSD_LATENCY];
assign out_x           = de_pipe_r[OSD_LATENCY] ? x_pipe_r[OSD_LATENCY] : 11'd0;
assign out_y           = de_pipe_r[OSD_LATENCY] ? y_pipe_r[OSD_LATENCY] : 11'd0;
assign out_raw8        = de_pipe_r[OSD_LATENCY] ? raw8_pipe_r[OSD_LATENCY] : 8'd0;
assign out_rgb888      = de_pipe_r[OSD_LATENCY]
                       ? (overlay_s6_r ? OSD_COLOR : rgb_pipe_r[OSD_LATENCY]) : 24'd0;

endmodule
