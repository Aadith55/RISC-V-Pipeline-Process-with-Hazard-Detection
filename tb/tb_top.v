module tb_top();

    reg clk;
    reg rst;

    top_module tm1 (
        .clk(clk),
        .rst(rst)
    );

    // 100 MHz simulation clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1;

        // Hold reset for two clock cycles
        #20;
        rst = 0;

        // Allow the pipeline to complete the test program
        repeat (50) @(posedge clk);

        $display("========================================");
        $display("          FINAL PROCESSOR STATE");
        $display("========================================");

        $display("R1     = %h", tm1.r1.reg_data[1]);
        $display("R7     = %h", tm1.r1.reg_data[7]);
        $display("R8     = %h", tm1.r1.reg_data[8]);
        $display("MEM[5] = %h", tm1.d1.d_mem[5]);
        $display("MEM[8] = %h", tm1.d1.d_mem[8]);

        $display("========================================");

        #10;
        $finish;
    end

endmodule
