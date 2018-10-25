vcs:
	vcs -full64 -f flist.f -sverilog +incdir+./src/design/common +incdir+./src/design/newcache -fgp -debug_access+all +vcs+fsdbon+mda -kdb -lca; ./simv -fgp:numcores=10  