module qdbreakout(  input wire clk,
				    input wire reset_n,
					input wire enc_a,
					input wire enc_b,
					output wire enc_c,
					output reg [2:0] rgb,
					output reg hsync,
					output reg vsync
					);
					
					
	reg [9:0] hcount;	
	reg [9:0] vcount;

	wire [5:0] position;
	
	wire pxl_clk;		//25 MHz clock
	wire debounce_clk; //16 kHz clk for sampling FPGA input pins
	reg [3:0] debounce;
	reg [1:0] hold;
		
	reg drawn;
	reg lose = 0;
	reg win = 0;
	reg checked;
	reg [2:0] flash;
	reg [3:0] flash_time;
	reg flash_hold;
	
	reg [9:0] ball_x;
	reg [9:0] ball_y;
	reg [1:0] ball_state;
	reg [1:0] next_ball_state;
	
	reg [4:0] num_blocks = 15;
	//reg [9:0] blocks_pos[31:0] /* synthesis ram_init_file = "block_positions.mif" */;
	reg [9:0] block_addr;
	
	reg block_clr;
	wire [9:0] block_addr_r;
	reg [9:0] block_addr_wr;
	wire [3:0] block_num;
	reg [3:0] block_to_delete;
	
	`define ycoord 9:6
	`define xcoord 5:0
	
	reg xory;
	wire [18:0] block_coords;
	
	reg v_collision;
	reg h_collision;

	
	parameter red = 3'b100;
	parameter green = 3'b010;
	parameter blue = 3'b001;
	parameter white = 3'b111;
	parameter black = 3'b000;
	parameter cyan = 3'b011;
	parameter magenta = 3'b101;
	parameter yellow = 3'b110;
	
	parameter win_color = white;
	parameter lose_color = red;
	
	parameter screen_left = 0;
	parameter screen_right = 639;
	parameter screen_top = 0;
	parameter screen_bottom = 479;
	
	parameter left_edge = 8;
	parameter right_edge = 632 ;
	parameter top_edge = 8;
	parameter bottom_edge = 472;
	
	parameter player_vstart = 460;
	parameter player_width = 8;
	parameter player_hlength = 32;
	
	parameter blocks_hstart = 64;
	parameter blocks_hend = 576;
	parameter blocks_vstart = 64;
	parameter blocks_vend = 192;
	
	parameter block_width = 10;
	parameter block_length = 90;
	
	parameter down_right = 2'b00;
	parameter down_left = 2'b01;
	parameter up_right = 2'b10;
	parameter up_left = 2'b11;
	
	reg drawing_player;
	reg drawing_block;
	
		
	wire [9:0] x_addr;
	wire [9:0] y_addr;
	
	assign x_addr = hcount - blocks_hstart;
	assign y_addr = blocks_vend - vcount;
	
	assign block_addr_r = {y_addr[6:3],x_addr[8:3]};
	
	//assign block_addr = vsync ? block_addr_r : block_addr_wr;
	

	
	
	
//							   |========||========||========||========|	
//	                      |========||========||========||========||========|
//	                 |========||========||========||========||========||========|
//15 blocks	
//90 pixels wide = 540 wide along bottom rom
//10 pixels high... 30 pixels top to bottom
//start at (100,320)

//should implement as a dual-port ram
//each location in ram is a 8 x 8 block the value is the block number. 
//a lookup table then maps block number to color
// 64 locations x 16 locations
// 512 pixls x 128 pixels

	always @ (posedge pxl_clk)
	begin
		if (vsync)	block_addr <= block_addr_r;
		else	block_addr <= block_addr_wr;
	
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
			flash <= black;
		end
		
		
		else if (flash_time == 3)
		begin
			if (win) flash <=  win_color;
			else if (lose) flash <= lose_color;
		end
		
		else if (flash_time >= 6)
		begin
			flash_time <= 0;
		end
		
	end




	
	assign enc_c = 0;
					
	pxl_clk pxl_clk_inst (clk, pxl_clk);	//pll to convert 50 MHz onboard clock to 25 MHz
	
	encoder horizontal_enc (.clk(pxl_clk),
							.reset_n(reset_n),
							.a(enc_a),
							.b(enc_b),
							.ctrl(position) );
							
