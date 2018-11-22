# -*- coding: utf-8 -*-
import os
import struct
import sys
from time import sleep
from time import time
import platform

# create a GUI variable called app
filename="RISCV_Test_Benchmark.hex"
#filename=str(sys.argv[1])
#os.system('make clean')
#os.system('make all')
#os.system('python comp.py '+filename)
# os.system('python conv.py xx')

if( platform.system()=='Windows'):
    import msvcrt
else:
    import getch

reg_array = []

memory = []
fifo_addr = 'e0001030'
mem_size = 24
#PC = int('00010000', 16) / 4
PC = (int('0000000', 16) / 4 )

opcode = {
    '0110111': 'lui',
    '0010111': 'auipc',
    '1101111': 'jump',
    '1100111': 'jumpr',
    '1100011': 'cjump',
    '0000011': 'load',
    '0100011': 'store',
    '0010011': 'iops',
    '0110011': 'rops',
    '1110011': 'system',
    '0001111': 'fenc',
    '0111011': 'rops',
    # '0000000': 'uimp',
    '0101111': 'amo',
    '0000111': 'f1',
    '0100111' : 'f2',
    '1000011' : 'f3',
    '1000011' :'f4',
    '1001011' :'f5',
    '1001111':'f6',
    '1010011':'f7'
    }

