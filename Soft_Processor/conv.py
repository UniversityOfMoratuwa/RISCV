import os
import sys

try:
    c_file=sys.argv[1]
except:
    c_file=raw_input("input_filename : ")

#os.system('make clean')
#os.system('make')


os.system('riscv64-unknown-elf-objdump -s  RISCV_Test_Benchmark.elf > data.txt')

data=open("data.txt","r")

out2=open("data_hex.txt","w")

datas=data.readlines()
go=0

addr_array=[]
dat_array=[]
for dat in datas:
    dats=dat.split()
    try: 
        addr_array.append(int("0x"+str(dats.pop(0)),16))
        while (len(dats)>4):
            dats.pop(-1)
        for vals in dats:
            x=int(vals,16)
            dat_array.append(vals)
                
    except:
        pass
i=0
j=0
try:
    while (i<addr_array[j]):
        out2.write("00000000\n")
        i=i+4
    for values in dat_array:
        valt=""
        if(len(values)):
            for i in range(4):
                valt = valt+ values[(3-i)*2:(3-i)*2+2]
            out2.write(valt+"\n")
        else:
            out2.write("00000000\n")
                    
except:
    pass
out2.close()
