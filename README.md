# FP32 Floating-Point Multiply-Accumulate (FP-MAC)

A modular Verilog implementation of a sequential single-precision floating-point
multiply-accumulate unit. The repository currently contains the RTL source files
and preliminary simulation/physical-design notes. A LibreLane run is planned.

## RTL modules

- `fp_mac.v` — top-level MAC controller and accumulator
- `fp_decoder.v` — floating-point operand decoder
- `fp_multiplier.v` — multiplier control/datapath
- `shift_add_multiplier.v` — shift-add multiplication datapath
- `fp_adder.v` — floating-point alignment and addition
- `fp_norm_pack.v` — normalization and result packing

## Functional verification

The current directed testbench run reported **30 passed, 0 failed** for the tested
cases, including normal arithmetic, accumulation, cancellation, zero, subnormal,
infinity, NaN, and overflow cases.

This is directed testing, not exhaustive verification and not proof of complete
IEEE 754 compliance.

Add your actual testbench source as `tb/tb_fp_mac.v` before publishing the repository.
The testbench was not included in the uploaded source files used to prepare this starter package.

## Preliminary physical-design baseline

The following values were copied from the reported implementation run:

- Target clock period: 10 ns (100 MHz target)
- Worst synchronous setup slack: +0.31 ns
- Reported design area: 244,691 µm²
- Reported utilization: 74%
- Reported estimated total power: 373 mW
- Critical path: `acc[12]` to `ADD0.a_aligned[26]`

These results are specific to one run and its constraints, libraries, tool versions,
and power-analysis assumptions. The setup margin is small. The power number should
not be compared against other runs unless the power settings and activity assumptions
are consistent. See `reports/physical_design_baseline.txt`.

The layout screenshot is provided as visual evidence only; it does not establish
DRC/LVS cleanliness.

## Planned work

- Run a reproducible LibreLane RTL-to-GDSII flow
- Record exact tool versions and configuration
- Review routed timing and setup/hold checks
- Run and document DRC and LVS
- Re-evaluate area and power under documented assumptions
- Expand directed and corner-case verification

## Repository contents

- `rtl/` — RTL source files
- `tb/` — place the testbench here
- `reports/` — current baseline notes
- `images/` — layout screenshot

## License

No license has been selected yet. Add a license only after deciding how you want others
to use and redistribute this project.
