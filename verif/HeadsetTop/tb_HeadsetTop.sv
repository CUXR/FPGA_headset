`timescale 1ns/1ps

module tb_HeadsetTop;
    logic               clk = 1'b0;
    logic               rst = 1'b1;
    logic               i_frame_valid = 1'b0;
    logic               o_frame_ready;
    logic signed [17:0] o_line_vertex_1 [0:3];
    logic signed [17:0] o_line_vertex_2 [0:3];
    logic [2:0]         o_line_object_id;
    logic [15:0]        o_line_color;
    logic               o_line_valid;
    logic               i_line_ready = 1'b1;

    always #2.5 clk = ~clk;  // 200 MHz

    HeadsetTop dut (.*);

    // Packed aliases make the controller's unpacked input ports visible in VCD.
    // [2] = X, [1] = Y, [0] = Z.
    logic [2:0][17:0] sc_camera_translation;
    logic [2:0][17:0] sc_camera_sin;
    logic [2:0][17:0] sc_camera_cos;

    assign sc_camera_translation = {dut.scene_controller.i_camera_translation[0],
                                    dut.scene_controller.i_camera_translation[1],
                                    dut.scene_controller.i_camera_translation[2]};
    assign sc_camera_sin = {dut.scene_controller.i_camera_sin[0],
                            dut.scene_controller.i_camera_sin[1],
                            dut.scene_controller.i_camera_sin[2]};
    assign sc_camera_cos = {dut.scene_controller.i_camera_cos[0],
                            dut.scene_controller.i_camera_cos[1],
                            dut.scene_controller.i_camera_cos[2]};


    string waves_file;

    initial begin
        if (!$value$plusargs("WAVES=%s", waves_file)) begin
            waves_file = "HeadsetTop.vcd";
        end
        $dumpfile(waves_file);
        $dumpvars(0, tb_HeadsetTop);
        // Icarus requires explicit dumps for unpacked-array elements.
        $dumpvars(0, dut.default_camera_translation[0], dut.default_camera_translation[1], dut.default_camera_translation[2]);
        $dumpvars(0, dut.default_camera_sin[0], dut.default_camera_sin[1], dut.default_camera_sin[2]);
        $dumpvars(0, dut.default_camera_cos[0], dut.default_camera_cos[1], dut.default_camera_cos[2]);
        $dumpvars(0, dut.scene_controller.o_vvp_camera_translation[0], dut.scene_controller.o_vvp_camera_translation[1], dut.scene_controller.o_vvp_camera_translation[2]);
        $dumpvars(0, dut.scene_controller.o_vvp_camera_sin[0], dut.scene_controller.o_vvp_camera_sin[1], dut.scene_controller.o_vvp_camera_sin[2]);
        $dumpvars(0, dut.scene_controller.o_vvp_camera_cos[0], dut.scene_controller.o_vvp_camera_cos[1], dut.scene_controller.o_vvp_camera_cos[2]);

        repeat (4) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        i_frame_valid = 1'b1;
        @(negedge clk);
        i_frame_valid = 1'b0;

        #10000;
        $finish;
    end
endmodule
