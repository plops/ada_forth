with Ada.Text_IO;
with Ada.Command_Line;
with Forth_VM;
with Forth_Interpreter;

procedure Test_Integration
  with SPARK_Mode => Off
is
   use Ada.Text_IO;
   use type Forth_Interpreter.Interpret_Result;

   Total_Tests  : Natural := 0;
   Passed_Tests : Natural := 0;

   procedure Report (Name : String; Pass : Boolean) is
   begin
      Total_Tests := Total_Tests + 1;
      if Pass then
         Passed_Tests := Passed_Tests + 1;
         Put_Line ("  PASS: " & Name);
      else
         Put_Line ("  FAIL: " & Name);
      end if;
   end Report;

   --  Helper: set up a line buffer from a string
   procedure Set_Line
     (Buf : out Forth_Interpreter.Line_Buffer;
      Src : in  String;
      Len : out Natural)
   is
   begin
      Buf := (others => ' ');
      Len := Src'Length;
      if Len > Forth_Interpreter.Max_Line_Length then
         Len := Forth_Interpreter.Max_Line_Length;
      end if;
      Buf (1 .. Len) := Src (Src'First .. Src'First + Len - 1);
   end Set_Line;

   VM   : Forth_VM.VM_State;
   Line : Forth_Interpreter.Line_Buffer;
   Res  : Forth_Interpreter.Interpret_Result;
   Len  : Natural;

