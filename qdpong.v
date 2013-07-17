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

	reg [5:0] position;
	
	wire pxl_clk;
	wire debounce_clk; //16 kHz clk
	reg [3:0] debounce;
	reg hold;
	
	wire [2:0] pixel;
	
	parameter red = 3'b100;
	parameter green = 3'b010;
	parameter blue = 3'b001;
	parameter white = 3'b111;
	parameter black = 3'b000;
	parameter cyan = 3'b011;
	parameter magenta = 3'b101;
	parameter yellow = 3'b110;
	
	assign enc_c = 0;
					
	pxl_clk pxl_clk_inst (clk, pxl_clk);
	
	debounce_clk debounce_clk_inst (clk, debounce_clk);
	
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
	
	always @ (hcount, vcount, pixel, position)
	begin : display_decoder
	
		if (hcount >= 640 || vcount >= 480) rgb <= 3'b000;
		
		else if (vcount <= 460 && (hcount >= 0 && hcount < 8)) rgb <= green;
		
		else if (vcount <= 460 && hcount >= 631 && hcount < 640) rgb <= green;
		
		else if (vcount < 8 ) rgb <= green;
		
		else if (vcount > 472) rgb <= red;
		
		//else if (hcount == 320 || vcount == 240) rgb = black;
		
		//else if (hcount < 100 || vcount < 100 || hcount > 540 || vcount > 380) rgb = 3'b100;
		
		else if ((vcount > 460 && vcount < 470) && (hcount > ((position << 5) - 32) && hcount < ((position << 5) + 32))) rgb <= 3'b111;
		
		else rgb <= 3'b00;
		
	end
	
	always @ (posedge debounce_clk)
	begin : encoder_logic
		if (~enc_a && enc_b && hold == 0) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce == 15)
			begin
				if (position < 19) position <= position + 1; 
				hold <= 1;
				debounce <= 0;
			end
		end
		
		else if (~enc_a &&  ~enc_b && hold == 0) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce == 15)
			begin
				if (position > 1) position <= position - 1; 
				hold <= 1;
				debounce <= 0;
			end
		end
		
		else if (enc_a && hold == 1) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce == 15)
			begin
				hold <= 0;
				debounce <= 0;
			end
		end
		
		else debounce <= 0;
	end
		
	
endmodule
	
	