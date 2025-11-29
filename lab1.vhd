---------------------------------------------------------------------
--
--  Fichero:
--    lab1.vhd  07/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 1
--
--  Notas de diseño:
--
---------------------------------------------------------------------
  
library ieee;
use ieee.std_logic_1164.all;

entity lab1 is
  port (
    sws    :  in std_logic_vector(15 downto 0);
    btnL   :  in std_logic;
    btnR   :  in std_logic;
    leds   : out std_logic_vector(15 downto 0);
    an_n   : out std_logic_vector(3 downto 0);  
    segs_n : out std_logic_vector(7 downto 0)
  );
end lab1;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of lab1 is

  signal opCode  : std_logic_vector(1 downto 0); 
  signal leftOp  : signed(7 downto 0);
  signal rightOp : signed(7 downto 0);
  signal result  : signed(15 downto 0);
  signal digit   : std_logic_vector(3 downto 0);
  
begin

  opCode  <= ...;
  leftOp  <= ...;
  rightOp <= ...;

  ALU:
  with opCode select
   result <= 
     ...;
    
  leds  <= ...;
  digit <= ...; 
    
  an_n  <= ...;

  converter : bin2segs
  port map ( en => ..., bin => ..., dp => ..., segs_n => ... ); 
    
end syn;	