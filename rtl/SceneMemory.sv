`ifndef SCENE_MEMORY_SV
`define SCENE_MEMORY_SV

`timescale 1ns/1ps

module SceneMemory #(
    parameter int DATA_W = 18  // Q8.10
) (
    input  logic clk,
    input  logic rst,

    input  logic                      i_object_read_en,
    input  logic [2:0]                i_object_read_addr,
    output logic [12*DATA_W+36-1:0]   o_object_data,
    output logic                      o_object_valid,

    input  logic                      i_vertex_read_en,
    input  logic [4:0]                i_vertex_read_addr,
    output logic [3*DATA_W-1:0]       o_vertex_data,
    output logic                      o_vertex_valid,

    input  logic                      i_edge_read_en,
    input  logic [4:0]                i_edge_read_addr,
    output logic [5:0]                o_edge_data,
    output logic                      o_edge_valid
);

    // Fixed Cornell capacities; both boxes share the same cube geometry.
    localparam int OBJECTS             = 7;
    localparam int VERTICES            = 28;
    localparam int EDGES               = 32;
    localparam int MAX_OBJECT_VERTICES = 8;

    localparam int OBJECT_ADDR_W = $clog2(OBJECTS);  // 3
    localparam int VERTEX_ADDR_W = $clog2(VERTICES); // 5
    localparam int EDGE_ADDR_W   = $clog2(EDGES);    // 5

    localparam int VERTEX_COUNT_W = $clog2(MAX_OBJECT_VERTICES + 1); // 4
    localparam int EDGE_COUNT_W   = $clog2(EDGES + 1);               // 6

    localparam int LOCAL_VERTEX_IDX_W = $clog2(MAX_OBJECT_VERTICES); // 3

    localparam int COLOR_W = 16;

    localparam int VERTEX_RECORD_W = 3 * DATA_W;             // 54
    localparam int EDGE_RECORD_W   = 2 * LOCAL_VERTEX_IDX_W; // 6
    localparam int OBJECT_RECORD_W = 
        VERTEX_ADDR_W + VERTEX_COUNT_W +
        EDGE_ADDR_W + EDGE_COUNT_W +
        12 * DATA_W +
        COLOR_W; // 252
    
    // Data layout
    // [53:36] | [35:18] | [17:0]
    //    X    |    Y    |    Z
    logic [VERTEX_RECORD_W-1:0] vertex_table [0:VERTICES-1];

    // Data layout
    //  [5:3]   |  [2:0]
    // Vertex 1 | Vertex 2
    logic [EDGE_RECORD_W-1:0]   edge_table   [0:EDGES-1];

    // Data layout
    //  [251:247]  |  [246:243]   | [242:238] | [237:232]  |  [231:178]  | [177:124] | [123:70] | [69:16] | [15:0]
    // Vertex Base | Vertex Count | Edge Base | Edge Count | Translation |   Scale   |   sin    |   cos   | color
    logic [OBJECT_RECORD_W-1:0] object_table [0:OBJECTS-1];


    always_ff @(posedge clk) begin
        if (i_object_read_en)
            o_object_data <= object_table[i_object_read_addr];
        if (i_vertex_read_en)
            o_vertex_data <= vertex_table[i_vertex_read_addr];
        if (i_edge_read_en)
            o_edge_data <= edge_table[i_edge_read_addr];

        if (rst) begin
            o_object_valid <= 1'b0;
            o_vertex_valid <= 1'b0;
            o_edge_valid   <= 1'b0;
        end else begin
            o_object_valid <= i_object_read_en;
            o_vertex_valid <= i_vertex_read_en;
            o_edge_valid   <= i_edge_read_en;
        end
    end

    // Cornell Box scene stored

    initial begin
        object_table[0] = {5'd0, 4'd4, 5'd0, 6'd4, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 16'hFFFF};
        object_table[1] = {5'd4, 4'd4, 5'd4, 6'd4, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 16'hFFFF};
        object_table[2] = {5'd8, 4'd4, 5'd8, 6'd4, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 16'hFFFF};
        object_table[3] = {5'd12, 4'd4, 5'd12, 6'd4, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 16'hF800};
        object_table[4] = {5'd16, 4'd4, 5'd16, 6'd4, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 18'd0, 18'd0, 18'd0, 18'd1024, 18'd1024, 18'd1024, 16'h07E0};
        object_table[5] = {5'd20, 4'd8, 5'd20, 6'd12, 18'd261376, 18'd260659, 18'd6349, 18'd1229, 18'd1126, 18'd1178, 18'd0, 18'd283, 18'd0, 18'd1024, 18'd984, 18'd1024, 16'hFFFF};
        object_table[6] = {5'd20, 4'd8, 5'd20, 6'd12, 18'd768, 18'd261274, 18'd6963, 18'd922, 18'd2355, 18'd1024, 18'd0, 18'd261921, 18'd0, 18'd1024, 18'd999, 18'd1024, 16'hFFFF};
    end

    initial begin
        vertex_table[0] =  {18'd260096, 18'd260096, 18'd4096  }; // (-2, -2, 4)
        vertex_table[1] =  {18'd2048,   18'd260096, 18'd4096  }; // (2, -2, 4)
        vertex_table[2] =  {18'd2048,   18'd260096, 18'd8192  }; // (2, -2, 8)
        vertex_table[3] =  {18'd260096, 18'd260096, 18'd8192  }; // (-2, -2, 8)
        vertex_table[4] =  {18'd260096, 18'd2048,   18'd4096  }; // (-2, 2, 4)
        vertex_table[5] =  {18'd260096, 18'd2048,   18'd8192  }; // (-2, 2, 8)
        vertex_table[6] =  {18'd2048,   18'd2048,   18'd8192  }; // (2, 2, 8)
        vertex_table[7] =  {18'd2048,   18'd2048,   18'd4096  }; // (2, 2, 4)
        vertex_table[8] =  {18'd260096, 18'd260096, 18'd8192  }; // (-2, -2, 8)
        vertex_table[9] =  {18'd2048,   18'd260096, 18'd8192  }; // (2, -2, 8)
        vertex_table[10] = {18'd2048,   18'd2048,   18'd8192  }; // (2, 2, 8)
        vertex_table[11] = {18'd260096, 18'd2048,   18'd8192  }; // (-2, 2, 8)
        vertex_table[12] = {18'd260096, 18'd260096, 18'd4096  }; // (-2, -2, 4)
        vertex_table[13] = {18'd260096, 18'd260096, 18'd8192  }; // (-2, -2, 8)
        vertex_table[14] = {18'd260096, 18'd2048,   18'd8192  }; // (-2, 2, 8)
        vertex_table[15] = {18'd260096, 18'd2048,   18'd4096  }; // (-2, 2, 4)
        vertex_table[16] = {18'd2048,   18'd260096, 18'd4096  }; // (2, -2, 4)
        vertex_table[17] = {18'd2048,   18'd2048,   18'd4096  }; // (2, 2, 4)
        vertex_table[18] = {18'd2048,   18'd2048,   18'd8192  }; // (2, 2, 8)
        vertex_table[19] = {18'd2048,   18'd260096, 18'd8192  }; // (2, -2, 8)
        vertex_table[20] = {18'd261632, 18'd261632, 18'd261632}; // (-0.5, -0.5, -0.5)
        vertex_table[21] = {18'd512,    18'd261632, 18'd261632}; // (0.5, -0.5, -0.5)
        vertex_table[22] = {18'd512,    18'd512,    18'd261632}; // (0.5, 0.5, -0.5)
        vertex_table[23] = {18'd261632, 18'd512,    18'd261632}; // (-0.5, 0.5, -0.5)
        vertex_table[24] = {18'd261632, 18'd261632, 18'd512   }; // (-0.5, -0.5, 0.5)
        vertex_table[25] = {18'd512,    18'd261632, 18'd512   }; // (0.5, -0.5, 0.5)
        vertex_table[26] = {18'd512,    18'd512,    18'd512   }; // (0.5, 0.5, 0.5)
        vertex_table[27] = {18'd261632, 18'd512,    18'd512   }; // (-0.5, 0.5, 0.5)
    end

    initial begin
        edge_table[0] =  {3'd0, 3'd1};
        edge_table[1] =  {3'd1, 3'd2};
        edge_table[2] =  {3'd2, 3'd3};
        edge_table[3] =  {3'd3, 3'd0};
        edge_table[4] =  {3'd0, 3'd1};
        edge_table[5] =  {3'd1, 3'd2};
        edge_table[6] =  {3'd2, 3'd3};
        edge_table[7] =  {3'd3, 3'd0};
        edge_table[8] =  {3'd0, 3'd1};
        edge_table[9] =  {3'd1, 3'd2};
        edge_table[10] = {3'd2, 3'd3};
        edge_table[11] = {3'd3, 3'd0};
        edge_table[12] = {3'd0, 3'd1};
        edge_table[13] = {3'd1, 3'd2};
        edge_table[14] = {3'd2, 3'd3};
        edge_table[15] = {3'd3, 3'd0};
        edge_table[16] = {3'd0, 3'd1};
        edge_table[17] = {3'd1, 3'd2};
        edge_table[18] = {3'd2, 3'd3};
        edge_table[19] = {3'd3, 3'd0};
        edge_table[20] = {3'd0, 3'd1};
        edge_table[21] = {3'd1, 3'd2};
        edge_table[22] = {3'd2, 3'd3};
        edge_table[23] = {3'd3, 3'd0};
        edge_table[24] = {3'd4, 3'd5};
        edge_table[25] = {3'd5, 3'd6};
        edge_table[26] = {3'd6, 3'd7};
        edge_table[27] = {3'd7, 3'd4};
        edge_table[28] = {3'd0, 3'd4};
        edge_table[29] = {3'd1, 3'd5};
        edge_table[30] = {3'd2, 3'd6};
        edge_table[31] = {3'd3, 3'd7};
    end

endmodule

`endif