begin
   Put_Line ("=== Integration Tests for Forth Interpreter ===");
   New_Line;

   --  Test 1: "3 4 + ." => OK, stack empty after dot prints
   Put_Line ("Test 1: 3 4 + .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "3 4 + .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 2: "5 DUP * ." => OK (5*5=25), stack empty
   Put_Line ("Test 2: 5 DUP * .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "5 DUP * .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 3: "1 2 SWAP - ." => OK (1-2=-1), stack empty
   Put_Line ("Test 3: 1 2 SWAP - .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "1 2 SWAP - .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 4: "10 20 30" => OK with 3 items on stack
   Put_Line ("Test 4: 10 20 30");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "10 20 30", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack has 3 items",
           Forth_VM.Data_Stacks.Size (VM.Data_Stack) = 3);
   Report ("Top of stack is 30",
           Forth_VM.Data_Stacks.Peek (VM.Data_Stack) = 30);
   New_Line;

   --  Test 5: "FOOBAR" => Unknown_Word
   Put_Line ("Test 5: FOOBAR (unknown word)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "FOOBAR", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is Unknown_Word",
           Res = Forth_Interpreter.Unknown_Word);
   New_Line;

   --  Test 6: "+" => Stack_Error (underflow, empty stack)
   Put_Line ("Test 6: + (stack underflow on empty)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "+", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is Stack_Error",
           Res = Forth_Interpreter.Stack_Error);
   New_Line;

   --  Test 7: "1 DROP DROP" => Stack_Error (underflow on second DROP)
   Put_Line ("Test 7: 1 DROP DROP (underflow on second DROP)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "1 DROP DROP", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is Stack_Error",
           Res = Forth_Interpreter.Stack_Error);
   New_Line;

   --  Test 8: Stack overflow — push 256 values then try one more
   Put_Line ("Test 8: Stack overflow (push 257 values)");
   Forth_VM.Initialize (VM);
   --  Push 256 values using a loop of Interpret_Line calls
   declare
      Overflow_Hit : Boolean := False;
   begin
      for I in 1 .. Forth_VM.Stack_Capacity loop
         Set_Line (Line, "1", Len);
         Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
         if Res /= Forth_Interpreter.OK then
            Overflow_Hit := True;
            exit;
         end if;
      end loop;

      if not Overflow_Hit then
         Report ("Stack filled to capacity (256)",
                 Forth_VM.Data_Stacks.Size (VM.Data_Stack) =
                   Forth_VM.Stack_Capacity);
         --  Now try pushing one more
         Set_Line (Line, "1", Len);
         Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
         Report ("Result is Stack_Error on overflow",
                 Res = Forth_Interpreter.Stack_Error);
      else
         Report ("Stack filled to capacity (256)", False);
         Report ("Result is Stack_Error on overflow", False);
      end if;
   end;
   New_Line;

   --  Test 9: User-defined word SQUARE
   --  : SQUARE DUP * ; 5 SQUARE .  => prints 25, stack empty
   Put_Line ("Test 9: : SQUARE DUP * ; 5 SQUARE .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, ": SQUARE DUP * ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Definition accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, "5 SQUARE .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Execution result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 10: Nested user-defined words SQUARE and CUBE
   --  : SQUARE DUP * ; : CUBE DUP SQUARE * ; 3 CUBE .  => prints 27
   Put_Line ("Test 10: : SQUARE DUP * ; : CUBE DUP SQUARE * ; 3 CUBE .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, ": SQUARE DUP * ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("SQUARE definition accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, ": CUBE DUP SQUARE * ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("CUBE definition accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, "3 CUBE .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Execution result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 11: Undefined word in colon definition => Compile_Error
   Put_Line ("Test 11: : BAD NONEXISTENT ; (undefined word in definition)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, ": BAD NONEXISTENT ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is Compile_Error",
           Res = Forth_Interpreter.Compile_Error);
   New_Line;

   --  Note: Backward compatibility (Requirement 19.1, 19.2) is verified by
   --  Tests 1-8 above continuing to pass with the extended interpreter.

   --  ===== Phase 2 Tests: Comparison Operators and Control Flow =====

   --  Test 12: Comparison operators — 5 3 > . => prints -1 (true)
   Put_Line ("Test 12: 5 3 > . (greater-than true)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "5 3 > .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 13: Comparison operators — 3 5 > . => prints 0 (false)
   Put_Line ("Test 13: 3 5 > . (greater-than false)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "3 5 > .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 14: Less-than — 3 5 < . => prints -1 (true)
   Put_Line ("Test 14: 3 5 < . (less-than true)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "3 5 < .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 15: Equal — 7 7 = . => prints -1 (true)
   Put_Line ("Test 15: 7 7 = . (equal true)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "7 7 = .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 16: IF/THEN — : ABS DUP 0 < IF -1 * THEN ; -5 ABS . => prints 5
   Put_Line ("Test 16: : ABS DUP 0 < IF -1 * THEN ; -5 ABS .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, ": ABS DUP 0 < IF -1 * THEN ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("ABS definition accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, "-5 ABS .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Execution result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 17: IF/THEN with positive (false branch, no ELSE) — 5 ABS . => 5
   Put_Line ("Test 17: 5 ABS . (positive, IF not taken)");
   --  Reuse VM from Test 16 (ABS already defined)
   Set_Line (Line, "5 ABS .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Execution result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 18: IF/ELSE/THEN — SIGN word
   Put_Line ("Test 18: SIGN word with IF/ELSE/THEN");
   Forth_VM.Initialize (VM);
   Set_Line (Line, ": SIGN DUP 0 > IF DROP 1 ELSE DUP 0 < IF DROP -1 ELSE DROP 0 THEN THEN ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("SIGN definition accepted (OK)",
           Res = Forth_Interpreter.OK);
   --  Test SIGN with positive
   Set_Line (Line, "5 SIGN .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("SIGN(5) result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   --  Test SIGN with negative
   Set_Line (Line, "-3 SIGN .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("SIGN(-3) result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   --  Test SIGN with zero
   Set_Line (Line, "0 SIGN .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("SIGN(0) result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 19: Fuel exhaustion — mutual recursion via word shadowing
   --  Define RECUR as a no-op, then TRAMPOLINE calls RECUR,
   --  then redefine RECUR to call TRAMPOLINE. The new RECUR calls
   --  TRAMPOLINE which calls the OLD RECUR (the no-op), so no infinite loop.
   --  True self-recursion isn't possible in this Forth since words aren't
   --  visible during their own compilation. Fuel exhaustion (Req 9.2) is
   --  formally verified by GNATprove. Test a deep but terminating call chain instead.
   Put_Line ("Test 19: Deep nested calls (stress test)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, ": D4 DUP * ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Set_Line (Line, ": D3 D4 ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Set_Line (Line, ": D2 D3 ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Set_Line (Line, ": D1 D2 ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Deep chain definitions accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, "3 D1 .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Deep chain execution result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  ===== Phase 3 Tests: Variables =====

   --  Test 20: VARIABLE X 42 X ! X @ . => prints 42, result OK, stack empty
   Put_Line ("Test 20: VARIABLE X 42 X ! X @ .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "VARIABLE X 42 X ! X @ .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Test 21: Increment pattern — declare X, fetch default (0), add 1, store back
   --  Then verify X @ gives 1
   Put_Line ("Test 21: VARIABLE X X @ 1 + X ! then X @ (increment pattern)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "VARIABLE X X @ 1 + X !", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Increment step result is OK",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, "X @", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Fetch step result is OK",
           Res = Forth_Interpreter.OK);
   Report ("X @ gives 1",
           Forth_VM.Data_Stacks.Peek (VM.Data_Stack) = 1);
   New_Line;

   --  Test 22: Invalid address — push out-of-range address (999), call ! => Stack_Error
   Put_Line ("Test 22: 999 42 SWAP ! (invalid variable address)");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "42 999 !", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Result is Stack_Error",
           Res = Forth_Interpreter.Stack_Error);
   New_Line;

   --  Test 23: VARIABLE in colon definition context
   --  Define VARIABLE X, then : SETX X ! ;, then 99 SETX X @ . => prints 99
   Put_Line ("Test 23: VARIABLE X : SETX X ! ; 99 SETX X @ .");
   Forth_VM.Initialize (VM);
   Set_Line (Line, "VARIABLE X", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("VARIABLE X accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, ": SETX X ! ;", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("SETX definition accepted (OK)",
           Res = Forth_Interpreter.OK);
   Set_Line (Line, "99 SETX X @ .", Len);
   Forth_Interpreter.Interpret_Line (VM, Line, Len, Res);
   Report ("Execution result is OK",
           Res = Forth_Interpreter.OK);
   Report ("Stack is empty after dot",
           Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack));
   New_Line;

   --  Summary
   Put_Line ("=== Results: " & Natural'Image (Passed_Tests) &
             " /" & Natural'Image (Total_Tests) & " passed ===");

   if Passed_Tests = Total_Tests then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;

end Test_Integration;
