// Forma el candidato de fault de ID; su confirmación pertenece al arbitraje.
module id_fault_check (
    input  logic                     ifid_valid,
    input  system_pkg::word_t        ifid_pc,
    input  logic                     ifid_fetch_fault_valid,
    input  system_pkg::fault_cause_t ifid_fetch_fault_cause,
    input  logic                     decode_legal,
    output logic                     id_fault_candidate,
    output system_pkg::fault_cause_t id_fault_cause,
    output system_pkg::word_t        id_fault_pc
);
  import system_pkg::*;

  logic illegal_candidate;
  logic fetch_fault_candidate;

  // Solo una instrucción válida puede ser ilegal; los residuos de una burbuja no cuentan.
  assign illegal_candidate = ifid_valid && !decode_legal;

  // Un fault de fetch ocupa IF/ID sin representar una instrucción ejecutable.
  assign fetch_fault_candidate = !ifid_valid && ifid_fetch_fault_valid;
  assign id_fault_candidate    = illegal_candidate || fetch_fault_candidate;

  // Los candidatos son excluyentes; sin candidato, la causa no se consume.
  assign id_fault_cause = illegal_candidate ? FAULT_ILLEGAL_INSTRUCTION : ifid_fetch_fault_cause;

  // El PC identifica la entrada de IF/ID que originó el candidato.
  assign id_fault_pc = ifid_pc;
endmodule
