CC = gcc

all: rv32i_pipeline

rv32i_pipeline: rv32i_pipeline.o rv32i.o
	$(LINK.cc) $^ $(LOADLIBES) $(LDLIBS) -o $@

clean:
	rm -f rv32i_pipeline *.o
