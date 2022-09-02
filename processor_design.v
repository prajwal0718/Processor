`timescale 1ns / 1ps
 
module top();
 //NOTE : one GPR is only 16 bit but one IR is 32 bit 
reg [15:0] GPR [32:0]; ////Total there are 33 registers among them 32 Registers are user accessible and R[32] -->> for mul
reg [31:0] IR; // 32 bit instruction register
reg [31:0] temp;  //used in case of multiplication.

 //Define of instruction register that is 32 bit
  `define opcode IR[31:27]
// MSB of IR[31:27] this is 5 bit and is (opcode )to define what function processor would perform at that specific clock cycle.

`define rdst IR[26:22]
 //bit[26:22]  5 bit is mainly defined for destination register.(To store result of operation) , we assumed that there would be 32 general purpose registers so we considered it as 5 bit , eg if 5 bit is 00110 than output would be stored in (register 6)
  
`define src1 IR[21:17]
  // Define source register from [22;17] (1st input data) and source 2 from [15:11]
  
`define imm_sel IR[16]
 // Bit 16 is used as mode to select addressing mode 
 /*0 -  Register addressing mode  ---> rdst = rsrc1 + rsrc2;
1 -  Immediate addressing mode  --->  rdst = rsrc1 + immediate_number */
`define src2 IR[15:11]
 
// This is patter of instruction register -->> opcode(5) reg_dst(5) src1_reg (5) sel_mode src2_reg(5)

//Defining of instructions (opcode)
//arthemetic operations are defined here.
`define mov 5'b00000  //1st instruction is mov 
`define add 5'b00001  
`define sub 5'b00010
`define mul 5'b00011
 
//Logical operations are defined here

`define and 5'b00100
`define or 5'b00101
`define xor 5'b00110
`define nand 5'b00111
`define nor 5'b01000
`define xnor 5'b01001
`define not 5'b01010


task excecute();
begin
 
case(`opcode)
/////////Updating Register data is main objective of mov instruction
`mov : begin
 if(`imm_sel == 1'b1)   // if mode is immediate(1) than mov LSB 16 bit into destination 
GPR[`rdst] = IR[15:0];
else
  GPR[`rdst] = GPR[`src1]; // Else move data in src register into destination
end
 
 // Focus on register addressing mode only so no need of if else condition
//Here we also add immediate addressing mode capabilities to the processor....
`add: begin
if(`imm_sel == 1'b1)
GPR[`rdst] = GPR[`src1] + IR[15:0]; //Immediate addressing mode after source we have 16 bit data that has to be added
else
GPR[`rdst] = GPR[`src1] + GPR[`src2];
conditionflag();
end
 
 //When opcode is 00010 then subtraction
`sub: begin
if(`imm_sel == 1'b1)
GPR[`rdst] = GPR[`src1] - IR[15:0]; 
else
GPR[`rdst] = GPR[`src1] - GPR[`src2];
conditionflag();  //after subtraction we want to check condition of flag....
end
 
`mul : begin   //In mul result will be mainly 32 bit as two sources are of 16 bit each..
 // to handle 32 bit we add temp variable....
  if(`imm_sel == 1'b1)
 	 GPR[`rdst] = GPR[`src1] * IR[15:0];
  else 
  temp = GPR[`src1] * GPR[`src2];//This generates 32 bit result
  GPR[`rdst] = temp[15:0];   //Each register is only of 16 bit wide thus we can store only LSB 16 bit rest 16 bit we Need one extra register....
  GPR[32] = temp[31:16]; // GPR[32] used to store additional 16 bit in mul result....
conditionflag();
end
 
//Logical operation code is done here
`and: begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] = GPR[`src1] & IR[15:0];
 else
 GPR[`rdst] = GPR[`src1] & GPR[`src2];
end
 
`or: begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] = GPR[`src1] | IR[15:0];
 else
 GPR[`rdst] = GPR[`src1] | GPR[`src2];
end
 
`xor: begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] = GPR[`src1] ^ IR[15:0];
 else
 GPR[`rdst] = GPR[`src1] ^ GPR[`src2];
end
 
`nand: begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] = ~(GPR[`src1] & IR[15:0]);
 else
 GPR[`rdst] = ~(GPR[`src1] & GPR[`src2]);
end
 
 
`nor: begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] = ~(GPR[`src1] | IR[15:0]);
 else
 GPR[`rdst] = ~(GPR[`src1] | GPR[`src2]);
end
 
`xnor: begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] = GPR[`src1] ~^ IR[15:0];
 else
 GPR[`rdst] = GPR[`src1] ~^ GPR[`src2];
end
 
 
`not:begin
 if(`imm_sel == 1'b1)
 GPR[`rdst] =  ~ (IR[15:0]);
 else
 GPR[`rdst] = ~(GPR[`src1]) ;
end
 
endcase
end
endtask



///conditional flag task

reg zero, sign, carry, overflow;  //flag names declared
reg [15:0] s1, s2;  // new names declared for sources 
reg [32:0] o;   // output range upto 33 bit!!

task conditionflag();
begin
  //Updating value of s1 and s2....
if(`imm_sel == 1'b1) begin
s1 = GPR[`src1];
s2 = IR[15:0];
end
else begin
s1 = GPR[`src1];
s2 = GPR[`src2];    //just assigning it to newly declared variables
end

 
case(`opcode)
`add: o = s1 + s2;
`sub: o = s1 - s2;
`mul: o = s1 * s2;
default: o = 0;
endcase
 
zero = ~(|o[32:0]);   // Check MSB bit by OR of all bits and then complement it.

sign = (o[15] & ~IR[28] & IR[27] ) | (o[15] & IR[28] & ~IR[27]) | (o[31] & IR[28] & IR[27] );
// This is for addition operation  | Subtraction operation opcode last 2 bit 10     | Multiplication operation  opcode last 2 bit is 11
// addition opcode is 00001 where last two digit is 0 and 1 so opcode is from[31:27] where 28th bit is 0 so ~IR[28] and LSB that is 27th bit is 1--> IR[27]

carry = o[16] & ~IR[28] & IR[27];
// result MSB =1 and is valid only for addition operation..

overflow = ( ~s1[15] & ~s2[15] & o[15] & ~IR[28] & IR[27] ) |
           ( s1[15] & s2[15] & ~o[15] & ~IR[28] & IR[27] ) |    //For addition condition.
           ( ~s1[15] & s2[15] & o[15] & IR[28] & ~IR[27] ) |
           ( s1[15] & ~s2[15] & ~o[15] & IR[28] & ~IR[27] );    //For subtraction condition
//Overflow mainly when s1 and s2 are positive(~s1[15] & ~s2[15]) and output (o[15]) is negative and also we took addition condition here and other when s1 and s2 are negative but result is positive
end
endtask

endmodule
