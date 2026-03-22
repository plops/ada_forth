generic
   Max_Depth : Positive;
package Bounded_Stacks
  with SPARK_Mode => On
is
   type Stack is private;

   function Is_Empty (S : Stack) return Boolean;
   function Is_Full  (S : Stack) return Boolean;
   function Size     (S : Stack) return Natural;
   function Peek     (S : Stack) return Integer
     with Pre => not Is_Empty (S);

   --  Ghost function: returns the element at logical position I (1-based)
   function Element_At (S : Stack; I : Positive) return Integer
     with Ghost,
          Pre => I >= 1 and then I <= Size (S);

   procedure Push (S : in out Stack; Value : in Integer)
     with Pre  => not Is_Full (S),
          Post => Size (S) = Size (S'Old) + 1
                  and then Peek (S) = Value
                  and then (for all I in 1 .. Size (S'Old) =>
                              Element_At (S, I) = Element_At (S'Old, I));

   procedure Pop (S : in out Stack; Value : out Integer)
     with Pre  => not Is_Empty (S),
          Post => Size (S) = Size (S'Old) - 1
                  and then Value = Peek (S'Old)
                  and then (for all I in 1 .. Size (S) =>
                              Element_At (S, I) = Element_At (S'Old, I));

   Empty_Stack : constant Stack;

private
   subtype Depth_Range is Natural range 0 .. Max_Depth;
   subtype Index_Range is Positive range 1 .. Max_Depth;
   type Data_Array is array (Index_Range) of Integer;

   type Stack is record
      Data : Data_Array := (others => 0);
      Top  : Depth_Range := 0;
   end record;

   Empty_Stack : constant Stack := (Data => (others => 0), Top => 0);
end Bounded_Stacks;
