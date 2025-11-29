---------------------------------------------------------------------
--
--  Fichero:
--    lab3.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 3
--
--  Notas de diseño:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--PREGUNTAAAAR, la puerta xor que he sustituido por una or ya que sino no me pillaba las veces que los 3 son igulaes
entity lab3 is
port
(
  aRst   : in  std_logic;
  osc    : in  std_logic;
  coin   : in  std_logic;
  go     : in  std_logic;
  an_n   : out std_logic_vector(3 downto 0);  
  segs_n : out std_logic_vector(7 downto 0)
);
end lab3;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;
architecture syn of lab3 is

component synchronizer
    generic (
    STAGES  : natural;       -- número de biestables del sincronizador
    XPOL    : std_logic      -- polaridad (valor en reposo) de la señal a sincronizar
  );
  port (
    clk   : in  std_logic;   -- reloj del sistema
    x     : in  std_logic;   -- entrada binaria a sincronizar
    xSync : out std_logic    -- salida sincronizada que sigue a la entrada
  );
  end component;
  component edgeDetector
    generic(
    XPOL  : std_logic         -- polaridad (valor en reposo) de la señal a la que eliminar rebotes
  );
  port (
    clk   : in  std_logic;   -- reloj del sistema
    x     : in  std_logic;   -- entrada binaria con flancos a detectar
    xFall : out std_logic;   -- se activa durante 1 ciclo cada vez que detecta un flanco de subida en x
    xRise : out std_logic    -- se activa durante 1 ciclo cada vez que detecta un flanco de bajada en x
  );
  end component;
  component debouncer
  generic(
    FREQ_KHZ  : natural;    -- frecuencia de operacion en KHz
    BOUNCE_MS : natural;    -- tiempo de rebote en ms
    XPOL      : std_logic   -- polaridad (valor en reposo) de la señal a la que eliminar rebotes
  );
  port (
    clk  : in  std_logic;   -- reloj del sistema
    rst  : in  std_logic;   -- reset síncrono del sistema
    x    : in  std_logic;   -- entrada binaria a la que deben eliminarse los rebotes
    xDeb : out std_logic    -- salida que sique a la entrada pero sin rebotes
  );
  end component;
  component freqSynthesizer
  generic (
    FREQ_KHZ : natural;                 -- frecuencia del reloj de entrada en KHz
    MULTIPLY : natural range 1 to 64;   -- factor por el que multiplicar la frecuencia de entrada 
    DIVIDE   : natural range 1 to 128   -- divisor por el que dividir la frecuencia de entrada
  );
  port (
    clkIn  : in  std_logic;   -- reloj de entrada
    rdy    : out std_logic;   -- indica si el reloj de salida es válido
    clkOut : out std_logic    -- reloj de salida
  );
end component;
component asyncRstSynchronizer
  generic (
    STAGES : natural;         -- número de biestables del sincronizador
    XPOL   : std_logic        -- polaridad (en reposo) de la señal de reset
  );
  port (
    clk    : in  std_logic;   -- reloj del sistema
    rstIn  : in  std_logic;   -- rst de entrada
    rstOut : out std_logic    -- rst de salida
  );
end component;

component segsBankRefresher is
  generic(
    FREQ_KHZ : natural;   -- frecuencia de operacion en KHz
    SIZE     : natural    -- número de displays a refrescar     
  );
  port (
    -- host side
    clk    : in std_logic;                              -- reloj del sistema
    ens    : in std_logic_vector (SIZE-1 downto 0);     -- capacitaciones
    bins   : in std_logic_vector (4*SIZE-1 downto 0);   -- códigos binarios a mostrar
    dps    : in std_logic_vector (SIZE-1 downto 0);     -- puntos
    -- 7 segs display side
    an_n   : out std_logic_vector (SIZE-1 downto 0);    -- selector de display  
    segs_n : out std_logic_vector (7 downto 0)          -- código 7 segmentos 
  );
end component;
  
  constant SIZE      : natural := 4;
  constant OSC_KHZ   : natural := 100_000;     -- frecuencia del oscilador externo en KHz
  constant FREQ_KHZ  : natural := OSC_KHZ/10;  -- frecuencia de operacion en KHz
  constant BOUNCE_MS : natural := 50;          -- tiempo de rebote de los pulsadores en ms
  
  type reelType is array (2 downto 0) of unsigned(3 downto 0);

  -- Registros  
  signal credit : unsigned(3 downto 0) := (others => '0');
  signal reel   : reelType             := (others => (others => '0'));

  -- Señales 
  signal bins_concat : std_logic_vector(4*SIZE-1 downto 0);
  signal clk, rdy : std_logic;
  signal rstSync, rstAux : std_logic;
  signal coinSync, coinDeb, coinRise : std_logic;
  signal goSync, goDeb, goRise       : std_logic;

  signal spin : std_logic_vector(2 downto 0);
  signal decCredit, incCredit, hasCredit : std_logic;
  signal cycleCntTc : std_logic;  
  signal iguales2,iguales3 : std_logic; 
  signal aux : std_logic;

