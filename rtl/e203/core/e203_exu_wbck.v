 /*                                                                      
 Copyright 2017 Silicon Integrated Microelectronics, Inc.                
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
  Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */                                                                      
                                                                         
                                                                         
                                                                         
//=====================================================================
//--        _______   ___
//--       (   ____/ /__/
//--        \ \     __
//--     ____\ \   / /
//--    /_______\ /_/   MICROELECTRONICS
//--
//=====================================================================
//
// Designer   : Bob Hu
//
// Description:
//  The Write-Back module to arbitrate the write-back request to regfile
//
// ====================================================================

`include "e203_defines.v"

module e203_exu_wbck(

  //////////////////////////////////////////////////////////////
  // The ALU Write-Back Interface
  // 所有单周期指令的写回
  input  alu_wbck_i_valid, // Handshake valid
  output alu_wbck_i_ready, // Handshake ready
  input  [`E203_XLEN-1:0] alu_wbck_i_wdat,           // 写回的数据值
  input  [`E203_RFIDX_WIDTH-1:0] alu_wbck_i_rdidx,   // 写回的寄存器索引值
  // If ALU have error, it will not generate the wback_valid to wback module
      // so we dont need the alu_wbck_i_err here

  //////////////////////////////////////////////////////////////
  // The Longp Write-Back Interface
  // 来自长指令写回仲裁的长指令写回
  input  longp_wbck_i_valid, // Handshake valid
  output longp_wbck_i_ready, // Handshake ready
  input  [`E203_FLEN-1:0] longp_wbck_i_wdat,        // 写回的数据值
  input  [5-1:0] longp_wbck_i_flags,                // ？？？
  input  [`E203_RFIDX_WIDTH-1:0] longp_wbck_i_rdidx,// 写回的寄存器索引值
  input  longp_wbck_i_rdfpu,

  //////////////////////////////////////////////////////////////
  // The Final arbitrated Write-Back Interface to Regfile

  output  rf_wbck_o_ena,
  output  [`E203_XLEN-1:0] rf_wbck_o_wdat,
  output  [`E203_RFIDX_WIDTH-1:0] rf_wbck_o_rdidx,


  
  input  clk,
  input  rst_n
  );


  // The ALU instruction can write-back only when there is no any 
  //  long pipeline instruction writing-back
  //    * Since ALU is the 1 cycle instructions, it have lowest 
  //      priority in arbitration
  wire wbck_ready4alu = (~longp_wbck_i_valid);          // 检查有没有长指令写回
  wire wbck_sel_alu = alu_wbck_i_valid & wbck_ready4alu;// 检查短指令是否可以写回
  // The Long-pipe instruction can always write-back since it have high priority 
  wire wbck_ready4longp = 1'b1;                         //  长指令写回随时为true
  wire wbck_sel_longp = longp_wbck_i_valid & wbck_ready4longp;  // 检查长指令是否可以写回

  //Add================================
  wire alu_wbck_i_ready_nxt;
  wire longp_wbck_i_ready_nxt;

  wire rf_wbck_o_ena_en = 1'b1;
  wire rf_wbck_o_ena_nxt;

  wire rf_wbck_o_wdat_en = 1'b1;
  wire [`E203_XLEN-1:0] rf_wbck_o_wdat_nxt;

  wire rf_wbck_o_rdidx_en = 1'b1;
  wire [`E203_RFIDX_WIDTH-1:0] rf_wbck_o_rdidx_nxt;

  
  sirv_gnrl_dfflr #(1) alu_wbck_i_ready_dfflr(1'b1, alu_wbck_i_ready_nxt, alu_wbck_i_ready, clk, rst_n);
  sirv_gnrl_dfflr #(1) longp_wbck_i_ready_dfflr(1'b1, longp_wbck_i_ready_nxt, longp_wbck_i_ready, clk, rst_n);
  sirv_gnrl_dfflr #(1) rf_wbck_o_ena_dfflr(rf_wbck_o_ena_en, rf_wbck_o_ena_nxt, rf_wbck_o_ena, clk, rst_n);
  sirv_gnrl_dfflr #(`E203_XLEN) rf_wbck_o_wdat_dfflr(rf_wbck_o_wdat_en, rf_wbck_o_wdat_nxt, rf_wbck_o_wdat, clk, rst_n);
  sirv_gnrl_dfflr #(`E203_RFIDX_WIDTH) rf_wbck_o_rdidx_dfflr(rf_wbck_o_rdidx_en, rf_wbck_o_rdidx_nxt, rf_wbck_o_rdidx, clk, rst_n);
 
  //////////////////////////////////////////////////////////////
  // The Final arbitrated Write-Back Interface
  wire rf_wbck_o_ready = 1'b1; // Regfile is always ready to be write because it just has 1 w-port

  wire wbck_i_ready;
  wire wbck_i_valid;
  wire [`E203_FLEN-1:0] wbck_i_wdat;
  wire [5-1:0] wbck_i_flags;
  wire [`E203_RFIDX_WIDTH-1:0] wbck_i_rdidx;
  wire wbck_i_rdfpu;

