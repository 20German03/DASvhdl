---------------------------------------------------------------------
--
--  Fichero:
--    lab8multicycle.vhd  14/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 10: multicycle
--
--  Notas de diseño:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lab10multicycle is
  port(
    clk      : in  std_logic;
    filterOn : in  std_logic;
    mclkAD   : out std_logic;
    sclkAD   : out std_logic;
    lrckAD   : out std_logic;
    sdto     : in  std_logic;
    mclkDA   : out std_logic;
    sclkDA   : out std_logic;
    lrckDA   : out std_logic;
    sdti     : out std_logic
  );
end lab10multicycle;

-------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of lab10multicycle is

  component multicycleNotchFilter is
    generic (
      WL : natural;  -- anchura de la muestra
      QM : natural;  -- número de bits decimales en la muestra
      FS : real;     -- frecuencia de muestreo
      F0 : real      -- frecuencia de corte
    );
    port(
      clk       : in    std_logic;  -- reloj del sistema
      newSample : in    std_logic;  -- indica si existe una nueva muestra que procesar
      inSample  : in    std_logic_vector(WL-1 downto 0);  -- muestra de entrada
      outSample : out   std_logic_vector(WL-1 downto 0)   -- muestra de salida
    );
  end component;

  constant FREQ_KHZ : natural := 100_000;  -- frecuencia de operacion en KHz
  constant ISS_KHZ  : natural := 25_000;   -- frecuencia de operación del interfaz ISS en KHz
  constant FREQ_DIV : natural := FREQ_KHZ/ISS_KHZ; 
   
  constant UNDERSAMPLE : natural := 1; 
  constant FS          : natural := ((ISS_KHZ*1000)/512)/UNDERSAMPLE; 
  
  constant WL : natural := 16; 
  constant QM : natural := 14; 
  constant F0 : real    := 800.0; 
  
  signal filterOnSync : std_logic;

  signal inSample, outSample : std_logic_vector (15 downto 0);
  signal rChannel, newSample, newLeftSample, newRightSample : std_logic;
  
  signal sample, outLeftSample, outRightSample : std_logic_vector (15 downto 0);
  
  signal mclk, sclk, lrck : std_logic;

begin
 
  filterOnSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map ( clk => clk, x => filterOn, xSync => filterOnSync );
      
------------------  
 
  outSampleMux :
  process ( filterOnSync, rChannel, outLeftSample, outRightSample )
  begin
    if( filterOnSync='1' ) then
      if( rChannel='1' ) then
        outSample <= std_logic_vector(outLeftSample);
      else
        outSample <= std_logic_vector(outRightSample);
      end if;
    else
      outSample <= sample;
    end if;
  end process;    
  
------------------  

  process (clk)
  begin
    if rising_edge(clk) then
      if newSample='1' then
        sample <= inSample;
      end if;
    end if;
  end process;
 
------------------  
  
  leftFilter : multicycleNotchFilter
    generic map ( WL => WL, QM => QM, FS => real( FS ), F0 => F0 )
    port map ( clk => clk, newSample => newLeftSample, inSample => inSample, outSample => outLeftSample );
    
  rightFilter : multicycleNotchFilter
    generic map ( WL => WL, QM => QM, FS => real( FS ), F0 => F0 )
    port map ( clk => clk, newSample => newRightSample, inSample => inSample, outSample => outRightSample );

  newLeftSample  <= newSample and not rChannel;
  
  newRightSample <= newSample and rChannel;
  
------------------  

  mclkAD <= mclk;
  sclkAD <= sclk;
  lrckAD <= lrck;
  
  mclkDA <= mclk;
  sclkDA <= sclk;
  lrckDA <= lrck;

  codecInterface : iisInterface
    generic map( WL => WL,  FREQ_DIV => FREQ_DIV,  UNDERSAMPLE => UNDERSAMPLE ) 
    port map( 
      clk => clk, rChannel => rChannel, newSample => newSample, inSample => inSample, outSample => outSample,
      mclk => mclk, sclk => sclk, lrck => lrck, sdti => sdti, sdto => sdto
    );
   
end syn;

