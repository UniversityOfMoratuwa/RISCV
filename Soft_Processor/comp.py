import os
#os.system('riscv64-unknown-elf-gcc new_test.c -o K_1.elf -nostartfiles -march=rv32i -mabi=ilp32 -Xlinker -T"link.ld"');

os.system('riscv64-unknown-elf-objcopy RISCV_Test_Benchmark.elf -O verilog g.hex');

os.system('riscv64-unknown-elf-objdump -d RISCV_Test_Benchmark.elf -d >  test.txt');
