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

   function Token_Equals (Tok : Token; S : String) return Boolean
     with Pre => S'Length <= Max_Token_Length
                 and then S'First = 1
   is
      Result : Boolean;
   begin
      if Tok.Length /= S'Length then
         return False;
      end if;
      Result := True;
      for I in 1 .. Tok.Length loop
         pragma Loop_Invariant
           (Result = (for all K in 1 .. I - 1 =>
              To_Upper (Tok.Text (K)) =
                To_Upper (S (S'First + K - 1))));
         if To_Upper (Tok.Text (I)) /=
            To_Upper (S (S'First + I - 1))
         then
            Result := False;
         end if;
      end loop;
      return Result;
   end Token_Equals;

   procedure Lookup
     (Dict      : in     Forth_VM.Dict_Array;
      Dict_Sz   : in     Natural;
      Tok       : in     Token;
      Found     :    out Boolean;
      Entry_Idx :    out Natural)
     with Pre  => Dict_Sz <= Forth_VM.Max_Dict_Entries
                  and then Tok.Length >= 1
                  and then Tok.Length <= Max_Token_Length,
          Post => (if Found then Entry_Idx in 1 .. Dict_Sz)
   is
      Match : Boolean;
   begin
      Found     := False;
      Entry_Idx := 0;

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
               Found     := True;
               Entry_Idx := I;
               return;
            end if;
         end if;
      end loop;
   end Lookup;

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

   procedure Create_Variable
     (VM  : in out Forth_VM.VM_State;
      Tok : in     Token;
      OK  :    out Boolean)
     with Pre  => Forth_VM.VM_Is_Valid (VM)
                  and then not VM.Compiling
                  and then Tok.Length >= 1,
          Post => Forth_VM.VM_Is_Valid (VM)
   is
      WN : Forth_VM.Word_Name := (others => ' ');
   begin
      WN (1 .. Tok.Length) := Tok.Text (1 .. Tok.Length);
      Forth_VM.Create_Variable (VM, WN, Tok.Length, OK);
   end Create_Variable;

   procedure Compile_Token
     (VM  : in out Forth_VM.VM_State;
      Tok : in     Token;
      OK  :    out Boolean)
     with Pre  => Forth_VM.VM_Is_Valid (VM)
                  and then VM.Compiling
                  and then Tok.Length >= 1
                  and then VM.Comp_Start <= VM.Code_Size,
          Post => Forth_VM.VM_Is_Valid (VM)
   is
      Found     : Boolean;
      Eidx      : Natural;
      Value     : Integer;
      Parsed    : Boolean;
      Emit_OK   : Boolean;
      Save_Start : constant Natural := VM.Comp_Start;
   begin
      OK := True;
      Lookup (VM.Dictionary, VM.Dict_Size, Tok, Found, Eidx);

      if Found then
         case VM.Dictionary (Eidx).Kind is
            when Forth_VM.Primitive_Entry =>
               Forth_VM.Emit_Instruction
                 (VM,
                  (Kind    => Forth_VM.Inst_Primitive,
                   Op      => VM.Dictionary (Eidx).Op,
                   Operand => 0),
                  Emit_OK);
               if not Emit_OK then
                  --  Code space full: roll back
                  VM.Code_Size := Save_Start;
                  VM.Compiling := False;
                  OK := False;
               end if;
            when Forth_VM.User_Defined_Entry =>
               Forth_VM.Emit_Instruction
                 (VM,
                  (Kind    => Forth_VM.Inst_Call,
                   Op      => Forth_VM.Op_Noop,
                   Operand => Eidx),
                  Emit_OK);
               if not Emit_OK then
                  VM.Code_Size := Save_Start;
                  VM.Compiling := False;
                  OK := False;
               end if;
            when Forth_VM.Variable_Entry =>
               Forth_VM.Emit_Instruction
                 (VM,
                  (Kind    => Forth_VM.Inst_Var_Addr,
                   Op      => Forth_VM.Op_Noop,
                   Operand => VM.Dictionary (Eidx).Var_Addr),
                  Emit_OK);
               if not Emit_OK then
                  VM.Code_Size := Save_Start;
                  VM.Compiling := False;
                  OK := False;
               end if;
         end case;
      else
         Try_Parse_Integer (Tok, Value, Parsed);
         if Parsed then
            Forth_VM.Emit_Instruction
              (VM,
               (Kind    => Forth_VM.Inst_Literal,
                Op      => Forth_VM.Op_Noop,
                Operand => Value),
               Emit_OK);
            if not Emit_OK then
               VM.Code_Size := Save_Start;
               VM.Compiling := False;
               OK := False;
            end if;
         else
            --  Unknown word during compilation: roll back
            VM.Code_Size := Save_Start;
            VM.Compiling := False;
            OK := False;
         end if;
      end if;
   end Compile_Token;

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
         pragma Loop_Invariant (Pos in 1 .. Len);
         pragma Loop_Invariant (Res = OK);

         Skip_Spaces (Line, Len, Pos);
         exit when Pos > Len;

         Read_Token (Line, Len, Pos, Tok);

         if VM.Compiling then
            --  COMPILATION MODE
            if Token_Equals (Tok, ";") then
               --  End of colon definition
               if VM.Comp_Name_Len > 0 then
                  declare
                     Fin_OK : Boolean;
                  begin
                     Forth_VM.Finalize_Definition (VM, Fin_OK);
                     if not Fin_OK then
                        Res := Compile_Error;
                     end if;
                  end;
               else
                  Res := Compile_Error;
               end if;
            else
               --  Compile the token (handles primitives, user-defined, variables, literals)
               if VM.Comp_Start <= VM.Code_Size then
                  declare
                     Comp_OK : Boolean;
                  begin
                     Compile_Token (VM, Tok, Comp_OK);
                     if not Comp_OK then
                        Res := Compile_Error;
                     end if;
                  end;
               else
                  Res := Compile_Error;
               end if;
            end if;

         else
            --  INTERPRETATION MODE
            if Token_Equals (Tok, ":") then
               --  Enter compilation mode: read next token as word name
               Skip_Spaces (Line, Len, Pos);
               if Pos > Len then
                  --  ":" is last token with no name following
                  Res := Compile_Error;
               else
                  declare
                     Name_Tok : Token;
                     WN : Forth_VM.Word_Name := (others => ' ');
                  begin
                     Read_Token (Line, Len, Pos, Name_Tok);
                     WN (1 .. Name_Tok.Length) :=
                       Name_Tok.Text (1 .. Name_Tok.Length);
                     Forth_VM.Enter_Compilation_Mode
                       (VM, WN, Name_Tok.Length);
                  end;
               end if;

            elsif Token_Equals (Tok, "VARIABLE") then
               --  Create a new variable
               Skip_Spaces (Line, Len, Pos);
               if Pos > Len then
                  Res := Compile_Error;
               else
                  declare
                     Var_Tok : Token;
                     Var_OK  : Boolean;
                  begin
                     Read_Token (Line, Len, Pos, Var_Tok);
                     Create_Variable (VM, Var_Tok, Var_OK);
                     if not Var_OK then
                        Res := Compile_Error;
                     end if;
                  end;
               end if;

            else
               --  Standard dispatch: lookup token in dictionary
               declare
                  Found     : Boolean;
                  Entry_Idx : Natural;
                  Success   : Boolean;
               begin
                  Lookup (VM.Dictionary, VM.Dict_Size, Tok,
                          Found, Entry_Idx);

                  if Found then
                     case VM.Dictionary (Entry_Idx).Kind is
                        when Forth_VM.Primitive_Entry =>
                           Forth_VM.Dispatch_Primitive
                             (VM, VM.Dictionary (Entry_Idx).Op, Success);
                           if not Success then
                              Res := Stack_Error;
                           end if;

                        when Forth_VM.User_Defined_Entry =>
                           if VM.Dictionary (Entry_Idx).Body_Start >= 1
                             and then VM.Dictionary (Entry_Idx).Body_Len >= 1
                             and then VM.Dictionary (Entry_Idx).Body_Start
                                      <= Forth_VM.Max_Code_Size
                             and then VM.Dictionary (Entry_Idx).Body_Len
                                      <= Forth_VM.Max_Code_Size
                                         - VM.Dictionary (Entry_Idx).Body_Start
                                         + 1
                             and then VM.Dictionary (Entry_Idx).Body_Start
                                      + VM.Dictionary (Entry_Idx).Body_Len - 1
                                      <= VM.Code_Size
                             and then Forth_VM.Return_Stacks.Is_Empty
                                        (VM.Return_Stack)
                           then
                              Forth_VM.Execute_Word
                                (VM,
                                 VM.Dictionary (Entry_Idx).Body_Start,
                                 VM.Dictionary (Entry_Idx).Body_Len,
                                 Success);
                              if not Success then
                                 Res := Stack_Error;
                              end if;
                           else
                              Res := Stack_Error;
                           end if;

                        when Forth_VM.Variable_Entry =>
                           if not Forth_VM.Data_Stacks.Is_Full
                                    (VM.Data_Stack)
                           then
                              Forth_VM.Data_Stacks.Push
                                (VM.Data_Stack,
                                 VM.Dictionary (Entry_Idx).Var_Addr);
                           else
                              Res := Stack_Error;
                           end if;
                     end case;
                  else
                     --  Try integer literal
                     declare
                        Value  : Integer;
                        Parsed : Boolean;
                     begin
                        Try_Parse_Integer (Tok, Value, Parsed);
                        if Parsed then
                           if not Forth_VM.Data_Stacks.Is_Full
                                    (VM.Data_Stack)
                           then
                              Forth_VM.Data_Stacks.Push
                                (VM.Data_Stack, Value);
                           else
                              Res := Stack_Error;
                           end if;
                        else
                           Res := Unknown_Word;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end if;
      end loop;
   end Interpret_Line;

end Forth_Interpreter;
