library ieee;
use ieee.std_logic_1164.all;

entity vgaRefresher is
  generic(
    FREQ_DIV  : natural  -- razon entre la frecuencia de reloj del sistema y 25 MHz
  );
  port ( 
    -- host side
    clk   : in  std_logic;   -- reloj del sistema
    line  : out std_logic_vector(9 downto 0);   -- numero de linea que se esta barriendo
    pixel : out std_logic_vector(9 downto 0);   -- numero de pixel que se esta barriendo
    R     : in  std_logic_vector(3 downto 0);   -- intensidad roja del pixel que se esta barriendo
    G     : in  std_logic_vector(3 downto 0);   -- intensidad verde del pixel que se esta barriendo
    B     : in  std_logic_vector(3 downto 0);   -- intensidad azul del pixel que se esta barriendo
    -- VGA side
    hSync : out std_logic := '0';   -- sincronizacion horizontal
    vSync : out std_logic := '0';   -- sincronizacion vertical
    RGB   : out std_logic_vector(11 downto 0) := (others => '0')   -- canales de color
  );
end vgaRefresher;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of vgaRefresher is

  constant CYCLESxPIXEL : natural := FREQ_DIV;
  constant PIXELSxLINE  : natural := 800;
  constant LINESxFRAME  : natural := 525;
     
  signal hSyncInt, vSyncInt : std_logic;

  signal cycleCnt : natural range 0 to CYCLESxPIXEL-1 := 0;  
  signal pixelCnt : unsigned(pixel'range) := (others=>'0');
  signal lineCnt  : unsigned(line'range)  := (others=>'0');

  signal blanking : boolean;
  
begin

  counters:
  process (clk)
  begin
    if rising_edge(clk) then
        if cycleCnt=CYCLESxPIXEL-1 then
            cycleCnt <= 0;
            if pixelCnt=PIXELSxLINE-1 then
                pixelCnt <= (others => '0');
                if lineCnt = LINESxFRAME-1 then
                    lineCnt <= (others => '0');
                else
                    lineCnt <= lineCnt + 1;
                end if;
            else
                pixelCnt <= pixelCnt + 1;
            end if;
        else
            cycleCnt <= cycleCnt + 1;
        end if;
    end if;
  end process;

  pixel <= std_logic_vector(pixelCnt);
  line  <= std_logic_vector(lineCnt);
  
  hSyncInt <= '0' when (pixelCnt >= 656 and pixelCnt < 752) else '1';
  vSyncInt <= '0' when (lineCnt >= 490 and lineCnt < 492) else '1';        

  blanking <= (lineCnt >= 480) or (pixelCnt >= 640);
  
  outputRegisters:
  process (clk)
  begin
    if rising_edge(clk) then
        if cycleCnt < CYCLESxPIXEL then
            hSync <= hSyncInt;
            vSync <= vSyncInt;
            if not blanking then
                RGB <= R & G & B;
            else
                RGB <= (others => '0');
            end if; 
        end if;
    end if;
  end process;
    
end syn;

