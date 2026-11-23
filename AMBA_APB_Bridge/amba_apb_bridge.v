module amba_apb_bridge (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        sys_transfer_req,
    input  wire        sys_write_req,
    input  wire [31:0] sys_addr_in,
    input  wire [31:0] sys_wdata_in,
    input  wire        apb_ready_in,
    input  wire [31:0] apb_rdata_in,

    output reg         apb_sel_out,
    output reg         apb_enable_out,
    output reg         apb_write_out,
    output reg  [31:0] apb_addr_out,
    output reg  [31:0] apb_wdata_out,
    output wire        sys_trans_done,
    output reg  [31:0] sys_rdata_out
);

    // APB FSM State Encoding
    localparam [1:0] IDLE   = 2'b00;
    localparam [1:0] SETUP  = 2'b01;
    localparam [1:0] ACCESS = 2'b10;

    reg [1:0] state;

    // Combinational transfer-complete indicator during ACCESS when slave is ready
    assign sys_trans_done = (state == ACCESS) && apb_ready_in;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            state          <= IDLE;
            apb_sel_out    <= 1'b0;
            apb_enable_out <= 1'b0;
            apb_write_out  <= 1'b0;
            apb_addr_out   <= 32'd0;
            apb_wdata_out  <= 32'd0;
            sys_rdata_out  <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (sys_transfer_req) begin
                        state          <= SETUP;
                        apb_sel_out    <= 1'b1;
                        apb_enable_out <= 1'b0;
                        apb_write_out  <= sys_write_req;
                        apb_addr_out   <= sys_addr_in;
                        apb_wdata_out  <= sys_wdata_in;
                    end else begin
                        state          <= IDLE;
                        apb_sel_out    <= 1'b0;
                        apb_enable_out <= 1'b0;
                        apb_write_out  <= 1'b0;
                    end
                end

                SETUP: begin
                    state          <= ACCESS;
                    apb_sel_out    <= 1'b1;
                    apb_enable_out <= 1'b1;
                end

                ACCESS: begin
                    if (apb_ready_in) begin
                        if (!apb_write_out) begin
                            sys_rdata_out <= apb_rdata_in;
                        end

                        if (sys_transfer_req) begin
                            // Back-to-back transfer
                            state          <= SETUP;
                            apb_sel_out    <= 1'b1;
                            apb_enable_out <= 1'b0;
                            apb_write_out  <= sys_write_req;
                            apb_addr_out   <= sys_addr_in;
                            apb_wdata_out  <= sys_wdata_in;
                        end else begin
                            // Clean return to IDLE
                            state          <= IDLE;
                            apb_sel_out    <= 1'b0;
                            apb_enable_out <= 1'b0;
                            apb_write_out  <= 1'b0;
                        end
                    end else begin
                        // Hold outputs stable during wait states
                        state <= ACCESS;
                    end
                end

                default: begin
                    state          <= IDLE;
                    apb_sel_out    <= 1'b0;
                    apb_enable_out <= 1'b0;
                    apb_write_out  <= 1'b0;
                end
            endcase
        end
    end

endmodule
