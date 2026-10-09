# FP32 Floating-Point Multiply-Accumulate (FP-MAC)

A modular, sequential floating-point MAC designed in Verilog HDL, implementing a datapath for single-precision IEEE 754 arithmetic.

The design computes:

$$
acc \leftarrow \operatorname{round}(acc + a \times b)
$$

Rather than treating multiplication and addition as black-box operators, I built the datapath from separate arithmetic modules, including a shift-add multiplier, exponent alignment logic, extended-precision addition, and a normalization and rounding stage.

The project focuses on understanding and implementing floating-point arithmetic at the RTL level, with an emphasis on datapath organization, control sequencing, numerical corner cases, and physical implementation.

## Architecture

![FP-MAC Architecture](images/fp_mac_architecture.png)

The design is organized into five main stages.

### 1. Operand decoding

`fp_decoder.v`

Each 32-bit operand is decoded into its sign, internal exponent, and significand. The decoder also identifies special values such as zero, infinity, and NaN.

Subnormal inputs require additional handling because they do not have the implicit leading 1 used by normal floating-point numbers. The decoder normalizes their significands internally while adjusting their exponents.

### 2. Sequential multiplication

`fp_multiplier.v` and `shift_add_multiplier.v`

The multiplier operates on two 24-bit significands, including the implicit leading bit for normal operands.

Instead of using a single combinational multiplication operator, the design uses an iterative shift-add datapath:

- A 24-bit multiplier controls conditional accumulation.
- The multiplicand is shifted left between iterations.
- The multiplier is shifted right to expose the next bit.
- A 48-bit accumulator retains the product.

The multiplication takes 24 iterations. This approach makes the arithmetic operation explicit at the RTL level and trades execution latency for a simpler, iterative datapath.

The product sign and exponent are calculated separately from the significand multiplication.

### 3. Exponent alignment and addition

`fp_adder.v`

The product must be aligned with the current accumulator value before addition or subtraction.

The adder compares the operand exponents, shifts the operand with the smaller exponent, and preserves information about discarded bits using shift-right-with-jamming logic.

The arithmetic stage then performs:

- Addition when both operands have the same sign.
- Subtraction when their signs differ.
- Magnitude comparison to determine the result sign after subtraction.
- Extended-width arithmetic to retain carry and rounding information.

The aligned operands use a 51-bit internal representation, and the adder produces a 52-bit result.

### 4. Normalization, rounding and packing

`fp_norm_pack.v`

The arithmetic result is converted back into a 32-bit floating-point representation.

This stage handles:

- Left and right normalization shifts.
- Exponent adjustment during normalization.
- Subnormal result generation.
- Guard and sticky information for rounding.
- Round-to-nearest, ties-to-even (RNE).
- Exponent overflow and infinity generation.
- Final sign, exponent, and fraction packing.

Keeping normalization and rounding separate from the adder makes these operations easier to understand, verify, and modify independently.

### 5. Accumulator and control

`fp_MAC.v`

The top-level module coordinates the arithmetic stages using a finite-state machine.

The controller sequences the operation through:

`IDLE → CHECK → MUL → ADD → NORM → DONE`

The accumulator stores the result of each completed operation and feeds it back into the adder for the next operation.

The design also includes:

- Input registers to capture operands when a transaction starts.
- Start/done handshaking between the arithmetic modules.
- Special-case bypass logic for results that do not require the normal arithmetic path.
- An accumulator-clear control.
- A completion signal indicating that the result has been committed.

This organization separates control sequencing from the arithmetic datapath.

## Design decisions

These are some of the important implementation choices behind the design.

### Iterative multiplication instead of a combinational multiplier

The significand multiplier is implemented using shift-add arithmetic rather than relying on a single `*` operator.

This makes the multiplication process explicit and provides a useful basis for studying register-transfer-level arithmetic, control logic, and area-versus-latency trade-offs.

The trade-off is a longer execution time compared with a sufficiently parallel multiplier.

### Preserve the product before final rounding

The multiplier retains the full 48-bit significand product instead of immediately reducing it to a 24-bit significand.

