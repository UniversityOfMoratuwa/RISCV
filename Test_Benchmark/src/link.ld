 OUTPUT_ARCH( "riscv" )
 ENTRY( "_start" )

SECTIONS{

	/* text: test code section */
	. = 0x00010000;
	.text :{
		*(.text.boot)
		*(.text)
	} 
	
	/* data: ReadOnly data segment */
	.rodata :{
    	*(.rodata)
    } 

	/* data: Initialized data segment */
	.data :{
		*(.data)
	}

	/* data: Uninitialized data segment */
	.bss  :{
		*(.bss) 
	} 
	
}