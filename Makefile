verilog:
	bsc --verilog -show-schedule -u TopModule.bsv
sim:
	bsc -sim -u -g mkTb TopModule.bsv
	bsc -sim -e mkTb -o run.out
	./run.out