//   assign alu_wbck_i_ready   = wbck_ready4alu   & wbck_i_ready;  // 返回给alu是否ready
  assign alu_wbck_i_ready_nxt   = wbck_ready4alu   & wbck_i_ready;
//   assign longp_wbck_i_ready = wbck_ready4longp & wbck_i_ready;  // 返回给longpipe是否可以发射星爆气流斩
  assign longp_wbck_i_ready_nxt = wbck_ready4longp & wbck_i_ready;

  assign wbck_i_valid = wbck_sel_alu ? alu_wbck_i_valid : longp_wbck_i_valid;   // 如果短可以写回，则返回是否有短可以写，否则返回长可以写
  `ifdef E203_FLEN_IS_32//{
  assign wbck_i_wdat  = wbck_sel_alu ? alu_wbck_i_wdat  : longp_wbck_i_wdat;    // (32)如果短可以写回，返回短数值，否则返回长数值
  `else//}{                                                                     // (16)如果短可以写回，返回补充长度的短数值，否则长指令使用星爆气流斩
  assign wbck_i_wdat  = wbck_sel_alu ? {{`E203_FLEN-`E203_XLEN{1'b0}},alu_wbck_i_wdat}  : longp_wbck_i_wdat;
  `endif//}
  assign wbck_i_flags = wbck_sel_alu ? 5'b0  : longp_wbck_i_flags;              // 啥子玩意
  assign wbck_i_rdidx = wbck_sel_alu ? alu_wbck_i_rdidx : longp_wbck_i_rdidx;   // 寄存器索引
  assign wbck_i_rdfpu = wbck_sel_alu ? 1'b0 : longp_wbck_i_rdfpu;               // fpu

  // If it have error or non-rdwen it will not be send to this module
  //   instead have been killed at EU level, so it is always need to 
  //   write back into regfile at here
  assign wbck_i_ready  = rf_wbck_o_ready;
  wire rf_wbck_o_valid = wbck_i_valid;  // 检查是否有东西写

  wire wbck_o_ena   = rf_wbck_o_valid & rf_wbck_o_ready; // 一定要又有空又有东西写

//  Revise ===================================================
//   assign rf_wbck_o_ena   = wbck_o_ena & (~wbck_i_rdfpu); // Regfile使能信号
  assign rf_wbck_o_ena_nxt   = wbck_o_ena & (~wbck_i_rdfpu);

//   assign rf_wbck_o_wdat  = wbck_i_wdat[`E203_XLEN-1:0];
  assign rf_wbck_o_wdat_nxt  = wbck_i_wdat[`E203_XLEN-1:0];
//   assign reg_rf_wbck_o_rdidx = wbck_i_rdidx;
  assign rf_wbck_o_rdidx_nxt = wbck_i_rdidx;
endmodule                                      
                                               
                                               
                                               
