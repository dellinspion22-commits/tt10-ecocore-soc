`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // enable - always 1 when the design is powered or selected
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Internal wires for Eco-Core SoC mapping
    wire clk_core = clk;
    wire rst_n_core = rst_n;

    // Mapping inputs from ui_in
    wire start_task   = ui_in[0];
    wire [2:0] task_type  = ui_in[3:1];
    wire [3:0] data_in    = ui_in[7:4];

    // Internal Registers for Eco-Core SoC FSM
    reg [2:0] current_state, next_state;
    reg [7:0] internal_accumulator;
    reg [3:0] sram_addr;
    reg [7:0] sram_data_out;
    reg       task_done;

    // Bidirectional and unused pins assignments
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000; // All bidirectional pins configured as inputs

    // State Encoding
    localparam STATE_IDLE      = 3'b000;
    localparam STATE_FETCH     = 3'b001;
    localparam STATE_EXECUTE   = 3'b010;
    localparam STATE_SRAM_R_W  = 3'b011;
    localparam STATE_DONE      = 3'b100;

    // FSM State Transition
    always @(posedge clk_core or negedge rst_n_core) begin
        if (!rst_n_core) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Next State Logic
    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (start_task)
                    next_state = STATE_FETCH;
                else
                    next_state = STATE_IDLE;
            end
            STATE_FETCH: begin
                next_state = STATE_EXECUTE;
            end
            STATE_EXECUTE: begin
                if (task_type == 3'b011 || task_type == 3'b100) // SRAM Task types
                    next_state = STATE_SRAM_R_W;
                else
                    next_state = STATE_DONE;
            end
            STATE_SRAM_R_W: begin
                next_state = STATE_DONE;
            end
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    // FSM Output & Datapath Logic
    always @(posedge clk_core or negedge rst_n_core) begin
        if (!rst_n_core) begin
            internal_accumulator <= 8'h00;
            sram_addr           <= 4'h0;
            sram_data_out       <= 8'h00;
            task_done           <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    task_done <= 1'b0;
                end
                STATE_FETCH: begin
                    sram_addr <= data_in; // Pre-loading address
                end
                STATE_EXECUTE: begin
                    case (task_type)
                        3'b000: internal_accumulator <= internal_accumulator + data_in; // Processing ADD
                        3'b001: internal_accumulator <= internal_accumulator - data_in; // Processing SUB
                        3'b010: internal_accumulator <= internal_accumulator & {4'hF, data_in}; // Processing AND
                        default: internal_accumulator <= internal_accumulator;
                    endcase
                end
                STATE_SRAM_R_W: begin
                    if (task_type == 3'b011) begin
                        sram_data_out <= internal_accumulator; // SRAM Write operation simulated
                    end else if (task_type == 3'b100) begin
                        internal_accumulator <= sram_data_out; // SRAM Read operation simulated
                    end
                end
                STATE_DONE: begin
                    task_done <= 1'b1;
                end
            endcase
        end
    end

    // Assigning outputs to uo_out
    assign uo_out[0]     = task_done;
    assign uo_out[4:1]   = internal_accumulator[3:0];
    assign uo_out[7:5]   = current_state;

endmodule