The product is then combined with the accumulator in an extended-precision representation before the final normalization and rounding stage.

The intended arithmetic behavior is:

$$
acc_{\text{new}} = \operatorname{RN}(acc + a \times b)
$$

where RN denotes round-to-nearest, ties-to-even.

This avoids introducing a separate FP32 rounding step immediately after multiplication. Full IEEE 754 fused-operation equivalence still requires verification across rounding, subnormal, overflow, and special-value cases.

### Explicit handling of floating-point corner cases

Floating-point arithmetic is not limited to ordinary positive and negative numbers.

The design includes special-case detection and handling for zero, infinity, NaN, and subnormal operands or results.

It also handles cancellation during subtraction, where leading significand bits may become zero and additional normalization is required.

### Extended precision and sticky-bit handling

Exponent alignment can discard low-order bits. Simply shifting an operand right would lose information that may affect the final rounded result.

The adder therefore uses shift-right-with-jamming logic to preserve whether any discarded bit was nonzero.

The final rounding stage uses guard and sticky information, together with the least significant retained bit, to implement round-to-nearest, ties-to-even.

## Functional verification

The design has been tested using a self-checking Verilog testbench.

The current directed testbench run reported:

| Metric | Result |
|---|---:|
| Passed test cases | 30 |
| Failed test cases | 0 |

The tested cases include:

- Normal floating-point arithmetic.
- Repeated multiply-accumulate operations.
- Positive and negative operands.
- Cancellation and zero results.
- Subnormal values.
- Infinity and NaN cases.
- Overflow and rounding-related cases.

These results represent the tested cases only. They do not establish exhaustive correctness or complete IEEE 754 compliance.

The testbench and its execution instructions will be maintained alongside the RTL so that the results can be reproduced.

## Physical design

The RTL has also been taken through a preliminary physical-design run.

The current baseline is:

| Parameter | Reported result |
|---|---:|
| Target clock period | 10 ns |
| Target frequency | 100 MHz |
| Worst synchronous setup slack | +0.31 ns |
| Reported design area | 244,691 µm² |
| Reported utilization | 74% |
| Reported estimated total power | 373 mW |

These values are from a specific implementation run and depend on its constraints, technology libraries, tool configuration, and analysis assumptions.

The positive setup slack indicates that the reported run met its setup requirement, but the margin is small. Further timing optimization and repeatable physical-design analysis are needed before drawing stronger conclusions about performance.

The reported power is an estimate and should not be treated as a technology-independent measurement.

The current critical path was reported from `acc[12]` to `ADD0.a_aligned[26]`. This provides a starting point for investigating the accumulator-to-adder path and the cost of exponent alignment.

The physical-design results are preliminary. DRC and LVS cleanliness must be established separately and documented before claiming a fully verified layout.

## Current limitations and next steps

The design is an ongoing hardware implementation project. The main areas for further work are:

- Complete and document a reproducible LibreLane RTL-to-GDSII flow.
- Run and review DRC and LVS.
- Investigate the critical timing path and improve setup margin.
- Reassess area and power using documented analysis settings.
- Expand verification using independent reference calculations and additional corner cases.
- Evaluate the numerical behavior of subnormal results, rounding boundaries, and exceptional operations against an IEEE 754 reference.
- Document supported operations, rounding behavior, and exceptional-result handling more precisely.

The current architecture prioritizes clarity of the arithmetic datapath and explicit control over minimum latency.

## Repository structure

```text
fp-mac/
├── rtl/
│   ├── fp_MAC.v
│   ├── fp_decoder.v
│   ├── fp_multiplier.v
│   ├── shift_add_multiplier.v
│   ├── fp_adder.v
│   └── fp_norm_pack.v
├── tb/
│   └── tb_fp_mac.v
├── images/
│   └── fp_mac_architecture.png
├── reports/
│   └── physical_design_baseline.txt
└── README.md
```

## Tools

- Verilog HDL
- Icarus Verilog
- GTKWave
- LibreLane
- OpenROAD
- Sky130 / GF180 MCU PDKs, as applicable to individual runs

## License

No license has been selected yet.
