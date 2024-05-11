// `include "vending_machine_def.v"

// Macro constants (prefix k & CamelCase)
`define kTotalBits 32

`define kItemBits 8
`define kNumItems 4

`define kCoinBits 8
`define kNumCoins 3
`define kReturnCoins 10

`define kWaitTime 10


module vending_machine (

	clk,							// Clock signal
	reset_n,						// Reset signal (active-low)

	i_input_coin,				// coin is inserted.
	i_select_item,				// item is selected.
	i_trigger_return,			// change-return is triggered

	o_available_item,			// Sign of the item availability
	o_output_item,			   // Sign of the item withdrawal
	o_return_coin,			   // Sign of the coin return
	o_current_total
);

	// Ports Declaration
	input clk;
	input reset_n;

	input [`kNumCoins-1:0] i_input_coin;
	input [`kNumItems-1:0] i_select_item;
	input i_trigger_return;

	output [`kNumItems-1:0] o_available_item;
	output [`kNumItems-1:0] o_output_item;
	output [`kReturnCoins-1:0] o_return_coin;
	output [`kTotalBits-1:0] o_current_total;

	// Net constant values (prefix kk & CamelCase)
	wire [31:0] kkItemPrice [`kNumItems-1:0];	// Price of each item
	wire [31:0] kkCoinValue [`kNumCoins-1:0];	// Value of each coin
	assign kkItemPrice[0] = 400;
	assign kkItemPrice[1] = 500;
	assign kkItemPrice[2] = 1000;
	assign kkItemPrice[3] = 2000;
	assign kkCoinValue[0] = 100;
	assign kkCoinValue[1] = 500;
	assign kkCoinValue[2] = 1000;

	// Internal states. You may add your own reg variables.
	reg [`kTotalBits-1:0] current_total;
	reg [`kItemBits-1:0] num_items [`kNumItems-1:0]; //use if needed
	reg [`kCoinBits-1:0] num_coins [`kNumCoins-1:0]; //use if needed
	reg [1:0] state; // current state
	reg [1:0] nstate; // next state
	reg [`kNumItems-1:0] o_available_item_reg; // reg of o_available_item output variable for combinational circuit
	reg [`kNumItems-1:0] o_output_item_reg; // reg of o_output_item output variable for combinational circuit
	reg [`kReturnCoins-1:0] o_return_coin_reg; // reg of o_return_coin output variable for combinational circuit
	reg [`kTotalBits-1:0] o_current_total_reg; // reg of o_current_total output variable for combinational circuit
	
	// Combinational circuit for the next states
	always @(i_input_coin or i_select_item or i_trigger_return) begin // when any input changes
        if(i_input_coin) begin // if coin is input, then next state go to 01
            nstate = 2'b01;
        end
        else if(i_select_item) begin // if item is selected then next state go to 10
            nstate = 2'b10;
        end
        else if(i_trigger_return) begin // if return trigger is on, then next state go to 11
            nstate = 2'b11;
        end
	end

	// Combinational circuit for the output
	always @(posedge clk or state) begin // when posedge of clk or there is state change
	  
	   case (state)
	   	2'b00 : begin // 00 state is reset state
			o_current_total_reg = 0;
			o_output_item_reg = 4'b0000;
			o_return_coin_reg = 4'b0000;
			o_available_item_reg = 4'b0000;
		end
		2'b01 : begin // 01 state is input coin state updating o_current_total output variable
			o_current_total_reg = i_input_coin[0] * kkCoinValue[0] + i_input_coin[1] * kkCoinValue[1] + i_input_coin[2] * kkCoinValue[2] + o_current_total;
			// update current total coin amount by accumulating input coins
			o_output_item_reg = 4'b0000; // no output item
			o_return_coin_reg = 4'b0000; // no return coin
			o_available_item_reg = {(o_current_total_reg >= kkItemPrice[3]), (o_current_total_reg >= kkItemPrice[2]), (o_current_total_reg >= kkItemPrice[1]), (o_current_total_reg >= kkItemPrice[0])};
			// update available item according to current coin
		end
		2'b10 : begin // 10 state is select item state updating o_available_item ouput variable according to current coin amount
			o_return_coin_reg = 4'b0000; // no return coin
			o_output_item_reg = {(o_available_item[3] & i_select_item[3]), (o_available_item[2] & i_select_item[2]), (o_available_item[1] & i_select_item[1]), (o_available_item[0] & i_select_item[0])};
			// output item considering availble item and selected item
			if(o_output_item_reg[0]) begin
				o_current_total_reg = o_current_total - kkItemPrice[0]; // update current total coin amount after outputting selected item
			end
			else if(o_output_item_reg[1]) begin
				o_current_total_reg = o_current_total - kkItemPrice[1];
			end
			else if(o_output_item_reg[2]) begin
				o_current_total_reg = o_current_total - kkItemPrice[2];
			end
			else if(o_output_item_reg[3]) begin
				o_current_total_reg = o_current_total - kkItemPrice[3];
			end
		    o_available_item_reg = {(o_current_total_reg >= kkItemPrice[3]), (o_current_total_reg >= kkItemPrice[2]), (o_current_total_reg >= kkItemPrice[1]), (o_current_total_reg >= kkItemPrice[0])};
			// update available item after outputting selected item
		end
		2'b11 : begin // 11 state is return coin state updating o_return_coin output variable according to current coin amount
		    o_return_coin_reg=0;
			o_output_item_reg = 4'b0000; // No output item
			o_return_coin_reg = o_current_total / kkCoinValue[2]; // quotient of current total coin amount devided by kkCoinValue[x] is # of coins
			o_current_total_reg = o_current_total_reg % kkCoinValue[2]; // remainder of current total coin amount devided by kkCoinValue[x] is the new current total coin amount
		   	o_return_coin_reg = o_return_coin_reg + (o_current_total_reg / kkCoinValue[1]);
			o_current_total_reg = o_current_total_reg % kkCoinValue[1];
		   	o_return_coin_reg = o_return_coin_reg + (o_current_total_reg / kkCoinValue[0]);
			o_current_total_reg = o_current_total_reg % kkCoinValue[0];
			o_available_item_reg = 4'b0000; // No available item
			nstate = 2'b00; // next state go to reset state because all of output variables are zero after return change coins
		end
	   endcase
	end

	// Sequential circuit to reset or update the states
	
	assign o_available_item = o_available_item_reg; // assign reg variables to output variables
	assign o_output_item = o_output_item_reg;		// reg variables are computed in combinational circuit
	assign o_return_coin = o_return_coin_reg;
	assign o_current_total = o_current_total_reg;
	
	always @(posedge clk) begin
		if (!reset_n) begin
			// TODO: reset all states.
			state <= 2'b00; // reset state
		end
		else begin
			// TODO: update all states.
			state <= nstate; // putting next state on current state
		end
	end
endmodule