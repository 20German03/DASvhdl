 --space shooter
library ieee;
use ieee.std_logic_1164.all;

entity pFinal is
  port ( 
    clk     : in  std_logic;
    rst     : in  std_logic;
    ps2Clk  : in  std_logic;
    ps2Data : in  std_logic;
    hSync   : out std_logic;
    vSync   : out std_logic;
    RGB     : out std_logic_vector(3*4-1 downto 0)
  );
end pFinal;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of pFinal is
  constant FREQ_KHZ : natural := 100_000;  -- frecuencia de operacion en KHz
  constant VGA_KHZ  : natural := 25_000;   -- frecuencia de envio de pixeles a la VGA en KHz
  constant FREQ_DIV : natural := FREQ_KHZ/VGA_KHZ; 
  
  constant SPRITE_ANCHO : natural := 16;  --tamaño de los sprites del juego
  constant SPRITE_ALTO : natural := 16;
  
  constant MAX_DISPAROS : natural := 3;  --maximo numero de disparos a la vez
  constant ANCHO_DISPARO : natural := 4;  --tamaño de los disparos
  constant ALTO_DISPARO : natural := 2;
  constant CADENCIA_DE_DISPARO : natural := hz2cycles(FREQ_KHZ, 2);
  constant VELOCIDAD_DISPARO : natural := 4; 
  
  constant NUM_ENEMIGOS : natural := 7;  --numero total de enemigos
  constant MAX_DISPAROS_ENEMIGOS : natural := 2;  -- maximo de disparos por enemigo
  constant CADENCIA_DISPARO_ENEMIGO : natural := hz2cycles(FREQ_KHZ, 1);
  constant VELOCIDAD_DISPARO_ENEMIGO : natural := 3;  -- Velocidad de disparos enemigos
  
  constant NUM_ESTRELLAS : natural := 32;  --numero total de estrellas
  constant MAX_VELOCIDAD : natural := 3;  --velocidad maxima de las estrellas
  
  constant MAX_VIDAS : natural := 2;  --vidas del jugador
  
  type sprite_rom is array (0 to 79) of std_logic_vector(15 downto 0);  --tipo de la rom de sprites
  type array_enemigos is array(0 to NUM_ENEMIGOS - 1) of unsigned(7 downto 0);  --array de los enemigos
  type array_dir_enem is array(0 to NUM_ENEMIGOS - 1) of std_logic;  --array de la direccion de los enemigos
  type array_disparos_enemigos is array(0 to NUM_ENEMIGOS - 1, 0 to MAX_DISPAROS_ENEMIGOS - 1) of unsigned(7 downto 0);  --array para todos los disparos enemigos
  type array_act_disparos is array(0 to NUM_ENEMIGOS - 1, 0 to MAX_DISPAROS_ENEMIGOS - 1) of std_logic;  --array para los disparos actuale enemigos
  type array_estrellas is array(0 to NUM_ESTRELLAS - 1) of unsigned(7 downto 0);  --array que para todas las estrellas
  
  constant sprite_romm : sprite_rom := (
    --sprite de la nave protagonista
    "0000000001000000",
    "0000000000100000",
    "0000000001110000",
    "0000000000100000",
    "0000000000111000",
    "0000000001111100",
    "0000001111111111",
    "0000000011110010",
    "0000000011110010",
    "0000001111111111",
    "0000000001111100",
    "0000000000111000",
    "0000000000100000",
    "0000000001110000",
    "0000000000100000",
    "0000000001000000",
    --sprite de la pelota
    "0000000000000000",
    "0000000000000000", 
    "0000000000000000", 
    "0000001111000000", 
    "0000011111100000", 
    "0000011111100000", 
    "0000001111000000", 
    "0000000000000000", 
    "0000000000000000", 
    "0000000000000000", 
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    --spite enemigo normal
    "0000000000000000",
    "0000000000000000",
    "0001111110000000",
    "0000011000000000",
    "0011111100000000",
    "0000110000000000",
    "0111110000000000",
    "1100111000000000",
    "1100111000000000",
    "0111110000000000",
    "0000110000000000",
    "0011111100000000",
    "0000011000000000",
    "0001111110000000",
    "0000000000000000",
    "0000000000000000",
    --sprite superior del jefe
    "0000000011000000", 
    "0000000011100000", 
    "0000000111110000", 
    "0000000111110000", 
    "0000001100011000",
    "0000011111111000",
    "0000110000001000",
    "0111111111111110",
    "1010101010110101",
    "1010101010110101", 
    "0111111111111110", 
    "0000110000001100", 
    "0000111111111100", 
    "0001111100011100", 
    "0111111111111110", 
    "1100011111111111", 
    --sprite inferior del jefe
    "1100011111111111",
    "0111111111111110",
    "0001111100011100",
    "0000111111111100",
    "0000110000001100",
    "0111111111111110",
    "1010101010110101",
    "1010101010110101",
    "0111111111111110",
    "0000110000001000",
    "0000011111111000",
    "0000001100011000",
    "0000000111110000",
    "0000000111110000",
    "0000000011100000",
    "0000000011000000"
  );
   
  signal yLeft  : unsigned(7 downto 0) := to_unsigned(8, 8);  --posicion x de la nave
  signal xLeft  : unsigned(7 downto 0) := to_unsigned(0, 8);  --posicion y de la nave
  signal wP, sP, spcP, aP, dP: boolean := false;  --señales para la pulsacion de teclas

  signal rstSync : std_logic;
  signal data: std_logic_vector(7 downto 0);
  signal dataRdy: std_logic;
  
  signal color_r, color_g, color_b : std_logic_vector(3 downto 0);  --vectores para la visualizacion de colores que se le pasaran a vgarefresher
  signal campoJuego, raquetaIzq: std_logic;  --campo de juego representa las dos franjas blancas, raquetaIzq representa la nave
  signal mover: boolean;

  signal lineAux, pixelAux : std_logic_vector(9 downto 0);  
  signal line, pixel : unsigned(7 downto 0);

  signal sprite_addr : unsigned(7 downto 0) := (others => '0');  --direccion en la rom para sacar un sprite
  signal sprite_data : std_logic_vector(15 downto 0);  --se almacena una linea de la rom en un momento determinado
  signal sprite_pixel : std_logic;  --indica si se muestra el sprite concreto
  signal sprite_x_off : unsigned(7 downto 0);  --utilizado para ir eligiendo fila en la rom
  signal sprite_y_off : unsigned(7 downto 0);  --utilizado para ir eligiendo col en la rom
  signal sprite_ac : unsigned(2 downto 0);  --tipo de sprite a elegir
  
  signal disparo_x, disparo_y : unsigned(7 downto 0) := (others => '0');  --posicion de los disparos del jugador
  signal disparo_activo : std_logic := '0';  --indicador de si hay o no un disparo activo
  signal contador_disp : natural range 0 to CADENCIA_DE_DISPARO := 0;  --velocidad a la que se puede disparar
  signal disparar : boolean := true;  --indicador de si se puede disparar
  signal disparo_pixel : std_logic;  --indicador para establecer si se muestra o no el disparo del jugador
  
  signal xEnemy : array_enemigos := (to_unsigned(130, 8), to_unsigned(90, 8), to_unsigned(90, 8), to_unsigned(110, 8), to_unsigned(110, 8), to_unsigned(130, 8),  to_unsigned(130, 8)); --array de las posiciones x de los enemigos
  signal yEnemy : array_enemigos := (to_unsigned(50, 8), to_unsigned(30, 8), to_unsigned(70, 8), to_unsigned(20, 8), to_unsigned(90, 8), to_unsigned(50, 8), to_unsigned(66, 8));  --array de las posiciones y de los enemigos
  signal dirEnemy : array_dir_enem := (others => '0');  --direccion de movimiento de los enemigos
  signal enemy_pixel : std_logic_vector(NUM_ENEMIGOS - 1 downto 0);  --indicador para mostrar al enemigo
  signal enemigo_actual : integer range 0 to NUM_ENEMIGOS - 1:= 0;  --enemigo que se esta tratando
  
  signal disparos_enem_x, disparos_enem_y : array_disparos_enemigos;  --elementos relacionados con los disparos de los enemigos
  signal disparos_enem_act : array_act_disparos := (others => (others => '0'));
  signal contadores_disparo_enem : array_enemigos := (others => (others => '0'));
  signal disparo_enem_pixel : std_logic;
  signal disparo_enem_actual : integer range 0 to NUM_ENEMIGOS - 1 := 0;
  
  signal enemy_control : std_logic_vector(NUM_ENEMIGOS-1 downto 0) := (NUM_ENEMIGOS - 1 downto 3 => '0', 2 downto 0 => '1');  --señal de control para activar y desactivar enemigos
  signal debug_hit     : std_logic_vector(NUM_ENEMIGOS-1 downto 0) := (others => '0');
  
  signal estrellas_x, estrellas_y, estrellas_vel : array_estrellas := (others => (others => '0'));  --elementos relacionados con las estrellas
  signal estrella_pixel : std_logic := '0';
  signal lfsr : unsigned(15 downto 0) := to_unsigned(16#ACE1#, 16); --para numeros aleatorios
  
  signal vidas : natural range 0 to MAX_VIDAS := MAX_VIDAS;  --vidas del jugador
  signal finPartida : boolean := false;
  
  signal esperando_reinicio : boolean := false;  --utilizado para reiniciar con el spc
  
  signal oleada : integer range 0 to 3 := 1;  --control de las 3 oleadas del juego
  
  signal vidas_boss : integer range 0 to 10 := 10;  --vidas del jefe final
  
  begin
 
  rstSynchronizer : synchronizer
    generic map (STAGES => 2, XPOL => '0')
    port map (clk => clk, x => rst, xSync => rstSync);

  ------------------  
 
  ps2KeyboardInterface : ps2receiver
    port map (clk => clk, rst => rstSync, dataRdy => dataRdy, data => data, ps2Clk => ps2Clk, ps2Data => ps2Data);   
   
  keyboardScanner:
  process (clk)
    type states is (keyON, keyOFF);
    variable state : states := KeyON;
  begin
    if rising_edge(clk) then
      if rstSync='1' then
        state:= keyON;
        wP <= false;
        sP <= false;
        spcP <= false;
        aP <= false;
        dP <= false;
        esperando_reinicio <= false;
      elsif dataRdy='1' then
        case state is
          when keyON =>
            case data is
              when X"F0" => state := keyOFF;
              when X"1D" => wP <= true;
              when X"1B" => sP <= true;
              when X"29" => spcP <= true;
                if finPartida then
                  esperando_reinicio <= true;
                end if;
              when X"1C" => aP <= true;
              when X"23" => dP <= true;
              when others => null;
            end case;
          when keyOFF =>
            state := keyON;
            case data is
              when X"1D" => wP <= false;
              when X"1B" => sP <= false;
              when X"29" => spcP <= false;
              when X"1C" => aP <= false;
              when X"23" => dP <= false;
              when others => null;
            end case;
        end case;
      end if;
      if esperando_reinicio then
        esperando_reinicio <= false;
      end if;
    end if;
  end process;        

------------------  

    screenInteface: vgaRefresher
    generic map (FREQ_DIV => FREQ_DIV)
    port map (clk => clk, line => lineAux, pixel => pixelAux, R => color_r, G => color_g, B => color_b, 
              hSync => hSync, vSync => vSync, RGB => RGB);

    pixel <= unsigned(pixelAux(9 downto 2));
    line  <= unsigned(lineAux(9 downto 2));
  
    sprite_data <= sprite_romm(to_integer(sprite_addr)) when sprite_addr < 79 else (others => '0');
  
    sprite_ac <= "000" when raquetaIzq = '1' else
             "010" when (enemy_pixel(1) or enemy_pixel(2) or enemy_pixel(0) or enemy_pixel(3) or enemy_pixel(4)) = '1' else
             "011" when enemy_pixel(5) = '1' else
             "100" when enemy_pixel(6) = '1' else
             "101";
             
    gen_enemy_pixel:
    for i in 0 to NUM_ENEMIGOS - 1 generate
      enemy_pixel(i) <= '1' when enemy_control(i) = '1' and 
                     pixel >= xEnemy(i) and pixel < xEnemy(i) + SPRITE_ANCHO and 
                     line >= yEnemy(i) and line < yEnemy(i) + SPRITE_ALTO else '0';
    end generate;
        
    seleccion_enem:
    process(enemy_pixel, xEnemy, yEnemy, pixel, line, xLeft, sprite_ac)
    begin
      sprite_x_off <= (others => '0');
      sprite_y_off <= (others => '0');
        
      if sprite_ac = "000" then
        sprite_x_off <= pixel - xLeft;
        sprite_y_off <= line - yLeft;
        
      elsif sprite_ac = "010" then
        for i in 0 to 4 loop
          if enemy_pixel(i) = '1' then
            sprite_x_off <= pixel - xEnemy(i);
            sprite_y_off <= line - yEnemy(i);
            enemigo_actual <= i;
            exit;
          end if;
        end loop;
 
        
      elsif sprite_ac = "011" then
        if enemy_pixel(5) = '1' then
          sprite_x_off <= pixel - xEnemy(5);
          sprite_y_off <= line - yEnemy(5);
          enemigo_actual <= 5;
        end if;
        
      elsif sprite_ac = "100" then
        if enemy_pixel(6) = '1' then
          sprite_x_off <= pixel - xEnemy(6);
          sprite_y_off <= line - yEnemy(6);
          enemigo_actual <= 6;
        end if;
      end if;
    end process;

    sprite_addr <= resize((sprite_ac & sprite_y_off(3 downto 0)), 8);

    sprite_pixel <= sprite_data(to_integer(15 - sprite_x_off)) when
                 sprite_x_off < SPRITE_ANCHO and sprite_y_off < SPRITE_ALTO
                 and sprite_ac /= "101" else '0';
  
    disparo_pixel <= '1' when disparo_activo = '1' and 
                  pixel >= disparo_x and pixel < disparo_x + ANCHO_DISPARO and 
                  line >= disparo_y and line < disparo_y + ALTO_DISPARO 
                  else '0';
                 
    process(disparos_enem_act, disparos_enem_x, disparos_enem_y, pixel, line)
    begin
      disparo_enem_pixel <= '0';
      disparo_enem_actual <= 0;
    
      for i in 0 to NUM_ENEMIGOS-1 loop
        for j in 0 to MAX_DISPAROS_ENEMIGOS-1 loop
          if disparos_enem_act(i,j) = '1' and
            pixel >= disparos_enem_x(i,j) and pixel < disparos_enem_x(i,j) + ANCHO_DISPARO and
            line >= disparos_enem_y(i,j) and line < disparos_enem_y(i,j) + ALTO_DISPARO then
            disparo_enem_pixel <= '1';
            disparo_enem_actual <= i;
            exit;
          end if;
        end loop;
      end loop;
    end process;
  
    gestion_estrellas:  --utilizada para no dibujar las estrellas que, resultado de los numeros aleatorios aparecen fuera de las franjas del campo de juego
    process(estrellas_x, estrellas_y, pixel, line)
    begin
      estrella_pixel <= '0';
      for i in 0 to NUM_ESTRELLAS-1 loop
        if pixel >= estrellas_x(i) and pixel < estrellas_x(i)+1 and
           line >= estrellas_y(i) and line < estrellas_y(i)+1 then
           if not(line <= 7 or line = 112 or (pixel = 79 and ((line >= 8 and line < 16) or 
              (line >= 24 and line < 32) or (line >= 40 and line < 48) or 
              (line >= 56 and line < 64) or (line >= 72 and line < 80) or 
              (line >= 88 and line < 96) or (line >= 104 and line < 112)))) then
             estrella_pixel <= '1';
           end if;
        end if;
      end loop;
    end process; 
     
    movimiento_estrellas:
    process(clk)
      variable rand_temp : unsigned(15 downto 0);
    begin
      if rising_edge(clk) then
        if rstSync = '1' or esperando_reinicio then
      -- inicialización aleatoria de estrellas
          for i in 0 to NUM_ESTRELLAS-1 loop
            rand_temp := lfsr rol i;  -- rol rota i posiciones a la izquierda el lfsr
            estrellas_x(i) <= resize(rand_temp(7 downto 0) mod 160, 8);  --160 es el ancho de la pantalla
            estrellas_y(i) <= resize(rand_temp(15 downto 8) mod 112, 8);  --112 alto de la pantalla
            estrellas_vel(i) <= resize(rand_temp(3 downto 0) mod MAX_VELOCIDAD + 1, 8);
          end loop;
        elsif mover then
          for i in 0 to NUM_ESTRELLAS-1 loop  -- movimiento de las estrellas
            if estrellas_x(i) > estrellas_vel(i) then
              estrellas_x(i) <= estrellas_x(i) - estrellas_vel(i);
            else
              estrellas_x(i) <= to_unsigned(159, 8);  -- cuando la estrella sale por la izquierda, reaparece a la derecha
              rand_temp := lfsr rol i;  -- nueva posición y aleatoria
              estrellas_y(i) <= resize(rand_temp(15 downto 8) mod 112, 8); -- nueva velocidad aleatoria
              estrellas_vel(i) <= resize(rand_temp(3 downto 0) mod MAX_VELOCIDAD + 1, 8);
            end if;
          end loop;
        end if;
      end if;
    end process;
                     
    color_r <= "1111" when campoJuego = '1' else
            "1111" when finPartida and (line >= 50 and line < 60 and pixel >= 60 and pixel < 100) else         
            "0000" when sprite_pixel = '1' and sprite_ac = "000" and vidas > 1 else
            "1111" when sprite_pixel = '1' and sprite_ac = "000" and vidas <= 1 else
            "0000" when sprite_pixel = '1' and sprite_ac = "001" else
            "0000" when sprite_pixel = '1' and sprite_ac = "010" else 
            "0000" when sprite_pixel = '1' and sprite_ac = "011" else 
            "0000" when sprite_pixel = '1' and sprite_ac = "100" else
            "1111" when disparo_pixel = '1' else
            "1111" when estrella_pixel = '1' else  
            "0000";

    color_g <= "1111" when campoJuego = '1' else
            "1111" when sprite_pixel = '1' and sprite_ac = "000" and vidas > 1 else
            "0000" when sprite_pixel = '1' and sprite_ac = "000" and vidas <= 1 else
            "0000" when sprite_pixel = '1' and sprite_ac = "001" else
            "1111" when sprite_pixel = '1' and sprite_ac = "010" else 
            "1111" when sprite_pixel = '1' and sprite_ac = "011" else 
            "1111" when sprite_pixel = '1' and sprite_ac = "100" else
            "1111" when disparo_pixel = '1' else  
            "1111" when estrella_pixel = '1' else  
            "0000";

    color_b <= "1111" when campoJuego = '1' else
            "1111" when sprite_pixel = '1' and sprite_ac = "000" and vidas > 1 else
            "0000" when sprite_pixel = '1' and sprite_ac = "000" and vidas <= 1 else
            "1111" when sprite_pixel = '1' and sprite_ac = "001" else
            "0000" when sprite_pixel = '1' and sprite_ac = "010" else 
            "0000" when sprite_pixel = '1' and sprite_ac = "011" else 
            "0000" when sprite_pixel = '1' and sprite_ac = "100" else
            "0000" when disparo_pixel = '1' else
            "1111" when estrella_pixel = '1' else  
            "1111" when disparo_enem_pixel = '1' else 
            "0000";
  
    campoJuego <= '1' when line = 7 or line = 112 else '0';
  
    raquetaIzq <= '1' when pixel >= xLeft and pixel < xLeft + SPRITE_ANCHO and line >= yLeft and line < yLeft + SPRITE_ALTO else '0';
    
    pulseGen:
    process (clk)
      constant CYCLES : natural := hz2cycles(FREQ_KHZ, 50);
      variable count : natural range 0 to CYCLES-1 := 0;
    begin
      if rising_edge(clk) then
        if not finPartida then
          if rstSync = '1' then
            count := 0;
            mover <= false;
          elsif not finPartida then
            if count = 0 then 
              mover <= true;
              count := CYCLES-1;
            else 
              mover <= false;
              count := count - 1;
            end if;
          
            -- control de cadencia de disparo del jugador
            if spcP then
              if contador_disp = 0 then
                disparar <= true;
              else
                contador_disp <= contador_disp - 1;
                disparar <= false;
              end if;
            else
              contador_disp <= CADENCIA_DE_DISPARO;
              disparar <= true;
            end if;
          end if;
        else
          mover <= false;
        end if;
      end if;  
    end process;    
        
    unified_control:
    process (clk)
      variable v_enemy_hit : std_logic_vector(NUM_ENEMIGOS-1 downto 0);
    begin
      if rising_edge(clk) then
        if rstSync = '1' or esperando_reinicio then 
          -- Reset valores iniciales
          yLeft <= to_unsigned(8, 8);
          xLeft <= to_unsigned(0, 8);
          disparo_activo <= '0';
          enemy_control <= (others => '0');
          enemy_control(0) <= '1';
          enemy_control(1) <= '1';
          enemy_control(2) <= '1';
          oleada <= 1;
          debug_hit <= (others => '0');
          vidas_boss <= 10;
          xEnemy(0) <= to_unsigned(130, 8);
          yEnemy(0) <= to_unsigned(50, 8);
          xEnemy(1) <= to_unsigned(90, 8);
          yEnemy(1) <= to_unsigned(30, 8);
          xEnemy(2) <= to_unsigned(90, 8);
          yEnemy(2) <= to_unsigned(70, 8);
          xEnemy(3) <= to_unsigned(110, 8);
          yEnemy(3) <= to_unsigned(20, 8);
          xEnemy(4) <= to_unsigned(110, 8);
          yEnemy(4) <= to_unsigned(90, 8);
          xEnemy(5) <= to_unsigned(130, 8);
          yEnemy(5) <= to_unsigned(50, 8);
          xEnemy(6) <= to_unsigned(130, 8);
          yEnemy(6) <= to_unsigned(66, 8);
                
        elsif mover and not finPartida then
          --movimiento del jugador
          if wP and yLeft > 8 then
            yLeft <= yLeft - 1;
          elsif sP and yLeft + 16 <= 111 then
            yLeft <= yLeft + 1;
          end if;

          if aP and xLeft > 0 then
            xLeft <= xLeft - 1;
          elsif dP and xLeft < 79 - SPRITE_ANCHO then
            xLeft <= xLeft + 1;
          end if;

        --disparo del jugador
          if spcP and disparar and disparo_activo = '0' then
            disparo_x <= xLeft + SPRITE_ANCHO;
            disparo_y <= yLeft + 7;
            disparo_activo <= '1';
          end if;

        --movimiento y colision de disparo
          v_enemy_hit := (others => '0');
          if disparo_activo = '1' then
            if disparo_x < 159 - ANCHO_DISPARO then
              disparo_x <= disparo_x + VELOCIDAD_DISPARO;
              --deteccion de colision con enemigos
              for i in 0 to NUM_ENEMIGOS-1 loop
                if enemy_control(i) = '1' then
                  if disparo_x + ANCHO_DISPARO >= xEnemy(i) and 
                    disparo_x <= xEnemy(i) + SPRITE_ANCHO and
                    disparo_y + ALTO_DISPARO - 2 >= yEnemy(i) and  --el -2 porque el sprite no tiene nada en 2 pixeles por encimma y por debajo
                    disparo_y <= yEnemy(i) + SPRITE_ALTO - 2 then
                    v_enemy_hit(i) := '1';
                  end if;
                end if;
              end loop;
            else
              disparo_activo <= '0';
            end if;
          
            -- Actualizar estado de enemigos golpeados
            for i in 0 to NUM_ENEMIGOS-1 loop
              if v_enemy_hit(i) = '1' then
                if  i < 5 then
                  enemy_control(i) <= '0';
                  disparo_activo <= '0';
                  debug_hit(i) <= '1';
                else
                  disparo_activo <= '0';
                  vidas_boss <= vidas_boss - 1;
                  if vidas_boss = 0 then
                    if i = 5 then
                      enemy_control(i + 1) <= '0';
                      debug_hit(i + 1) <= '1';
                    else
                      enemy_control(i - 1) <= '0';
                      debug_hit(i - 1) <= '1';
                    end if;
                    enemy_control(i) <= '0';
                    debug_hit(i) <= '1';
                  end if;
                end if;
              end if;
            end loop;
          end if;
        
          if oleada = 1 then
            if enemy_control(0) = '0' and enemy_control(1) = '0' and enemy_control(2) = '0' then
              enemy_control(3) <= '1';
              enemy_control(4) <= '1';
              oleada <= 2;
            end if;
          elsif oleada = 2 then
            if enemy_control(3) = '0' and enemy_control(4) = '0' then
              enemy_control(5) <= '1';
              enemy_control(6) <= '1';
              oleada <= 3;
            end if;
          elsif oleada = 3 then
            if enemy_control(5) = '0' and enemy_control(6) = '0' then
              enemy_control(0) <= '1';
              enemy_control(1) <= '1';
              enemy_control(2) <= '1';
              oleada <= 1;
            end if;
          end if;
        
        --movimiento de enemigos
          for i in 0 to NUM_ENEMIGOS-1 loop
            if enemy_control(i) = '1' then
              case i is
                when 0 =>
                  if dirEnemy(i) = '0' then
                    if yEnemy(i) < 80 then yEnemy(i) <= yEnemy(i) + 1;
                    else dirEnemy(i) <= '1'; end if;
                  else
                    if yEnemy(i) > 50 then yEnemy(i) <= yEnemy(i) - 1;
                    else dirEnemy(i) <= '0'; end if;
                  end if;
                
                when 1 =>
                  if dirEnemy(i) = '0' then
                    if yEnemy(i) < 50 then yEnemy(i) <= yEnemy(i) + 1;
                    else dirEnemy(i) <= '1'; end if;
                  else
                    if yEnemy(i) > 30 then yEnemy(i) <= yEnemy(i) - 1;
                    else dirEnemy(i) <= '0'; end if;
                  end if;
                
                when 2 =>
                  if dirEnemy(i) = '0' then
                    if yEnemy(i) < 80 then yEnemy(i) <= yEnemy(i) + 1;
                    else dirEnemy(i) <= '1'; end if;
                  else
                    if yEnemy(i) > 60 then yEnemy(i) <= yEnemy(i) - 1;
                    else dirEnemy(i) <= '0'; end if;
                  end if;
                  
                when 3 =>
                  if dirEnemy(i) = '0' then
                    if yEnemy(i) < 40 then yEnemy(i) <= yEnemy(i) + 1;
                    else dirEnemy(i) <= '1'; end if;
                  else
                    if yEnemy(i) > 20 then yEnemy(i) <= yEnemy(i) - 1;
                    else dirEnemy(i) <= '0'; end if;
                  end if;
  
                when 4 =>
                  if dirEnemy(i) = '0' then
                    if yEnemy(i) < 100 then yEnemy(i) <= yEnemy(i) + 1;
                    else dirEnemy(i) <= '1'; end if;
                  else
                    if yEnemy(i) > 80 then yEnemy(i) <= yEnemy(i) - 1;
                    else dirEnemy(i) <= '0'; end if;
                  end if;
  
                when 5 | 6 =>  
                  if dirEnemy(5) = '0' then  
                    if yEnemy(5) < 70 then 
                      yEnemy(5) <= yEnemy(5) + 1;
                      yEnemy(6) <= yEnemy(6) + 1;
                    else 
                      dirEnemy(5) <= '1';
                      dirEnemy(6) <= '1';
                    end if;
                  else
                    if yEnemy(5) > 20 then 
                      yEnemy(5) <= yEnemy(5) - 1;
                      yEnemy(6) <= yEnemy(6) - 1;
                    else 
                      dirEnemy(5) <= '0';
                      dirEnemy(6) <= '0';
                    end if;
                  end if;
              end case;
            end if;
          end loop;
        end if;
      end if;
    end process; 
  
    disparos_enemigos:
    process(clk)
      variable hit_jugador : boolean;
    begin
      if rising_edge(clk) then
        if rstSync = '1' then
        --reset de todos los disparos enemigos
          for i in 0 to NUM_ENEMIGOS-1 loop
            for j in 0 to MAX_DISPAROS_ENEMIGOS-1 loop
              disparos_enem_act(i,j) <= '0';
            end loop;
            contadores_disparo_enem(i) <= (others => '0');
          end loop;
          vidas <= MAX_VIDAS;
        elsif esperando_reinicio then
          for i in 0 to NUM_ENEMIGOS-1 loop
            for j in 0 to MAX_DISPAROS_ENEMIGOS-1 loop
              disparos_enem_act(i,j) <= '0';
            end loop;
            contadores_disparo_enem(i) <= (others => '0');
          end loop;
          vidas <= MAX_VIDAS;
          finPartida <= false;
        elsif mover and not finPartida then
        --manejo de disparos enemigos
          hit_jugador := false;
          for i in 0 to NUM_ENEMIGOS-1 loop
            if enemy_control(i) = '1' then -- solo si el enemigo está activo
            --cuenta de disparo para cada enemigo
              if contadores_disparo_enem(i) > 0 then
                contadores_disparo_enem(i) <= contadores_disparo_enem(i) - 1;
              else
                contadores_disparo_enem(i) <= to_unsigned(CADENCIA_DISPARO_ENEMIGO, 8);
                for j in 0 to MAX_DISPAROS_ENEMIGOS-1 loop
                  if disparos_enem_act(i,j) = '0' then
                    --se crea nuevo disparo
                    disparos_enem_x(i,j) <= xEnemy(i) - ANCHO_DISPARO;
                    disparos_enem_y(i,j) <= yEnemy(i) + SPRITE_ALTO/2 - ALTO_DISPARO/2;
                    disparos_enem_act(i,j) <= '1';
                    exit;
                  end if;
                end loop;
              end if;
            end if;
        
            -- mover disparos existentes
            for j in 0 to MAX_DISPAROS_ENEMIGOS-1 loop
              if disparos_enem_act(i,j) = '1' then
                if enemy_control(i) = '0' then
                  disparos_enem_act(i,j) <= '0';
                elsif disparos_enem_x(i,j) > VELOCIDAD_DISPARO_ENEMIGO then
                  disparos_enem_x(i,j) <= disparos_enem_x(i,j) - VELOCIDAD_DISPARO_ENEMIGO;
                else
                  disparos_enem_act(i,j) <= '0'; -- desactivar disparo al salir de pantalla
                end if;
            
                -- colision con el jugador
                if disparos_enem_x(i,j) + ANCHO_DISPARO >= xLeft and disparos_enem_x(i,j) <= xLeft + SPRITE_ANCHO and
                  disparos_enem_y(i,j) + ALTO_DISPARO >= yLeft and disparos_enem_y(i,j) <= yLeft + SPRITE_ALTO then
                  disparos_enem_act(i,j) <= '0'; -- desactivar disparo
                  hit_jugador := true; 
                end if;
              end if;
            end loop;
          end loop;
          
          if hit_jugador then
            if vidas > 0 then
              vidas <= vidas - 1;
            end if;
            if vidas = 0 then
              finPartida <= true;
            end if;
          end if;
        end if;
      end if;
    end process;
end syn;