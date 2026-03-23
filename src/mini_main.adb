pragma No_Run_Time;
pragma Restrictions (No_Exception_Propagation);
pragma Restrictions (No_Secondary_Stack);

with Forth_VM;
with Forth_Interpreter;
with Mini_IO;

procedure Mini_Main is
   VM   : Forth_VM.VM_State;
   Line : Forth_Interpreter.Line_Buffer := (others => ' ');
   Res  : Forth_Interpreter.Interpret_Result;
   Last : Natural;
begin
   Forth_VM.Initialize (VM);

   loop
      Mini_IO.Put ("> ");

      Mini_IO.Get_Line (Line, Last);

      exit when Last = 0;

      Forth_Interpreter.Interpret_Line (VM, Line, Last, Res);

      case Res is
         when Forth_Interpreter.OK =>
            Mini_IO.Put_Line (" OK");
         when Forth_Interpreter.Unknown_Word =>
            Mini_IO.Put_Line ("Error: unknown word");
         when Forth_Interpreter.Stack_Error =>
            Mini_IO.Put_Line ("Error: stack underflow/overflow");
         when Forth_Interpreter.Compile_Error =>
            Mini_IO.Put_Line ("Error: compilation error");
         when Forth_Interpreter.Halted =>
            Mini_IO.Put_Line ("VM halted");
            exit;
      end case;

      --  Reset buffer
      Line := (others => ' ');
   end loop;
end Mini_Main;