csr_file = {
'0x342': 'mcause', 
'0x343': 'mtval', 
'0x340': 'mscratch', 
'0x341': 'mepc', 
'0x344': 'mip', 
'0x7A3': 'tdata3', 
'0x104': 'sie', 
'0xC14': 'hpmcounter20', 
'0xC17': 'hpmcounter23', 
'0x041': 'uepc', 
'0x040': 'uscratch', 
'0x043': 'utval', 
'0x042': 'ucause', '0x044': 'uip', '0x100': 'sstatus', '0x102': 'sedeleg', '0x103': 'sideleg', '0x3A1': 'pmpcfg1', '0x3A0': 'pmpcfg0', '0x3A3': 'pmpcfg3', '0x3A2': 'pmpcfg2', '0x180': 'satp', '0xC0F': 'hpmcounter15', '0xC0D': 'hpmcounter13', '0xC0E': 'hpmcounter14', '0xC0B': 'hpmcounter11', '0xC0C': 'hpmcounter12', '0xC0A': 'hpmcounter10', '0x328': 'mhpmevent8', '0xC8F': 'hpmcounter15h', '0xC8D': 'hpmcounter13h', '0xC8E': 'hpmcounter14h', '0xC8B': 'hpmcounter11h', '0xC8C': 'hpmcounter12h', '0xC8A': 'hpmcounter10h', '0xC99': 'hpmcounter25h', '0xC98': 'hpmcounter24h', '0xC95': 'hpmcounter21h', '0xC94': 'hpmcounter20h', '0xC97': 'hpmcounter23h', '0xC96': 'hpmcounter22h', '0xC91': 'hpmcounter17h', '0xC90': 'hpmcounter16h', '0xC93': 'hpmcounter19h', '0xC92': 'hpmcounter18h', '0xC15': 'hpmcounter21', '0x105': 'stvec', '0x106': 'scounteren', '0xC16': 'hpmcounter22', '0xC11': 'hpmcounter17', '0xC10': 'hpmcounter16', '0xC13': 'hpmcounter19', '0xC12': 'hpmcounter18', '0xC19': 'hpmcounter25', '0xC18': 'hpmcounter24', '0xC1E': 'hpmcounter30', '0xC1D': 'hpmcounter29', '0xC1F': 'hpmcounter31', '0xC1A': 'hpmcounter26', '0xC1C': 'hpmcounter28', '0xC1B': 'hpmcounter27', '0x005': 'utvec', '0x004': 'uie', '0x7A1': 'tdata1', '0x001': 'fflags', '0x000': 'ustatus', '0x003': 'fcsr', '0x002': 'frm', '0xC9E': 'hpmcounter30h', '0xC9D': 'hpmcounter29h', '0xC9F': 'hpmcounter31h', '0xC9A': 'hpmcounter26h', '0xC9C': 'hpmcounter28h', '0xC9B': 'hpmcounter27h', '0xC88': 'hpmcounter8h', '0xC89': 'hpmcounter9h', '0xC86': 'hpmcounter6h', '0xC87': 'hpmcounter7h', '0xC84': 'hpmcounter4h', '0xC85': 'hpmcounter5h', '0xC82': 'instreth', '0xC83': 'hpmcounter3h', '0xC80': 'cycleh', '0xC81': 'timeh', '0xC06': 'hpmcounter6', '0xC07': 'hpmcounter7', '0xC04': 'hpmcounter4', '0xC05': 'hpmcounter5', '0xC02': 'instret', '0xC03': 'hpmcounter3', '0xC00': 'cycle', '0xC01': 'time', '0xC08': 'hpmcounter8', '0xC09': 'hpmcounter9', '0x306': 'mcounteren', '0x304': 'mie', '0x305': 'mtvec', '0x302': 'medeleg', '0x303': 'mideleg', '0x300': 'mstatus', '0x301': 'misa', '0x3B8': 'pmpaddr8', '0x3B9': 'pmpaddr9', '0x3B4': 'pmpaddr4', '0x3B5': 'pmpaddr5', '0x3B6': 'pmpaddr6', '0x3B7': 'pmpaddr7', '0x3B0': 'pmpaddr0', '0x3B1': 'pmpaddr1', '0x3B2': 'pmpaddr2', '0x3B3': 'pmpaddr3', '0x7A2': 'tdata2', '0x329': 'mhpmevent9', '0x33C': 'mhpmevent28', '0x33B': 'mhpmevent27', '0x33A': 'mhpmevent26', '0x33F': 'mhpmevent31', '0x33E': 'mhpmevent30', '0x33D': 'mhpmevent29', '0x333': 'mhpmevent19', '0x332': 'mhpmevent18', '0x331': 'mhpmevent17', '0x330': 'mhpmevent16', '0x337': 'mhpmevent23', '0x336': 'mhpmevent22', '0x335': 'mhpmevent21', '0x334': 'mhpmevent20', '0x339': 'mhpmevent25', '0x338': 'mhpmevent24', '0x3BD': 'pmpaddr13', '0x3BE': 'pmpaddr14', '0x3BF': 'pmpaddr15', '0x3BA': 'pmpaddr10', '0x3BB': 'pmpaddr11', '0x3BC': 'pmpaddr12', '0x7B0': 'dcsr', '0x7B1': 'dpc', '0x7B2': 'dscratch', '0x7A0': 'tselect', '0xB9A': 'mhpmcounter26h', '0xB9B': 'mhpmcounter28h', '0xB9D': 'mhpmcounter29h', '0xB9E': 'mhpmcounter30h', '0xB9F': 'mhpmcounter31h', '0x324': 'mhpmevent4', '0x325': 'mhpmevent5', '0x326': 'mhpmevent6', '0x327': 'mhpmevent7', '0x323': 'mhpmevent3', '0xF14': 'mhartid', '0xF11': 'mvendorid', '0xF12': 'marchid', '0xF13': 'mimpid', '0xB1A': 'mhpmcounter26', '0xB1B': 'mhpmcounter28', '0xB1D': 'mhpmcounter29', '0xB1E': 'mhpmcounter30', '0xB1F': 'mhpmcounter31', '0xB09': 'mhpmcounter9', '0xB08': 'mhpmcounter8', '0xB07': 'mhpmcounter7', '0xB06': 'mhpmcounter6', '0xB05': 'mhpmcounter5', '0xB04': 'mhpmcounter4', '0xB03': 'mhpmcounter3', '0xB02': 'minstret', '0xB00': 'mcycle', '0xB87': 'mhpmcounter7h', '0xB86': 'mhpmcounter6h', '0xB85': 'mhpmcounter5h', '0xB84': 'mhpmcounter4h', '0xB83': 'mhpmcounter3h', '0xB82': 'minstreth', '0xB80': 'mcycleh', '0x140': 'sscratch', '0x141': 'sepc', '0x142': 'scause', '0x143': 'stval', '0x144': 'sip', '0xB89': 'mhpmcounter9h', '0xB88': 'mhpmcounter8h', '0xB8F': 'mhpmcounter15h', '0xB8E': 'mhpmcounter14h', '0xB8D': 'mhpmcounter13h', '0xB8B': 'mhpmcounter12h', '0xB8A': 'mhpmcounter10h', '0x32D': 'mhpmevent13', '0x32E': 'mhpmevent14', '0xB0F': 'mhpmcounter15', '0xB0E': 'mhpmcounter14', '0xB0D': 'mhpmcounter13', '0xB0B': 'mhpmcounter12', '0xB0A': 'mhpmcounter10', '0xB18': 'mhpmcounter24', '0xB19': 'mhpmcounter25', '0xB10': 'mhpmcounter16', '0xB11': 'mhpmcounter17', '0xB12': 'mhpmcounter18', '0xB13': 'mhpmcounter19', '0xB14': 'mhpmcounter20', '0xB15': 'mhpmcounter21', '0xB16': 'mhpmcounter22', '0xB17': 'mhpmcounter23', '0xB90': 'mhpmcounter16h', '0xB91': 'mhpmcounter17h', '0xB92': 'mhpmcounter18h', '0xB93': 'mhpmcounter19h', '0xB94': 'mhpmcounter20h', '0xB95': 'mhpmcounter21h', '0xB96': 'mhpmcounter22h', '0xB97': 'mhpmcounter23h', '0xB98': 'mhpmcounter24h', '0xB99': 'mhpmcounter25h', '0x32F': 'mhpmevent15', '0x32A': 'mhpmevent10', '0x32B': 'mhpmevent11', '0x32C': 'mhpmevent12'
}


