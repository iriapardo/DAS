library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_module is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    uart_rx        : in  std_logic;
    space_detected : out std_logic
  );
end uart_module;

architecture arch_uart_module of uart_module is

  signal load_uart_cicle_count : std_logic := '0';
  signal load_uart_byte_count  : std_logic := '0';
  signal incr_uart_byte_count  : std_logic := '0';
  signal load_byte_desp_reg    : std_logic := '0';
  signal byte_desp_der         : std_logic := '0';

  -- Registro de entrada RX
  signal uart_rx_reg_out : std_logic := '1';

  -- Contador de ciclos UART
  signal uart_cicle_count_value : unsigned(12 downto 0) := (others => '0');
  signal half_uart_count        : std_logic;
  signal done_uart_count        : std_logic;

  -- Contador de byte
  signal uart_byte_count_value : unsigned(2 downto 0) := (others => '0');
  signal done_uart_byte_count  : std_logic;

  -- Registro de desplazamiento del byte recibido
  signal byte_desp_reg_out : std_logic_vector(7 downto 0) := (others => '0');
  signal is_space          : std_logic;
  
  type estado is (e0, e1, e2, e3, e4, e5, e6, e7);
  signal epres, esig: estado;

begin

  -- REGISTRO UART RX
  REG_UART_RX: process (clk, reset, uart_rx)
  begin
    if reset = '1' then
      uart_rx_reg_out <= '1';
    elsif clk'event and clk = '1' then
      uart_rx_reg_out <= uart_rx;
    end if;
  end process;

  -- CONTADOR DE CICLOS
  CONT_UART_CICLE: process (clk, reset, load_uart_cicle_count, uart_cicle_count_value)
  begin
    if reset = '1' then
      uart_cicle_count_value <= (others => '0');
    elsif clk'event and clk = '1' then
      if load_uart_cicle_count = '1' then
        uart_cicle_count_value <= (others => '0');
      else
        uart_cicle_count_value <= uart_cicle_count_value + 1;
      end if;
    end if;
  end process;

  half_uart_count <= '1' when uart_cicle_count_value = to_unsigned(2603, 13) else '0';
  done_uart_count <= '1' when uart_cicle_count_value = to_unsigned(5207, 13) else '0';

  -- CONTADOR DE BYTE 
  CONT_UART_BYTE: process (clk, reset, load_uart_byte_count, incr_uart_byte_count, uart_byte_count_value)
  begin
    if reset = '1' then
      uart_byte_count_value <= (others => '0');
    elsif clk'event and clk = '1' then
      if load_uart_byte_count = '1' then
        uart_byte_count_value <= (others => '0');
      elsif incr_uart_byte_count = '1' then
        uart_byte_count_value <= uart_byte_count_value + 1;
      end if;
    end if;
  end process;
  done_uart_byte_count <= '1' when uart_byte_count_value = "000" else '0';

  -- REGISTRO DE DESPLAZAMIENTO
  REG_BYTE_DESP: process (clk, reset, load_byte_desp_reg, byte_desp_der, byte_desp_reg_out, uart_rx_reg_out)
  begin
    if reset = '1' then
      byte_desp_reg_out <= (others => '0');
    elsif clk'event and clk = '1' then
      if load_byte_desp_reg = '1' then
        byte_desp_reg_out <= (others => '0');
      elsif byte_desp_der = '1' then
        byte_desp_reg_out(6 downto 0) <= byte_desp_reg_out(7 downto 1);
        byte_desp_reg_out(7) <= uart_rx_reg_out;
      end if;
    end if;
  end process;

  -- COMPARADOR ASCII ESPACIO: 0010_0000
  is_space <= '1' when byte_desp_reg_out = "00100000" else '0';
  
  
  -- UNIDAD DE CONTROL
  	process (clk,reset) --proceso s ncrono que registra el estado en cada flanco

	begin
		if reset='1' then epres<=e0; --reset as�ncrono
		elsif clk'event and clk='1' then epres<=esig;
		end if;
	end process;
		
	process (epres, uart_rx_reg_out, half_uart_count, done_uart_count, done_uart_byte_count, is_space)
	begin 
		case (epres) is
			-- Esperamos por bit de start '0'.
			when e0 => if uart_rx_reg_out = '1' then esig <= e0;
						  else esig <= e1;
						  end if;
			-- Esperamos a estar en la mitad del bit.
			when e1 => if half_uart_count = '0' then esig <= e1;
						  -- Comprobamos si al estar en la mitad el bit tiene el valor que esperamos.
						  else if uart_rx_reg_out = '1' then esig <= e0;
								 else esig <= e2;
								 end if;
						  end if;
			when e2 => esig <= e3;
			when e3 => if done_uart_count = '1' then esig <= e4;
						  else esig <= e3;
						  end if;
			when e4 => if done_uart_byte_count = '1' then esig <= e5;
						  else esig <= e2;
						  end if;
			when e5 => esig <= e6;
			when e6 => if done_uart_count = '0' then esig <= e6;
						  else if uart_rx_reg_out = '0' or is_space = '0' then esig <= e0;
								else esig <= e7;
								end if;
						  end if;
			when e7 => esig <= e0;
		end case	;
	end process;
	
  load_uart_cicle_count <= '1' when (epres=e0 and uart_rx_reg_out='0') or epres=e2 or epres=e5 else '0';
  byte_desp_der <= '1' when epres=e3 and done_uart_count='1' else '0';
  incr_uart_byte_count <= '1' when epres=e3 and done_uart_count='1' else '0';
  load_byte_desp_reg <= '1' when epres=e0 and uart_rx_reg_out='0' else '0';
  space_detected <= '1' when epres=e7 else '0';
  load_uart_byte_count <= '1' when epres=e0 and uart_rx_reg_out='0' else '0';

end arch_uart_module;
