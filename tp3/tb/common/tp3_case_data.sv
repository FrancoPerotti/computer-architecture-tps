// Lector de los datos externos de cada caso, exclusivo de simulación.
module tp3_case_data #(
    // Límite de registros que pueden cargarse en las tablas del lector.
    parameter integer MAX_RECORDS = 65536
);
  string  paths        [];
  string  kinds        [];
  string  texts        [];
  integer record_count;
  bit     loaded = 0;
  string  case_id;

  // Convierte un dígito hexadecimal a entero; rechaza caracteres inválidos.
  function automatic integer hex_digit(input byte character);
    if (character >= "0" && character <= "9") begin
      hex_digit = character - "0";
    end else if (character >= "a" && character <= "f") begin
      hex_digit = character - "a" + 10;
    end else if (character >= "A" && character <= "F") begin
      hex_digit = character - "A" + 10;
    end else begin
      $fatal(1, "CASE_DATA: invalid hexadecimal character");
      hex_digit = -1;
    end
  endfunction

  // Reconstruye la cadena codificada en hexadecimal; admite el marcador vacío
  // y rechaza bytes NUL o una codificación incompleta.
  function automatic string decode_token(input string token);
    integer index;
    byte    character;
    begin
      decode_token = "";
      if (token != "-") begin
        if (token.len() == 0 || token.len() % 2 != 0) begin
          $fatal(1, "CASE_DATA: invalid hexadecimal token");
        end
        for (index = 0; index < token.len(); index = index + 2) begin
          character = 16 * hex_digit(token[index]) + hex_digit(token[index+1]);
          if (character == 0) $fatal(1, "CASE_DATA: NUL cannot be represented in a string");
          decode_token = {decode_token, character};
        end
      end
    end
  endfunction

  // Busca el índice de una ruta; falla si los datos no se cargaron o la ruta no existe.
  function automatic integer find(input string path);
    integer index;
    begin
      if (!loaded) $fatal(1, "CASE_DATA: call load() before accessing data");
      find = -1;
      for (index = 0; index < record_count; index = index + 1) begin
        if (paths[index] == path) find = index;
      end
      if (find == -1) $fatal(1, "CASE_DATA: missing path %s", path);
    end
  endfunction

  // Devuelve el tipo JSON del registro identificado por la ruta.
  function automatic string get_type(input string path);
    get_type = kinds[find(path)];
  endfunction

  // Devuelve la representación textual del valor, conservando su contenido original.
  function automatic string get_text(input string path);
    get_text = texts[find(path)];
  endfunction

  // Devuelve una cadena y rechaza registros de otro tipo.
  function automatic string get_string(input string path);
    if (get_type(path) != "string") $fatal(1, "CASE_DATA: expected string at %s", path);
    get_string = get_text(path);
  endfunction

  // Interpreta un entero decimal con signo y comprueba el rango de 64 bits
  // antes de acumular cada dígito para evitar desbordamientos.
  function automatic longint signed parse_integer(input string text_value);
    integer          index;
    integer          digit;
    bit              negative;
    longint unsigned magnitude;
    longint unsigned limit;
    begin
      negative  = (text_value.len() > 0 && text_value[0] == "-");
      index     = negative ? 1 : 0;
      magnitude = 0;
      limit     = negative ? 64'h8000000000000000 : 64'h7fffffffffffffff;
      if (index == text_value.len()) $fatal(1, "CASE_DATA: empty integer");
      for (; index < text_value.len(); index = index + 1) begin
        digit = text_value[index] - "0";
        if (digit < 0 || digit > 9) $fatal(1, "CASE_DATA: invalid decimal integer %s", text_value);
        if (magnitude > (limit - digit) / 10) begin
          $fatal(1, "CASE_DATA: integer exceeds signed 64-bit range: %s", text_value);
        end
        magnitude = magnitude * 10 + digit;
      end
      parse_integer = negative ? -$signed(magnitude) : $signed(magnitude);
    end
  endfunction

  // Lee un entero de 64 bits con signo; rechaza un tipo o valor incompatible.
  function automatic longint signed get_integer(input string path);
    if (get_type(path) != "integer") $fatal(1, "CASE_DATA: expected integer at %s", path);
    get_integer = parse_integer(get_text(path));
  endfunction

  // Lee un booleano y exige que su representación sea true o false.
  function automatic bit get_boolean(input string path);
    string value;
    begin
      if (get_type(path) != "boolean") $fatal(1, "CASE_DATA: expected boolean at %s", path);
      value = get_text(path);
      if (value != "true" && value != "false") $fatal(1, "CASE_DATA: invalid boolean at %s", path);
      get_boolean = (value == "true");
    end
  endfunction

  // Lee un real y rechaza tipos incorrectos o texto que no pueda interpretarse completo.
  function automatic real get_real(input string path);
    string  value;
    byte    extra;
    real    parsed;
    integer scanned;
    begin
      if (get_type(path) != "real") $fatal(1, "CASE_DATA: expected real at %s", path);
      value   = get_text(path);
      scanned = $sscanf(value, "%f%c", parsed, extra);
      if (scanned != 1) $fatal(1, "CASE_DATA: invalid real at %s", path);
      get_real = parsed;
    end
  endfunction

  // Indica si el registro de la ruta contiene el valor JSON null.
  function automatic bit is_null(input string path);
    is_null = (get_type(path) == "null");
  endfunction

  // Obtiene la cantidad de elementos de un objeto o array y valida su rango.
  function automatic integer get_size(input string path);
    string         kind;
    longint signed size;
    begin
      kind = get_type(path);
      if (kind != "array" && kind != "object") begin
        $fatal(1, "CASE_DATA: expected array or object at %s", path);
      end
      size = parse_integer(get_text(path));
      if (size < 0 || size >= record_count) begin
        $fatal(1, "CASE_DATA: invalid collection size at %s", path);
      end
      get_size = size;
    end
  endfunction

  // Carga el archivo recibido por plusargs; valida formato, rutas únicas e ID
  // antes de habilitar las consultas de datos.
  task automatic load;
    integer descriptor;
    integer index;
    integer previous;
    integer scanned;
    string  filename;
    string  header;
    string  encoded_path;
    string  encoded_value;
    string  kind;
    string  trailing;
    begin
      loaded = 0;
      if (!$value$plusargs("CASE=%s", case_id)) $fatal(1, "CASE_DATA: missing +CASE=<case-id>");
      if (!$value$plusargs("CASE_DATA=%s", filename)) begin
        $fatal(1, "CASE_DATA: missing +CASE_DATA=<file>");
      end
      descriptor = $fopen(filename, "r");
      if (descriptor == 0) $fatal(1, "CASE_DATA: cannot open %s", filename);
      scanned = $fscanf(descriptor, "%s %d", header, record_count);
      if (scanned != 2 || header != "TP3_CASE_DATA" || record_count < 1 ||
          record_count > MAX_RECORDS) begin
        $fatal(1, "CASE_DATA: invalid header in %s", filename);
      end
      paths = new[record_count];
      kinds = new[record_count];
      texts = new[record_count];
      for (index = 0; index < record_count; index = index + 1) begin
        scanned = $fscanf(descriptor, "%s %s %s", encoded_path, kind, encoded_value);
        if (scanned != 3) $fatal(1, "CASE_DATA: incomplete record %0d", index);
        if (kind != "object" && kind != "array" && kind != "string" && kind != "integer" &&
            kind != "real" && kind != "boolean" && kind != "null") begin
          $fatal(1, "CASE_DATA: unknown type %s", kind);
        end
        paths[index] = decode_token(encoded_path);
        kinds[index] = kind;
        texts[index] = decode_token(encoded_value);
        if (kind == "null" && texts[index] != "") $fatal(1, "CASE_DATA: null record has a value");
        for (previous = 0; previous < index; previous = previous + 1) begin
          if (paths[previous] == paths[index]) begin
            $fatal(1, "CASE_DATA: duplicate path %s", paths[index]);
          end
        end
      end
      scanned = $fscanf(descriptor, "%s", trailing);
      if (scanned > 0 || !$feof(descriptor)) $fatal(1, "CASE_DATA: trailing data in %s", filename);
      $fclose(descriptor);
      loaded = 1;
      if (get_type("") != "object" || get_string("/id") != case_id) begin
        $fatal(1, "CASE_DATA: file does not match case %s", case_id);
      end
    end
  endtask
endmodule
