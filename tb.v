`timescale 1ns/1ps

module tb();

reg clk = 0;
reg rst_n;
wire [7:0] leds;

reg [43:0] file_data [0:0];
reg [7:0] expected_leds;
reg [31:0] expected_memory;
reg [3:0] test_case;

always #1 clk = ~clk; // Clock generation

core_top #(
    .MEMORY_FILE("programa.txt") // Specify the memory file
) t (
    .clk(clk),
    .rst_n(rst_n),
    .leds(leds)
);

integer i;
reg [7:0] counter = 0;

initial begin
    $dumpfile("saida.vcd");
    $dumpvars(0, tb);

    $readmemh("teste.txt", file_data); // Read the memory file

    test_case = file_data[0][43:40];
    expected_leds = file_data[0][39:32];
    expected_memory = file_data[0][31:0];

    //$display("Test case: %b, Expected LEDs: %b, Expected Memory: %h", test_case, expected_leds, expected_memory);

    rst_n = 0; // Reset the system
    #5;
    rst_n = 1; // Release reset

    #50; // wait for the end of the program

    case (test_case)
        4'b0000, 4'b0001: begin
            $display("Teste de escrita nos LEDS...");
            if (leds !== expected_leds) begin
                $display("=== ERRO Escrita nos LEDS falhou: esperava %h, obtive %h", expected_leds, leds);
            end else begin
                $display("=== OK Escrita nos LEDS passou: obtive %h", leds);
            end
        end
        4'b0010: begin
            $display("Teste de leitura dos LEDS seguido de escrita na memória...");
            if (expected_memory !== t.mem.memory[64/4]) begin
                $display("=== ERRO Leitura dos LEDs falhou: esperava %h, obtive %h", expected_memory, t.mem.memory[64/4]);
            end else begin
                $display("=== OK Leitura dos LEDs passou: obtive %h", t.mem.memory[64/4]);
            end
        end
        4'b0011: begin
            $display("Teste de escrita independente na memória...");
            if (expected_memory !== t.mem.memory[64/4]) begin
                $display("=== ERRO Escrita na memória falhou: esperava %h, obtive %h", expected_memory, t.mem.memory[16/4]);
            end else begin
                $display("=== OK Escrita na memória passou: obtive %h", t.mem.memory[64/4]);
            end
        end
    endcase

    $finish; // End simulation
end

endmodule