def convert(i):
    return int(bin(i + 2 ** 32)[-32:])


for i in range(32):
    if i == 2:
        reg_array.append(int('0040000',16))
    elif i == 3:
        reg_array.append(0)
    elif i == 11:
        reg_array.append(int('0x10000',16))
    else:
        reg_array.append(0)

csr_size = 12
csr_mem = []
for i in xrange(1 << csr_size):
    csr_mem.append(0)

for i in xrange(1 << mem_size):
    memory.append(0)
filed = open('data_hex.txt', 'r')

data = filed.readlines()


def rem(num1, num2):
    if num2 == 0:
        return num1
    elif num1 < 0 and num2 > 0:
        return -(-num1 % num2)
    elif num1 > 0 and num2 > 0:
        return num1 % num2
    elif num1 < 0 and num2 < 0:
        return -(-num1 % -num2)
    elif num1 > 0 and num2 < 0:
        return num1 % -num2
    elif num1 == 0:
        return 0


def div(num1, num2):
    if num2 == 0:
        if num1 < 0:
            return 1
        else:
            return -1
    elif num1 < 0 and num2 > 0:
        return -(-num1 / num2)
    elif num1 > 0 and num2 < 0:
        return -(num1 / -num2)
    elif num1 < 0 and num2 < 0:
        return -num1 / -num2
    elif num1 > 0 and num2 > 0:
        return num1 / num2
    elif num1 == 0:
        return 0


def twoscomp32(num):
    if num < 0:
        num = pow(2, 32) + num
    else:
        num = num
    return num


def twoscomp64(num):
    if num < 0:
        num = pow(2, 64) + num
    else:
        num = num
    return num


def usigned(num):
    if num < 0:
        num = num + 1 << 32
    else:
        return num


def signed(num):
    if bin(num)[2] == '1' and len(bin(num)) == 34:
        return num - (1 << 32)
    else:
        return num


for i in range(len(data)):
    memory[i] = int(data[i], 16)


def conv(imm):
    num = int('0b' + imm, 2)
    return num


def byte_extend(num, typ):
    if bin(num)[2] == '1' and len(bin(num)) == 10 and typ == 1:
        return conv('1' * 24 + bin(num)[2:])
    else:
        return conv(bin(num)[2:])


def hword_extend(num, typ):
    if bin(num)[2] == '1' and len(bin(num)) == 18 and typ == 1:
        return conv('1' * 16 + bin(num)[2:])
    else:
        return conv(bin(num)[2:])


def rashift(num, n):

    if bin(num)[2] == '1' and len(bin(num)) == 34:

        return int('1' * n + bin(num)[2:34 - n], 2)
    else:
        return num >> n
##################################CSR Related Variables ###############################
#machine mode specific
mmode          =    0b11
hmode          =    0b10
smode          =    0b01
umode          =    0b00

heip=seip=ueip=htip=stip=utip=hsip=ssip=usip = 0              
meie=heie=seie=ueie=mtie=htie=stie=utie=msie=hsie=ssie=usie = 0
sd=mxr=sum1=mprv=spp=mpie=spie=upie=m_ie=s_ie=u_ie = 0    

curr_privilage = mmode
mpp = 0
mt_base       =0 
mt_mode       =0 
medeleg_reg   =0
mideleg_reg   =0
mcycle_reg    =0
minsret_reg   =0
mir=mtm=mcy   =0
mscratch_reg  =0
mepc_reg      =0
mtval_reg     =0
mecode_reg    =0
minterrupt    =0  


##################################CSR Related Variables End###############################

