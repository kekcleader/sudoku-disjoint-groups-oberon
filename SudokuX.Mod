MODULE SudokuX;
IMPORT Out, OsRand, Math;

CONST
  startT = 1000.0;
  decreaseT = 0.9999;
  minT = 0.01;

  fixedCells = 15;

TYPE
  (* A single Sudoku cell *)
  Cell = RECORD
    num: INTEGER;  (* Number 0..9 in the cell, 0 = blank *)
    fixed: BOOLEAN (* TRUE if the number is part of the task *)
  END;

  (* Whole Sudoku field 9x9, first index is Y, second is X *)
  Sudoku = ARRAY 9, 9 OF Cell;

(** Returns random integer in range 0..(n - 1). *)
PROCEDURE Random(n: INTEGER): INTEGER;
VAR x: INTEGER;
BEGIN
  IF ~OsRand.Int(x) THEN
    ASSERT(FALSE)
  END
RETURN x MOD n END Random;

(** Returns random real number in range [0; 1). *)
PROCEDURE Uniform(): REAL;
VAR x: REAL;
BEGIN
  IF ~OsRand.Real(x) THEN
    ASSERT(FALSE)
  END
RETURN x END Uniform;

(** Fills in a single 3x3 square with random numbers,
    so that each such 3x3 square would have different
    numbers only. The coordinates of the square may be
    (0; 0), (3; 0), (6, 0), (0; 3) etc. *)
PROCEDURE RandomFill3x3(VAR s: Sudoku; X, Y: INTEGER);
VAR x, y, i, num: INTEGER;
  free: ARRAY 10 OF BOOLEAN; (* What numbers are free to use (1..9) *)
  left: INTEGER; (* Number of TRUE in array free[1..9] *)

  PROCEDURE RandomFromArray(VAR free: ARRAY OF BOOLEAN;
      VAR left: INTEGER): INTEGER;
  VAR skip, i: INTEGER;
  BEGIN
    (* Get to the first free number *)
    i := 1; WHILE ~free[i] DO INC(i) END;

    skip := Random(left);
    WHILE skip # 0 DO
      REPEAT INC(i) UNTIL free[i];
      DEC(skip)
    END;

    free[i] := FALSE;
    DEC(left)
  RETURN i END RandomFromArray;

BEGIN
  (* All numbers [1..9] are free to use *)
  free[0] := FALSE;
  FOR i := 1 TO 9 DO free[i] := TRUE END;
  left := 9;

  (* Remove used numbers *)
  FOR y := Y TO Y + 2 DO
    FOR x := X TO X + 2 DO
      num := s[y, x].num;
      IF free[num] THEN
        free[num] := FALSE;
        DEC(left)
      END
    END
  END;

  (* Fill in *)
  FOR y := Y TO Y + 2 DO
    FOR x := X TO X + 2 DO
      IF s[y, x].num = 0 THEN (* Empty cell *)
        s[y, x].num := RandomFromArray(free, left)
      END
    END
  END
END RandomFill3x3;

(** Fills in each of nine 3x3 squares with random numbers,
    so that each such 3x3 square would have different
    numbers only. *)
PROCEDURE RandomFill(VAR s: Sudoku);
VAR x, y: INTEGER;
BEGIN
  FOR y := 0 TO 6 BY 3 DO
    FOR x := 0 TO 6 BY 3 DO
      RandomFill3x3(s, x, y)
    END
  END
END RandomFill;

PROCEDURE Print(s: Sudoku);
VAR x, y: INTEGER;
BEGIN
  FOR y := 0 TO 8 DO
    FOR x := 0 TO 8 DO
      IF s[y, x].fixed THEN Out.Char("(") ELSE Out.Char(" ") END;
      Out.Int(s[y, x].num, 0);
      IF s[y, x].fixed THEN Out.Char(")") ELSE Out.Char(" ") END
    END;
    Out.Ln
  END;
  Out.Ln
END Print;

(** Returns the number of repeated numbers in the row. *)
PROCEDURE RepetitionsInRow(s: Sudoku; row: INTEGER): INTEGER;
VAR i, num, res: INTEGER;
  repeated: ARRAY 10 OF BOOLEAN; (* Indices 1..9 are used *)
BEGIN
  res := 0;
  FOR i := 1 TO 9 DO repeated[i] := FALSE END;
  FOR i := 0 TO 8 DO
    num := s[row, i].num;
    IF repeated[num] THEN INC(res) ELSE repeated[num] := TRUE END
  END
RETURN res END RepetitionsInRow;

(** Returns the number of repeated numbers in the column. *)
PROCEDURE RepetitionsInCol(s: Sudoku; col: INTEGER): INTEGER;
VAR i, num, res: INTEGER;
  repeated: ARRAY 10 OF BOOLEAN; (* Indices 1..9 are used *)
BEGIN
  res := 0;
  FOR i := 1 TO 9 DO repeated[i] := FALSE END;
  FOR i := 0 TO 8 DO
    num := s[i, col].num;
    IF repeated[num] THEN INC(res) ELSE repeated[num] := TRUE END
  END
RETURN res END RepetitionsInCol;

(** Returns the number of repeated numbers in the disjoined
    group, that is identified by it's X and Y, modulus 3.
    So, both X and Y have a range of 0..2. *)
PROCEDURE RepetitionsInGroup(s: Sudoku; X, Y: INTEGER): INTEGER;
VAR x, y, i, num, res: INTEGER;
  repeated: ARRAY 10 OF BOOLEAN; (* Indices 1..9 are used *)
BEGIN
  res := 0;
  FOR i := 1 TO 9 DO repeated[i] := FALSE END;
  FOR y := Y TO 8 BY 3 DO
    FOR x := X TO 8 BY 3 DO
      num := s[y, x].num;
      IF repeated[num] THEN INC(res) ELSE repeated[num] := TRUE END
    END
  END
