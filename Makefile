all: sudokux

sudokux: SudokuX.Mod
	ost to-bin 'SudokuX.Do' sudokux -m .

.PHONY: run
run: sudokux
	./sudokux

.PHONY: clear
clear:
	rm -rf sudokux
