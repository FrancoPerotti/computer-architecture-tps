package runner_smoke_pkg;
  // Suma usada para verificar la importación del paquete y el orden de compilación.
  function automatic longint signed add(input longint signed a, input longint signed b);
    add = a + b;
  endfunction
endpackage
