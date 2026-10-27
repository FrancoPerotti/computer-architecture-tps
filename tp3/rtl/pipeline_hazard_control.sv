// Selecciona la acción del ciclo a partir de candidatos y condiciones ya calculados.
module pipeline_hazard_control (
    input  logic cpu_cycle_fire,
    input  logic drain_mode,
    input  logic ex_fault_candidate,
    input  logic ex_halt_candidate,
    input  logic redirect_requested,
    input  logic id_fault_candidate,
    input  logic load_use_stall,
    output logic act_ex_fault,
    output logic act_halt,
    output logic act_redirect,
    output logic act_id_fault,
    output logic act_load_use,
    output logic act_normal,
    output logic act_drain_load_use,
    output logic act_drain_advance
);
  always_comb begin
    // Sin ciclo efectivo no se aplica ninguna acción, tampoco durante HOLD.
    act_ex_fault       = 1'b0;
    act_halt           = 1'b0;
    act_redirect       = 1'b0;
    act_id_fault       = 1'b0;
    act_load_use       = 1'b0;
    act_normal         = 1'b0;
    act_drain_load_use = 1'b0;
    act_drain_advance  = 1'b0;

    if (cpu_cycle_fire) begin
      if (drain_mode) begin
        // El contexto de drain selecciona exclusivamente una de sus dos ramas.
        if (load_use_stall) begin
          act_drain_load_use = 1'b1;
        end else begin
          act_drain_advance = 1'b1;
        end
      end else if (ex_fault_candidate) begin
        // Los eventos de EX preceden a los de ID; el fault propio domina en EX.
        act_ex_fault = 1'b1;
      end else if (ex_halt_candidate) begin
        act_halt = 1'b1;
      end else if (redirect_requested) begin
        act_redirect = 1'b1;
      end else if (id_fault_candidate) begin
        act_id_fault = 1'b1;
      end else if (load_use_stall) begin
        act_load_use = 1'b1;
      end else begin
        // El avance normal es la selección por defecto del ciclo ordinario.
        act_normal = 1'b1;
      end
    end
  end
endmodule
