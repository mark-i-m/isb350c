VFILES=$(wildcard *.v)

cpu : $(VFILES) Makefile
	iverilog -o cpu $(VFILES)

run : cpu
	timeout 3 ./cpu

run% : cpu mem%.hex
	@cp mem$*.hex mem.hex
	make run

clean :
	rm -rf cpu mem.hex test.ok test.raw test.cycles
	rm -rf *.out
	rm -rf *.vcd

test : $(sort $(patsubst %.ok,%,$(wildcard test?.ok)))

test% : cpu mem%.hex
	@echo -n "test$* ... "
	@cp mem$*.hex mem.hex
	@cp test$*.ok test.ok
	@timeout 3 ./cpu > test.raw 2>&1
	-@egrep "^#" test.raw > test.out
	-@egrep "^@" test.raw > test.cycles
	@((diff -b test.out test.ok > /dev/null 2>&1) && echo "pass `cat test.cycles`") || (echo "fail" ; echo "\n\n----------- expected ----------"; cat test.ok ; echo "\n\n------------- found ----------"; cat test.out)

# keep make from deleting .hex files
.SECONDARY:

mem%.hex : test%.asm
	./as.sh $^ $@