//	blocks_pos_rom blocks_pos (	.clk(pxl_clk),
//								.addr(block_addr),
//								.q(block_coords) );
								
	block_positions block_positions (	.clock(pxl_clk),
										.addressstall_a(1'b0),
										.data(4'b0000),
										.address(block_addr),
										.wren(block_clr),
										.q(block_num)  );
	
			

	always @ (posedge pxl_clk or negedge reset_n)
	begin : hcounter
		if (!reset_n) hcount <= 0;
		
		else if (hcount <= 799) hcount <= hcount + 1'b1;
		
		else hcount <= 0;
	end
	
	always @ (posedge pxl_clk or negedge reset_n)
	begin : vcounter
		if (!reset_n) vcount <= 0;
		
		else if (hcount == 799 && vcount <= 521) vcount <= vcount + 1'b1;
		
		else if (vcount <= 521) vcount <= vcount;
		
		else vcount <= 0;
	end
/********************************	
 640 pixels video 
 16 pixels front porch 
 96 pixels horizontal sync 
 48 pixels back porch 
*********************************/
	always @ (hcount)
	begin : hsync_decoder
		if (hcount >= 656 && hcount <= 752) hsync <= 0;
		
		else hsync <= 1;
		
	end
	
/********************************	
 480 lines video 
 2 lines front porch 
 10 lines vertical sync 
 29 lines back porch 
*********************************/	
	always @ (vcount)
	begin : vsync_decoder
		if (vcount >= 482 && vcount <= 492) vsync <= 0;
		
		else vsync <= 1;
	end
	
	
	always @ (posedge pxl_clk or negedge reset_n)
	begin : ball_logic
		if (!reset_n)
		begin
			drawn <= 1;
			//lose <= 0;
			ball_y <= 240;
			ball_x <= 260;
			//ball_y <= 240;
		end
		
		else if (!vsync && !drawn) 
		begin
			drawn <= 1;
			case(ball_state)
				down_right:
				begin
					ball_x <= ball_x + 2'd1;
					ball_y <= ball_y + 2'd2;
				end
				
				down_left:
				begin
					ball_x <= ball_x - 2'd1;
					ball_y <= ball_y + 2'd2;
				end
				
				up_right:
				begin
					ball_x <= ball_x + 2'd1;
					ball_y <= ball_y - 2'd2;
				end
				
				up_left:
				begin
					ball_x <= ball_x - 2'd1;
					ball_y <= ball_y - 2'd2;
				end
				
				default:
				begin
					ball_x <= ball_x + 2'd1;
					ball_y <= ball_y + 2'd2;
				end
			endcase
		end
				
		else if (vsync && drawn)
		begin
			drawn <= 0;
		end
	
	end
	
	always @ (posedge pxl_clk or negedge reset_n)
	begin : register_generation
		if (!reset_n) ball_state <= down_right;
		
		else ball_state <= next_ball_state;
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
					if (num_blocks == 0) win <= 1;
				end
				
				else
				begin
					v_collision <= 0;
					h_collision <= 0;
				end
			end
			
			else if (ball_y >= bottom_edge) lose <= 1;
		end
			
		else if (!vsync && checked)	//initialize addresses
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
	

	always @ (ball_state or ball_x or ball_y or h_collision or v_collision)
	begin
		case (ball_state)
			down_right:
			begin
				if (ball_y >= bottom_edge) next_ball_state <= up_right;
				else if (ball_x >= right_edge) next_ball_state <= down_left;
				else if (v_collision) next_ball_state <= up_right;
				else if (h_collision) next_ball_state <= down_left;
				else next_ball_state <= down_right;
			end
			
			down_left:
			begin
				if (ball_y >= bottom_edge) next_ball_state <= up_left;
				else if (ball_x <= left_edge) next_ball_state <= down_right;
				else if (v_collision) next_ball_state <= up_left;
				else if (h_collision) next_ball_state <= down_right;
				else next_ball_state <= down_left;
			end
			
			up_right:
			begin
				if (ball_y <= top_edge) next_ball_state <= down_right;
				else if (ball_x >= right_edge) next_ball_state <= up_left;
				else if (v_collision) next_ball_state <= down_right;
				else if (h_collision) next_ball_state <= up_left;
				else next_ball_state <= up_right;
			end
			
			up_left:
			begin
				if (ball_y <= top_edge) next_ball_state <= down_left;
				else if (ball_x <= left_edge) next_ball_state <= up_right;
				else if (v_collision) next_ball_state <= down_left;
				else if (h_collision) next_ball_state <= up_right;
				else next_ball_state <= up_left;
			end 
		endcase
	end
	
	//add loss logic!
/*	always @ (ball_x or ball_y)
	begin
		if (ball_y >= bottom_edge) lose <= 1;
		else lose <= 0;
	end*/

	
	//always @ (hcount, vcount, position, lose)
	always @ (hcount, vcount, ball_y, ball_x, position, block_num, lose, win, flash)
	begin : display_decoder
		
		drawing_player = 0;
		drawing_block = 0;

		if (hcount > screen_right || vcount > screen_bottom) rgb <= 3'b000;
		
		else if (win) rgb <= flash;
		
		else if (lose) rgb <= red;
		
		else if (vcount < bottom_edge && hcount < left_edge) rgb <= green;
		
		else if (vcount < bottom_edge && hcount > right_edge) rgb <= green;
		
		else if (vcount < top_edge ) rgb <= green;
		
		else if (vcount > bottom_edge) rgb <= red;
		
		
				
		else if (vcount < ball_y + 3 && vcount > ball_y - 3 && 
					hcount < ball_x + 3 && hcount > ball_x - 3)	rgb <= white;
		
		else if (	vcount > player_vstart && vcount < (player_vstart + player_width ) && 
					hcount > (position << 5) - player_hlength + left_edge && 
					hcount < ((position << 5) + player_hlength + left_edge)	) 
		begin
			
			rgb <= white;
			drawing_player <= 1;
		end 
					
		else if (vcount > blocks_vstart && vcount <= blocks_vend && hcount > blocks_hstart && hcount <= blocks_hend && |block_num)
		begin
			drawing_block <= 1;
			if ( |block_num[2:0] ) rgb <= block_num[2:0];
			
			else rgb <= block_num[2:0] + 3;
	
		//	rgb <= ~|block_num[3:0] ? block_num[2:0] : block_num[2:0] + 3'd3;
		end
		
		else rgb <= black;
	end
	
endmodule
	
	
