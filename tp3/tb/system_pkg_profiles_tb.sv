`timescale 1ns / 1ps

module system_pkg_profiles_tb #(
    parameter system_pkg::memory_profile_t MEMORY_PROFILE = system_pkg::REFERENCE,
    parameter integer FORBID_RESOURCES = 0
);
  import system_pkg::*;

  localparam memory_capacity_t IMEM_CAPACITY_BYTES = imem_capacity_bytes(MEMORY_PROFILE);
  localparam memory_capacity_t DMEM_CAPACITY_BYTES = dmem_capacity_bytes(MEMORY_PROFILE);

  tp3_case_data data();

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  if (memory_profile_supported(MEMORY_PROFILE)) begin : supported_profile
    // Este módulo inexistente detecta una elaboración indebida en la prueba negativa.
    if (FORBID_RESOURCES) begin : forbidden_resources
      profile_resource_must_not_be_elaborated unexpected_resource();
    end

    initial begin
      data.load();
      if ((MEMORY_PROFILE === REFERENCE && data.get_string("/inputs/profile") != "REFERENCE") ||
          (MEMORY_PROFILE === ALT_1000 && data.get_string("/inputs/profile") != "ALT_1000"))
        fail("selected profile differs from manifest");
      if ($bits(IMEM_CAPACITY_BYTES) != 64 || $bits(DMEM_CAPACITY_BYTES) != 64)
        fail("capacities must have 64 bits");
      if (memory_capacity_t'(-1) <= 0)
        fail("capacities must be unsigned");
      if (IMEM_CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/IMEM_C")))
        fail("IMEM capacity differs from manifest");
      if (DMEM_CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/DMEM_C")))
        fail("DMEM capacity differs from manifest");
      if (memory_profile_diagnostic(MEMORY_PROFILE) != "")
        fail("supported profile has a diagnostic");
      $display("PASS %s", data.case_id);
      $finish;
    end
  end else begin : unsupported_profile
    initial begin
      data.load();
      if (IMEM_CAPACITY_BYTES !== 64'd0 || DMEM_CAPACITY_BYTES !== 64'd0)
        fail("unsupported profile returned a capacity");
      if (memory_profile_diagnostic(MEMORY_PROFILE) != data.get_string("/expected/diagnostic"))
        fail("unexpected diagnostic");
      $display("REJECT %s %s", data.case_id, memory_profile_diagnostic(MEMORY_PROFILE));
      $fatal(1, "%s", memory_profile_diagnostic(MEMORY_PROFILE));
    end
  end
endmodule
