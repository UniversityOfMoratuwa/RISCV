import os
import sys
# try:
# except:
# 	filename='new_test.c'
filename=str(sys.argv[1])

os.system('riscv64-unknown-elf-gcc '+filename+' -s -o K_1.elf -nostartfiles -march=rv32g -mabi=ilp32 -fPIC');

os.system('riscv64-unknown-elf-objcopy K_1.elf  -O verilog g.hex');
os.system('riscv64-unknown-elf-objdump  K_1.elf -d >  test.txt');
mile = open('g.hex','r')
out = open('data_hex.txt','w')
lines= mile.readlines()

int_addr=int(lines.pop(0)[1:],16)
curr_addr= 0
mem=[]

for i in xrange (1<<22):
	mem.append(["00","00","00","00"])


for val in lines:
	if ('@' not in val):
		vals=val.split()
		for value in vals:
			mem[curr_addr>>2][3-(curr_addr & 0b11)] = value
			if ((curr_addr%4)==0):
				pass #print hex(curr_addr),mem[curr_addr>>2]
			curr_addr = curr_addr + 1
		
	else:
		curr_addr = int(val[1:],16) - int_addr
		# print hex(curr_addr)






for i in xrange (1<<22):
	out.write(''.join(mem[i])+'\n')