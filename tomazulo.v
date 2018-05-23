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


module pc(pcatual, clock, pcatualizado);
	input pcatual, clock;
	output reg pcatualizado;

	always@(posedge clock) begin
		pcatualizado <= pcatual + 1'b1;
	end

endmodule

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

module instrucoes(posicao, instrucoes);

	reg [7:0] instrucao[15:0];
	                      //op      reg3     reg2     reg1
	assign instrucao[0] = {4'b0000, 4'b0001, 4'b0010, 4'b0011};
	assign instrucao[1] = {4'b0010, 4'b0100, 4'b0101, 4'b0110};
	assign instrucao[2] = {4'b0001, 4'b0001, 4'b0010, 4'b0011};
	assign instrucao[3] = {4'b0000, 4'b0111, 4'b0001, 4'b0010};
	assign instrucao[4] = {4'b0011, 4'b0110, 4'b0100, 4'b0101};
	assign instrucao[5] = {4'b0011, 4'b0001, 4'b0110, 4'b0111};
	assign instrucao[6] = {4'b0001, 4'b0001, 4'b0010, 4'b0011};
	assign instrucao[7] = {4'b0010, 4'b0001, 4'b0010, 4'b0011};

endmodule

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

module estacao_reserva_somasub(op, Vj, Vk, Qj, Qk, clock, Busy, CDBarbiter);

	input [3:0] op, Vk, Vj, Qj, Qk;
	output reg [1:0] Busy [0:0];
	output reg [3:0] CDBarbiter;

	reg [31:0] er [2:0];

	assign [31:28] er [linha] = op;
	assign [27:24] er [linha] = Vj;
	assign [23:20] er [linha] = Vk;
	assign [19:16] er [linha] = Qj;
	assign [15:12] er [linha] = Qk;




endmodule

module estacao_reserva_muldiv(op, Vj, Vk, Qj, Qk, clock, Busy, CDBarbiter);

	input [3:0] op, Vk, Vj, Qj, Qk;
	output reg [1:0] Busy [0:0];
	output reg [3:0] CDBarbiter;

	reg [31:0] er [2:0];


	assign [31:28] er [linha]  = op;
	assign [27:24] er [linha] = Vj;
	assign [23:20] er [linha] = Vk;
	assign [19:16] er [linha] = Qj;
	assign [15:12] er [linha] = Qk;


endmodule


module tomazulo();
endmodule
