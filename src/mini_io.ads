package Mini_IO is
   procedure Put (S : String);
   procedure Put_Line (S : String);
   procedure Put_Int (Value : Integer);
   procedure Get_Line (Buffer : out String; Last : out Natural);
   procedure New_Line;
   procedure Flush;
end Mini_IO;
