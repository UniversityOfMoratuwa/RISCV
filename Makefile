# This makefile handles running vcs simulation, compiling isa/benchmark tests, and running python emulator on the compiled c codes
vcs:
	vcs -full64 -f flist.f -sverilog +incdir+./src/design/common +incdir+./src/design/newcache -fgp -debug_access+all +vcs+fsdbon+mda -kdb -lca; ./simv -fgp:numcores=10  

clean:
	cd Test_Benchmark/Debug/ && $(MAKE) clean
	cd Soft_Processor/ && rm -rf *.txt RISCV_Test_Benchmark.* 

riscv_test_compile:
	cd Test_Benchmark/Debug/ && $(MAKE) clean && $(MAKE) all
	

copy_elf_files:
	cp Test_Benchmark/Debug/RISCV_Test_Benchmark.* Soft_Processor/

run_emulator:
	cd Soft_Processor/ && python conv.py && python emu.py


all: riscv_test_compile copy_elf_files run_emulator
	
