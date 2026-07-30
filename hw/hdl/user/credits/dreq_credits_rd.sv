/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2021-2025, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * @brief   Credit based system for the read requests.
 *
 * Prevents region stalls from propagating to the whole system.
 *
 *  @param DATA_BITS        Size of the data bus
 */
module dreq_credits_rd #(
    parameter integer DATA_BITS = AXI_DATA_BITS
) (
    input  logic            aclk,
    input  logic            aresetn,
    
    // Requests
    metaIntf.s              s_req,
    metaIntf.m              m_req,

    // Data read
    input  logic            xfer
);

// -- FSM
typedef enum logic[0:0]  {ST_IDLE, ST_READ} state_t;
logic [0:0] state_C, state_N;

// Capacity (in beats) of the per-dest response FIFO this stage guards
// (axisr_data_fifo_512_rd_resp in remote_credits_rd, generated with
// FIFO_DEPTH = rd_resp_mult * n_outs * roundup_pow2(pmtu)/64 in
// common_infrastructure.tcl; RD_RESP_FIFO_MULT here must equal rd_resp_mult there,
// and the unrounded PMTU_BYTES under-approximates that depth, which is safe).
// The FIFO is URAM-based (4096 deep at no extra cost), so the budget holds
// RD_RESP_FIFO_MULT max-size single reads (RDMA_MAX_SINGLE_READ = N_OUTSTANDING *
// PMTU with the default config) — at full-size reads the RDMA_N_RD_OUTSTANDING
// request credit and this byte budget saturate together.
// Solicited-but-undrained data must never exceed this capacity, otherwise the
// responses backpressure the shared RDMA write mux and, through it, the
// network stack RX path, which cannot be stalled without losing packets.
localparam integer RD_RESP_FIFO_MULT = 8;
localparam integer FIFO_BEATS = RD_RESP_FIFO_MULT * N_OUTSTANDING * (PMTU_BYTES / (DATA_BITS/8));

// -- Internal regs
logic [7:0] cred_reg_C, cred_reg_N;
logic [BLEN_BITS-1:0] cnt_C, cnt_N;
logic [BLEN_BITS:0] beats_C, beats_N;

// -- Internal signals
logic req_sent;
logic req_done;

logic [BLEN_BITS-1:0] rd_len;

metaIntf #(.STYPE(logic[BLEN_BITS-1:0])) req_que_in (.*);
metaIntf #(.STYPE(logic[BLEN_BITS-1:0])) req_que_out (.*);

metaIntf #(.STYPE(dreq_t)) m_req_int (.*);

// -- REG
always_ff @(posedge aclk) begin: PROC_REG
if (aresetn == 1'b0) begin
	state_C <= ST_IDLE;

    cred_reg_C <= 0;
    beats_C <= 0;
    cnt_C <= 'X;
end
else begin
    state_C <= state_N;

    cred_reg_C <= cred_reg_N;
    beats_C <= beats_N;
    cnt_C <= cnt_N;
end
end

// -- NSL
always_comb begin: NSL
	state_N = state_C;

	case(state_C)
		ST_IDLE: 
			state_N = req_que_out.valid ? ST_READ : ST_IDLE;

        ST_READ:
            state_N = req_done ? (req_que_out.valid ? ST_READ : ST_IDLE) : ST_READ;

	endcase // state_C
end

// -- DP
always_comb begin
  cred_reg_N = cred_reg_C;
  cnt_N =  cnt_C;

  // IO
  s_req.ready = 1'b0;

  m_req_int.valid = 1'b0;
  m_req_int.data = s_req.data;

  // Status (rd_len and req_done must be assigned before their use in req_sent;
  // signals written inside an always_comb do not re-trigger it)
  rd_len = (s_req.data.req_1.len - 1) >> BEAT_LOG_BITS;
  req_done = (cnt_C == 0) && xfer;

  // A request is admitted only if, in addition to the request-count credit, its
  // response fits into the remaining FIFO byte budget (beats_C tracks beats
  // solicited by admitted requests that have not yet drained past the FIFO).
  req_sent = s_req.valid && m_req_int.ready && req_que_in.ready && ((cred_reg_C < RDMA_N_RD_OUTSTANDING) || req_done)
          && (beats_C + rd_len + 1 <= FIFO_BEATS);

  // Outstanding queue
  req_que_in.valid = 1'b0;
  req_que_in.data = rd_len;
  req_que_out.ready = 1'b0;

  if(req_sent && !req_done)
      cred_reg_N = cred_reg_C + 1;
  else if(req_done && !req_sent)
      cred_reg_N = cred_reg_C - 1;

  // Byte budget: reserve on admission, release per beat drained to the user.
  // Saturate at 0: a drained beat that was never reserved here (misrouted or otherwise
  // anomalous data in the dest FIFO) must not wrap the budget to a huge value and
  // permanently block this dest's admission.
  if (xfer && !req_sent && beats_C == 0)
      beats_N = 0;
  else
      beats_N = beats_C + (req_sent ? (rd_len + 1) : 0) - (xfer ? 1 : 0);

  if(req_sent) begin
      s_req.ready = 1'b1;
      m_req_int.valid = 1'b1;
      req_que_in.valid = 1'b1;
  end

  case(state_C)
    ST_IDLE: begin
      if(req_que_out.valid) begin
        req_que_out.ready = 1'b1;
        cnt_N = req_que_out.data[0+:BLEN_BITS];
      end   
    end

    ST_READ: begin
      if(req_done) begin
        if(req_que_out.valid) begin
            req_que_out.ready = 1'b1;
            cnt_N = req_que_out.data[0+:BLEN_BITS];
        end  
      end 
      else begin
        cnt_N = xfer ? cnt_C - 1 : cnt_C;
      end
    end

  endcase
end

`ifndef SYNTHESIS
// Every drained beat must have been reserved by an admitted request; a violation means
// data reached this dest's FIFO that this stage never solicited (routing anomaly).
assert property (@(posedge aclk) disable iff (!aresetn)
    !(xfer && !req_sent && beats_C == 0))
else $error("dreq_credits_rd: beat drained with empty budget (unsolicited data in dest FIFO)");
`endif

// Outstanding
queue_stream #(
  .QTYPE(logic [BLEN_BITS-1:0]),
  .QDEPTH(RDMA_N_RD_OUTSTANDING)
) inst_dque (
  .aclk(aclk),
  .aresetn(aresetn),
  .val_snk(req_que_in.valid),
  .rdy_snk(req_que_in.ready),
  .data_snk(req_que_in.data),
  .val_src(req_que_out.valid),
  .rdy_src(req_que_out.ready),
  .data_src(req_que_out.data)
);

meta_reg #(.DATA_BITS($bits(dreq_t))) inst_out_reg  (.aclk(aclk), .aresetn(aresetn), .s_meta(m_req_int), .m_meta(m_req));

/////////////////////////////////////////////////////////////////////////////
// DEBUG
/////////////////////////////////////////////////////////////////////////////
`ifdef DBG_DREQ_CREDITS_RD

`endif

endmodule