begin

  rstAux <= (not rdy) xor aRst;
  
  resetSyncronizer : asyncRstSynchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map (
        clk => clk,
        rstIn => rstAux,
        rstOut => rstSync
    );
    
  clkGenerator : freqSynthesizer
    generic map ( FREQ_KHZ => OSC_KHZ, MULTIPLY => 1, DIVIDE => 10 )
    port map (
        clkIn => osc,
        rdy => rdy,
        clkOut => clk   
    );
      
  ------------------  
  
  coinSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map (
        x => coin,
        clk => clk,
        xSync => coinSync
    );   

  coinDebouncer : debouncer
    generic map ( FREQ_KHZ => FREQ_KHZ, BOUNCE_MS => BOUNCE_MS, XPOL => '0' )
    port map ( 
        clk => clk,
        rst => rstSync,
        x => coinSync,
        xDeb => coinDeb);
   
  coinEdgeDetector : edgeDetector
    generic map ( XPOL => '0' )
    port map ( 
        clk => clk,
        xFall => open,
        xRise => coinRise,
        x => coinDeb);  
  
  ------------------  
    goSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map (
        x => go,
        clk => clk,
        xSync => goSync
    );   

  goDebouncer : debouncer
    generic map ( FREQ_KHZ => FREQ_KHZ, BOUNCE_MS => BOUNCE_MS, XPOL => '0' )
    port map ( 
        clk => clk,
        rst => rstSync,
        x => goSync,
        xDeb => goDeb);
   
  goEdgeDetector : edgeDetector
    generic map ( XPOL => '0' )
    port map ( 
        clk => clk,
        xFall => open,
        xRise => goRise,
        x => goDeb);  
  
  ------------------  
 
  fsm:
  process (rstSync, clk, goRise, hasCredit)
    type states is (initial, S1, S2, S3, reward); 
    variable state: states := initial;
  begin 
    decCredit <= '0';
    incCredit <= '0';
    spin      <= "000"; 
    case state is
        when initial =>
            if goRise = '1' and hasCredit  = '1' then
                decCredit <= '1';
            end if;
        when S1 =>
            spin <= "111";
        when S2 =>
            spin <= "011";
        when S3 =>
            spin <= "001";
        when reward =>
            incCredit <= '1';     
    end case;
    if rstSync='1' then
      state := initial;
      decCredit <= '0';
      incCredit <= '0';
      spin <= "000";
    elsif rising_edge(clk) then
      case state is
        when initial =>
            if goRise = '1' and hasCredit  = '1' then
               state := S1;
            end if;
           -- spin <= "000";
            --if goRise = '1' and hasCredit = '1' then
             --   state := S1;
              --  decCredit <= '1';
           -- end if;
        when S1 =>
            if goRise = '1' then
                state := S2;
            end if;
            --spin <= "111";
            --if goRise = '1' then
            --    state := S2;
            --end if;
        when S2 =>
            if goRise = '1' then
               state := S3;
            end if;
            --spin <= "011";
            --if goRise = '1' then
            --    state := S3;
            --end if;
        when S3 =>
            if goRise = '1' then
                state := reward;
            end if;
            --if goRise = '1' then
            --    state := reward;
           -- end if;
           -- spin <= "001";
        when reward =>
            state := initial;
            --incCredit <= '1';
           -- spin <= "000";
        when others =>
            state := initial;          
      end case;
    end if;
  end process;  
  
  cycleCounter :  
  process (clk)
    constant CYCLES : natural := ms2cycles(FREQ_KHZ, 50);
    variable count  : natural range 0 to CYCLES := 0;
  begin
    cycleCntTc <= '0';
    if rising_edge(clk) then
        if count = CYCLES then 
            count := 0;
            cycleCntTc <= '1';
        else
            cycleCntTc <= '0';
            count := count + 1;
        end if;
    end if;
  end process;
     
  reelRegisters : 
  for i in reel'range generate
  begin
    process (rstSync, clk)
    begin
      if rstSync='1' then
        reel(i) <= (others => '0');
      elsif rising_edge(clk) then
        if spin(i) = '1' and cycleCntTc = '1' then
                reel(i) <= (reel(i) + 1) mod 6;
        end if;
      end if;
    end process; 
  end generate;
 
  creditComparator: 
  hasCredit <= '0' when credit = "0000" else '1';
  
  creditInerLogic:
  iguales2 <= '1' when (reel(1) = reel(2)) or (reel(2) = reel(0)) or (reel(0) = reel(1)) else '0'; 
  iguales3 <= '1' when (reel(1) = reel(2)) and (reel(0) = reel(2)) else '0';
  aux <= (iguales3 or iguales2) and incCredit;
  
  creditRegister :
  process (rstSync, clk)
  begin
    if rstSync='1' then
      credit <= (others => '0');    
    elsif rising_edge(clk) then
      if coinRise='1' then
            credit <= (credit + 1) mod 16; --en caso de que pulsemos lo de aumentar credito directamente
      elsif decCredit='1' then
            credit <= (credit - 1) mod 16;
            if credit < "0000" then 
                credit <= "0000";
            end if;
      elsif aux='1' then
        if iguales3 = '1' then
            credit <= (credit + 3) mod 16;
        else 
            credit <= (credit + 2) mod 16;
        end if; 
      end if;
   end if; 
  end process; 
  logicaBins:
  bins_concat <= std_logic_vector(credit) & std_logic_vector(reel(0))& std_logic_vector(reel(1)) & std_logic_vector(reel(2));
  displayInterface : segsBankRefresher
    generic map(FREQ_KHZ => FREQ_KHZ, SIZE => SIZE)
    port map(
        clk => clk,
        ens => "1111",
        bins => bins_concat,
        dps => "1000",
        an_n => an_n,
        segs_n => segs_n 
    );
end syn;
