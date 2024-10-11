# Sudoku using Simulated Annealing
A program that solves Sudoku (Disjoint Groups variation) using Simulated Annealing algorithm, written in Oberon.

## Compilation

To compile the program, you will need to setup [Vostok Oberon compiler](https://vostok.oberon.org/).
The author used Vostok for Mac (Apple Silicon processor), but it should compile and work
on all supported systems.

Vostok setup on MacOS (using Homebrew):
```
brew tap vostok-space/oberon &&
brew install vostok
```

Compile:
```
make
```
or:
```
ost to-bin 'SudokuX.Do' sudokux -m .
```

## Usage
```
./sudokux
```

### Using another compiler

Another Oberon compiler can be also used, but minor code amendments could be required. Revised Oberon (Oberon-07) dialect is used.

The used modules and procedures are:
* OsRand.Open - starts a random generator
* OsRand.Int(x) - generates a random integer from 0 to (x - 1).
* OsRand.Real(x) - generates a random real number from 0 to 1.
* Math.exp(x) - standard library Oberon function that calculates exponent of x.
* Out.Open, Out.Int, Out.Char, Out.String, Out.Ln - standard library procedures.
