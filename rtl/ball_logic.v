module ball_logic(  input pxl_clk,
                    input reset_n,
                    input vsync,
                    input h_collision,
                    input v_collision,
                    input start,
                    output reg [9:0] ball_x,
                    output reg [9:0] ball_y   );


    `include "defines.v"

    parameter down_right = 3'b000;
    parameter down_left = 3'b001;
    parameter up_right = 3'b010;
    parameter up_left = 3'b011;
    parameter stop = 3'b100;

    reg drawn;
    reg [2:0] ball_state;
    reg [2:0] next_ball_state;

    always @ (posedge pxl_clk or negedge reset_n)
    begin : ball_logic
        if (!reset_n)  
        begin
            drawn <= 1;
            //lose <= 0;
            ball_y <= 240;
            ball_x <= 260;
        end
        
        else if (!vsync && !drawn) 
        begin
            drawn <= 1;
            case(ball_state)
                stop:
                begin
                    ball_x <= ball_x;
                    ball_y <= ball_y;
                end
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
        if (!reset_n) ball_state <= stop;
        
        else ball_state <= next_ball_state;
    end



    always @ (ball_state or ball_x or ball_y or h_collision or v_collision or start)
    begin
        case (ball_state)
            stop:
            begin
                if (start == 1) next_ball_state <= down_right;
                else next_ball_state <= stop;
            end
            
            down_right:
            begin
                if (ball_y >= `bottom_edge) next_ball_state <= up_right;
                else if (ball_x >= `right_edge) next_ball_state <= down_left;
                else if (v_collision) next_ball_state <= up_right;
                else if (h_collision) next_ball_state <= down_left;
                else next_ball_state <= down_right;
            end
            
            down_left:
            begin
                if (ball_y >= `bottom_edge) next_ball_state <= up_left;
                else if (ball_x <= `left_edge) next_ball_state <= down_right;
                else if (v_collision) next_ball_state <= up_left;
                else if (h_collision) next_ball_state <= down_right;
                else next_ball_state <= down_left;
            end
            
            up_right:
            begin
                if (ball_y <= `top_edge) next_ball_state <= down_right;
                else if (ball_x >= `right_edge) next_ball_state <= up_left;
                else if (v_collision) next_ball_state <= down_right;
                else if (h_collision) next_ball_state <= up_left;
                else next_ball_state <= up_right;
            end
            
            up_left:
            begin
                if (ball_y <= `top_edge) next_ball_state <= down_left;
                else if (ball_x <= `left_edge) next_ball_state <= up_right;
                else if (v_collision) next_ball_state <= down_left;
                else if (h_collision) next_ball_state <= up_right;
                else next_ball_state <= up_left;
            end 
        endcase
    end
endmodule
