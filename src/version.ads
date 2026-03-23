--  src/version.ads
--  This file is overwritten by CI during release builds.
package Version
  with SPARK_Mode => Off
is
   Name  : constant String := "ada-forth";
   Value : constant String := "dev";
   --  CI replaces "dev" with the tag version, e.g., "1.0.0"
end Version;