x = 0
n = 0
pre = 0
cycle = 0
pr = ''
amo_reserve_valid = False
amo_reserve_addr  = 0
try:
    mile = \
        open('/home/riscv_group/Desktop/New/Wingle.sim/sim_1/behav/mem_reads.txt'
             , 'r')
    cile = \
        open('/home/riscv_group/Desktop/New/Wingle.sim/sim_1/behav/clocks.txt'
             , 'r')
    nile = mile.readlines()
    clocks = cile.readlines()

except:
###    print "error"
###    sys.exit(0)
    pass
flag=0

# print hex(memory[int('4005e0',16)/4])
csr_mem[int(csr_file.keys()[csr_file.values().index('mstatus')],16)] = 1<<13
while PC < 1 << 23:
    
    sub = []
    imm = 32 * '0'
    wb_data = 0
    instruction = memory[PC]
    # if (PC*4>= int('400000',16)):
    #     print hex(PC*4),hex(instruction),hex(reg_array[2]),hex(memory[reg_array[2]/4])

    binary = bin(instruction)[2:]
    binary = (32 - len(binary)) * '0' + binary
    rs1_sel = conv(binary[12:17])
    rs2_sel = conv(binary[7:12])
    rd = conv(binary[20:25])
    function = binary[17:20]
    start_fu = binary[0:7]
    lpc = PC
    PC = PC + 1

 # ##########################################lui##################################################

    if opcode[binary[25:32]] == 'lui':
        imm = binary[0:20] + 12 * '0'
        wb_data = conv(imm)
        reg_array[rd] = wb_data
    elif opcode[binary[25:32]] == 'auipc':

 # ###########################################auipc######################################################

        imm = binary[0:20] + 12 * '0'
        wb_data = ((PC - 1) * 4 + conv(imm)) % (1 << 32)
        reg_array[rd] = wb_data
    elif opcode[binary[25:32]] == 'jump':

#######################################jump and link ####################################################

        imm = 12 * binary[0] + binary[12:20] + binary[11] + binary[1:7] \
            + binary[7:11] + '0'
        wb_data = PC * 4
        reg_array[rd] = wb_data
        PC = ((PC - 1) * 4 + conv(imm)) % (1 << 32) / 4
    elif opcode[binary[25:32]] == 'jumpr':

###############################################jump and link register####################################

        imm = 21 * binary[0] + binary[1:12]
        wb_data = PC * 4
        PC = (reg_array[rs1_sel] + conv(imm)) % (1 << 32) / 4
        reg_array[rd] = wb_data
    elif opcode[binary[25:32]] == 'cjump':

#####################################conditional jump####################################################

        branch = 0
        imm = 20 * binary[0] + binary[24] + binary[1:7] + binary[20:24] \
            + '0'

        if function == '000':  # #BEQ
            branch = reg_array[rs1_sel] == reg_array[rs2_sel]
        elif function == '001':

                                   # #BNE

            branch = reg_array[rs1_sel] != reg_array[rs2_sel]
        elif function == '100':

                                   # #BLT

            branch = signed(reg_array[rs1_sel]) \
                < signed(reg_array[rs2_sel])
        elif function == '101':

                                   # #BGE

            branch = signed(reg_array[rs1_sel]) \
                >= signed(reg_array[rs2_sel])
        elif function == '110':

                                   # #BLTU

            branch = reg_array[rs1_sel] < reg_array[rs2_sel]
        elif function == '111':

                                   # #BGEU

            branch = reg_array[rs1_sel] >= reg_array[rs2_sel]
        if branch == 1:
            PC = ((PC - 1) * 4 + conv(imm)) % (1 << 32) / 4
    elif opcode[binary[25:32]] == 'load':

####################################load####################################################################

        imm = 21 * binary[0] + binary[1:12]
        wb_data = (((reg_array[rs1_sel] + conv(imm))) % (1<<mem_size)) 
        wb_prev=(((reg_array[rs1_sel] + conv(imm))) % (1<<32)) 
        if wb_data >= 1 << mem_size:
            print 'out_of_range_memory', hex(lpc * 4), hex(wb_data)
            break
        read_data = memory[wb_data / 4]
        if ((wb_prev!=int('e000102c',16)) and (wb_prev!=int('e0001030',16))):
            if function == '000':
                reg_array[rd] = byte_extend((read_data >> wb_data % 4 * 8)
                        % 256, 1)
            elif function == '001':
                reg_array[rd] = hword_extend((read_data >> wb_data % 4 * 8)
                        % (256 * 256), 1)
            elif function == '010':
                reg_array[rd] = read_data
            elif function == '100':
                reg_array[rd] = byte_extend((read_data >> wb_data % 4 * 8)
                        % 256, 0)
            elif function == '101':

                reg_array[rd] = hword_extend((read_data >> wb_data % 4 * 8)
                        % (256 * 256), 0)
            
        elif (wb_prev==int('e000102c',16)):
