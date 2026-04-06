module ExampleModule (
    input logic clk,
);

    always_ff @(posedge clk) begin
        // do stuff here
    end