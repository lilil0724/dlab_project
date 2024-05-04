// Purpose of this Module:
// Controls the state transition and designs of all the states
module Pong_FSM #(
    parameter
    TOTAL_COLS = 800,
    TOTAL_ROWS = 525,
    ACTIVE_COLS = 640,
    ACTIVE_ROWS = 480
    ) (
    input clock,
    input in_Hsync,
    input in_Vsync,
    input start,
    input p1_up,
    input p1_down,
    input p2_up,
    input p2_down,

    output reg out_Hsync = 0,
    output reg out_Vsync = 0,
    output reg [3:0] p1_score,
    output reg [3:0] p2_score,
    output [3:0] out_Red,
    output [3:0] out_Green,
    output [3:0] out_Blue
    );


    // We divide the original width and height by 16
    // 640/16 = 40, 480/16 = 30
    // now each board unit represents 16*16 pixels
    // This way we only need to keep track of less column and row positions
    parameter GAME_WIDTH = 40, GAME_HEIGHT = 30;
    parameter SCORE_LIMIT = 9;
    parameter PADDLE_HEIGHT = 6;
    parameter P1_PADDLE_COLUMN = 0, P2_PADDLE_COLUMN = GAME_WIDTH-1;
    parameter IDLE = 3'd0, RUNNING = 3'd1, P1_SCORE = 3'd2, P2_SCORE = 3'd3, RESTART = 3'd4;


    reg [3:0] state = IDLE;
    wire temp_Hsync, temp_Vsync, p1_draw_paddle, p2_draw_paddle, draw, reset_n;
    wire [9:0] column_count, row_count;
    wire [5:0] p1_paddle_y, p2_paddle_y, ball_x, ball_y;
    wire [5:0] small_column_count, small_row_count;

    // Divide by 16
    assign small_column_count = column_count[9:4];
    assign small_row_count = row_count[9:4];
    assign reset_n = (state == RUNNING) ? 1 : 0;


    VGA_Sync_to_Count #(
        .TOTAL_COLS(TOTAL_COLS),
        .TOTAL_ROWS(TOTAL_ROWS)
        ) VGA_Sync_to_Count_wrap (
        .clock(clock),
        .in_Hsync(in_Hsync),
        .in_Vsync(in_Vsync),

        .out_Hsync(temp_Hsync),
        .out_Vsync(temp_Vsync),
        .column_count(column_count),
        .row_count(row_count)
        );

    always @(posedge clock) begin
        out_Hsync <= temp_Hsync;
        out_Vsync <= temp_Vsync;
    end


    Pong_Paddle_Control #(
        .PADDLE_HEIGHT(PADDLE_HEIGHT),
        .GAME_HEIGHT(GAME_HEIGHT)
        ) p1_paddle (
        .clock(clock),
        .column_count(small_column_count),
        .row_count(small_row_count),
        .up(p1_up),
        .down(p1_down),

        .paddle_y(p1_paddle_y)
        );

    Pong_Paddle_Control #(
        .PADDLE_HEIGHT(PADDLE_HEIGHT),
        .GAME_HEIGHT(GAME_HEIGHT)
        ) p2_paddle (
        .clock(clock),
        .column_count(small_column_count),
        .row_count(small_row_count),
        .up(p2_up),
        .down(p2_down),

        .paddle_y(p2_paddle_y)
        );

    Pong_Ball_Control #(
        .GAME_HEIGHT(GAME_HEIGHT),
        .GAME_WIDTH(GAME_WIDTH)
        ) ball_wrap (
        .clock(clock),
        .reset_n(reset_n),
        .column_count(small_column_count),
        .row_count(small_row_count),

        .ball_x(ball_x),
        .ball_y(ball_y)
        );

    Draw #(
        .P1_PADDLE_X(P1_PADDLE_COLUMN),
        .P2_PADDLE_X(P2_PADDLE_COLUMN),
        .PADDLE_HEIGHT(PADDLE_HEIGHT)
        ) draw_wrap (
        .clock(clock),
        .ball_y(ball_y),
        .column_count(small_column_count),
        .row_count(small_row_count),

        .out_Red(out_Red),
        .out_Green(out_Green),
        .out_Blue(out_Blue)
        );

    
    always @(posedge clock) begin
        case (state)
        // Stay in this state until start button is hit
        IDLE: state <= (reset_n) ? RUNNING : IDLE;
        // Stay in this state until a player scores
        RUNNING: begin
            // P1 score 
            if (((ball_x == GAME_WIDTH-1) && (ball_y < p2_paddle_y))
                || (ball_y > (p2_paddle_y + PADDLE_HEIGHT))) begin
                state <= P1_SCORE;
            // P2 score
            end else if ((ball_x == 0) && (ball_y < p1_paddle_y) 
                || (ball_y > (p1_paddle_y + PADDLE_HEIGHT))) begin
                state <= P2_SCORE;
            end
        end
        
        P1_SCORE: begin
            if (p1_score == SCORE_LIMIT-1) begin
                p1_score <= 0;
            end else begin
                p1_score <= p1_score + 1;
                state <= RESTART;
            end
        end

        P2_SCORE: begin
            if (p2_score == SCORE_LIMIT-1) begin
                p2_score <= 0;
            end else begin
                p2_score <= p2_score + 1;
                state <= RESTART;
            end
        end

        RESTART: state <= IDLE;
        endcase
    end
endmodule