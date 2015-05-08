VFILES=$(wildcard *.v)

cpu : $(VFILES) Makefile
	iverilog -Wall -o cpu $(VFILES)

run : cpu
	timeout 3 ./cpu

run% : cpu test%.hex
	@cp tests/test$*.hex test.hex
	make run

clean :
	rm -rf cpu test.hex test.ok test.raw test.cycles *.out *.vcd

test : $(sort $(patsubst tests/%.ok,%,$(wildcard tests/test?.ok)))

test% : cpu tests/test%.hex
	@echo -n "test$* ... "
	@cp tests/test$*.hex test.hex
	@cp tests/test$*.ok test.ok
	@timeout 3 ./cpu > test.raw 2>&1
	-@egrep "^#" test.raw > test.out
	-@egrep "^@" test.raw > test.cycles
	@((diff -b test.out test.ok > /dev/null 2>&1) && echo "pass `cat test.cycles`") || (echo "fail" ; echo "\n\n----------- expected ----------"; cat test.ok ; echo "\n\n------------- found ----------"; cat test.out)

# keep make from deleting .hex files
.SECONDARY:

tests/test%.hex : tests/test%.asm
	./tests/as.sh $^ $@