##            print 'here1'
            reg_array[rd]=0
        elif  (wb_prev==int('e0001030',16)):
           #  print 'here'
            if( platform.system()=='Windows'):
                reg_array[rd]=ord(msvcrt.getch())
            else:
                reg_array[rd]=ord(getch.getch())
            

        wb_data = wb_prev
    elif opcode[binary[25:32]] == 'store':

  # ######################### store############################################################################

        imm = 21 * binary[0] + binary[1:7] + binary[20:25]
        wb_data = (reg_array[rs1_sel] + conv(imm)) % (1 << mem_size)
        wb_prev =  (reg_array[rs1_sel] + conv(imm)) % (1 << 32)
        sub = []
        if wb_data >= 1 << mem_size:
            print 'out_of_range_memory', hex(lpc * 4), hex(wb_data / 4)
            break
        if (((reg_array[rs1_sel] + conv(imm))%(1<<32))) != int(fifo_addr,16):  # #FIFO ADDRESSS for printf (65872)
            if function == '000':  # #STORE_BYTE
                sub.extend((32 - len(bin(memory[wb_data / 4])[2:]))
                           * '0' + bin(memory[wb_data / 4])[2:])
                sub[8 * (3 - wb_data % 4):8 * (3 - wb_data % 4) + 8] = \
                    (8 - len(bin(reg_array[rs2_sel] % 256)[2:])) * '0' \
                    + bin(reg_array[rs2_sel] % 256)[2:]
                memory[wb_data / 4] = int(''.join(sub), 2)
            elif function == '001':

                                      # #STORE_HALF_WORD

                sub.extend((32 - len(bin(memory[wb_data / 4])[2:]))
                           * '0' + bin(memory[wb_data / 4])[2:])
                if wb_data % 4 == 3:
                    print 'data_missaligned at PC =', hex(lpc * 4)
                    break
                sub[8 * (2 - wb_data % 4):8 * (2 - wb_data % 4) + 16] = \
                    (16 - len(bin(reg_array[rs2_sel] % (256
                     * 256))[2:])) * '0' + bin(reg_array[rs2_sel]
                        % (256 * 256))[2:]
                memory[wb_data / 4] = int(''.join(sub), 2)
            else:
                memory[wb_data / 4] = reg_array[rs2_sel]  # #STORE_WORD
        else:

            sys.stdout.write(chr(reg_array[rs2_sel]))
        wb_data =wb_prev
        
    elif opcode[binary[25:32]] == 'iops':

  # ######################## register-imediate operations##########################################################

        imm = 21 * binary[0] + binary[1:12]
        if function == '000':  # #ADDI
            wb_data = (reg_array[rs1_sel] + conv(imm)) % (1 << 32)
        elif function == '001':

                                # #SLLI

            wb_data = (reg_array[rs1_sel] << conv(imm[27:32])) % (1
                    << 32)
        elif function == '010':

                                # #SLTI

            wb_data = signed(reg_array[rs1_sel]) < signed(conv(imm))
        elif function == '011':

                                # #SLTUI

            wb_data = reg_array[rs1_sel] < conv(imm)
        elif function == '100':

                                # #XORI

            wb_data = reg_array[rs1_sel] ^ conv(imm)
        elif function == '101':
            if start_fu == '0000000':  # #SLLI
                wb_data = reg_array[rs1_sel] >> conv(imm[27:32])
            elif start_fu == '0100000':

                                         # #SLAI

                wb_data = rashift(reg_array[rs1_sel], conv(imm[27:32]))
        elif function == '110':

                                # #ORI

            wb_data = reg_array[rs1_sel] | conv(imm)
        elif function == '111':

                                # #ANDI

            wb_data = reg_array[rs1_sel] & conv(imm)
        reg_array[rd] = wb_data
    elif opcode[binary[25:32]] == 'rops':

   # #########################################register-register operation ##################################################

        if start_fu == '0000001':
            if function == '000':  # #MUL
                wb_data = twoscomp64(signed(reg_array[rs1_sel])
                        * signed(reg_array[rs2_sel])) % (1 << 32)
            elif function == '001':

                # wb_data= (usigned((reg_array[rs1_sel] * reg_array[rs2_sel]))%(1<<32))
                                        # #MULH

                wb_data = twoscomp64(signed(reg_array[rs1_sel])
                        * signed(reg_array[rs2_sel])) / (1 << 32)
            elif function == '010':

                                        # #MULHSU

                wb_data = twoscomp64(signed(reg_array[rs1_sel])
                        * reg_array[rs2_sel]) / (1 << 32)
            elif function == '011':

                                        # #MULHU

                wb_data = twoscomp64(reg_array[rs1_sel]
                        * reg_array[rs2_sel]) / (1 << 32)
            elif function == '100':

                                       # #DIV

                wb_data = twoscomp32(div(signed(reg_array[rs1_sel]),
                        signed(reg_array[rs2_sel])))
            elif function == '110':

                                       # #REM

                wb_data = twoscomp32(rem(signed(reg_array[rs1_sel]),
                        signed(reg_array[rs2_sel])))
            elif function == '101':

                                       # #DIVU

                wb_data = twoscomp32(div(reg_array[rs1_sel],
                        reg_array[rs2_sel]))
            elif function == '111':

                                       # #REMU

                wb_data = twoscomp32(rem(reg_array[rs1_sel],
                        reg_array[rs2_sel]))
        else:

            if function == '000':
                if start_fu == '0000000':  # ADD
                    wb_data = (reg_array[rs1_sel] + reg_array[rs2_sel]) \
                        % (1 << 32)
                if start_fu == '0100000':  # #SUB
                    wb_data = (reg_array[rs1_sel] + (1 << 32)
                               - reg_array[rs2_sel]) % (1 << 32)
            elif function == '001':

                                    # #SLL

                wb_data = (reg_array[rs1_sel] << reg_array[rs2_sel]
                           % 32) % (1 << 32)
            elif function == '010':

                                    # #SLT

                wb_data = signed(reg_array[rs1_sel]) \
                    < signed(reg_array[rs2_sel])
            elif function == '011':

                                    # #SLTU

                wb_data = reg_array[rs1_sel] < reg_array[rs2_sel]
            elif function == '100':

                                    # #XOR

                wb_data = reg_array[rs1_sel] ^ reg_array[rs2_sel]
            elif function == '101':
                if start_fu == '0000000':  # # SRL
                    wb_data = reg_array[rs1_sel] >> reg_array[rs2_sel] \
                        % 32
                elif start_fu == '0100000':

                                             # #SRA

                    wb_data = rashift(reg_array[rs1_sel],
                            reg_array[rs2_sel] % 32)
            elif function == '110':

                                    # #OR

                wb_data = reg_array[rs1_sel] | reg_array[rs2_sel]
            elif function == '111':

                                    # #AND

                wb_data = reg_array[rs1_sel] & reg_array[rs2_sel]
        reg_array[rd] = wb_data
    elif opcode[binary[25:32]] == 'system':
    
