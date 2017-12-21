################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include src/riscv_isa_tests/subdir.mk
-include src/dhrystone/subdir.mk
-include src/coremark/subdir.mk
-include src/subdir.mk
-include subdir.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(ASM_DEPS)),)
-include $(ASM_DEPS)
endif
ifneq ($(strip $(S_UPPER_DEPS)),)
-include $(S_UPPER_DEPS)
endif
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 
SECONDARY_FLASH += \
RISCV_Test_Benchmark.hex \

SECONDARY_LIST += \
RISCV_Test_Benchmark.lst \


# All Target
all: RISCV_Test_Benchmark.elf secondary-outputs

# Tool invocations
RISCV_Test_Benchmark.elf: $(OBJS) $(USER_OBJS)
	@echo 'Building target: $@'
	@echo 'Invoking: RISC-V GCC/Newlib C Linker'
	riscv64-unknown-elf-gcc -mabi=ilp32 -march=rv32i -T"../src/link.ld" -nostartfiles -Wl,-Map,RISCV_Test_Benchmark.map -o "RISCV_Test_Benchmark.elf" $(OBJS) $(USER_OBJS) $(LIBS)
	@echo 'Finished building target: $@'
	@echo ' '

RISCV_Test_Benchmark.hex: RISCV_Test_Benchmark.elf
	@echo 'Invoking: RISC-V GCC/Newlib GNU Create Flash Image'
	riscv64-unknown-elf-objcopy -O elf32-littleriscv -j .text -j .data RISCV_Test_Benchmark.elf  "RISCV_Test_Benchmark.hex"
	@echo 'Finished building: $@'
	@echo ' '

RISCV_Test_Benchmark.lst: RISCV_Test_Benchmark.elf
	@echo 'Invoking: RISC-V GCC/Newlib Create Listing'
	riscv64-unknown-elf-objdump -d -h -j .rodata.str1.4 -j .text RISCV_Test_Benchmark.elf > "RISCV_Test_Benchmark.lst"
	@echo 'Finished building: $@'
	@echo ' '

# Other Targets
clean:
	-$(RM) $(EXECUTABLES)$(SECONDARY_VHEX)$(OBJS)$(SECONDARY_FLASH)$(SECONDARY_LIST)$(ASM_DEPS)$(S_UPPER_DEPS)$(C_DEPS) RISCV_Test_Benchmark.elf
	-@echo ' '

secondary-outputs: $(SECONDARY_FLASH) $(SECONDARY_LIST) $(SECONDARY_VHEX)

.PHONY: all clean dependents

-include ../makefile.targets
