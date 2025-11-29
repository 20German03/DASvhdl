---------------------------------------------------------------------
--
--  Fichero:
--    lab8loopback.vhd  02/02/2024
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 10: Loopback
--
--  Notas de diseño:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lab10loopback is
  port(
    clk        : in  std_logic;
    mclkAD     : out std_logic;
    sclkAD     : out std_logic;
    lrckAD     : out std_logic;
    sdto       : in  std_logic;
    mclkDA     : out std_logic;
    sclkDA     : out std_logic;
    lrckDA     : out std_logic;
    sdti       : out std_logic
  );
end lab10loopback;

-------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of lab10loopback is

  constant FREQ_KHZ : natural := 100_000;  -- frecuencia de operacion en KHz
  constant ISS_KHZ  : natural := 25_000;   -- frecuencia de operación del interfaz ISS en KHz
  constant FREQ_DIV : natural := FREQ_KHZ/ISS_KHZ; 
  
  constant WL : natural := 16; 

  signal inSample, outSample : std_logic_vector (WL-1 downto 0);
  signal newSample : std_logic;
 
  signal mclk, sclk, lrck : std_logic;

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if newSample='1' then
        outSample <= inSample;
      end if;
    end if;
  end process;
  
  -------------  
 
  mclkAD <= mclk;
  sclkAD <= sclk;
  lrckAD <= lrck;
  
  mclkDA <= mclk;
  sclkDA <= sclk;
  lrckDA <= lrck;
  
  codecInterface : iisInterface
    generic map( WL => WL,  FREQ_DIV => FREQ_DIV,  UNDERSAMPLE => 1 ) 
    port map( 
      clk => clk, rChannel => open, newSample => newSample, inSample => inSample, outSample => outSample,
      mclk => mclk, sclk => sclk, lrck => lrck, sdti => sdti, sdto => sdto
    );
   
end syn;