##################################################previledge instructions#####################################################
        """        
if binary[0:12] == bin(int('c00', 16))[2:]:
            reg_array[rd] = n#int(clocks[n])  # rd_CYCLE
        if binary[0:12] == bin(int('c02', 16))[2:]:
            reg_array[rd] = n  # INSRET
        wb_data = reg_array[rd]
        """

        """
        Values of curr_privilage
        localparam     mmode          =    2'b11        ;
        localparam     hmode          =    2'b10        ;
        localparam     smode          =    2'b01        ;
        localparam     umode          =    2'b00        ;
        """

        csr_reg = conv(binary[0:12])
        if   function == '001': #CSRRW
            wb_data = csr_mem[csr_reg]
            csr_mem[csr_reg] = reg_array[rs1_sel]
            reg_array[rd] = wb_data
            # print hex(csr_reg),hex(int(csr_file.keys()[csr_file.values().index('mtvec')],16)), hex(reg_array[rs1_sel])

        elif function == '010': #CSRRS
            wb_data = csr_mem[csr_reg]
            csr_mem[csr_reg] = csr_mem[csr_reg] | reg_array[rs1_sel]
            reg_array[rd] = wb_data

        elif function == '011': #CSRRC
            wb_data = csr_mem[csr_reg]
            csr_mem[csr_reg] = csr_mem[csr_reg] & (~reg_array[rs1_sel])
            reg_array[rd] = wb_data

        elif function == '101': #CSRRWI
            wb_data = csr_mem[csr_reg]
            csr_mem[csr_reg] = rs1_sel
            reg_array[rd] = wb_data

        elif function == '110': #CSRRSI
            wb_data = csr_mem[csr_reg]
            csr_mem[csr_reg] = csr_mem[csr_reg] | rs1_sel
            reg_array[rd] = wb_data

        elif function == '111': #CSRRCI	
            wb_data = csr_mem[csr_reg]
            csr_mem[csr_reg] = csr_mem[csr_reg] & (~rs1_sel)
            reg_array[rd] = wb_data

        elif function == '000' and csr_reg == 0: #ecall
            # print "ecall"
            #print("PC : "+'{:032b}'.format(PC))
            minterrupt = 0
            mepc_reg = (PC-1)*4
            mpp = mmode
            mecode_reg = 11
            csr_mem[int(csr_file.keys()[csr_file.values().index('mepc')],16)] = mepc_reg
            mtvec_r = csr_mem[int(csr_file.keys()[csr_file.values().index('mtvec')],16)] 

            mt_mode = mtvec_r & 0b11
            mt_base = mtvec_r >>2
            # print "mepc value (current PC) : " +hex(mepc_reg)
            # print "mtvec addr              : " +hex(mt_base)
            if curr_privilage == umode :
                #PC = utvec_r
                print "umode Not supported yet"
            elif curr_privilage == smode :
                #PC = stvec_r
                print "smode Not supported yet"
            elif curr_privilage == mmode :
                if mt_mode == 0:
                    PC = mt_base
                elif mt_mode == 1:
                    PC = mt_base + mecode_reg
                else :
                    print "Illegel mt_mode"
                csr_mem[int(csr_file.keys()[csr_file.values().index('mcause')],16)] = (minterrupt<<31)+mecode_reg
                # print "e",
                #print('{:032b}'.format((minterrupt<<31)+mecode_reg))

        elif function == '000' and csr_reg == 1: #ebreak
            minterrupt  = 0
            mecode_reg = 3
            if   curr_privilage == umode :
                uepc_reg = PC
                csr_mem[int(csr_file.keys()[csr_file.values().index('uepc')],16)] = uepc_reg
            elif curr_privilage == smode :
                sepc_reg = PC
                csr_mem[int(csr_file.keys()[csr_file.values().index('sepc')],16)] = sepc_reg
            elif curr_privilage == mmode :
                mepc_reg = PC
                csr_mem[int(csr_file.keys()[csr_file.values().index('mepc')],16)] = mepc_reg
            csr_mem[int(csr_file.keys()[csr_file.values().index('mcause')],16)] = (minterrupt<<31)+mecode_reg
        


        elif function == '000' and csr_reg == 770: #mret
            # print "mret"
            mepc_reg = csr_mem[int(csr_file.keys()[csr_file.values().index('mepc')],16)]
            PC = mepc_reg/4
            curr_privilage = mpp
            mpie = (csr_mem[int(csr_file.keys()[csr_file.values().index('mstatus')],16)]>>7) & 1
            m_ie = mpie
            mpie = 0
            csr_mem[int(csr_file.keys()[csr_file.values().index('mstatus')],16)] = csr_mem[int(csr_file.keys()[csr_file.values().index('mstatus')],16)] & ~(1<<7) ## setting mpie to 0


        #print("t0 value = "+'{:032b}'.format(reg_array[5]))
        #print("t1 value = "+'{:032b}'.format(reg_array[6]))
        #print("t2 value = "+'{:032b}'.format(reg_array[7]))
    


