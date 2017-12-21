################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/coremark/core_list_join.c \
../src/coremark/core_main.c \
../src/coremark/core_matrix.c \
../src/coremark/core_portme.c \
../src/coremark/core_state.c \
../src/coremark/core_util.c 

OBJS += \
./src/coremark/core_list_join.o \
./src/coremark/core_main.o \
./src/coremark/core_matrix.o \
./src/coremark/core_portme.o \
./src/coremark/core_state.o \
./src/coremark/core_util.o 

C_DEPS += \
./src/coremark/core_list_join.d \
./src/coremark/core_main.d \
./src/coremark/core_matrix.d \
./src/coremark/core_portme.d \
./src/coremark/core_state.d \
./src/coremark/core_util.d 


# Each subdirectory must supply rules for building sources it contributes
src/coremark/%.o: ../src/coremark/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: RISC-V GCC/Newlib C Compiler'
	riscv64-unknown-elf-gcc -mabi=ilp32 -march=rv32i -DTIME -DUSE_MYSTDLIB -DRISCV -O2 -Wall -ffreestanding -nostdlib  -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


