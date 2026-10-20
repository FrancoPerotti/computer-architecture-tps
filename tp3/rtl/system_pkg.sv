package system_pkg;
  // Identificadores de elaboración; no son códigos del protocolo UART.
  typedef logic [31:0] memory_profile_t;
  typedef longint unsigned memory_capacity_t;

  localparam memory_profile_t REFERENCE = 32'd0;
  localparam memory_profile_t ALT_1000  = 32'd1;

  localparam memory_capacity_t REFERENCE_IMEM_CAPACITY_BYTES = 64'd1024;
  localparam memory_capacity_t REFERENCE_DMEM_CAPACITY_BYTES = 64'd2048;
  localparam memory_capacity_t ALT_1000_IMEM_CAPACITY_BYTES  = 64'd1000;
  localparam memory_capacity_t ALT_1000_DMEM_CAPACITY_BYTES  = 64'd1000;

  localparam CONFIG_UNSUPPORTED = "CONFIG_UNSUPPORTED";

  function automatic bit memory_profile_supported(input memory_profile_t profile);
    case (profile)
      REFERENCE, ALT_1000: memory_profile_supported = 1'b1;
      default:            memory_profile_supported = 1'b0;
    endcase
  endfunction

  function automatic memory_capacity_t imem_capacity_bytes(input memory_profile_t profile);
    case (profile)
      REFERENCE: imem_capacity_bytes = REFERENCE_IMEM_CAPACITY_BYTES;
      ALT_1000:  imem_capacity_bytes = ALT_1000_IMEM_CAPACITY_BYTES;
      // El consumidor debe rechazar el perfil antes de elaborar recursos.
      default:   imem_capacity_bytes = 64'd0;
    endcase
  endfunction

  function automatic memory_capacity_t dmem_capacity_bytes(input memory_profile_t profile);
    case (profile)
      REFERENCE: dmem_capacity_bytes = REFERENCE_DMEM_CAPACITY_BYTES;
      ALT_1000:  dmem_capacity_bytes = ALT_1000_DMEM_CAPACITY_BYTES;
      default:   dmem_capacity_bytes = 64'd0;
    endcase
  endfunction

  function automatic string memory_profile_diagnostic(input memory_profile_t profile);
    if (memory_profile_supported(profile))
      memory_profile_diagnostic = "";
    else
      memory_profile_diagnostic = CONFIG_UNSUPPORTED;
  endfunction
endpackage
