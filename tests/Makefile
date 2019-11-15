CC=mpicc
CFLAGS=-Wall -g -O0

PROGS=init_finalize mpi_sleeper

all: $(PROGS)

init_finalize: init_finalize.c
	$(CC) init_finalize.c $(CFLAGS) -o init_finalize

mpi_sleeper: mpi_sleeper.c
	$(CC) mpi_sleeper.c $(CFLAGS) -o mpi_sleeper

install: all
	mv -f $(PROGS) ../bin/

clean:
	$(RM) $(PROGS) *.o
