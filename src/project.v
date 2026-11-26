/*
 * Copyright (c) 2025 Renaldas Zioma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_rejunity_vga_logo (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Unused signals
    wire _unused_ok = &{ena, ui_in[7:3], uio_in};

    // VGA signals
    wire hsync;
    wire vsync;

    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;

    // Unused outputs
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Pixel position
    wire [9:0] x_px;
    wire [9:0] y_px;
    wire activevideo;

    // VGA synchronization generator
    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(activevideo),
        .hpos(x_px),
        .vpos(y_px)
    );

    // Logo generator
    wire logo;

    tt_logo tt_logo (
        .x(x_px),
        .y(y_px),
        .logo(logo)
    );

    // Frame counter
    reg [9:0] y_prv;
    reg [10:0] frame;

    always @(posedge clk) begin
        if (~rst_n) begin
            frame <= 0;
        end else begin
            y_prv <= y_px;

            if (y_px == 0 && y_prv != y_px) begin
                frame <= frame + 1;
            end
        end
    end

    // Bayer dithering
    wire [2:0] bayer_i =
        x_px[2:0] ^ {3{frame[0]}};

    wire [1:0] bayer_j =
        y_px[1:0];

    wire [2:0] bayer_x = {
        bayer_i[2],
        bayer_i[1] ^ bayer_j[1],
        bayer_i[0] ^ bayer_j[0]
    };

    wire [4:0] bayer = {
        bayer_x[0],
        bayer_i[0],
        bayer_x[1],
        bayer_i[1],
        bayer_x[2]
    };

    // Convert 6-bit color to 2-bit color
    function [1:0] dither2;

        input [5:0] color6;
        input [4:0] bayer5;

        begin
            dither2 = (
                {1'b0, color6} +
                {2'b0, bayer5} +
                color6[0] +
                color6[5] +
                color6[5:1]
            ) >> 5;
        end

    endfunction

    wire [5:0] r;
    wire [5:0] g;
    wire [5:0] b;

    wire [1:0] r_dither = dither2(r, bayer);
    wire [1:0] g_dither = dither2(g, bayer);
    wire [1:0] b_dither = dither2(b, bayer);

    // RGB conversion
    function [17:0] rgb18;

        input [5:0] rgb6;

        begin
            rgb18 = {
                rgb6[5:4], 4'b0,
                rgb6[3:2], 4'b0,
                rgb6[1:0], 4'b0
            };
        end

    endfunction

    // RGB addition
    function signed [17:0] rgb18_add;

        input signed [17:0] rgb0;
        input signed [17:0] rgb1;

        begin
            rgb18_add = {
                rgb0[17:11] + rgb1[17:11],
                rgb0[10:6]  + rgb1[10:6],
                rgb0[5:0]   + rgb1[5:0]
            };
        end

    endfunction

    // Background registers
    reg signed [17:0] bg_at_y0;
    reg signed [17:0] bg_at_x0;
    reg signed [17:0] bg;

    // Background color increment
    wire signed [17:0] bg_inc = $signed({
        {5'b00000, ~ui_in[2]},
        6'b111111,
        6'b000001
    });

    // Background animation
    always @(posedge clk) begin

        if (~rst_n) begin

            bg_at_y0 <= bg_inc * 640;
            bg_at_x0 <= 0;
            bg <= 0;

        end else if (x_px == 0) begin

            if (y_px == 0) begin

                bg_at_x0 <= bg_inc * 640 + bg_at_y0;

                bg_at_y0 <= rgb18_add(
                    bg_at_y0,
                    -bg_inc * (ui_in[1:0] + 3'b1)
                );

            end else begin

                bg_at_x0 <= rgb18_add(bg_at_x0, bg_inc);
                bg <= bg_at_x0;

            end

        end else begin

            bg <= rgb18_add(bg, bg_inc);

        end
    end

    // Select logo or background color
    assign {r, g, b} = logo ? rgb18(63-2) : bg;

    // Disable colors outside visible area
    assign {R, G, B} =
        ~activevideo ? 0 :
        {r_dither, g_dither, b_dither};

    // TinyVGA PMOD outputs
    // Only one output assignment is selected

`ifdef VGA_REGISTERED_OUTPUTS

    reg [7:0] UO_OUT;

    always @(posedge clk)
        UO_OUT <= {
            hsync,
            B[0],
            G[0],
            R[0],
            vsync,
            B[1],
            G[1],
            R[1]
        };

    assign uo_out = UO_OUT;

`else

    assign uo_out = {
        hsync,
        B[0],
        G[0],
        R[0],
        vsync,
        B[1],
        G[1],
        R[1]
    };

`endif

endmodule


// =====================================================
// MODULE 2: TINY TAPEOUT LOGO
// =====================================================

module tt_logo (
    input  wire [9:0] x,
    input  wire [9:0] y,
    output wire logo
);

    wire signed [8:0] x_signed = $signed(x[8:0]);
    wire signed [8:0] y_signed = $signed(y[8:0]);

    wire [17:0] x_sq;
    wire [17:0] y_sq;

    // Approximate horizontal square
    approx_signed_square #(9,4,4) sq0x (
        .a(x_signed - 9'sd320),
        .p_approx(x_sq)
    );

    // Approximate vertical square
    approx_signed_square #(9,4,3) sq0y (
        .a(y_signed - 9'sd240),
        .p_approx(y_sq)
    );

    wire _unused_ok = &{
        x_sq[17:16],
        y_sq[17:16]
    };

    wire [15:0] r_sq =
        x_sq[15:0] + y_sq[15:0];

    // Circular ring
    wire ring =
        r_sq < 238*238 &
        r_sq > (238-36)*(238-36);

    // Logo geometry
    wire hat0 =
        x >= 80+46 &
        x < 80+46+240 &
        y >= 100 &
        y < 100+64;

    wire leg0 =
        x >= 80+144 &
        x < 80+144+70 &
        y >= 100 &
        y < 100+228;

    wire hat1 =
        x >= 80+144 &
        x < 80+144+254 &
        y >= 222 &
        y < 222+64;

    wire leg1 =
        x >= 80+256 &
        x < 80+256+70 &
        y >= 222 &
        y < 222+240;

    // Ring cuts
    wire cut0 = ~(
        x >= 80 &
        x < 80+144 &
        y >= 100+64 &
        y < 100+60+22
    );

    wire cut1 = ~(
        x >= 80+256+70 &
        x < 80+256+70+22 &
        y >= 222+64 &
        y < 480
    );

    // Final logo
    assign logo =
        (ring & cut0 & cut1) |
        hat0 |
        leg0 |
        hat1 |
        leg1;

endmodule


// =====================================================
// MODULE 3: APPROXIMATE SIGNED SQUARE
// =====================================================

module approx_signed_square #(

    parameter integer W = 12,
    parameter integer T = 4,
    parameter integer R = 3

)(
    input  wire signed [W-1:0] a,
    output wire [2*W-1:0] p_approx
);

    // Parameter validation
    initial begin

        if (W <= 1)
            $error("W must be >= 2");

        if (T < 0)
            $error("T must be >= 0");

        if (T >= W)
            $error("T must be <= W-1");

        if (R < 0)
            $error("R must be >= 0");

        if (R > T)
            $error("R must be <= T");

    end

    localparam integer H = W - T;

    localparam integer PROD_W_HH = 2*H;

    localparam integer SHIFT_HH = 2*T;

    localparam integer SHIFT_X =
        (2*T >= R) ? (2*T - R) : 0;

    // Absolute value
    wire [W-1:0] x =
        a[W-1] ? (~a + 1'b1) : a;

    // Partition
    wire [H-1:0] x_h =
        (T == 0) ? x[W-1:0] : x[W-1:T];

    wire [T-1:0] x_l =
        (T == 0) ? {T{1'b0}} : x[T-1:0];

    // Core multiplication
    wire [PROD_W_HH-1:0] prod_hh_u =
        x_h * x_h;

    wire [2*W-1:0] term_hh_u = {
        {(2*W-PROD_W_HH){1'b0}},
        prod_hh_u
    } << SHIFT_HH;

    // Optional correction
    generate

        if (R == 0) begin : no_correction

            assign p_approx = $signed(term_hh_u);

        end else begin : with_correction

            wire [R-1:0] x_l_top =
                x_l[T-1 -: R];

            wire [H+R-1:0] prod_hl_u =
                x_h * x_l_top;

            wire [2*W-1:0] term_x_u = (
                {
                    {(2*W-(H+R)){1'b0}},
                    prod_hl_u
                } << (SHIFT_X + 1)
            );

            assign p_approx =
                $signed(term_hh_u + term_x_u);

        end

    endgenerate

endmodule


// =====================================================
// MODULE 4: VGA SYNCHRONIZATION GENERATOR
// NEW MODULE ADDED
// VGA 640 x 480
// =====================================================

module hvsync_generator (

    input  wire clk,
    input  wire reset,

    output wire hsync,
    output wire vsync,
    output wire display_on,

    output reg [9:0] hpos,
    output reg [9:0] vpos

);

    // Horizontal VGA parameters
    localparam H_DISPLAY    = 10'd640;
    localparam H_SYNC_START = 10'd656;
    localparam H_SYNC_END   = 10'd752;
    localparam H_TOTAL      = 10'd800;

    // Vertical VGA parameters
    localparam V_DISPLAY    = 10'd480;
    localparam V_SYNC_START = 10'd490;
    localparam V_SYNC_END   = 10'd492;
    localparam V_TOTAL      = 10'd525;

    // Horizontal and vertical counters
    always @(posedge clk) begin

        if (reset) begin

            hpos <= 10'd0;
            vpos <= 10'd0;

        end else begin

            if (hpos == H_TOTAL - 10'd1) begin

                hpos <= 10'd0;

                if (vpos == V_TOTAL - 10'd1)
                    vpos <= 10'd0;
                else
                    vpos <= vpos + 10'd1;

            end else begin

                hpos <= hpos + 10'd1;

            end

        end
    end

    // Horizontal synchronization
    assign hsync = ~(
        (hpos >= H_SYNC_START) &&
        (hpos < H_SYNC_END)
    );

    // Vertical synchronization
    assign vsync = ~(
        (vpos >= V_SYNC_START) &&
        (vpos < V_SYNC_END)
    );

    // Visible area
    assign display_on =
        (hpos < H_DISPLAY) &&
        (vpos < V_DISPLAY);

endmodule

`default_nettype wire
