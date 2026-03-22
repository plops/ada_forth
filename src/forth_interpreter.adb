package body Forth_Interpreter
  with SPARK_Mode => On
is
   use type Forth_VM.Primitive_Op;

   procedure Skip_Spaces
     (Line : in     Line_Buffer;
      Len  : in     Natural;
      Pos  : in out Natural)
     with Pre  => Pos in 1 .. Len + 1
                  and then Len <= Max_Line_Length,
          Post => Pos in Pos'Old .. Len + 1
                  and then (Pos > Len or else Line (Pos) /= ' ')
   is
   begin
      while Pos <= Len and then Line (Pos) = ' ' loop
         pragma Loop_Invariant (Pos in Pos'Loop_Entry .. Len);
         Pos := Pos + 1;
      end loop;
   end Skip_Spaces;

   procedure Read_Token
     (Line : in     Line_Buffer;
      Len  : in     Natural;
      Pos  : in out Natural;
      Tok  :    out Token)
     with Pre  => Pos >= 1 and then Pos <= Len
                  and then Len <= Max_Line_Length
                  and then Line (Pos) /= ' ',
          Post => Pos in Pos'Old + 1 .. Len + 1
                  and then Tok.Length >= 1
                  and then Tok.Length <= Max_Token_Length
   is
      Start : constant Natural := Pos;
      Count : Natural := 0;
   begin
      Tok := (Text => (others => ' '), Length => 0);

      while Pos <= Len and then Line (Pos) /= ' ' loop
         pragma Loop_Invariant (Pos in Start .. Len);
         pragma Loop_Invariant (Count <= Pos - Start);
         pragma Loop_Invariant (Count <= Max_Token_Length);
         if Count < Max_Token_Length then
            Count := Count + 1;
            Tok.Text (Count) := Line (Pos);
         end if;
         Pos := Pos + 1;
      end loop;

      --  At least one character was consumed (precondition: Line(Pos) /= ' ')
      --  so Pos > Start, meaning Count >= 1 (first iteration always increments
      --  Count since Count starts at 0 < Max_Token_Length).
      --  But the prover may not see this, so we guard:
      if Count = 0 then
         Tok.Length := 1;
      else
         Tok.Length := Count;
      end if;
   end Read_Token;

   function To_Upper (C : Character) return Character is
     (if C in 'a' .. 'z'
      then Character'Val (Character'Pos (C) - Character'Pos ('a')
                          + Character'Pos ('A'))
      else C);

   procedure Lookup
     (Dict     : in     Forth_VM.Dict_Array;
      Dict_Sz  : in     Natural;
      Tok      : in     Token;
      Found    :    out Boolean;
      Op       :    out Forth_VM.Primitive_Op)
     with Pre  => Dict_Sz <= Forth_VM.Max_Dict_Entries
                  and then Tok.Length >= 1
                  and then Tok.Length <= Max_Token_Length
   is
      Match : Boolean;
   begin
      Found := False;
      Op    := Forth_VM.Op_Noop;

      for I in 1 .. Dict_Sz loop
         pragma Loop_Invariant (not Found);
         if Dict (I).Length = Tok.Length then
            Match := True;
            for J in 1 .. Tok.Length loop
               pragma Loop_Invariant (Match = (for all K in 1 .. J - 1 =>
                  To_Upper (Tok.Text (K)) = To_Upper (Dict (I).Name (K))));
               if To_Upper (Tok.Text (J)) /= To_Upper (Dict (I).Name (J)) then
                  Match := False;
               end if;
            end loop;
            if Match then
               Found := True;
               Op    := Dict (I).Op;
               return;
            end if;
         end if;
      end loop;
   end Lookup;

   function Has_Enough_Operands
     (S  : Forth_VM.Data_Stacks.Stack;
      Op : Forth_VM.Primitive_Op) return Boolean
   is
      Sz : constant Natural := Forth_VM.Data_Stacks.Size (S);
   begin
      case Op is
         when Forth_VM.Op_Add | Forth_VM.Op_Sub | Forth_VM.Op_Mul
            | Forth_VM.Op_Swap =>
            return Sz >= 2;
         when Forth_VM.Op_Dup =>
            return Sz >= 1 and then not Forth_VM.Data_Stacks.Is_Full (S);
         when Forth_VM.Op_Drop | Forth_VM.Op_Dot =>
            return Sz >= 1;
         when Forth_VM.Op_Noop =>
            return True;
      end case;
   end Has_Enough_Operands;

   procedure Try_Parse_Integer
     (Tok    : in     Token;
      Value  :    out Integer;
      Parsed :    out Boolean)
     with Pre => Tok.Length >= 1 and then Tok.Length <= Max_Token_Length
   is
      Neg    : Boolean := False;
      Start  : Natural;
      Accum  : Long_Long_Integer := 0;
      Digit  : Long_Long_Integer;
      Int_Min : constant Long_Long_Integer := Long_Long_Integer (Integer'First);
      Int_Max : constant Long_Long_Integer := Long_Long_Integer (Integer'Last);
   begin
      Value  := 0;
      Parsed := False;

      if Tok.Text (1) = '-' then
         if Tok.Length = 1 then
            return;
         end if;
         Neg   := True;
         Start := 2;
      else
         Start := 1;
      end if;

      for I in Start .. Tok.Length loop
         pragma Loop_Invariant (Accum >= 0);
         if Tok.Text (I) not in '0' .. '9' then
            return;
         end if;
         Digit := Long_Long_Integer (Character'Pos (Tok.Text (I))
                                     - Character'Pos ('0'));
         if Accum > (Long_Long_Integer'Last - Digit) / 10 then
            return;
         end if;
         Accum := Accum * 10 + Digit;
      end loop;

      if Neg then
         Accum := -Accum;
      end if;

      if Accum in Int_Min .. Int_Max then
         Value  := Integer (Accum);
         Parsed := True;
      end if;
   end Try_Parse_Integer;

   procedure Dispatch
     (VM      : in out Forth_VM.VM_State;
      Op      : in     Forth_VM.Primitive_Op;
      Success :    out Boolean)
     with Pre  => Forth_VM.VM_Is_Valid (VM),
          Post => Forth_VM.VM_Is_Valid (VM)
   is
      Sz : constant Natural := Forth_VM.Data_Stacks.Size (VM.Data_Stack);
   begin
      Success := True;
      case Op is
         when Forth_VM.Op_Add =>
            if Sz >= 2 then
               Forth_VM.Execute_Add (VM, Success);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Sub =>
            if Sz >= 2 then
               Forth_VM.Execute_Sub (VM, Success);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Mul =>
            if Sz >= 2 then
               Forth_VM.Execute_Mul (VM, Success);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Dup =>
            if not Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack)
              and then not Forth_VM.Data_Stacks.Is_Full (VM.Data_Stack)
            then
               Forth_VM.Execute_Dup (VM);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Drop =>
            if not Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack) then
               Forth_VM.Execute_Drop (VM);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Swap =>
            if Sz >= 2 then
               Forth_VM.Execute_Swap (VM);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Dot =>
            if not Forth_VM.Data_Stacks.Is_Empty (VM.Data_Stack) then
               Forth_VM.Execute_Dot (VM);
            else
               Success := False;
            end if;
         when Forth_VM.Op_Noop =>
            null;
      end case;
   end Dispatch;

   procedure Interpret_Line
     (VM   : in out Forth_VM.VM_State;
      Line : in     Line_Buffer;
      Len  : in     Natural;
      Res  :    out Interpret_Result)
   is
      Pos : Natural := 1;
      Tok : Token;
   begin
      Res := OK;

      if Len = 0 then
         return;
      end if;

      while Pos <= Len and then Res = OK loop
         pragma Loop_Invariant (Forth_VM.VM_Is_Valid (VM));
         pragma Loop_Invariant (Pos in 1 .. Len + 1);
         pragma Loop_Invariant (Res = OK);

         Skip_Spaces (Line, Len, Pos);
         exit when Pos > Len;

         --  At this point Pos <= Len and Line(Pos) /= ' '
         --  (from Skip_Spaces postcondition)
         Read_Token (Line, Len, Pos, Tok);

         declare
            Found   : Boolean;
            Op      : Forth_VM.Primitive_Op;
            Success : Boolean;
         begin
            Lookup (VM.Dictionary, VM.Dict_Size, Tok, Found, Op);

            if Found then
               if Has_Enough_Operands (VM.Data_Stack, Op) then
                  Dispatch (VM, Op, Success);
                  if not Success then
                     Res := Stack_Error;
                  end if;
               else
                  Res := Stack_Error;
               end if;
            else
               declare
                  Value  : Integer;
                  Parsed : Boolean;
               begin
                  Try_Parse_Integer (Tok, Value, Parsed);
                  if Parsed then
                     if not Forth_VM.Data_Stacks.Is_Full (VM.Data_Stack) then
                        Forth_VM.Data_Stacks.Push (VM.Data_Stack, Value);
                     else
                        Res := Stack_Error;
                     end if;
                  else
                     Res := Unknown_Word;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Interpret_Line;

end Forth_Interpreter;
