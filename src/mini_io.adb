with System;

package body Mini_IO is

   function C_Write (Fd : Integer; Str : System.Address; Len : Integer) return Integer;
   pragma Import (C, C_Write, "write");

   function C_Read (Fd : Integer; Buffer : System.Address; Len : Integer) return Integer;
   pragma Import (C, C_Read, "read");

   procedure Put (S : String) is
      Discard : Integer;
   begin
      Discard := C_Write (1, S'Address, S'Length);
   end Put;

   procedure Put_Line (S : String) is
   begin
      Put (S);
      New_Line;
   end Put_Line;

   procedure New_Line is
      LF : constant String := "" & ASCII.LF;
      Discard : Integer;
   begin
      Discard := C_Write (1, LF'Address, 1);
   end New_Line;

   procedure Put_Int (Value : Integer) is
      Buffer : String (1 .. 12);
      Last   : Natural := Buffer'Last;
      V      : Integer := abs (Value);
      Neg    : constant Boolean := Value < 0;
   begin
      if V = 0 then
         Buffer (Last) := '0';
         Last := Last - 1;
      else
         while V > 0 loop
            Buffer (Last) := Character'Val (Character'Pos ('0') + (V mod 10));
            V := V / 10;
            Last := Last - 1;
         end loop;
      end if;

      if Neg then
         Buffer (Last) := '-';
         Last := Last - 1;
      end if;

      Put (Buffer (Last + 1 .. Buffer'Last));
   end Put_Int;

   procedure Get_Line (Buffer : out String; Last : out Natural) is
      C : Character;
      Len : Integer;
      Count : Natural := 0;
   begin
      Last := 0;
      loop
         Len := C_Read (0, C'Address, 1);
         if Len <= 0 then --  EOF or Error
            exit;
         end if;
         exit when C = ASCII.LF or else C = ASCII.CR;
         if Count < Buffer'Length then
            Count := Count + 1;
            Buffer (Buffer'First + Count - 1) := C;
         end if;
      end loop;
      Last := Buffer'First + Count - 1;
   end Get_Line;

   procedure Flush is
   begin
      null; --  Standard output is typically line-buffered or unbuffered at this level
   end Flush;

end Mini_IO;
