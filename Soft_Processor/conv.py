import os
import sys
try:
    c_file=sys.argv[1]
except:
    c_file=raw_input("input_filename : ")
filed="test"
#os.system('make')

os.system('riscv64-unknown-elf-objdump -d RISCV_Test_Benchmark.elf > test.txt')
os.system('riscv64-unknown-elf-objdump -s  RISCV_Test_Benchmark.elf > data.txt')
x=open(str(filed)+".txt","r")
data=open("data.txt","r")
out=open(filed+"_hex.txt","w")
out=open(filed+"_hex.txt","w")
out1=open(filed+"_pc_reset.txt","w")
out2=open("data_hex.txt","w")
y= x.readlines()
datas=data.readlines()
go=0
for i in y:
    if ((len(i)>2)):
        if ((":" in i.split()[0]) and (i.split()[0][0:-1].isalnum()) and "file" not in i):
            

            out.write(i.split()[1]+"\n")
            out1.write(str(hex(go))+" "+i.split(":")[1])
            go=go+4;
         #   print i
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
#print addr_array

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
    
##for i in xrange (2**14-len(y)+1):
##    if (1):
##        if (1):
##            out.write("0"+"\n")
##            out1.write(#str(go)+" "+
##                       str(hex(go))+" "+"0\n")
##            go=go+4;
##           

             
out.close()
out1.close()
out2.close()
