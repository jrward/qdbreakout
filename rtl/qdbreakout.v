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
	reg hold;
		
	reg drawn;
	reg lose;
	reg checked;
	
	reg [9:0] ball_x = 320;
	reg [9:0] ball_y = 240;
	reg [1:0] ball_state;
	reg [1:0] next_ball_state;
	
	reg blocks [14:0];
	//reg [9:0] blocks_pos[31:0] /* synthesis ram_init_file = "block_positions.mif" */;
	reg [3:0] block_addr;
	reg xory;
	wire [18:0] block_coords;
	reg [18:0] b0 = {10'd100,9'd320};
	reg [18:0] b1 = {10'd190,9'd320};
	reg [18:0] b2 = {10'd280,9'd320};
	reg [18:0] b3 = {10'd370,9'd320};
	reg [18:0] b4 = {10'd460,9'd320};
	reg [18:0] b5 = {10'd550,9'd320};
	reg [18:0] b6 = {10'd145,9'd330};
	reg [18:0] b7 = {10'd235,9'd330};
	reg [18:0] b8 = {10'd325,9'd330};
	reg [18:0] b9 = {10'd415,9'd330};
	reg [18:0] b10 = {10'd505,9'd330};
	reg [18:0] b11 = {10'd190,9'd340};
	reg [18:0] b12 = {10'd280,9'd340};
	reg [18:0] b13 = {10'd370,9'd340};
	reg [18:0] b14 = {10'd460,9'd340};

	`define ycoord 18:9
	`define xcoord 8:0
	
//	reg [9:0] blocks_x [10:0];
//	reg [9:0] blocks_y [10:0];
	
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
	parameter screen_left = 0;
	parameter screen_right = 639;
	parameter screen_top = 0;
	parameter screen_bottom = 479;
	parameter left_edge = 8;
	parameter right_edge = 632 ;
	parameter top_edge = 8;
	parameter bottom_edge = 472;
	
	parameter num_blocks = 15;
	
	parameter player_vstart = 460;
	parameter player_width = 8;
	parameter player_hlength = 32;
	
	parameter block_width = 10;
	parameter block_length = 90;
	
	parameter down_right = 2'b00;
	parameter down_left = 2'b01;
	parameter up_right = 2'b10;
	parameter up_left = 2'b11;
	
	
	
//							   |========||========||========||========|	
//	                      |========||========||========||========||========|
//	                 |========||========||========||========||========||========|
//15 blocks	
//90 pixels wide = 540 wide along bottom rom
//10 pixels high... 30 pixels top to bottom
//start at (100,320)


	
	assign enc_c = 0;
					
	pxl_clk pxl_clk_inst (clk, pxl_clk);	//pll to convert 50 MHz onboard clock to 25 MHz
	
	encoder horizontal_enc (.clk(pxl_clk),
							.reset_n(reset_n),
							.a(enc_a),
							.b(enc_b),
							.ctrl(position) );
							
	blocks_pos_rom blocks_pos (	.clk(pxl_clk),
								.addr(block_addr),
								.q(block_coords) );
	/*blocks_pos_rom disp_blocks_pos ( .clk(pxl_clk),
										.addr(disp_block_addr
	*/						
	initial 
	begin
		integer i;
		for (i=0; i<15; i=i+1)
		begin
			blocks[i] = 1'b1;
		end
		
	//	for (i = 0; i <31; i=i+1)
	//	begin
