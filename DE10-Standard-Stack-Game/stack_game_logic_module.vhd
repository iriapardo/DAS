library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stack_game_logic is
  port (
		reset, clk: in std_logic;
		push_button: in std_logic;
		draw_rect_done_rect: in std_logic;
		
		x_pos: out unsigned (7 downto 0);
 		y_pos: out unsigned (8 downto 0);
 		r_width: out unsigned (6 downto 0);
		r_height: out unsigned (4 downto 0);
		r_RGB: out unsigned (15 downto 0);
		delegate_draw: out std_logic
		
	);
end stack_game_logic;

architecture arch_stack_game_logic of stack_game_logic is 

	-- registro del bloque actual
	signal d_in_block_data: unsigned (39 downto 0);
	signal load_block_data: std_logic;
	signal block_data_out: unsigned (39 downto 0);

	-- registro de desplazamiento
	signal load_r_desp: std_logic;
	signal desp_izq: std_logic;
	signal d_in_r_desp: unsigned (6 downto 0);
	signal r_desp_out: unsigned (7 downto 0);

	-- contador de cliclos
	signal ld_cicle_count: std_logic;
	signal cicle_count_value: unsigned (18 downto 0);
	signal move_block: std_logic;
	
	-- calculo de ciclos deseados
	signal desired_cicles: unsigned (18 downto 0);
	
	-- movimiento del bloque 
	signal moving_block_x: unsigned (7 downto 0);
	signal rest: std_logic;

   signal dir: std_logic;
	signal x_plus_w: unsigned (8 downto 0);
	signal cero_equal_x: std_logic;
	signal x_plus_w_equal_239: std_logic;
	signal change_dir: std_logic;
	
	--Selección mapeo de salidas:
	signal select_draw_r_rgb: std_logic;
	

	signal first_time: std_logic := '1';
	constant D_IN_BLOCK_DATA_INI: unsigned (39 downto 0):=
		x"07e0" & 
                "1010000" &
		"100101100" &
		"01010000";

	type estado is (e0,e1,e2,e3,e4,e5,e6,e7,e8,e9);
	signal epres, esig: estado;
	


begin 

-- REGISTRO DEL BLOQUE ACTUAL
	REG_BLOCK_DATA: process(clk, reset, load_block_data, d_in_block_data)
	begin	
		if reset='1' then block_data_out <= (others => '0');
		elsif clk'event and clk='1' and load_block_data='1' then block_data_out <= d_in_block_data;
		end if;
	end process;
 

-- CALCULO DE CICLOS DESEADOS

	REG_RDESP: process(clk, reset, load_r_desp, desp_izq, d_in_r_desp)
	begin 
		if reset='1' then r_desp_out <= (others => '0');
		elsif clk'event and clk='1' then
			if load_r_desp='1' then r_desp_out <= "0"&d_in_r_desp;
			elsif desp_izq='1' then r_desp_out(7 downto 1)<=r_desp_out(6 downto 0);
				   	    r_desp_out(0)<='0';
			end if;
		end if;
	end process;

	d_in_r_desp<="1010000" - block_data_out(23 downto 17);
	--desired_cicles<="111010110" - ("0"&r_desp_out);
	desired_cicles<="1110010011100001110";
		


-- CONTADOR DE CICLOS

	CONT_CICLES: process(clk, reset, ld_cicle_count)
	begin 
		if reset='1' then cicle_count_value <= (others => '0');
		elsif clk'event and clk='1' then
			if ld_cicle_count='1' then cicle_count_value <= (others => '0');
			else  cicle_count_value <= cicle_count_value + 1;
			end if;
		end if;
	end process;
	move_block <= '1' when cicle_count_value = desired_cicles else '0';


-- SUM/REST POSICI�N

      	moving_block_x <= block_data_out(7 downto 0) - 1 when rest = '1'
			  else block_data_out(7 downto 0) + 1;

-- MUXERS
	
	d_in_block_data <= D_IN_BLOCK_DATA_INI when first_time='1' 
			   else block_data_out(39 downto 8) & moving_block_x;

-- BIESTABLES

	BI_LCD_RS: process(clk, reset, change_dir)
	begin 
		if reset='1' then dir <= '0';
		elsif clk'event and clk='1' then
			if change_dir='1' then dir <= not dir;
		        end if;
		end if;
	end process;
	

	x_plus_w <= ('0'&block_data_out(7 downto 0)) + ("00"&block_data_out(23 downto 17));
	cero_equal_x <= '1' when block_data_out(7 downto 0) = x"00" else '0';
	x_plus_w_equal_239 <= '1' when x_plus_w = "011101111" else '0';

	change_dir <= move_block and (cero_equal_x or x_plus_w_equal_239);
	
	rest <= dir;
	
--MAPEO DE SALIDAS	
	
	r_RGB   <= block_data_out(39 downto 24) when select_draw_r_rgb='1' else x"0000";
	r_width <= block_data_out(23 downto 17);
	y_pos   <= block_data_out(16 downto 8);
	x_pos   <= block_data_out(7 downto 0);
	r_height <= "10100"; 


--UNIDAD DE CONTROL (L�GICA DE ESTADOS)  	

	process (clk,reset) --proceso s�ncrono que registra el estado en cada flanco

	begin
		if reset='1' then epres<=e0; --reset as�ncrono
		elsif clk'event and clk='1' then epres<=esig;
		end if;
	end process;

	process (epres, move_block, draw_rect_done_rect)
	begin 
		case (epres) is 
			when e0 => esig <= e1;
			when e1 => esig <= e2;
			when e2 => esig <= e3;
			when e3 => if move_block='1' then esig <= e4;
				   else esig <= e3;
				   end if;
			when e4 => esig <= e5;
			when e5 => if draw_rect_done_rect='1' then esig <= e6;
				   else esig <= e5;
				   end if;
			when e6 => esig <= e7;
			when e7 => esig <= e8;
			when e8 => if draw_rect_done_rect='1' then esig <= e9;
				   else esig <= e8;
					end if;
			when e9 => esig <= e3;
		end case;
	end process;

first_time <= '1' when epres=e0 else '0';
load_block_data <= '1' when epres=e0 or epres=e6 else '0';
load_r_desp <= '1' when epres=e1 else '0';
desp_izq <= '1' when epres=e2 else '0';
delegate_draw <= '1' when epres=e4 or epres=e7 else '0';
ld_cicle_count <= '1' when epres=e9 else '0';
select_draw_r_rgb <= '1' when epres=e7 else '0';

end arch_stack_game_logic;