##################################################atomic instructions#####################################################
    elif opcode[binary[25:32]] == 'f1' or opcode[binary[25:32]] == 'f2' or opcode[binary[25:32]] == 'f3' or opcode[binary[25:32]] == 'f4' or opcode[binary[25:32]] == 'f5' or opcode[binary[25:32]] == 'f6' or opcode[binary[25:32]] == 'f7':
        minterrupt = 0
        mepc_reg = (PC-1)*4
        mpp = mmode
        mecode_reg = 2
        csr_mem[int(csr_file.keys()[csr_file.values().index('mepc')],16)] = mepc_reg
        mtvec_r = csr_mem[int(csr_file.keys()[csr_file.values().index('mtvec')],16)] 

        mt_mode = mtvec_r & 0b11
        mt_base = mtvec_r >>2
        # print "mepc value (current PC) : " +hex(mepc_reg)
        # print "mtvec addr              : " +hex(mt_base)
        if curr_privilage == umode :
            #PC = utvec_r
            print "umode Not supported yet"
        elif curr_privilage == smode :
            #PC = stvec_r
            print "smode Not supported yet"
        elif curr_privilage == mmode :
            if mt_mode == 0:
                PC = mt_base
            elif mt_mode == 1:
                PC = mt_base + mecode_reg
            else :
                print "Illegel mt_mode"
            csr_mem[int(csr_file.keys()[csr_file.values().index('mcause')],16)] = (minterrupt<<31)+mecode_reg
            # csr_mem[int(csr_file.keys()[csr_file.values().index('mtval')],16)] = int(binary,2)
            # print hex(csr_mem[int(csr_file.keys()[csr_file.values().index('mtval')],16)] )
            # break



    elif opcode[binary[25:32]] == 'amo':
        amo_op = binary[0:5]
        aq = binary[5]
        rl = binary[6]
        rs2_data = reg_array[rs2_sel]
        rs1_addr = reg_array[rs1_sel]
        #rd_addr = reg_array[int(binary[19:24],2)]
        
        data1 = memory[rs1_addr/4]
        #reg_array[int(rd_sel,2)] = data1
        #memory[rd_addr/4] = data1
        #print("AMO OP : " + str(binary[0:5]))
        #print("rs2 data : "+str(bin(rs2_data)))
        #print("rs1 data : "+str(bin(data1)))


        if amo_op == '00010': #LR
            data1 = memory[rs1_addr/4]
            amo_reserve_valid = True
            amo_reserve_addr  = rs1_addr

        elif amo_op == '00011': #SC
            if ( amo_reserve_valid and (rs1_addr==amo_reserve_addr)):
                memory[rs1_addr/4] = rs2_data
                data1 = 0
            else :
                data1 = 1
            amo_reserve_valid = False
            amo_reserve_addr  = 0


        elif amo_op == '00001': # swap
           wb_data = rs2_data
           memory[rs1_addr/4] = wb_data


        elif amo_op == '00000': # add
            wb_data = (rs2_data + data1)%(1 << 32)
            memory[rs1_addr/4] = wb_data


        elif amo_op == '00100': # xor
            wb_data = rs2_data ^ data1
            memory[rs1_addr/4] = wb_data


        elif amo_op == '01100': # and
            wb_data = rs2_data & data1
            memory[rs1_addr/4] = wb_data


        elif amo_op == '01000': # or
            wb_data = rs2_data | data1
            memory[rs1_addr/4] = wb_data


        elif amo_op == '11100': # maxu
            wb_data = max(rs2_data, data1)
            memory[rs1_addr/4] = wb_data


        elif amo_op == '11000': # minu
            wb_data = min(rs2_data,data1)
            memory[rs1_addr/4] = wb_data


        elif amo_op == '10100': # max 
            wb_data = twoscomp32(max(signed(rs2_data), signed(data1)))
            memory[rs1_addr/4] = wb_data


        elif int(amo_op,2) == int('10000',2): # min
            wb_data = twoscomp32(min(signed(rs2_data),signed(data1)))
            memory[rs1_addr/4] = wb_data



        reg_array[rd] = data1
    
    # print hex(reg_array[rd])
    try:
        if val != (nile[n])[:-1]:
            print prev
            print 'from python', val, 'from logic ', (nile[n])[:-1], \
                '\t'
            print 'last', prevs
            print 'now', int(clocks[n]), 'rs1', \
                hex(reg_array[rs1_sel]), 'rs2', \
                hex(reg_array[rs2_sel]), opcode[binary[25:32]], 'imm', \
                hex(conv(imm)), 'rs1', rs1_sel, 'rs2s', rs2_sel, rd, \
                function
            break
    except:

##        print "\nstill execting",n
##        break

        pass
    try:
        prev = val + ' ' + (nile[n])[:-1]
    except:
        pass

##        print n

##    if (instruction == int('00008067',16)):
##        x+=1
##        if (ins_memory[lpc]!=reg_array[1]):
##            ins_memory[lpc]=reg_array[1]
##            print hex(lpc*4),reg_array[1]
##
##        if(x==10000):break
##
##    if (reg_array[2] > (1<<20)):
##        print "outofboundry", reg_array[2]

    prevs = (
        hex(reg_array[rs1_sel]),
        hex(reg_array[rs2_sel]),
        opcode[binary[25:32]],
        conv(imm),
        start_fu,
        rs1_sel,
        rs2_sel,
        function,
        rd,
        hex(wb_data),
        )

    n = n + 1
    cycle += 1
    reg_array[0] = 0

    if lpc == PC:  # #BREAKS AT INFINITE LOOP
        break

            
