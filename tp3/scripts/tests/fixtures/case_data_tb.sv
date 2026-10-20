module case_data_tb;
    tp3_case_data data();
    string probe;
    longint signed ignored;
    logic signed [63:0] a, b;
    wire signed [63:0] result = a + b;

    initial begin
        data.load();
        if (!$value$plusargs("PROBE=%s", probe))
            probe = "normal";
        if (probe == "missing")
            ignored = data.get_integer("/inputs/missing");
        else if (probe == "wrong_type")
            ignored = data.get_integer("/inputs/label");
        else if (probe == "overflow")
            ignored = data.get_integer("/inputs/overflow");
        else if (probe == "platform") begin
            if (data.get_integer("/inputs/C") != 64'd4294967296 ||
                data.get_integer("/expected/CAPACITY_INCLUSIVE_WIDTH") != 33)
                $fatal(1, "platform data was truncated or changed");
        end else begin
            a = data.get_integer("/inputs/a");
            b = data.get_integer("/inputs/b");
            #1;
            assert (result === data.get_integer("/expected/result"))
                else $fatal(1, "CASE_DATA_CHECK %s: result does not match JSON expectation", data.case_id);
            if (data.get_integer("/inputs/minimum") != 64'sh8000000000000000 ||
                data.get_integer("/inputs/maximum") != 64'sh7fffffffffffffff)
                $fatal(1, "signed integer boundaries changed");
            if (!data.get_boolean("/inputs/enabled") || data.get_boolean("/inputs/disabled"))
                $fatal(1, "boolean data changed");
            if (!data.is_null("/expected/nothing") || data.is_null("/inputs/a"))
                $fatal(1, "null data changed");
            if (data.get_string("/inputs/label") != "Español\ncon espacios\ty comillas \"" ||
                data.get_string("/inputs/empty") != "" ||
                data.get_string("/inputs/a~1b/~0key") != "00xZ")
                $fatal(1, "string or escaped JSON Pointer changed");
            if (data.get_size("/inputs/items") != 3 ||
                data.get_integer("/inputs/items/0") != -7 ||
                data.get_size("/inputs/items/1") != 0 ||
                data.get_size("/inputs/items/2") != 0 ||
                data.get_size("/inputs/a~1b") != 1)
                $fatal(1, "array or object data changed");
            if (data.get_real("/expected/ratio") < 1.249999 ||
                data.get_real("/expected/ratio") > 1.250001)
                $fatal(1, "real data changed");
        end
        $display("CASE_DATA_OK %s", data.case_id);
        $finish;
    end
endmodule
