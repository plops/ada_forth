with Ada.Text_IO;
with Forth_VM;
with Forth_Interpreter;

procedure Main
  with SPARK_Mode => Off
is
   VM   : Forth_VM.VM_State;
   Line : Forth_Interpreter.Line_Buffer := (others => ' ');
   Res  : Forth_Interpreter.Interpret_Result;
   Last : Natural;
begin
   Forth_VM.Initialize (VM);

   loop
      Ada.Text_IO.Put ("> ");
      Ada.Text_IO.Flush;

      begin
         Ada.Text_IO.Get_Line (Line, Last);
      exception
         when Ada.Text_IO.End_Error =>
            Ada.Text_IO.New_Line;
            exit;
      end;

      exit when Last = 0;

      Forth_Interpreter.Interpret_Line (VM, Line, Last, Res);

      case Res is
         when Forth_Interpreter.OK =>
            Ada.Text_IO.Put_Line (" OK");
         when Forth_Interpreter.Unknown_Word =>
            Ada.Text_IO.Put_Line ("Error: unknown word");
         when Forth_Interpreter.Stack_Error =>
            Ada.Text_IO.Put_Line ("Error: stack underflow/overflow");
         when Forth_Interpreter.Halted =>
            Ada.Text_IO.Put_Line ("VM halted");
            exit;
      end case;

      --  Reset buffer for next iteration
      Line := (others => ' ');
   end loop;
end Main;
