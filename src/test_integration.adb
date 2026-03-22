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

   --  Summary
   Put_Line ("=== Results: " & Natural'Image (Passed_Tests) &
             " /" & Natural'Image (Total_Tests) & " passed ===");

   if Passed_Tests = Total_Tests then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;

end Test_Integration;
