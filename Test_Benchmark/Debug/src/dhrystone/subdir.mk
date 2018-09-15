################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/dhrystone/dhry_1.c \
../src/dhrystone/dhry_2.c 

OBJS += \
./src/dhrystone/dhry_1.o \
./src/dhrystone/dhry_2.o 

C_DEPS += \
./src/dhrystone/dhry_1.d \
./src/dhrystone/dhry_2.d 


# Each subdirectory must supply rules for building sources it contributes
src/dhrystone/%.o: ../src/dhrystone/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: RISC-V GCC/Newlib C Compiler'
	riscv64-unknown-elf-gcc -mabi=ilp32 -march=rv32ima -DTIME -DUSE_MYSTDLIB -DRISCV -O2 -Wall -ffreestanding -nostdlib  -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


