module display_logic(   input pxl_clk,
                        input [9:0] hcount,
                        input [9:0] vcount,
                        input [9:0] ball_y,
                        input [9:0] ball_x,
                        input [5:0] player_position,
                        input [3:0] block_num,
                        input vsync,
                        input lose,
                        input win,
                        output reg drawing_player,
                        output reg drawing_block,
                        output reg [2:0] rgb    );
    
    `include "defines.v"
    
    reg [2:0] flash;
    reg [3:0] flash_time;
    reg flash_hold;

    always @ (hcount, vcount, ball_y, ball_x, player_position, block_num, lose, win, flash)
    begin : display_decoder
        
        drawing_player = 0;
        drawing_block = 0;

        if (hcount > `screen_right || vcount > `screen_bottom) rgb <= 3'b000;
        
        else if (win) rgb <= flash;
        
        else if (lose) rgb <= `red;
        
        else if (vcount < `bottom_edge && hcount < `left_edge) rgb <= `green;
        
        else if (vcount < `bottom_edge && hcount > `right_edge) rgb <= `green;
        
        else if (vcount < `top_edge ) rgb <= `green;
        
        else if (vcount > `bottom_edge) rgb <= `red;
     
        else if (vcount < ball_y + 3 && vcount > ball_y - 3 && 
                    hcount < ball_x + 3 && hcount > ball_x - 3) rgb <= `white;
        
        else if (   vcount > `player_vstart && vcount < (`player_vstart + `player_width ) && 
                    hcount > (player_position << 5) - `player_hlength + `left_edge && 
                    hcount < ((player_position << 5) + `player_hlength + `left_edge) ) 
        begin
            rgb <= `white;
            drawing_player <= 1;
        end 
                    
        else if (vcount > `blocks_vstart && vcount <= `blocks_vend && hcount > `blocks_hstart && hcount <= `blocks_hend && |block_num)
        begin
            drawing_block <= 1;
            if ( |block_num[2:0] ) rgb <= block_num[2:0];
            
            else rgb <= block_num[2:0] + 3;
    
        //  rgb <= ~|block_num[3:0] ? block_num[2:0] : block_num[2:0] + 3'd3;
        end
        
        else rgb <= `black;
    end
    
    always @ (posedge pxl_clk)
    begin
        if (!vsync)
        begin
            if (!flash_hold) flash_time <= flash_time + 1;
        
            flash_hold <= 1;
        end
            
        else
        begin
            flash_hold <= 0;
        end
        
        if (flash_time == 0)
        begin
            flash <= `black;
        end
        
        
        else if (flash_time == 3)
        begin
            if (win) flash <=  `white;
            else if (lose) flash <= `red;
        end
        
        else if (flash_time >= 6)
        begin
            flash_time <= 0;
        end
        
    end

endmodule