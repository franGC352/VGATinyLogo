`timescale 1ns / 1ps

module testbench;

    // Entradas del chip
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    reg ena;
    reg clk;
    reg rst_n;

    // Salidas del chip
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Señales VGA
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;

    // Decodificacion de las salidas VGA
    assign hsync = uo_out[7];
    assign vsync = uo_out[3];

    assign R = {uo_out[0], uo_out[4]};
    assign G = {uo_out[1], uo_out[5]};
    assign B = {uo_out[2], uo_out[6]};

    // Instancia del diseño principal
    tt_um_rejunity_vga_logo dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Generacion de reloj de 25 MHz
    // Periodo: 40 ns
    initial clk = 0;
    always #20 clk = ~clk;

    // Secuencia de pruebas
    initial begin

        // Archivo para visualizar señales
        $dumpfile("dump.vcd");
        $dumpvars(1, testbench);
        $dumpvars(1, dut);

        // Condiciones iniciales
        ui_in  = 8'b00000000;
        uio_in = 8'b00000000;
        ena    = 1'b1;
        rst_n  = 1'b0;

        // PRUEBA 1: Reinicio del sistema
        $display("PRUEBA 1: Reinicio");
        repeat (10) @(negedge clk);
        rst_n = 1'b1;

        // PRUEBA 2: Funcionamiento normal
        $display("PRUEBA 2: Funcionamiento normal");
        #17000000;

        // PRUEBA 3: Cambio de velocidad del fondo
        $display("PRUEBA 3: Cambio de velocidad");
        ui_in = 8'b00000001;
        #17000000;

        // PRUEBA 4: Velocidad maxima
        $display("PRUEBA 4: Velocidad maxima");
        ui_in = 8'b00000011;
        #17000000;

        // PRUEBA 5: Cambio del fondo de colores
        $display("PRUEBA 5: Cambio de colores");
        ui_in = 8'b00000100;
        #17000000;

        // PRUEBA 6: Reinicio final
        $display("PRUEBA 6: Reinicio final");
        rst_n = 1'b0;
        repeat (10) @(negedge clk);
        rst_n = 1'b1;

        #1000;

        $display("SIMULACION FINALIZADA");
        $finish;

    end

    // Verificacion de las salidas no utilizadas
    always @(negedge clk) begin

        if (rst_n) begin

            if (uio_out !== 8'b00000000)
                $fatal(1, "Error en uio_out");

            if (uio_oe !== 8'b00000000)
                $fatal(1, "Error en uio_oe");

            // Durante el intervalo no visible,
            // los colores deben estar apagados.
            if (dut.activevideo === 1'b0) begin
                if ({R, G, B} !== 6'b000000)
                    $fatal(1, "Error de intervalo VGA");
            end

        end

    end

endmodule
