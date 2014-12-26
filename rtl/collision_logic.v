module collision_logic( input pxl_clk,
                        input reset_n,
                        input [9:0] vcount,
                        input [9:0] hcount,
                        input [9:0] ball_x,
                        input [9:0] ball_y,
                        input vsync,
                        input drawing_player,
                        input drawing_block,
                        output reg win,
                        output reg lose,
                        output wire [3:0] block_num,
                        output reg h_collision,
                        output reg v_collision );
                        
                        




        
    
//                             |========||========||========||========| 
//                        |========||========||========||========||========|
//                   |========||========||========||========||========||========|
//15 blocks 
//90 pixels wide = 540 wide along bottom rom
//10 pixels high... 30 pixels top to bottom
//start at (100,320)

//should implement as a dual-port ram
//each location in ram is a 8 x 8 block the value is the block number. 
//a lookup table then maps block number to color
// 64 locations x 16 locations
// 512 pixls x 128 pixels

    reg block_clr;
    wire [9:0] block_addr_r;
    reg [9:0] block_addr_wr;
    reg [3:0] block_to_delete;
    
    reg [4:0] num_blocks = 15;
    reg [9:0] block_addr;
    
    reg checked;
    reg [1:0] hold;
    
    wire [9:0] x_addr;
    wire [9:0] y_addr;
    
    assign x_addr = hcount - `blocks_hstart;
    assign y_addr = `blocks_vend - vcount;
    
    assign block_addr_r = {y_addr[6:3],x_addr[8:3]};


    block_positions block_positions_inst(   .clock(pxl_clk),
                                            .addressstall_a(1'b0),
                                            .data(4'b0000),
                                            .address(block_addr),
                                            .wren(block_clr),
                                            .q(block_num)  );

    always @ (posedge pxl_clk)
    begin
        if (vsync)  block_addr <= block_addr_r;
        else    block_addr <= block_addr_wr;
    
    end
    
    
    always @ (posedge pxl_clk or negedge reset_n)
    begin : delete_objects
    
        if (!reset_n)
        begin
            block_addr_wr <= 0;
            checked <= 1;
            block_clr <= 0;
            block_to_delete <= 0;
            v_collision <= 0;
            h_collision <= 0;
            hold <= 0;
            win <= 0;
            lose <= 0;
        end
        
        else if (vsync)
        begin
            block_clr <= 0;
        
            if (drawing_player) 
            begin
                
                if (ball_x == hcount && ball_y-3 <= vcount && ball_y + 3 >= vcount) v_collision <= 1;
                else v_collision <= 0;
                
            end 
                        
            else if (drawing_block)
            begin
                if (ball_x == hcount && ball_y - 3 <= vcount && ball_y + 3 >= vcount)
                begin
                    v_collision <= 1;
                    block_to_delete <= block_num;
                    num_blocks <= num_blocks - 1;
                    if (num_blocks == 1) win <= 1;
                    
                end
                
                else if (ball_y == vcount && ball_x - 3 <= hcount && ball_x + 3 >= hcount) 
                begin
                    h_collision <= 1;
                    block_to_delete <= block_num;
                    num_blocks <= num_blocks - 1;
                    if (num_blocks == 1) win <= 1;
                end
                
                else
                begin
                    v_collision <= 0;
                    h_collision <= 0;
                end
            end
            
            else if (ball_y >= `bottom_edge) lose <= 1;
        end
            
        else if (!vsync && checked) //initialize addresses
        begin
            block_addr_wr <= 0;
            checked <= 0;
            block_clr <= 0;
            hold <= 0;
        end
        
        
        else if (!vsync && !checked)
        begin
            if (block_num != 0 && block_num == block_to_delete) 
            begin
                block_clr <= 1;
            end

            else 
            begin
                block_clr <= 0;
                //hold <= 0;
                //block_addr_wr <= block_addr_wr + 1;
            end
            
            if (hold != 2 ) block_addr_wr <= block_addr_wr;
            else block_addr_wr <= block_addr_wr + 1;
            
            hold <= hold + 1;
            
            if (block_addr_wr >= 256) 
            begin
                block_addr_wr <= 0;
                checked <= 1;
            end
        end
    
    end
endmodule