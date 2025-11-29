---------------------------------------------------------------------
--
--  Fichero:
--    bin2segs.vhd  07/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Convierte codigo binario a codigo 7-segmentos
--
--  Notas de diseño:
--    - Asume que los sementos se encienden en logica inversa
--    - Los segmentos se ordenan en segs alfabéticamente de izquierda 
--      a derecha: a=segs_n(6), b=segs_n(5)... g=segs_n(0)
--    - El punto se corresponde con segs_n(7)
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity bin2segs is
  port (
    -- host side
    en     : in std_logic;                      -- capacitacion
    bin    : in std_logic_vector(3 downto 0);   -- codigo binario
    dp     : in std_logic;                      -- punto
    -- leds side
    segs_n : out std_logic_vector(7 downto 0)   -- codigo 7-segmentos
  );
end bin2segs;

-------------------------------------------------------------------

architecture syn of bin2segs is
  signal segs : std_logic_vector(7 downto 0);
begin 

  segs(7) <= ...; 
  with bin select
    segs(6 downto 0) <= 
      "0000001" when X"0",
      "......." when X"1",
         ...
      "......." when others;
      
  segs_n <= ... when ... else ...;

end syn;