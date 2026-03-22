package body Bounded_Stacks
  with SPARK_Mode => On
is

   function Is_Empty (S : Stack) return Boolean is
     (S.Top = 0);

   function Is_Full (S : Stack) return Boolean is
     (S.Top = Max_Depth);

   function Size (S : Stack) return Natural is
     (S.Top);

   function Peek (S : Stack) return Integer is
     (S.Data (S.Top));

   function Element_At (S : Stack; I : Positive) return Integer is
     (S.Data (I));

   procedure Push (S : in out Stack; Value : in Integer) is
   begin
      S.Top := S.Top + 1;
      S.Data (S.Top) := Value;
   end Push;

   procedure Pop (S : in out Stack; Value : out Integer) is
   begin
      Value := S.Data (S.Top);
      S.Top := S.Top - 1;
   end Pop;

end Bounded_Stacks;
