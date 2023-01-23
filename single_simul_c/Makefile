CC = gcc

all: rv32i_single

rv32i_single: rv32i_single.o rv32i.o
	$(LINK.cc) $^ $(LOADLIBES) $(LDLIBS) -o $@

clean:
	rm -f rv32i_single *.o