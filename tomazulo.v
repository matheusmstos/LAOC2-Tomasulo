module uf_soma_sub(operacao,clock, reg1, reg2, done, result);

	input operacao;
	input clock;
	input [7:0] reg1;
	input [7:0] reg2;
	output done;
	output reg [7:0] result;

	reg [1:0] count;

	always@(posedge clock) begin
		case (count)
			1'b0:
				count = count + 1'b1;
			1'b1:
				case (operacao)
					1'b0:
						result <= reg1 + reg2;
						count = 0;
						done = 1;
					1'b1:
						result <= reg1 - reg2;
						count = 0;
						done = 1;
				endcase
		endcase
	end

endmodule

module uf_mul_divisao(operacao,clock, reg1, reg2, done, result);

	input operacao;
	input clock;
	input [7:0] reg1;
	input [7:0] reg2;
	output done;
	reg [1:0] count;
	output reg [7:0] result;

	always@(posedge clock) begin
		case (count)
			2'b00:
				count = count + 2'b01;

			2'b01:
				count = count + 2'b01;

			2'b10:
				count = count + 2'b01;
				case (operacao)
					1'b0:
						result <= reg1 * reg2;
						count = 0;
						done = 1;
				endcase

			2'b11:
				case (operacao)
					1'b1:
						result <= reg1 / reg2;
						count = 0;
						done = 1;
				endcase
	end

endmodule

//******** CONTADOR DE INSTRUÇÕES **********	
module pc(pcatual, clock, disbalePC pcatualizado);
	input pcatual, clock;
	input disablePC;
	output reg [2:0] pcatualizado;
	
	initial begin 
		pcatualizado = 2'b00;
	end

	always@(posedge clock & posedge disbalePC) begin
		pcatualizado <= pcatual + 1'b1;
	end

endmodule

// ******** BANCO DE REGISTRADORES ********
module banco_registradores(valor, wren, op, clock, saida);

	input clock;
	input valor;
	input [2:0] op;
	output [15:0] saida;


	reg [15:0] registrador [2:0];

	initial begin
		registrador[0] = 0;
		registrador[1] = 2;
		registrador[2] = 4;
		registrador[3] = 0;
		registrador[4] = 2;
		registrador[5] = 2;
		registrador[6] = 0;
	end

	always @(posedge clock) begin
		case (wren)
			1'b0:
				saida <= registrador[op];
			1'b1:
				registrador[op] <= valor;
		endcase
	end

endmodule

//******* FILA DE INSTRUÇÔES *********
module instrucoes(clock, PC_address, soma_cheio, mul_cheio, disablePC, instruction);
	
	input clock;
	input [2:0] PC_address;
	input soma_cheio;
	input mul_cheio;
	
	output reg disablePC;
	output reg [15:0] Q;
	
	reg [7:0] instrucao[15:0];
	initial begin 
		disablePC = 1'b0;
	
	   //              op       reg3     reg2     reg1
		instrucao[0] = {4'b0000, 4'b0001, 4'b0010, 4'b0011};
		instrucao[1] = {4'b0010, 4'b0100, 4'b0101, 4'b0110};
		instrucao[2] = {4'b0001, 4'b0001, 4'b0010, 4'b0011};
		instrucao[3] = {4'b0000, 4'b0111, 4'b0001, 4'b0010};
		instrucao[4] = {4'b0011, 4'b0110, 4'b0100, 4'b0101};
		instrucao[5] = {4'b0011, 4'b0001, 4'b0110, 4'b0111};
		instrucao[6] = {4'b0001, 4'b0001, 4'b0010, 4'b0011};
		instrucao[7] = {4'b0010, 4'b0001, 4'b0010, 4'b0011};
	
	end
	
	always @(posedge clock) begin
		Q = instrucao[PC_address];
		
		case(Q[15:12])
			0000, 0001:
				if (soma_cheio)	//Estacao de reserva cheia
				begin
					disablePC = 1;
				end
				else
				begin
					disablePC = 0;
				end
			0010, 0011:
				if (mul_cheio)
				begin
					disablePC = 1;
				end
				else
				begin
					disablePC = 0;
				end
		endcase	
	end

endmodule

//******* SELETOR *********
module seletor(clock, instruction, add_station, mul_station, opcode);
	input clock;
	input [15:0] instruction;
	
	output reg	add_station;
	output reg 	mul_station;
	output reg opcode;
	
	always @(posedge clock) begin
		case(instruction[15:12])
			4'b0000, 4'b0001: // add/sub
			begin
				add_station = 1;
				mul_station = 0;
				opcode = instruction;
			end
			4'b0010, 4'b0011: // mul/div
			begin
				mul_station = 1;
				add_station = 0;
				opcode = instruction;
			end
		endcase
	end

endmodule

// ???????????????????

module ID(clock, instrucao, op, reg1, reg2, reg3);

	input clock;
	input posicao, instrucao;
	output [3:0] reg1, reg2, reg3;
	output [3:0] op;

	always@(posedge clock) begin
		reg1 <= instrucao[0:3];
		reg2 <= instrucao[4:7];
		reg3 <= instrucao[8:11];
		op <= instrucao[12:15];
	end

endmodule

//********* ESTAÇÃO DE RESERVA **********
module estacao_reserva_somasub(op, Vj, Vk, Qj, Qk, clock, Busy, CDBarbiter, cheio);

	input clock;
	input CDB_tag;
	input CDB_valor;
	
	output reg [1:0] Busy [0:0];
	output reg [3:0] CDBarbiter;
	output reg [1:0]cheio;
	
	reg [31:0] estacao [2:0];

	assign [31:28] estacao [linha] = op;
	assign [27:24] estacao [linha] = Vj;
	assign [23:20] estacao [linha] = Vk;
	assign [19:16] estacao [linha] = Qj;
	assign [15:12] estacao [linha] = Qk;
	/*
	op 		-> 31:28
	tag_Vj 	-> 27
	Vj 		-> 26:23
	tag_Vk 	-> 22
	Vk 		-> 21:18
	tag_Qj 	-> 17
	Qj 		-> 16:13
	tag_Qk 	-> 12
	Qk 		-> 11:8	
	
	*/
	
	initial begin
		estacao[0] 16'b0;
		estacao[1] 16'b0;
		estacao[2] 16'b0;
	end
	
	if(estacao[0][17] == CDB_tag) begin
	end
	if(estacao[0][12] == CDB_tag) begin
	end
	
	if(estacao[0][17] == CDB_tag) begin
	end
	if(estacao[0][12] == CDB_tag) begin
	end
	
	if(estacao[0][17] == CDB_tag) begin
	end
	if(estacao[0][12] == CDB_tag) begin
	end
	

	if(cheio = 2'11) begin 
		



endmodule

module estacao_reserva_muldiv(op, Vj, Vk, Qj, Qk, clock, Busy, CDBarbiter);

	input [3:0] op, Vk, Vj, Qj, Qk;
	output reg [1:0] Busy [0:0];
	output reg [3:0] CDBarbiter;

	reg [31:0] e_reserva [2:0];
	reg cheio;

	assign [31:28] er [linha] = op;
	assign [27:24] er [linha] = Vj;
	assign [23:20] er [linha] = Vk;
	assign [19:16] er [linha] = Qj;
	assign [15:12] er [linha] = Qk;


endmodule


module tomazulo();
endmodule
