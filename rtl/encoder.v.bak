module encoder (input clk,
				input enc_a,
				input enc_b,
				output reg [WIDTH-1:0] ctrl);
	
	parameter WIDTH = 6;
	parameter LIMIT = 19;
	parameter DEBOUNCE = 15;
	
	integer debounce;
			
	reg hold;
		
	always @ (posedge clk)
	begin : encoder_logic
		if (~enc_a && enc_b && hold == 0) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce == DEBOUNCE)
			begin
				if (ctrl < LIMIT) ctrl <= ctrl + 1; 
				hold <= 1;
				debounce <= 0;
			end
		end
		
		else if (~enc_a &&  ~enc_b && hold == 0) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce == DEBOUNCE)
			begin
				if (ctrl > 1) ctrl <= ctrl - 1; 
				hold <= 1;
				debounce <= 0;
			end
		end
		
		else if (enc_a && hold == 1) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce == DEBOUNCE)
			begin
				hold <= 0;
				debounce <= 0;
			end
		end
		
		else debounce <= 0;
	end
endmodule