//			blocks_pos[i] = 0;
//		
//		end
		
		//$readmemh("block_positions.mif", block_positions);
	
	end
	
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
 10 lines horizontal sync 
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
			endcase
		end
				
		else if (vsync && drawn) drawn <= 0;
	
	end
	
	always @ (posedge pxl_clk or negedge reset_n)
	begin : register_generation
		if (!reset_n) ball_state <= down_right;
		
		else ball_state <= next_ball_state;
	end
	
	always @ (posedge pxl_clk)// or negedge reset_n)
	begin
		/*if (!reset_n)
		begin
			integer i;
		//	for (i=0; i<15; i=i+1)
		//	begin
		//		blocks[i] = 1'b1;
		//	end
			block_addr <= 0;
			checked <= 0;
			v_collision <= 0;
			h_collision <= 0;
		end
		*/
		
		if (!vsync && !drawn)	//initialize addresses
		begin
			block_addr <= 0;
			checked <= 0;
			v_collision <= 0;
			h_collision <= 0;
		end
		
		else if (!vsync && drawn && !checked)
		begin
			if (blocks[block_addr])
			begin
				//just check for vertical/horizontal collisions. 
				if (ball_x > block_coords[`xcoord] + 1 && ball_x < block_coords[`xcoord] + 89 && 
					ball_y >= block_coords[`ycoord] && ball_y <= block_coords[`ycoord] + 10 )
				begin
					v_collision <= 1;
					blocks[block_addr] <= 0;
					checked <= 1;	
				end
				
				else if (ball_x >= block_coords[`xcoord] && ball_x <= block_coords[`xcoord] + 90 && 
					ball_y < block_coords[`ycoord] + 10 && ball_y > block_coords[`ycoord] +5 )
				begin
					h_collision <= 1;
					blocks[block_addr] <= 0;
					checked <= 1;			
				end
				
				else
				begin
					v_collision <= 0;
					h_collision <= 0;
				end
					
			end
			/*	
				if (ball_y >= block_coords[`ycoord] && ball_y <= block_coords[`ycoord] + 10)				
				begin
					if (ball_x >= block_coords[`xcoord] && ball_x =< block_coords[`xcoord] + 90)
					begin
						blocks[block_addr] <= 0;
		//				if (ball_x
						
						checked <= 1;
						
					end
				end
			end*/
			
			if(block_addr >= 14) 
			begin
				checked <= 1;
			//	block_addr <= 0;
			end
			
			else block_addr <= block_addr + 1'd1;
			
		end
		
	end
	

	always @ (ball_state or ball_x or ball_y or h_collision or v_collision)
	begin
		case (ball_state)
			down_right:
			begin
				if (ball_y >= bottom_edge)	next_ball_state <= up_right;
				else if (ball_x >= right_edge) next_ball_state <= down_left;
				else if (v_collision) next_ball_state <= up_right;
				else if (h_collision) next_ball_state <= down_left;
				else next_ball_state <= down_right;
			end
			
			down_left:
			begin
				if (ball_y >= bottom_edge)next_ball_state <= up_left;
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
	always @ (ball_x or ball_y)
	begin
		if (ball_y >= bottom_edge) lose <= 1;
		else lose <= 0;
	end

	
	//always @ (hcount, vcount, position, lose)
	always @ (*)
	begin : display_decoder
	
		if (hcount > screen_right || vcount > screen_bottom) rgb <= 3'b000;
		
		else if (lose) rgb <= red;
		
		else if (vcount < bottom_edge && hcount < left_edge) rgb <= green;
		
		else if (vcount < bottom_edge && hcount < right_edge) rgb <= green;
		
		else if (vcount < top_edge ) rgb <= green;
		
		else if (vcount > bottom_edge) rgb <= red;
		
		else if (vcount >= b0[`ycoord] && vcount <= b0[`ycoord] + block_width &&
					hcount >= b0[`xcoord] && hcount <= b0[`xcoord] + block_length && blocks[0])
					rgb <= cyan; 
					
		else if (vcount >= b1[`ycoord] && vcount <= b1[`ycoord] + block_width &&
					hcount >= b1[`xcoord] && hcount <= b1[`xcoord] + block_length && blocks[1])
					rgb <= magenta;
					
		else if (vcount >= b2[`ycoord] && vcount <= b2[`ycoord] + block_width &&
					hcount >= b2[`xcoord] && hcount <= b2[`xcoord] + block_length && blocks[2])
					rgb <= yellow;
					
		else if (vcount >= b3[`ycoord] && vcount <= b3[`ycoord] + block_width &&
					hcount >= b3[`xcoord] && hcount <= b3[`xcoord] + block_length && blocks[3])
					rgb <= red;
					
		else if (vcount >= b4[`ycoord] && vcount <= b4[`ycoord] + block_width &&
					hcount >= b4[`xcoord] && hcount <= b4[`xcoord] + block_length && blocks[4])
					rgb <= green;
			
		else if (vcount >= b5[`ycoord] && vcount <= b5[`ycoord] + block_width &&
					hcount >= b5[`xcoord] && hcount <= b5[`xcoord] + block_length && blocks[5])
					rgb <= blue;
					
		else if (vcount >= b6[`ycoord] && vcount <= b6[`ycoord] + block_width &&
					hcount >= b6[`xcoord] && hcount <= b6[`xcoord] + block_length && blocks[6])
					rgb <= red;
					
		else if (vcount >= b7[`ycoord] && vcount <= b7[`ycoord] + block_width &&
					hcount >= b7[`xcoord] && hcount <= b7[`xcoord] + block_length && blocks[7])
					rgb <= cyan;
					
		else if (vcount >= b8[`ycoord] && vcount <= b8[`ycoord] + block_width &&
					hcount >= b8[`xcoord] && hcount <= b8[`xcoord] + block_length && blocks[8])
					rgb <= magenta;
				
		else if (vcount >= b9[`ycoord] && vcount <= b9[`ycoord] + block_width &&
					hcount >= b9[`xcoord] && hcount <= b9[`xcoord] + block_length && blocks[9])
					rgb <= yellow;
					
		else if (vcount >= b10[`ycoord] && vcount <= b10[`ycoord] + block_width &&
					hcount >= b10[`xcoord] && hcount <= b10[`xcoord] + block_length && blocks[10])
					rgb <= green;
					
		else if (vcount >= b11[`ycoord] && vcount <= b11[`ycoord] + block_width &&
					hcount >= b11[`xcoord] && hcount <= b11[`xcoord] + block_length && blocks[11])
					rgb <= blue;
		
		else if (vcount >= b12[`ycoord] && vcount <= b12[`ycoord] + block_width &&
					hcount >= b12[`xcoord] && hcount <= b12[`xcoord] + block_length && blocks[12])
					rgb <= red;
					
		else if (vcount >= b13[`ycoord] && vcount <= b13[`ycoord] + block_width &&
					hcount >= b13[`xcoord] && hcount <= b13[`xcoord] + block_length && blocks[13])
					rgb <= cyan;
					
		else if (vcount >= b14[`ycoord] && vcount <= b14[`ycoord] + block_width &&
					hcount >= b14[`xcoord] && hcount <= b14[`xcoord] + block_length && blocks[14])
					rgb <= magenta;
					
		else if (vcount < ball_y + 1 && vcount > ball_y - 1 && 
					hcount < ball_x + 1 && hcount > ball_x - 1)	rgb <= white;
		
		else if (	vcount > player_vstart && vcount < (player_vstart + player_width ) && 
					hcount > ((position << 5) - player_hlength + left_edge) && 
					hcount < ((position << 5) + player_hlength + left_edge)	) rgb <= white;
		
		else rgb <= black;
	end
	
endmodule
	
	
