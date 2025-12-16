`default_nettype none

module not_a_dinosaur(
    input  wire [7:0] ui_in,       // Dedicated inputs
    output wire [7:0] uo_out,      // Dedicated outputs
    input  wire [7:0] uio_in,      // IOs: Input path
    output wire [7:0] uio_out,     // IOs: Output path
    output wire [7:0] uio_oe,      // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,         // always 1 when the design is powered, so you can ignore it
    input  wire       clk,         // clock
    input  wire       rst_n        // reset_n - low to reset
);

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Unused outputs assigned to 0.
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, uio_in};

    // Instantiate VGA signal generator
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // ROM for dinosaur shape
    reg [14:0] dino_rom[0:15];

    initial begin
        dino_rom[ 0] = 15'b000111100000000;
        dino_rom[ 1] = 15'b001111111000000;
        dino_rom[ 2] = 15'b011111111100000;
        dino_rom[ 3] = 15'b111111111110000;
        dino_rom[ 4] = 15'b111111111110000;
        dino_rom[ 5] = 15'b111111111110000;
        dino_rom[ 6] = 15'b011111111100000;
        dino_rom[ 7] = 15'b001111111000000;
        dino_rom[ 8] = 15'b001111111001110;
        dino_rom[ 9] = 15'b001111111001110;
        dino_rom[10] = 15'b001110111001110;
        dino_rom[11] = 15'b001110111001100;
        dino_rom[12] = 15'b001110111001100;
        dino_rom[13] = 15'b001110111001100;
        dino_rom[14] = 15'b001110111001100;
        dino_rom[15] = 15'b001110011001100;
    end

    // Parameters for character and square
    localparam DINOSAUR_WIDTH = 15;
    localparam DINOSAUR_HEIGHT = 16;
    localparam DINOSAUR_X_POS = 320;
    localparam JUMP_HEIGHT = 30;
    localparam JUMP_SPEED = 1;
    localparam JUMP_DELAY = 1_000_000;
    localparam SQUARE_SIZE = 10;
    localparam SQUARE_SPEED = 1;
    localparam SQUARE_DELAY = 10_000_000;
    localparam SQUARE_Y_POS = 250;

    // State variables for jumping and square movement
    reg [9:0] dinosaur_y_pos = 240;
    reg [3:0] jump_state = 0;
    reg [23:0] jump_counter = 0;
    reg [9:0] square_x_pos = 640;
    reg [23:0] square_counter = 0;
    reg prev_button_state = 0;

    always @(posedge clk) begin
        if (~rst_n) begin
            jump_state <= 0;
            dinosaur_y_pos <= 240;
            jump_counter <= 0;
            square_counter <= 0;
            prev_button_state <= ui_in[1];
            square_x_pos <= 640;
        end else begin
            prev_button_state <= ui_in[1];

            // Check button and manage jump initiation state
            if (jump_state == 0 && ui_in[1] && ~prev_button_state) begin
                jump_state <= 1;
            end

            // Manage dinosaur jump
            if (jump_state != 0) begin
                if (jump_counter < JUMP_DELAY) begin
                    jump_counter <= jump_counter + 1;
                end else begin
                    jump_counter <= 0;
                    case (jump_state)
                        1: begin
                            if (dinosaur_y_pos > 240 - JUMP_HEIGHT) begin
                                dinosaur_y_pos <= dinosaur_y_pos - JUMP_SPEED;
                            end else begin
                                jump_state <= 2;
                            end
                        end
                        2: begin
                            if (dinosaur_y_pos < 240) begin
                                dinosaur_y_pos <= dinosaur_y_pos + JUMP_SPEED;
                            end else begin
                                jump_state <= 0;
                            end
                        end
                    endcase
                end
            end

            // Manage square movement
            if (square_counter < SQUARE_DELAY) begin
                square_counter <= square_counter + 1;
            end else begin
                square_counter <= 0;
                if (square_x_pos > SQUARE_SPEED) begin
                    square_x_pos <= square_x_pos - SQUARE_SPEED;
                end else begin
                    square_x_pos <= 640;
                end
            end
        end
    end

    // Collision detection and display logic
    wire dino_on = (pix_x >= DINOSAUR_X_POS) && (pix_x < DINOSAUR_X_POS + DINOSAUR_WIDTH) &&
                   (pix_y >= dinosaur_y_pos) && (pix_y < dinosaur_y_pos + DINOSAUR_HEIGHT);
    wire dino_pixel = dino_on ? dino_rom[pix_y - dinosaur_y_pos][pix_x - DINOSAUR_X_POS] : 1'b0;
    wire square_on = (pix_x >= square_x_pos) && (pix_x < square_x_pos + SQUARE_SIZE) &&
                     (pix_y >= SQUARE_Y_POS) && (pix_y < SQUARE_Y_POS + SQUARE_SIZE);

    // Assign colors for display
    assign R = video_active && (dino_pixel || square_on) ? 2'b11 : 2'b00;
    assign G = video_active && dino_pixel ? 2'b11 : 2'b00;
    assign B = video_active && dino_pixel ? 2'b11 : 2'b00;

endmodule