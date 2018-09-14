import os
import sys
# try:
# except:
# 	filename='new_test.c'
filename=str(sys.argv[1])

os.system('riscv64-unknown-elf-gcc '+filename+' -o K_1.elf -nostartfiles -march=rv32im -mabi=ilp32 -Xlinker -T"link.ld"');

os.system('riscv64-unknown-elf-objcopy K_1.elf -O verilog g.hex');

os.system('riscv64-unknown-elf-objdump -d K_1.elf -d >  test.txt');
