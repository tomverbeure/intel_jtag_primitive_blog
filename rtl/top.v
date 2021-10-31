
`default_nettype none

module top(
        input  wire     button,
        output wire     led0,
        output wire     led1,
        output wire     led2,

        input  wire     altera_reserved_tck,
        input  wire     altera_reserved_tms,
        input  wire     altera_reserved_tdi,
        output wire     altera_reserved_tdo
    );

    //============================================================
    // Intel JTAG Primitive
    //============================================================

    wire tmsutap;
    wire tckutap;
    wire tdiutap;

    wire clkdruser;
    wire runidleuser;
    wire shiftuser;
    wire updateuser;
    wire usr1user;
    reg  tdouser;

    fiftyfivenm_jtag u_jtag(
        .tms(altera_reserved_tms),
        .tck(altera_reserved_tck),
        .tdi(altera_reserved_tdi),
        .tdo(altera_reserved_tdo),

        .tckutap(tckutap),
        .tmsutap(tmsutap),
        .tdiutap(tdiutap),

        .corectl        (1'b0),

        .clkdruser      (clkdruser),
        .shiftuser      (shiftuser),
        .usr1user       (usr1user), 
        .updateuser     (updateuser),
        .runidleuser    (runidleuser),
        .tdouser        (tdouser)
    );

    //============================================================
    // Tracking TAP FSM and IR capture to create captureuser signal
    //============================================================
    localparam jtag_exit2_dr            = 0;
    localparam jtag_exit1_dr            = 1;
    localparam jtag_shift_dr            = 2;
    localparam jtag_pause_dr            = 3;
    localparam jtag_select_ir_scan      = 4;
    localparam jtag_update_dr           = 5;
    localparam jtag_capture_dr          = 6;
    localparam jtag_select_dr_scan      = 7;
    localparam jtag_exit2_ir            = 8;
    localparam jtag_exit1_ir            = 9;
    localparam jtag_shift_ir            = 10;
    localparam jtag_pause_ir            = 11;
    localparam jtag_run_test_idle       = 12;
    localparam jtag_update_ir           = 13;
    localparam jtag_capture_ir          = 14;
    localparam jtag_test_logic_reset    = 15;

    reg [3:0] jtag_fsm_state = 15;

    always @(posedge tckutap) begin
        case(jtag_fsm_state) 
            jtag_test_logic_reset: jtag_fsm_state <= tmsutap ? jtag_test_logic_reset : jtag_run_test_idle;
            jtag_run_test_idle   : jtag_fsm_state <= tmsutap ? jtag_select_dr_scan   : jtag_run_test_idle;
            jtag_select_dr_scan  : jtag_fsm_state <= tmsutap ? jtag_select_ir_scan   : jtag_capture_dr;
            jtag_capture_dr      : jtag_fsm_state <= tmsutap ? jtag_exit1_dr         : jtag_shift_dr;
            jtag_shift_dr        : jtag_fsm_state <= tmsutap ? jtag_exit1_dr         : jtag_shift_dr;
            jtag_exit1_dr        : jtag_fsm_state <= tmsutap ? jtag_update_dr        : jtag_pause_dr;
            jtag_pause_dr        : jtag_fsm_state <= tmsutap ? jtag_exit2_dr         : jtag_pause_dr;
            jtag_exit2_dr        : jtag_fsm_state <= tmsutap ? jtag_update_dr        : jtag_shift_dr;
            jtag_update_dr       : jtag_fsm_state <= tmsutap ? jtag_select_dr_scan   : jtag_run_test_idle;
            jtag_select_ir_scan  : jtag_fsm_state <= tmsutap ? jtag_test_logic_reset : jtag_capture_ir;
            jtag_capture_ir      : jtag_fsm_state <= tmsutap ? jtag_exit1_ir         : jtag_shift_ir;
            jtag_shift_ir        : jtag_fsm_state <= tmsutap ? jtag_exit1_ir         : jtag_shift_ir;
            jtag_exit1_ir        : jtag_fsm_state <= tmsutap ? jtag_update_ir        : jtag_pause_ir;
            jtag_pause_ir        : jtag_fsm_state <= tmsutap ? jtag_exit2_ir         : jtag_pause_dr;
            jtag_exit2_ir        : jtag_fsm_state <= tmsutap ? jtag_update_ir        : jtag_shift_ir;
            jtag_update_ir       : jtag_fsm_state <= tmsutap ? jtag_select_dr_scan   : jtag_run_test_idle;
        endcase
    end

    wire capture_dr;
    assign capture_dr    = (jtag_fsm_state == jtag_capture_dr);

    reg [9:0] ir_shiftreg = 0;
    reg [9:0] ir_reg = 0;

    always @(posedge tckutap) begin
        if (jtag_fsm_state == jtag_shift_ir) begin
            ir_shiftreg <= { tdiutap, ir_shiftreg[9:1] };
        end

        if (jtag_fsm_state == jtag_update_ir) begin
            ir_reg <= ir_shiftreg;
        end
    end

    wire captureuser;
    assign captureuser = capture_dr && (ir_reg == 10'h00c || ir_reg == 10'h00e);

    //============================================================
    // USER0 and USER1 Chains
    //============================================================

    // USER0 counts the number of times Capture-DR has been triggered when USER0 was selected.
    reg [7:0] user0_shiftreg = 0;
    reg [7:0] user0_reg      = 0;
    reg [7:0] user0_cntr     = 0;

    // USER1 is used to capture the state of the Arrow DECA button and to drive 3 LEDs.
    reg [7:0] user1_shiftreg = 0;
    reg [7:0] user1_reg      = 0;

    always @(posedge tckutap) begin
        if (!usr1user) begin
            if (captureuser) begin
                user0_shiftreg  <= user0_cntr;
                user0_cntr      <= user0_cntr + 1'b1;
            end

            if (shiftuser)
                user0_shiftreg  <= { tdiutap, user0_shiftreg[7:1] };
    
            if (updateuser)
                user0_reg       <= user0_shiftreg;
        end
        else begin
            if (captureuser) 
                user1_shiftreg  <= { 7'h0, button };

            if (shiftuser) 
                user1_shiftreg  <= { tdiutap, user1_shiftreg[7:1] };
    
            if (updateuser) 
                user1_reg       <= user1_shiftreg;
        end
    end

    always @(negedge tckutap) begin
        tdouser  <= !usr1user ? user0_shiftreg[0] : user1_shiftreg[0];
    end

    assign led0 = user1_reg[0];
    assign led1 = user1_reg[1];
    assign led2 = user1_reg[2];

endmodule

