with Ada.Text_IO;

package body Forth_VM
  with SPARK_Mode => On
is

   Int_Min : constant Long_Long_Integer := Long_Long_Integer (Integer'First);
   Int_Max : constant Long_Long_Integer := Long_Long_Integer (Integer'Last);

   procedure Initialize (VM : out VM_State) is
      Blank_Name : constant Word_Name := (others => ' ');

      function Make_Prim (C1 : Character;
                          Len : Natural;
                          P  : Primitive_Op) return Dict_Entry
        with Pre  => Len in 1 .. Max_Word_Length,
             Post => Make_Prim'Result.Length = Len
      is
         N : Word_Name := Blank_Name;
      begin
         N (1) := C1;
         return (Name       => N,
                 Length     => Len,
                 Kind       => Primitive_Entry,
                 Op         => P,
                 Body_Start => 0,
                 Body_Len   => 0,
                 Var_Addr   => 0);
      end Make_Prim;

      function Make_Prim3 (C1, C2, C3 : Character;
                           Len : Natural;
                           P   : Primitive_Op) return Dict_Entry
        with Pre  => Len in 1 .. Max_Word_Length,
             Post => Make_Prim3'Result.Length = Len
      is
         N : Word_Name := Blank_Name;
      begin
         N (1) := C1;
         N (2) := C2;
         N (3) := C3;
         return (Name       => N,
                 Length     => Len,
                 Kind       => Primitive_Entry,
                 Op         => P,
                 Body_Start => 0,
                 Body_Len   => 0,
                 Var_Addr   => 0);
      end Make_Prim3;

      function Make_Prim4 (C1, C2, C3, C4 : Character;
                           Len : Natural;
                           P   : Primitive_Op) return Dict_Entry
        with Pre  => Len in 1 .. Max_Word_Length,
             Post => Make_Prim4'Result.Length = Len
      is
         N : Word_Name := Blank_Name;
      begin
         N (1) := C1;
         N (2) := C2;
         N (3) := C3;
         N (4) := C4;
         return (Name       => N,
                 Length     => Len,
                 Kind       => Primitive_Entry,
                 Op         => P,
                 Body_Start => 0,
                 Body_Len   => 0,
                 Var_Addr   => 0);
      end Make_Prim4;
   begin
      VM := (Data_Stack    => Data_Stacks.Empty_Stack,
             Return_Stack  => Return_Stacks.Empty_Stack,
             Dictionary    => (1  => Make_Prim ('+', 1, Op_Add),
                               2  => Make_Prim ('-', 1, Op_Sub),
                               3  => Make_Prim ('*', 1, Op_Mul),
                               4  => Make_Prim3 ('D', 'U', 'P', 3, Op_Dup),
                               5  => Make_Prim4 ('D', 'R', 'O', 'P', 4, Op_Drop),
                               6  => Make_Prim4 ('S', 'W', 'A', 'P', 4, Op_Swap),
                               7  => Make_Prim ('.', 1, Op_Dot),
                               8  => Make_Prim ('>', 1, Op_Greater),
                               9  => Make_Prim ('<', 1, Op_Less),
                               10 => Make_Prim ('=', 1, Op_Equal),
                               11 => Make_Prim ('!', 1, Op_Store),
                               12 => Make_Prim ('@', 1, Op_Fetch),
                               others => <>),
             Dict_Size     => 12,
             Code          => (others => <>),
             Code_Size     => 0,
             Memory        => (others => 0),
             Var_Count     => 0,
             Compiling     => False,
             Comp_Start    => 0,
             Comp_Name     => Blank_Name,
             Comp_Name_Len => 0,
             Halted        => False);
   end Initialize;

   procedure Execute_Add (VM : in out VM_State; Success : out Boolean) is
      A, B : Integer;
      R    : Long_Long_Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      R := Long_Long_Integer (A) + Long_Long_Integer (B);
      if R in Int_Min .. Int_Max then
         Data_Stacks.Push (VM.Data_Stack, Integer (R));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, B);
         Data_Stacks.Push (VM.Data_Stack, A);
         Success := False;
      end if;
   end Execute_Add;

   procedure Execute_Sub (VM : in out VM_State; Success : out Boolean) is
      A, B : Integer;
      R    : Long_Long_Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      R := Long_Long_Integer (B) - Long_Long_Integer (A);
      if R in Int_Min .. Int_Max then
         Data_Stacks.Push (VM.Data_Stack, Integer (R));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, B);
         Data_Stacks.Push (VM.Data_Stack, A);
         Success := False;
      end if;
   end Execute_Sub;

   procedure Execute_Mul (VM : in out VM_State; Success : out Boolean) is
      A, B : Integer;
      R    : Long_Long_Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      R := Long_Long_Integer (A) * Long_Long_Integer (B);
      if R in Int_Min .. Int_Max then
         Data_Stacks.Push (VM.Data_Stack, Integer (R));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, B);
         Data_Stacks.Push (VM.Data_Stack, A);
         Success := False;
      end if;
   end Execute_Mul;

   procedure Execute_Dup (VM : in out VM_State) is
      V : Integer;
   begin
      V := Data_Stacks.Peek (VM.Data_Stack);
      Data_Stacks.Push (VM.Data_Stack, V);
   end Execute_Dup;

   procedure Execute_Drop (VM : in out VM_State) is
      Discard : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, Discard);
   end Execute_Drop;

   procedure Execute_Swap (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      Data_Stacks.Push (VM.Data_Stack, A);
      Data_Stacks.Push (VM.Data_Stack, B);
   end Execute_Swap;

   procedure Execute_Dot (VM : in out VM_State)
     with SPARK_Mode => Off
   is
      V : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, V);
      Ada.Text_IO.Put (Integer'Image (V) & " ");
   end Execute_Dot;

   procedure Execute_Greater (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      if B > A then
         Data_Stacks.Push (VM.Data_Stack, -1);
      else
         Data_Stacks.Push (VM.Data_Stack, 0);
      end if;
   end Execute_Greater;

   procedure Execute_Less (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      if B < A then
         Data_Stacks.Push (VM.Data_Stack, -1);
      else
         Data_Stacks.Push (VM.Data_Stack, 0);
      end if;
   end Execute_Less;

   procedure Execute_Equal (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      if A = B then
         Data_Stacks.Push (VM.Data_Stack, -1);
      else
         Data_Stacks.Push (VM.Data_Stack, 0);
      end if;
   end Execute_Equal;

   procedure Execute_Store (VM : in out VM_State; Success : out Boolean) is
      Addr, Value : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, Addr);
      Data_Stacks.Pop (VM.Data_Stack, Value);
      if Addr >= 0 and then Addr < VM.Var_Count then
         VM.Memory (Addr) := Value;
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, Value);
         Data_Stacks.Push (VM.Data_Stack, Addr);
         Success := False;
      end if;
   end Execute_Store;

   procedure Execute_Fetch (VM : in out VM_State; Success : out Boolean) is
      Addr : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, Addr);
      if Addr >= 0 and then Addr < VM.Var_Count then
         Data_Stacks.Push (VM.Data_Stack, VM.Memory (Addr));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, Addr);
         Success := False;
      end if;
   end Execute_Fetch;

   procedure Emit_Instruction
     (VM   : in out VM_State;
      Inst : in     Instruction;
      OK   :    out Boolean)
   is
   begin
      if VM.Code_Size < Max_Code_Size then
         VM.Code_Size := VM.Code_Size + 1;
         VM.Code (VM.Code_Size) := Inst;
         OK := True;
      else
         OK := False;
      end if;
   end Emit_Instruction;

   procedure Finalize_Definition
     (VM  : in out VM_State;
      OK  :    out Boolean)
   is
   begin
      if VM.Comp_Start > VM.Code_Size
        or else VM.Code_Size - VM.Comp_Start < 1
        or else VM.Dict_Size = Max_Dict_Entries
      then
         --  Empty body or dictionary full: roll back and fail
         if VM.Comp_Start <= Max_Code_Size then
            VM.Code_Size := VM.Comp_Start;
         end if;
         VM.Compiling := False;
         OK := False;
      else
         declare
            Body_L   : constant Positive := VM.Code_Size - VM.Comp_Start;
            Old_Size : constant Natural  := VM.Dict_Size;
         begin
            VM.Dict_Size := Old_Size + 1;
            VM.Dictionary (VM.Dict_Size) :=
              (Name       => VM.Comp_Name,
               Length     => VM.Comp_Name_Len,
               Kind       => User_Defined_Entry,
               Op         => Op_Noop,
               Body_Start => VM.Comp_Start + 1,
               Body_Len   => Body_L,
               Var_Addr   => 0);

            pragma Assert (VM.Dictionary (VM.Dict_Size).Length > 0);

            VM.Compiling := False;
            OK := True;
         end;
      end if;
   end Finalize_Definition;

   procedure Dispatch_Primitive
     (VM      : in out VM_State;
      Op      : in     Primitive_Op;
      Success :    out Boolean)
   is
      Sz : constant Natural := Data_Stacks.Size (VM.Data_Stack);
   begin
      Success := True;
      case Op is
         when Op_Add =>
            if Sz >= 2 then
               Execute_Add (VM, Success);
            else
               Success := False;
            end if;
         when Op_Sub =>
            if Sz >= 2 then
               Execute_Sub (VM, Success);
            else
               Success := False;
            end if;
         when Op_Mul =>
            if Sz >= 2 then
               Execute_Mul (VM, Success);
            else
               Success := False;
            end if;
         when Op_Dup =>
            if not Data_Stacks.Is_Empty (VM.Data_Stack)
              and then not Data_Stacks.Is_Full (VM.Data_Stack)
            then
               Execute_Dup (VM);
            else
               Success := False;
            end if;
         when Op_Drop =>
            if not Data_Stacks.Is_Empty (VM.Data_Stack) then
               Execute_Drop (VM);
            else
               Success := False;
            end if;
         when Op_Swap =>
            if Sz >= 2 then
               Execute_Swap (VM);
            else
               Success := False;
            end if;
         when Op_Dot =>
            if not Data_Stacks.Is_Empty (VM.Data_Stack) then
               Execute_Dot (VM);
            else
               Success := False;
            end if;
         when Op_Greater =>
            if Sz >= 2 then
               Execute_Greater (VM);
            else
               Success := False;
            end if;
         when Op_Less =>
            if Sz >= 2 then
               Execute_Less (VM);
            else
               Success := False;
            end if;
         when Op_Equal =>
            if Sz >= 2 then
               Execute_Equal (VM);
            else
               Success := False;
            end if;
         when Op_Store =>
            if Sz >= 2 then
               Execute_Store (VM, Success);
            else
               Success := False;
            end if;
         when Op_Fetch =>
            if not Data_Stacks.Is_Empty (VM.Data_Stack) then
               Execute_Fetch (VM, Success);
            else
               Success := False;
            end if;
         when Op_Noop =>
            null;
      end case;
   end Dispatch_Primitive;

   procedure Execute_Word
     (VM         : in out VM_State;
      Body_Start : in     Positive;
      Body_Len   : in     Positive;
      Success    :    out Boolean)
   is
      subtype PC_Range is Natural range 1 .. Max_Code_Size + 1;
      PC       : PC_Range := Body_Start;
      End_Addr : PC_Range := Body_Start + Body_Len;
      Steps    : Natural := 0;
      Cur_Inst : Instruction;
      Op_OK    : Boolean;
      Done     : Boolean := False;
   begin
      Success := True;

      while Success and then not Done loop
         pragma Loop_Invariant (VM_Is_Valid (VM));
         pragma Loop_Invariant (PC in PC_Range);
         pragma Loop_Invariant (End_Addr in PC_Range);
         pragma Loop_Invariant (Steps <= Max_Exec_Steps);

         --  Return from completed word body
         if PC >= End_Addr then
            if Return_Stacks.Is_Empty (VM.Return_Stack) then
               Done := True;
            elsif Return_Stacks.Size (VM.Return_Stack) < 2 then
               Success := False;
               Done := True;
            else
               declare
                  Saved_End, Saved_PC : Integer;
               begin
                  Return_Stacks.Pop (VM.Return_Stack, Saved_End);
                  Return_Stacks.Pop (VM.Return_Stack, Saved_PC);
                  if Saved_PC >= 1 and then Saved_PC <= Max_Code_Size + 1
                    and then Saved_End >= 1 and then Saved_End <= Max_Code_Size + 1
                  then
                     PC := Saved_PC;
                     End_Addr := Saved_End;
                  else
                     Success := False;
                     Done := True;
                  end if;
               end;
            end if;
         elsif PC > Max_Code_Size then
            --  PC out of code bounds
            Success := False;
            Done := True;
         else
            --  Fuel check
            if Steps >= Max_Exec_Steps then
               Success := False;
               Done := True;
            else
               Steps := Steps + 1;
                  Cur_Inst := VM.Code (PC);

                  case Cur_Inst.Kind is
                     when Inst_Call =>
                        if Cur_Inst.Operand in 1 .. VM.Dict_Size
                          and then VM.Dictionary (Cur_Inst.Operand).Kind =
                                     User_Defined_Entry
                          and then VM.Dictionary (Cur_Inst.Operand).Body_Start >= 1
                          and then VM.Dictionary (Cur_Inst.Operand).Body_Len >= 1
                          and then VM.Dictionary (Cur_Inst.Operand).Body_Start
                                   <= Max_Code_Size
                          and then VM.Dictionary (Cur_Inst.Operand).Body_Len
                                   <= Max_Code_Size
                                      - VM.Dictionary (Cur_Inst.Operand).Body_Start
                                      + 1
                          and then VM.Dictionary (Cur_Inst.Operand).Body_Start
                                   + VM.Dictionary (Cur_Inst.Operand).Body_Len - 1
                                   <= VM.Code_Size
                          and then Return_Stacks.Size (VM.Return_Stack)
                                   <= Return_Capacity - 2
                        then
                           pragma Assert (PC + 1 >= 1);
                           pragma Assert (PC + 1 <= Max_Code_Size + 1);
                           Return_Stacks.Push (VM.Return_Stack, PC + 1);
                           Return_Stacks.Push (VM.Return_Stack, End_Addr);
                           declare
                              New_Start : constant Positive :=
                                VM.Dictionary (Cur_Inst.Operand).Body_Start;
                              New_Len   : constant Positive :=
                                VM.Dictionary (Cur_Inst.Operand).Body_Len;
                           begin
                              pragma Assert (New_Start >= 1);
                              pragma Assert (New_Start + New_Len >= 1);
                              pragma Assert (New_Start + New_Len <= Max_Code_Size + 1);
                              End_Addr := New_Start + New_Len;
                              PC := New_Start;
                           end;
                        else
                           Success := False;
                           Done := True;
                        end if;

                     when Inst_Primitive =>
                        Dispatch_Primitive (VM, Cur_Inst.Op, Op_OK);
                        if not Op_OK then
                           Success := False;
                           Done := True;
                        else
                           if PC < Max_Code_Size + 1 then
                              PC := PC + 1;
                           else
                              Success := False;
                              Done := True;
                           end if;
                        end if;

                     when Inst_Literal =>
                        if not Data_Stacks.Is_Full (VM.Data_Stack) then
                           Data_Stacks.Push (VM.Data_Stack, Cur_Inst.Operand);
                           if PC < Max_Code_Size + 1 then
                              PC := PC + 1;
                           else
                              Success := False;
                              Done := True;
                           end if;
                        else
                           Success := False;
                           Done := True;
                        end if;

                     when Inst_Branch_If_Zero =>
                        if not Data_Stacks.Is_Empty (VM.Data_Stack) then
                           declare
                              V : Integer;
                           begin
                              Data_Stacks.Pop (VM.Data_Stack, V);
                              if V = 0 then
                                 if Cur_Inst.Operand >= 1
                                   and then Cur_Inst.Operand <= Max_Code_Size + 1
                                 then
                                    PC := Cur_Inst.Operand;
                                 else
                                    Success := False;
                                    Done := True;
                                 end if;
                              else
                                 if PC < Max_Code_Size + 1 then
                                    PC := PC + 1;
                                 else
                                    Success := False;
                                    Done := True;
                                 end if;
                              end if;
                           end;
                        else
                           Success := False;
                           Done := True;
                        end if;

                     when Inst_Jump =>
                        if Cur_Inst.Operand >= 1
                          and then Cur_Inst.Operand <= Max_Code_Size + 1
                        then
                           PC := Cur_Inst.Operand;
                        else
                           Success := False;
                           Done := True;
                        end if;

                     when Inst_Var_Addr =>
                        if not Data_Stacks.Is_Full (VM.Data_Stack) then
                           Data_Stacks.Push (VM.Data_Stack, Cur_Inst.Operand);
                           if PC < Max_Code_Size + 1 then
                              PC := PC + 1;
                           else
                              Success := False;
                              Done := True;
                           end if;
                        else
                           Success := False;
                           Done := True;
                        end if;

                     when Inst_Noop =>
                        if PC < Max_Code_Size + 1 then
                           PC := PC + 1;
                        else
                           Success := False;
                           Done := True;
                        end if;
                  end case;
            end if;
         end if;
      end loop;

      --  Drain return stack on error
      if not Success then
         while not Return_Stacks.Is_Empty (VM.Return_Stack) loop
            pragma Loop_Invariant (VM_Is_Valid (VM));
            declare
               Discard : Integer;
            begin
               Return_Stacks.Pop (VM.Return_Stack, Discard);
            end;
         end loop;
      end if;
   end Execute_Word;

   procedure Create_Variable
     (VM       : in out VM_State;
      Name     : in     Word_Name;
      Name_Len : in     Positive;
      OK       :    out Boolean)
   is
      New_Idx : Positive;
   begin
      if VM.Dict_Size = Max_Dict_Entries
        or else VM.Var_Count = Max_Variables
      then
         OK := False;
         return;
      end if;

      New_Idx := VM.Dict_Size + 1;

      VM.Dictionary (New_Idx) :=
        (Name       => Name,
         Length     => Name_Len,
         Kind       => Variable_Entry,
         Op         => Op_Noop,
         Body_Start => 0,
         Body_Len   => 0,
         Var_Addr   => VM.Var_Count);

      VM.Dict_Size := New_Idx;

      VM.Memory (VM.Var_Count) := 0;
      VM.Var_Count := VM.Var_Count + 1;

      OK := True;
   end Create_Variable;

   procedure Enter_Compilation_Mode
     (VM       : in out VM_State;
      Name     : in     Word_Name;
      Name_Len : in     Positive)
   is
   begin
      VM.Compiling     := True;
      VM.Comp_Start    := VM.Code_Size;
      VM.Comp_Name     := Name;
      VM.Comp_Name_Len := Name_Len;
      pragma Assert (VM.Comp_Name_Len > 0);
   end Enter_Compilation_Mode;

end Forth_VM;
