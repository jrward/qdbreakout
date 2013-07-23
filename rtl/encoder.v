module encoder(	input clk,
				input reset_n,
				input a,
				input b,
				output reg [WIDTH-1:0] ctrl);
	
	parameter WIDTH = 6;
	parameter LIMIT = 19;
	parameter DEBOUNCE = 15000;
	
	integer debounce;
			
	reg hold;
		
	always @ (posedge clk or negedge reset_n)
	begin : encoder_logic
		if (!reset_n)
		begin
			ctrl <= 0;
			debounce <= 0;
		end
		
		else if (!a && b && !hold) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce >= DEBOUNCE)
			begin
				if (ctrl < LIMIT) ctrl <= ctrl + 1'b1; 
				hold <= 1;
				debounce <= 0;
			end
		end
		
		else if (!a &&  !b && !hold) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce >= DEBOUNCE)
			begin
				if (ctrl > 0) ctrl <= ctrl - 1'b1; 
				hold <= 1;
				debounce <= 0;
			end
		end
		
		else if (a && hold) 
		begin
			debounce <= debounce + 1'b1;
			if (debounce >= DEBOUNCE)
			begin
				hold <= 0;
				debounce <= 0;
			end
		end
		
		else debounce <= 0;
	end
	
endmodule
