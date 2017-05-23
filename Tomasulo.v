//Fila de Despacho
module Fila(clock, intr)
	intput clock;
	input parada; //quando paramos de despachar pra est de reserva, vulgo, contador
	output reg [15:0]intr; //intrução propriamente dita

	parameter size = 32;
	reg [15:0] mem[0:size-1]; //fila propriamente dita

endmodule

//Banco de Registradores
module Banco(clock, endereco1, endereco2, param1, iwr, saida1, saida2)
	input clock;
	input [4:0]endereco1;
	input [4:0]endereco2;
	input [16:0]param1;
	input iwr;
	
	
	parameter size = 32; 
	reg [15:0] mem[0:size-1];

	output reg [16:0]b_saida1;
   output reg [16:0]b_saida2;	

	always @(posedge clock) begin
		if(iwr == 1'b0) begin
			b_saida1 = mem[endereco1];
			b_saida2 = mem[endereco2];
		end
		else if(iwr == 1'b1) begin	
			mem[endereco1] = param1;
		end
	end
endmodule

//Unidade Funcional de Soma/Sub
module UFAdd(clock, a, b. soma)
	input clock;
	input [16:0]a; 
	input [16:0]b;
	output reg [16:0]soma;

	reg latencia;
	initial begin
		latencia = 2'b00;
	end
	
	always @(posedge clock) begin
		latencia = latencia + 1'b1;
		if(latencia == 2'b10) begin
			soma = a + b;
			latencia = 2'b00;
		end
endmodule

//Unidade Funcial de Multi/Div
module UFMul(clock, a, b, tipo, mult, div)

	input clock;
	input [16:0]a; 
	input [16:0]b;
	input tipo;
	output reg [16:0]md_saida;
	

	reg latencia;
	initial begin
		latencia = 4'b0000;
	end
	
	always @(posedge clock) begin
		latencia = latencia + 1'b1;
		if(latencia == 4'b0101 && tipo == 1'b1) begin
			md_saida = a * b;
			latencia = 4'b0000;
		end
		else if(latencia == 4'b1010 && tipo == 1'b0) begin
			md_saida = a/b;
			latencia = 4'b0000;
		end
endmodule

module CDBarbiter()
	input clock;
	input [16:0]entrada1;
	input [16:0]entrada2;
	input switch;
	output reg [16:0]saida;
	
	initial begin
		latencia = 1'b0;
	end
	
	always @(posedge clock) begin
		if(switch == 1'b0) begin 
				saida = entrada1;
		end
		else if(switch == 1'b1) begin
				saida = entrada2;
		end	
	end
endmodule