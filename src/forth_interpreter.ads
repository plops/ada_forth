with Forth_VM;

package Forth_Interpreter
  with SPARK_Mode => On
is
   Max_Line_Length  : constant := 256;
   Max_Token_Length : constant := 31;

   subtype Line_Buffer is String (1 .. Max_Line_Length);

   type Token is record
      Text   : String (1 .. Max_Token_Length) := (others => ' ');
      Length : Natural range 0 .. Max_Token_Length := 0;
   end record;

   type Interpret_Result is (OK, Unknown_Word, Stack_Error, Halted);

   procedure Interpret_Line
     (VM   : in out Forth_VM.VM_State;
      Line : in     Line_Buffer;
      Len  : in     Natural;
      Res  :    out Interpret_Result)
     with Pre  => Forth_VM.VM_Is_Valid (VM) and then Len <= Max_Line_Length,
          Post => Forth_VM.VM_Is_Valid (VM);

end Forth_Interpreter;
