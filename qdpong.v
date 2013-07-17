module qdpong(	input clk,
					input reset_n,
					input enc_a,
					input enc_b,
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
	
	wire [2:0] pixel;
	
	reg drawn;
	reg lose;
	
	reg [9:0] ball_x;
	reg [9:0] ball_y;
	reg [1:0] ball_state;
	reg [1:0] next_ball_state;
	
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
	
	parameter down_right = 2'b00;
	parameter down_left = 2'b01;
	parameter up_right = 2'b10;
	parameter up_left = 2'b11;
	
	
	assign enc_c = 0;
					
	pxl_clk pxl_clk_inst (clk, pxl_clk);	//pll to convert 50 MHz onboard clock to 25 MHz
	
	debounce_clk debounce_clk_inst (clk, debounce_clk);
	
	encoder horizontal_enc (.clk(debounce_clk),
							.enc_a(enc_a),
							.enc_b(enc_b),
							.ctrl(position) );
	
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
			ball_x <= 320;
			ball_y <= 240;
			drawn <= 1;
		end
		
		else if (!vsync && !drawn) 
		begin
			drawn <= 1;
			case(ball_state)
				down_right:
				begin
					ball_x <= ball_x + 1;
					ball_y <= ball_y + 2;
				end
				
				down_left:
				begin
					ball_x <= ball_x - 1;
					ball_y <= ball_y + 2;
				end
				
				up_right:
				begin
					ball_x <= ball_x + 1;
					ball_y <= ball_y - 2;
				end
				
				up_left:
				begin
					ball_x <= ball_x - 1;
					ball_y <= ball_y - 2;
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
	
	always @ (ball_state or ball_x or ball_y)
	begin : next_state_logic
		case (ball_state)
			down_right:
			begin
				if (ball_y <= bottom_edge) lose <= 1; //ball_state <= up_right;
				else if (ball_x >= right_edge) next_ball_state <= down_left;
			end
			
			down_left:
			begin
				if (ball_y <= bottom_edge) lose <= 1; //ball_state <= up_left;
				else if (ball_x <= left_edge) next_ball_state <= down_right;
			end
			
			up_right:
			begin
				if (ball_y >= top_edge) next_ball_state <= down_right;
				else if (ball_x >= right_edge) next_ball_state <= up_left;
			end
			
			up_left:
			begin
				if (ball_y >= top_edge) next_ball_state <= down_left;
				else if (ball_x <= left_edge) next_ball_state <= up_right;
			end
		endcase
	end

	
	always @ (hcount, vcount, pixel, position)
	begin : display_decoder
	
		if (hcount >= 640 || vcount >= 480) rgb <= 3'b000;
		
		else if (lose) rgb <= red;
		
		else if (vcount <= bottom_edge && hcount < left_edge) rgb <= green;
		
		else if (vcount <= bottom_edge && hcount < right_edge) rgb <= green;
		
		else if (vcount < top_edge ) rgb <= green;
		
		else if (vcount > bottom_edge) rgb <= red;
		
		else if ((vcount > 460 && vcount < 470) && (hcount > ((position << 5) - 32) && hcount < ((position << 5) + 32))) rgb <= 3'b111;
		
		else rgb <= 3'b000;
		
	end
	
	
	
endmodule
	
	