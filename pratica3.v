/*********************************************
*	Pratica III - LAOC II								*
*	Autores:												*
*				Matheus de Almeida Rosa				*
*				Vinicius Magalhaes D'Assuncao		*
*															*
*********************************************/

/*
Top-level

Intrucao:
	  op		 dest		 rx		 ry
	[15:12]	[11:8]	[7:4]		[3:0]
*/
module pratica3 (input clock);
	
	wire [3:0]endereco, saidaA, saidaB, tag;
	wire [15:0] I, opcode;
	//fios de controle
	wire enablePC;
	//fios para RS add
	wire opAdd, addCheio, Radd, sumOcup, exec;
	wire [3:0] addResult, addSaidaA, addSaidaB, addTag;
	wire [7:0] destinoAdd;
	//fios para RS mul
	wire opMul, mulCheio, Rmul;
	wire [3:0] mulResult, mulSaidaA, mulSaidaB, mulTag;
	wire [7:0] destinoMul;
	
	//fios para alu
	wire addOk, mulOk;
	
	//fios para CDB
	wire [15:0]regStatus;
	wire [3:0] CDBResult, CDBTag, cdbAddTag;
	
	//fios para regStatus
	wire [7:0]destino;
	wire [3:0] destino_result, result;
	
	//fios para bancoInst
	wire [3:0] A, B;
	
	contador cont(clock, enablePC, endereco);										//calcula endereco
	BancoInst banco1(clock, endereco, addCheio, mulCheio, enablePC, I);		//Seleciona intrucao
	seletor select(clock, I, opAdd, opMul, opcode);									//Seleciona Estacao de reserva
	
	RSadd s1(clock, opAdd, opcode, A, B, regStatus, CDBResult, CDBTag, sumOcup, addCheio, Radd, destino, addSaidaA, addSaidaB, addTag, exec);
	//RSmul r2(clock, opMul, I, I[7:4], I[3:0], registradores, bus, busTag, mulCheio, Rmul, destinoMul, mulSaidaA, mulSaidaB, tag);
	
	sumAdd alu1(clock, exec, addSaidaA, addSaidaB, Radd, addTag, addResult, cdbAddTag, sumOcup, addOk);	//Calculo do resultado para a estacao add
	//mulDiv...
	
	cdb c1(clock, addOk, cdbAddTag, addResult, 1'b0, 4'b0000, 4'b0000, CDBResult, CDBTag);
	regStatus status(clock, destino, CDBTag, CDBResult, destino_result, result, regStatus);
	bancoReg banco2(clock, I, destino_result, result, A, B);

endmodule

module BancoInst (input clock, input[3:0] endereco, input addCheio, input mulCheio, output reg enablePC = 1, output reg[15:0] Q);
 	reg [15:0] bancoIntrucoes[15:0];	
	
	//op		 dest		 rx		 ry
	//[15:12]	[11:8]	[7:4]		[3:0]
	initial 
	begin
		bancoIntrucoes[0]	= 16'b0000000000000000;
		bancoIntrucoes[1]	= 16'b0001000000010001;
		bancoIntrucoes[2]	= 16'b0000000000010001;
		bancoIntrucoes[3]	= 16'b0001000000010001;
		bancoIntrucoes[4] = 16'b0000000000010001;
		bancoIntrucoes[5] = 16'b0010000000000000;
		bancoIntrucoes[6] = 16'b0011000000000000;
		bancoIntrucoes[7] = 16'b0011000000000000;
		bancoIntrucoes[8] = 16'b0011000000000000;
	end
	
	always @(posedge clock)
	begin
		Q = bancoIntrucoes[endereco];
		
		case (Q[15:12])
			0000, 0001:
				if (addCheio)	//Estacao de reserva cheia
				begin
					enablePC = 0;
				end
				else
				begin
					enablePC = 1;
				end
			0010, 0011:
				if (mulCheio)
				begin
					enablePC = 0;
				end
				else
				begin
					enablePC = 1;
				end
		endcase
	end
	
endmodule

/*Estacoes de reserva
	Add1 = 0000
	Add2 = 0001
	Mul1 = 0010
	Mul2 = 0110
*/

// selecionar a estacao de reserva
module seletor (input clock, input [15:0] I, output reg opAdd=0, output reg opMul=0, output reg [15:0] opcode = 0);
	
	always @(posedge clock)
	begin
		case(I[15:12])
			4'b0000, 4'b0001: // add/sub
			begin
				opAdd = 1;
				opMul = 0;
				opcode = I;
			end
			4'b0010, 4'b0011: // mul/div
			begin
				opMul = 1;
				opAdd = 0;
				opcode = I;
			end
		endcase
	end
endmodule


/*
	Estacao Add correta
	tagVb		Vb		tagVa		Va		Qb		 Qa		op		RsTag		busy
	  25	[24:21]  [20]	[19:16][15:12]	 [11:8] [7:5]  [4:1]		[0]
*/
module RSadd(input clock, input opAdd, input [15:0]opcode, input [3:0]opA, input [3:0]opB, input [15:0] regStatus, 
				 input [3:0]CDBResult, input [3:0] CDBResultTag, input sumOcup,
				 output reg addCheio = 0, output reg R, output reg [7:0] destino, output reg [3:0] valorA,
				 output reg [3:0]valorB, output reg [3:0]tag=0, output reg exec=0);
	integer cont = 0;
	
	reg [25:0] estacao [2:0];
	integer vazio = 0, posicao;
	
	initial
	begin
		estacao[0] = 26'b00000000000000000000000010;		//RSAdd1
		estacao[1] = 26'b00000000000000000000000100;		//RSAdd2
		estacao[2] = 26'b00000000000000000000000110;		//RSAdd3
	end
	
	always @(posedge clock)
	begin
		exec = 0;
		//Verifica se algum resultado esta pronto no CDB
		if (estacao[0][11:8] == CDBResultTag)
		begin
			estacao[0][11:8] = 0;			//limpa o Q
			estacao[0][19:16] = CDBResult;	//Salva o valor em Va
			estacao[0][20] = 1;				//Seta a tagVa
		end
		if (estacao[0][15:12] == CDBResultTag)
		begin
			estacao[0][15:12] = 0;			//limpa o Q
			estacao[0][24:21] = CDBResult;	//Salva o valor em Va
			estacao[0][25] = 1;				//Seta a tagVa
		end
		if (estacao[1][11:8] == CDBResultTag)
		begin
			estacao[1][11:8] = 0;			//limpa o Q
			estacao[1][19:16] = CDBResult;	//Salva o valor em Va
			estacao[1][20] = 1;				//Seta a tagVa
		end
		if (estacao[1][15:12] == CDBResultTag)
		begin
			estacao[1][15:12] = 0;			//limpa o Q
			estacao[1][24:21] = CDBResult;	//Salva o valor em Va
			estacao[1][25] = 1;				//Seta a tagVa
		end
		if (estacao[2][11:8] == CDBResultTag)
		begin
			estacao[2][11:8] = 0;			//limpa o Q
			estacao[2][19:16] = CDBResult;	//Salva o valor em Va
			estacao[2][20] = 1;				//Seta a tagVa
		end
		if (estacao[2][15:12] == CDBResultTag)
		begin
			estacao[2][15:12] = 0;			//limpa o Q
			estacao[2][24:21] = CDBResult;	//Salva o valor em Va
			estacao[2][25] = 1;				//Seta a tagVa
		end
		
		//Verificacoes de Vb e Va, para que a execucao seja feita
		if (estacao[0][20] == 1 && estacao[0][25] == 1 && sumOcup == 0)
		begin
			cont = cont - 1;
			case (opcode[15:12])	//seleciona operacao
				4'b0000:	//add
					R = 0;
				4'b0001: //sub
					R = 1;
			endcase
			valorA = estacao[0][19:16];	//saida A
			valorB = estacao[0][24:21];	//saida B
			tag = estacao[0][4:1];						//add1
			estacao[0] = 26'b00000000000000000000000010;		//Reseta estacao
			addCheio = 0;												//determina estacao com espaco vazio
			exec = 1;
		end
		else if (estacao[1][20] == 1 && estacao[1][25] == 1 && sumOcup == 0)
		begin
			cont = cont - 1;
			case (opcode[15:12])	//seleciona operacao
				4'b0000:	//add
					R = 0;
				4'b0001: //sub
					R = 1;
			endcase
			valorA = estacao[1][19:16];	//saida A
			valorB = estacao[1][24:21];	//saida B
			tag = 4'b0010;						//add2
			estacao[1] = 26'b00000000000000000000000100;		//Reseta estacao
			addCheio = 0;												//determina estacao com espaco vazio
			exec = 1;
		end
		else if (estacao[2][20] == 1 && estacao[2][25] == 1 && sumOcup == 0)
		begin
			cont = cont - 1;
			case (opcode[15:12])	//seleciona operacao
				4'b0000:	//add
					R = 0;
				4'b0001: //sub
					R = 1;
			endcase
			valorA = estacao[2][19:16];	//saida A
			valorB = estacao[2][24:21];	//saida B
			tag = 4'b0011;						//Add3						
			estacao[2] = 26'b00000000000000000000000110;		//Reseta estacao
			addCheio = 0;
			exec = 1;
			//determina estacao com espaco vazio
		end
		//Escrita na estacao de reserva
		if (opAdd)
		begin
			//procura por posicao vazia
			if (!estacao[0][0]) 
			begin
				posicao = 0;
			end
			else if (!estacao[1][0]) 
			begin
				posicao = 1;
			end
			else if (!estacao[2][0]) 
			begin
				posicao = 2;
			end
			if (cont < 2)
			begin
				cont = cont + 1;
				estacao[posicao][0] = 1;					//seta o busy
				estacao[posicao][7:5] = opcode[15:12];	//guarda o tipo de operacao na estacao 
				//seleciona tag para o registrador de destino
				destino[7:4] = estacao[posicao][4:1];	//nome da estacao
				destino[3:0] = opcode[11:8];				//registrador a ser renomeado
				//Salva RX na estacao, verificando se o registrador possui ou nao dependencia de dados
				case (opcode[7:4])
					4'b0000:	//R0
					begin
						if(regStatus[3:0] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[3:0];	//Salva o registro esperado
						end
					end
					4'b0001: //R1
					begin
						if(regStatus[7:4] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[7:4];	//Salva o registro esperado
						end
					end
					4'b0010:	//R2
					begin
						if(regStatus[11:8] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[11:8];	//Salva o registro esperado
						end
					end
					4'b0011:	//R3
					begin
						if(regStatus[15:12] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[15:12];	//Salva o registro esperado
						end
					end
				endcase
				//Salva RY na estacao, verificando se o registrador possui ou nao dependencia de dados
				case (opcode[3:0])
					4'b0000:	//R0
					begin
						if(regStatus[3:0] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[3:0];	//Salva o registro esperado
						end
					end
					4'b0001: //R1
					begin
						if(regStatus[7:4] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[7:4];	//Salva o registro esperado
						end
					end
					4'b0010:	//R2
					begin
						if(regStatus[11:8] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[11:8];	//Salva o registro esperado
						end
					end
					4'b0011:	//R3
					begin
						if(regStatus[15:12] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[15:12];	//Salva o registro esperado
						end
					end
				endcase
			end
			if (cont == 2)
			begin
				addCheio = 1;
			end
		end
	end
endmodule

/*
	Estacao Mul
	tagVb		Vb		tagVa		Va		Qb		 Qa		op		RsTag		busy
	  25	[24:21]  [20]	[19:16][15:12]	 [11:8] [7:5]  [4:1]		[0]
*/

module RSmul(input clock, input opMul, input [15:0]opcode, input [3:0]opA, input [3:0]opB, input [15:0] regStatus, 
				 input [3:0]CDBResult, input [3:0] CDBResultTag, input mulOcup,
				 output reg mulCheio = 0, output reg R, output reg [7:0] destino, output reg [3:0] valorA,
				 output reg [3:0]valorB, output reg [3:0]tag);
	
	reg [25:0] estacao [1:0];
	integer vazio = 0, posicao;
	
	initial
	begin
		estacao[1] = 26'b00000000000000000000001000;		//RSAdd2
		estacao[2] = 26'b00000000000000000000001010;		//RSAdd3
	end
	
	always @(posedge clock)
	begin
		//Verifica se algum resultado esta pronto no CDB
		if (estacao[0][11:8] == CDBResultTag)
		begin
			estacao[0][11:8] = 0;			//limpa o Q
			estacao[0][19:16] = CDBResult;	//Salva o valor em Va
			estacao[0][20] = 1;				//Seta a tagVa
		end
		if (estacao[0][15:12] == CDBResultTag)
		begin
			estacao[0][15:12] = 0;			//limpa o Q
			estacao[0][24:21] = CDBResult;	//Salva o valor em Va
			estacao[0][25] = 1;				//Seta a tagVa
		end
		if (estacao[1][11:8] == CDBResultTag)
		begin
			estacao[1][11:8] = 0;			//limpa o Q
			estacao[1][19:16] = CDBResult;	//Salva o valor em Va
			estacao[1][20] = 1;				//Seta a tagVa
		end
		if (estacao[1][15:12] == CDBResultTag)
		begin
			estacao[1][15:12] = 0;			//limpa o Q
			estacao[1][24:21] = CDBResult;	//Salva o valor em Va
			estacao[1][25] = 1;				//Seta a tagVa
		end
		
		//Verificacoes de Vb e Va, para que a execucao seja feita
		if (estacao[0][20] == 1 && estacao[0][25] == 1 && mulOcup == 0)
		begin
			case (opcode[15:12])	//seleciona operacao
				4'b0000:	//add
					R = 0;
				4'b0001: //sub
					R = 1;
			endcase
			valorA = estacao[0][19:16];	//saida A
			valorB = estacao[0][24:21];	//saida B
			tag = 4'b0001;						//mul1
			estacao[0] = 26'b00000000000000000000001000;		//Reseta estacao
			mulCheio = 0;												//determina estacao com espaco vazio
		end
		else if (estacao[1][20] == 1 && estacao[1][25] == 1 && mulOcup == 0)
		begin
			case (opcode[15:12])	//seleciona operacao
				4'b0000:	//add
					R = 0;
				4'b0001: //sub
					R = 1;
			endcase
			valorA = estacao[1][19:16];	//saida A
			valorB = estacao[1][24:21];	//saida B
			tag = 4'b0010;						//add2
			estacao[1] = 26'b00000000000000000000001010;		//Reseta estacao
			mulCheio = 0;												//determina estacao com espaco vazio
		end
		vazio = 0;
		//Escrita na estacao de reserva
		if (opMul)
		begin
			//procura por posicao vazia
			if (!estacao[0][0]) 
			begin
				vazio = 1;
				posicao = 0;
			end
			else if (!estacao[1][0]) 
			begin
				vazio = 1;
				posicao = 1;
			end
			if (vazio)
			begin	//salva os dados na estacao
				estacao[posicao][0] = 1;					//seta o busy
				estacao[posicao][7:5] = opcode[15:12];	//guarda o tipo de operacao na estacao 
				//seleciona tag para o registrador de destino
				destino[7:4] = estacao[posicao][4:1];	//nome da estacao
				destino[3:0] = opcode[11:8];				//registrador a ser renomeado
				//Salva RX na estacao, verificando se o registrador possui ou nao dependencia de dados
				case (opcode[7:4])
					4'b0000:	//R0
					begin
						if(regStatus[3:0] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[3:0];	//Salva o registro esperado
						end
					end
					4'b0001: //R1
					begin
						if(regStatus[7:4] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[7:4];	//Salva o registro esperado
						end
					end
					4'b0010:	//R2
					begin
						if(regStatus[11:8] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[11:8];	//Salva o registro esperado
						end
					end
					4'b0011:	//R3
					begin
						if(regStatus[15:12] == 4'b0000)
						begin
							estacao[posicao][19:16] = opA;	//salva valor
							estacao[posicao][20] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][11:8] = regStatus[15:12];	//Salva o registro esperado
						end
					end
				endcase
				//Salva RY na estacao, verificando se o registrador possui ou nao dependencia de dados
				case (opcode[3:0])
					4'b0000:	//R0
					begin
						if(regStatus[3:0] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[3:0];	//Salva o registro esperado
						end
					end
					4'b0001: //R1
					begin
						if(regStatus[7:4] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[7:4];	//Salva o registro esperado
						end
					end
					4'b0010:	//R2
					begin
						if(regStatus[11:8] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[11:8];	//Salva o registro esperado
						end
					end
					4'b0011:	//R3
					begin
						if(regStatus[15:12] == 4'b0000)
						begin
							estacao[posicao][24:21] = opB;	//salva valor
							estacao[posicao][25] = 1;			//seta como usado
						end
						else
						begin
							estacao[posicao][15:12] = regStatus[15:12];	//Salva o registro esperado
						end
					end
				endcase
			end
			else
			begin
				mulCheio = 1;
			end
		end
	end
endmodule


module contador(Clk , en , Palavra);
	input Clk, en;
	output reg [3:0] Palavra = 0;
	
	initial Palavra = 4'b0;
	always @(posedge Clk)
	begin
		if (en)
			Palavra = Palavra + 1'b1;
	end
endmodule


/**
	buffer:	 tag	dado
				[7:4]	[3:0]
*/
//cdb c1(clock, addOk, addTag, addResult, 1'b0, 4'b0000, 4'b0000, CDBResult, CDBTag);
module cdb(input clock, input addOk, input [3:0]addTag, input [3:0]addRes, input mulOk, input [3:0]mulTag, input [3:0]mulRes, 
				output reg [3:0]dado, output reg [3:0]tag_dado);
	//Necessario tratar o caso em que o add e o mul ficam prontos ao mesmo tempo. Para isso deve se criar um buffer que guarde a intrucao 
	//mais recente ...
	reg [7:0] buffer; // buffer de resultados e tags
	reg armazenados;
	
	initial // inicializa o buffer vazio
	begin
		armazenados = 0;
		buffer = 8'b0;
	end
	
	always @(posedge clock)
	begin
		if (armazenados == 0) // nenhum resultado armazenado
		begin
			if (addOk) 
			begin
				if (mulOk) // duas instrucoes prontas ao mesmo tempo
				begin
					// executa add/sub e coloca mul/div no buffer
					dado = addRes;
					tag_dado = addTag;
					buffer = {mulTag[3],mulTag[2],mulTag[1],mulTag[0],  mulRes[3],mulRes[2],mulRes[1],mulRes[0]};
					armazenados = 1;
				end
				else 
				begin // apenas instrução de add/sub pronta
					dado = addRes;
					tag_dado = addTag;
				end
			end
			else if (mulOk) // apenas instrução de mul/div pronta
			begin
				dado = mulRes;
				tag_dado = mulTag;
			end
		end
		else // buffer nao vazio
		begin
			// escolhe o primeiro registro do buffer
			tag_dado = buffer[7:4];
			dado = buffer[3:0];
			// esvazia o buffer
			armazenados = armazenados - 1;
			
			// trata os dados recebidos
			if (addOk) 
			begin
				// apenas instrução de add/sub pronta
				buffer = {addTag[3:0],addRes[3:0]};
				armazenados = 1;
			end
			else if (mulOk) // apenas instrução de mul/div pronta
			begin
				buffer = {mulTag[3:0],mulRes[3:0]};
				armazenados = 1;
			end	
		end
	end
endmodule


module bancoReg(input clock, input [15:0] opcode, input [3:0]destino, input [3:0]dado,
					 output reg[3:0] A, output reg[3:0] B);
	reg [3:0] R[3:0];
	
	initial 
	begin
		R[0] = 4'b0000;
		R[1] = 4'b0000;
		R[2] = 4'b0000;
		R[3] = 4'b0000;
	end
	
	always @(posedge clock)
	begin
		case(destino)
			4'b0000:
				R[0] = dado;
			4'b0001:
				R[1] = dado;
			4'b0010:
				R[2] = dado;
			4'b0011:
				R[3] = dado;
		endcase
		case(opcode[7:4])
			4'b0000:
				A = R[0];
			4'b0001:
				A = R[1];
			4'b0010:
				A = R[2];
			4'b0011:
				A = R[3];
		endcase
		case(opcode[3:0])
			4'b0000:
				B = R[0];
			4'b0001:
				B = R[1];
			4'b0010:
				B = R[2];
			4'b0011:
				B = R[3];
		endcase
	end
endmodule


module regStatus (input clock, input [7:0]destino, input [3:0]CDBtag, input [3:0]CDBResult, 
						output reg [3:0] destino_result, output reg [3:0]result, output reg [15:0] regStatus = 0);
	
	always @(posedge clock)
	begin
		destino_result = CDBtag;
		result = CDBResult;
		if (destino[3:0] == 0000)
		begin
			regStatus[3:0] = destino[7:4]; 
		end
		else if (destino[3:0] == 0001)
		begin
			regStatus[7:4] = destino[7:4]; 
		end
		else if (destino[3:0] == 0010)
		begin
			regStatus[11:8] = destino[7:4]; 
		end
		else if (destino[3:0] == 0011)
		begin
			regStatus[15:12] = destino[7:4]; 
		end
	end

endmodule


module multDiv (input [15:0] dataa, input [15:0] datab, input [2:0] I,
	input aluActivate,
	input clk,
	output reg [15:0] result
);
	always @(posedge clk)
	begin
		if (aluActivate)
			case (I)
				3'b010: //Mul
				begin
					result <= dataa * datab;
				end
				3'b011:	//Div
				begin
					result <= dataa / datab;
				end
			endcase
	end
	
endmodule


module sumAdd (input clock, input exec, input [3:0] dataa, input [3:0] datab, input R, input [3:0] addTag,
					output reg [3:0] result, output reg [3:0]tag_out, output reg sumOcup = 0, output reg addOk = 0);
	
	integer estado = 0;
	
	always @(posedge clock)
	begin
		if (exec)
		begin
			case (estado)
				1'b0:
				begin
					//stall
					addOk = 0;
					sumOcup = 1;
					estado = 1;
				end
				1'b1:
				begin
					sumOcup = 0;
					estado = 0;
					case (R)
						1'b0: //Add
						begin
							result <= dataa + datab;
							tag_out = addTag;
							addOk = 1;
						end
						1'b1:	//Sub
						begin
							result <= dataa - datab;
							addOk = 1;
							tag_out = addTag;
						end
					endcase
				end
			endcase
		end
	end
endmodule