RETURN res END RepetitionsInGroup;

(** Returns a value of the Sudoku board, that should be zero if
    the Sudoku is solved and is greater when it is more far from
    the solution. Calculates the number of repetitions. *)
PROCEDURE Evaluate(s: Sudoku): INTEGER;
VAR res, i: INTEGER;
  x, y: INTEGER;
BEGIN
  res := 0;
  (* Repetitions in rows and columns *)
  FOR i := 0 TO 8 DO
    INC(res, RepetitionsInRow(s, i));
    INC(res, RepetitionsInCol(s, i))
  END;
  (* Repetitions in disjoint groups *)
  FOR y := 0 TO 2 DO
    FOR x := 0 TO 2 DO
      INC(res, RepetitionsInGroup(s, x, y))
    END
  END;
RETURN res END Evaluate;

(** Returns TRUE with a certain probability, based on temperature t. *)
PROCEDURE RollDice(diff: INTEGER; t: REAL): BOOLEAN;
RETURN Uniform() < Math.exp(FLT(diff) / t) END RollDice;

(** Puts in next a random neighbour of cur - randomly swaps
    two non-fixed numbers in a randomly-chosen 3x3 square. *)
PROCEDURE RandomNeighbour(cur: Sudoku; VAR next: Sudoku);
VAR X, Y, x, y, x2, y2, tmp, R: INTEGER;
BEGIN
  next := cur;
  (* Beginning of 3x3 square *)
  X := Random(3) * 3;
  Y := Random(3) * 3;
  (* Pick two cells at random *)
  R := 100;
  REPEAT
    x := X + Random(3);
    y := Y + Random(3);
    DEC(R)
  UNTIL ~next[y, x].fixed OR (R = 0);
  IF R # 0 THEN
    R := 200;
    REPEAT
      x2 := X + Random(3);
      y2 := Y + Random(3);
      DEC(R)
    UNTIL ((x # x2) OR (y # y2)) & ~next[y2, x2].fixed OR (R = 200);
    (* Swap *)
    IF R # 0 THEN
      tmp := next[y, x].num;
      next[y, x].num := next[y2, x2].num;
      next[y2, x2].num := tmp
    END
  END
END RandomNeighbour;

(** Tries to solve the given Sudoku if it is possible. Returns TRUE
    on success, FALSE on fail. The given Sudoku board variable will
    hold the best solution. Puts in steps the number of iterations
    it took to solve it. *)
PROCEDURE Solve(VAR s: Sudoku; VAR steps: INTEGER): BOOLEAN;
VAR
  cur, next, best: Sudoku; (* current, neighbour and best solutions *)
  curEval, nextEval, bestEval: INTEGER; (* Corresponding evaluations *)
  t: REAL;
BEGIN
  steps := 0;
  cur := s;
  curEval := Evaluate(cur);
  best := cur;
  bestEval := curEval;

  t := startT;
  REPEAT
    RandomNeighbour(cur, next);
    nextEval := Evaluate(next);
    IF nextEval < curEval THEN
      cur := next;
      curEval := nextEval;
      IF curEval < bestEval THEN
        best := cur;
        bestEval := curEval
      END
    ELSIF RollDice(curEval - nextEval, t) THEN
      cur := next;
      curEval := nextEval
    END;
    t := t * decreaseT;
    INC(steps)
  UNTIL (bestEval = 0) OR (t <= minT);
  s := best
RETURN bestEval = 0 END Solve;

(** Clears the whole field. *)
PROCEDURE Clear(VAR s: Sudoku);
VAR x, y: INTEGER;
BEGIN
  FOR y := 0 TO 8 DO
    FOR x := 0 TO 8 DO
      s[y, x].num := 0;
      s[y, x].fixed := FALSE
    END
  END
END Clear;

(** Creates a random Sudoku task (with only fixed numbers).
    The task may be broken - unreal to solve. *)
PROCEDURE RandomTask(VAR s: Sudoku; fixedCount: INTEGER);
VAR x, y, i, steps: INTEGER;
BEGIN
  REPEAT
    Clear(s);
    RandomFill(s)
  UNTIL Solve(s, steps);
  Out.String("Solve an empty Sudoku:"); Out.Ln;
  Print(s);
  (* Mark random cells as fixed *)
  FOR i := 1 TO fixedCount DO
    REPEAT
      x := Random(9);
      y := Random(9)
    UNTIL ~s[y, x].fixed;
    s[y, x].fixed := TRUE
  END;
  Out.String("Mark numbers as fixed randomly:"); Out.Ln;
  Print(s);
  (* Clear non-fixed cells *)
  FOR y := 0 TO 8 DO
    FOR x := 0 TO 8 DO
      IF ~s[y, x].fixed THEN s[y, x].num := 0 END
    END
  END
END RandomTask;

PROCEDURE Do*;
VAR s: Sudoku;
  steps: INTEGER;
BEGIN
  RandomTask(s, fixedCells);
  Out.String("Initial Sudoku task:"); Out.Ln;
  Print(s);

  RandomFill(s);
  Out.String("Starting random fill:"); Out.Ln;
  Print(s);

  IF Solve(s, steps) THEN
    Out.String("The solution took ");
    Out.Int(steps, 0); Out.String(" steps:")
  ELSE
    Out.String("Impossible to solve! Best attempt:")
  END;
  Out.Ln;
  Print(s)
END Do;

BEGIN
  Out.Open;
  IF ~OsRand.Open() THEN
    Out.String("Could not initialize Random numbers."); Out.Ln
  END
END SudokuX.
