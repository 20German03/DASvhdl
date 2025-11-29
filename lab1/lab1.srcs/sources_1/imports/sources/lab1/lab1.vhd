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
use ieee.numeric_std.all;

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

  opCode  <= btnL & btnR; --codigo de operacion que es el conjunto de btnl y btnr
  leftOp  <= signed(sws(15 downto 8)); --8 primeros bits de sws
  rightOp <= signed(sws(7 downto 0)); --8 ultimos bits de sws

  ALU:
  with opCode select
   result <= 
   resize(leftOp + rightOp, 16) when "00",--hago la extension de signo asi para que no se enciendan leds innecesarios en la placa y el primer bit pueda utilizarse como 1
   resize(leftOp - rightOp, 16) when "01",
   resize(NOT rightOp, 16) when "10",
   leftOp * rightOp when "11";
  
  leds  <= std_logic_vector(result);
  digit <= std_logic_vector(result(3 downto 0)); 
    
  an_n  <= "1110"; --esto sirve para elegir cual de los 4 displays se usa

  converter : bin2segs 
  port map ( en => '1', bin => digit, dp => '0', segs_n => segs_n ); 
    
end syn;	