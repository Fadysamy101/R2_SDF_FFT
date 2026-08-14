package fft_sequences_pkg;

    import uvm_pkg::*;
    import fft_cfg_pkg::*;
    import fft_wrapper_sequence_item::*;
    `include "uvm_macros.svh"

    class fft_matlab_seq extends uvm_sequence #(fft_wrapper_seq_item);

        `uvm_object_utils(fft_matlab_seq)

        string input_re_file = "../../System_modeling/vectors/input_re.hex";
        string input_im_file = "../../System_modeling/vectors/input_im.hex";
        function new(string name = "fft_matlab_seq");
            super.new(name);
        endfunction

        task body();

            fft_wrapper_seq_item item;

            int fd_re;
            int fd_im;
            int status_re;
            int status_im;

            logic signed [DATA_WIDTH-1:0] re_from_file;
            logic signed [DATA_WIDTH-1:0] im_from_file;

            fd_re = $fopen(input_re_file, "r");
            fd_im = $fopen(input_im_file, "r");

            if (fd_re == 0) begin
                `uvm_fatal("MATLAB_SEQ",
                    $sformatf("Could not open real input file: %s",
                              input_re_file))
            end

            if (fd_im == 0) begin
                `uvm_fatal("MATLAB_SEQ",
                    $sformatf("Could not open imaginary input file: %s",
                              input_im_file))
            end

            `uvm_info("MATLAB_SEQ",
                $sformatf("Reading real input file: %s", input_re_file),
                UVM_LOW)

            `uvm_info("MATLAB_SEQ",
                $sformatf("Reading imaginary input file: %s", input_im_file),
                UVM_LOW)

            while (!$feof(fd_re) && !$feof(fd_im)) begin

                status_re = $fscanf(fd_re, "%h\n", re_from_file);
                status_im = $fscanf(fd_im, "%h\n", im_from_file);

                if (status_re != 1 || status_im != 1)
                    continue;

                item = fft_wrapper_seq_item::type_id::create("item");

                start_item(item);

                item.rst_n = 1'b1;
                item.en    = 1'b1;

                item.in_re = re_from_file;
                item.in_im = im_from_file;

                finish_item(item);

                `uvm_info("MATLAB_SEQ",
                    $sformatf("Driving input: re=%0d im=%0d",
                              re_from_file,
                              im_from_file),
                    UVM_HIGH)
            end

            $fclose(fd_re);
            $fclose(fd_im);

            `uvm_info("MATLAB_SEQ",
                "Finished reading MATLAB input files",
                UVM_LOW)

        endtask

    endclass

endpackage