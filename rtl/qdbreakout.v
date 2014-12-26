module qdbreakout(  input wire clk,
                    input wire reset_n,
                    input wire enc_a,
                    input wire enc_b,
                    output wire enc_c,
                    output wire [2:0] rgb,
                    output wire hsync,
                    output wire vsync
                    );
                    
    `include "defines.v"                 
                    
    wire [9:0] hcount;   
    wire [9:0] vcount;
    wire [5:0] player_position;
    wire pxl_clk;       //25 MHz clock from PLL
    wire lose;
    wire win;
    wire [9:0] ball_x;
    wire [9:0] ball_y;
    wire [3:0] block_num;
    wire v_collision;
    wire h_collision;

    wire drawing_player;
    wire drawing_block;  
    
    reg start;
    integer count;
    
    //add 4 second wait to let monitor sync before starting game
    always @ (posedge pxl_clk or negedge reset_n)
    begin
        if (!reset_n)
        begin
            start <= 0;
            count <= 0;
        end
        
        else if (count < 100000000)
        begin
            count <= count + 1;
            start <= 0;
        end
        
        else
        begin
            count <= count;
            start <= 1;
        end
    end

    
    assign enc_c = 0;
                    
    pxl_clk pxl_clk_inst (clk, pxl_clk);    //pll to convert 50 MHz onboard clock to 25 MHz
    
    encoder horizontal_enc (.clk(pxl_clk),
                            .reset_n(reset_n),
                            .a(enc_a),
                            .b(enc_b),
                            .ctrl(player_position) );
                            


    vga vga_inst(   .pxl_clk(pxl_clk),
                    .reset_n(reset_n),
                    .hcount(hcount),
                    .vcount(vcount),
                    .vsync(vsync),
                    .hsync(hsync)   );


    ball_logic ball_inst(   .pxl_clk(pxl_clk),
                            .reset_n(reset_n),
                            .vsync(vsync),
                            .h_collision(h_collision),
                            .v_collision(v_collision),
                            .start(start),
                            .ball_x(ball_x),
                            .ball_y(ball_y) );
                            
    display_logic display_logic_inst(   .pxl_clk(pxl_clk),
                                        .hcount(hcount),
                                        .vcount(vcount),
                                        .ball_y(ball_y),
                                        .ball_x(ball_x),
                                        .player_position(player_position),
                                        .block_num(block_num),
                                        .lose(lose),
                                        .win(win),
                                        .vsync(vsync),
                                        .drawing_player(drawing_player),
                                        .drawing_block(drawing_block),
                                        .rgb(rgb)    );
                                        

    collision_logic collision_inst( .pxl_clk(pxl_clk),
                                    .reset_n(reset_n),
                                    .vcount(vcount),
                                    .hcount(hcount),
                                    .ball_x(ball_x),
                                    .ball_y(ball_y),
                                    .vsync(vsync),
                                    .drawing_player(drawing_player),
                                    .drawing_block(drawing_block),
                                    .win(win),
                                    .lose(lose),
                                    .block_num(block_num),
                                    .h_collision(h_collision),
                                    .v_collision(v_collision)    );
    

endmodule
    
    
