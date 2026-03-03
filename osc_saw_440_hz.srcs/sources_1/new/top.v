`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lark
// 
// Create Date: 03/02/2026 05:25:04 PM
// Design Name: saw_osc_440hz
// Module Name: saw_osc
// Project Name: saw_osc
// Target Devices: arty a7 100t
// Tool Versions: 2025.2
// Description: generates a saw wave output at ~440hz using internal clock,
//              routed out to JA PMOD through J3 Line Out on I2S2 PMOD
// Revision: NULL
//////////////////////////////////////////////////////////////////////////////////


module sawtooth_oscillator_top (
    input wire clk_100mhz, //100 mhz clock internal
    input wire reset_n, //reset connection
    
    //PMOD CONNECTIONS
    output wire i2s_mclk,   //master clock
    output wire i2s_lrck,   //left/right clock (word select)
    output wire i2s_sck,    //Serial Clock (bit clock)
    output wire i2s_sdout   //Serial Data Out
    );
    
    //440 hz parameters for audio
    localparam SAMPLE_RATE = 48000; //48kHz std sample rate, i2s2 supports 24 bit depth
    localparam MCLK_FREQ = 12288000; //12.288 MHz for 48kHz (256*48000)
    
    //internal sig
    wire mclk_enable;
    wire bclk;
    wire lrclk;
    wire [15:0] audio_sample;
    
    //gen mclk sig @ 12.288 MHZ from 100 MHz source clk
    mclk_generator #(
        .DIVIDER(8) // 100/8
    ) mclk_gen (
        .clk_100mhz(clk_100mhz),
        .reset_n(reset_n),
        .mclk(i2s_mclk)
    );
    
    // I2s clock gen
    i2s_clock_gen #(
        .MCLK_FREQ(MCLK_FREQ),
        .SAMPLE_RATE(SAMPLE_RATE)
    ) i2s_clocks (
        .mclk(i2s_mclk),
        .reset_n(reset_n),
        .bclk(i2s_sck),
        .lrclk(i2s_lrck)
    );
    
    // gen sawteeth /|/|/|/| :3
    sawtooth_generator #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .FREQUENCY(440)  // Target 440 Hz
    ) sawtooth_osc (
        .clk_100mhz(clk_100mhz),
        .reset_n(reset_n),
        .lrclk(i2s_lrck),
        .sample_out(audio_sample)
    );
    
    //transmitter: i2s2
    i2s_transmitter i2s_tx (
        .bclk(i2s_sck),
        .lrclk(i2s_lrck),
        .reset_n(reset_n),
        .left_channel(audio_sample),
        .right_channel(audio_sample),  // Mono output to both channels
        .sdata(i2s_sdout)
    );
    
endmodule

//GEN: Master Clock Signal
module mclk_generator #(
    parameter DIVIDER = 8  // div incl. fractional component
) (
    input wire clk_100mhz,
    input wire reset_n,
    output reg mclk
);
    reg[31:0] counter;
    reg[31:0] target;
    
        always @(posedge clk_100mhz or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 0;
            mclk <= 0;
            target <= 100000000 / (12288000 * 2);  // calculate toggle pnts
        end else begin
            if (counter >= target) begin
                counter <= 0;
                mclk <= ~mclk;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule


// I2S2 clock gen (BCLK and LRCLK)
module i2s_clock_gen #(
    parameter MCLK_FREQ = 12288000,
    parameter SAMPLE_RATE = 48000
) (
    input wire mclk,
    input wire reset_n,
    output reg bclk,
    output reg lrclk
);
    // BCLK = MCLK/4 LRCLK = BCLK/64
    localparam BCLK_DIV = 4;  // := 3.072 MHz
    localparam LRCLK_DIV = 64;  // := 48 kHz
    
    reg [7:0] bclk_counter;
    reg [7:0] lrclk_counter;
    
    always @(posedge mclk or negedge reset_n) begin
        if (!reset_n) begin
            bclk_counter <= 0;
            bclk <= 0;
        end else begin
            if (bclk_counter >= (BCLK_DIV/2 - 1)) begin
                bclk_counter <= 0;
                bclk <= ~bclk;
            end else begin
                bclk_counter <= bclk_counter + 1;
            end
        end
    end
    
    always @(posedge bclk or negedge reset_n) begin
        if (!reset_n) begin
            lrclk_counter <= 0;
            lrclk <= 0;
        end else begin
            if (lrclk_counter >= (LRCLK_DIV/2 - 1)) begin
                lrclk_counter <= 0;
                lrclk <= ~lrclk;
            end else begin
                lrclk_counter <= lrclk_counter + 1;
            end
        end
    end
endmodule

// wave gen
module sawtooth_generator #(
    parameter SAMPLE_RATE = 48000,
    parameter FREQUENCY = 440
) (
    input wire clk_100mhz,
    input wire reset_n,
    input wire lrclk,  // Sample clock (48 kHz)
    output reg [15:0] sample_out
);
    
    // Calculate increment per sample for desired frequency
    // With 16-bit resolution, we want to overflow at 2^16 = 65536
    // Phase incremenent = (FREQUENCY * 2^16) / SAMPLE_RATE
    localparam PHASE_INCREMENT = (FREQUENCY * 65536) / SAMPLE_RATE;
    
    reg [31:0] phase_accumulator;
    reg lrclk_prev;
    
    always @(posedge clk_100mhz or negedge reset_n) begin
        if (!reset_n) begin
            phase_accumulator <= 0;
            sample_out <= 0;
            lrclk_prev <= 0;
        end else begin
            lrclk_prev <= lrclk;
            
            // Update phase on rising edge of LRCLK (sample clock)
            if (lrclk && !lrclk_prev) begin
                phase_accumulator <= phase_accumulator + PHASE_INCREMENT;
                
                // Convert phase to sawtooth sample
                // Sawtooth: output the upper 16 bits of phase accumulator
                sample_out <= phase_accumulator[31:16];
            end
        end
    end
endmodule

// I2S transmitter module
module i2s_transmitter (
    input wire bclk,          // Bit clock
    input wire lrclk,         // Left/Right clock
    input wire reset_n,
    input wire [15:0] left_channel,
    input wire [15:0] right_channel,
    output reg sdata
);
    
    reg [4:0] bit_counter;  // Counts bits (0-31)
    reg [31:0] shift_register;
    reg lrclk_prev;
    
    always @(posedge bclk or negedge reset_n) begin
        if (!reset_n) begin
            bit_counter <= 0;
            shift_register <= 0;
            sdata <= 0;
            lrclk_prev <= 0;
        end else begin
            lrclk_prev <= lrclk;
            
            // On LRCLK edge, load new data
            if (lrclk != lrclk_prev) begin
                bit_counter <= 0;
                // I2S format: MSB first, left channel when LRCLK low
                if (lrclk == 1) begin  // Right channel (LRCLK high)
                    shift_register <= {right_channel, 16'b0};
                end else begin          // Left channel (LRCLK low)
                    shift_register <= {left_channel, 16'b0};
                end
            end else begin
                // Shift out data on each BCLK
                if (bit_counter < 32) begin
                    sdata <= shift_register[31];
                    shift_register <= {shift_register[30:0], 1'b0};
                    bit_counter <= bit_counter + 1;
                end
            end
        end
    end
endmodule