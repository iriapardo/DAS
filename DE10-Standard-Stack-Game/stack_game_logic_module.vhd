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
		r_width: out unsigned (7 downto 0);
		r_height: out unsigned (8 downto 0);
		r_RGB: out unsigned (15 downto 0);
		delegate_draw: out std_logic
		
	);
end stack_game_logic;

architecture arch_stack_game_logic of stack_game_logic is 

	-- registro del bloque actual
	signal d_in_block_data: unsigned (49 downto 0);
	signal load_block_data: std_logic;
	signal block_data_out: unsigned (49 downto 0);

	-- registro de desplazamiento
	signal load_r_desp: std_logic;
	signal desp_izq: std_logic;
	signal d_in_r_desp: unsigned (7 downto 0);
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
	signal x_minor_equal_cero: std_logic;
	signal x_plus_w_greater_equal_240: std_logic;
	signal change_dir: std_logic;
	
	--Selección mapeo de salidas:
	signal select_draw_r_rgb: std_logic;
	signal select_draw_x_pos: std_logic;
	signal select_draw_y_pos: std_logic;
	signal select_draw_r_width: std_logic;
	signal select_draw_r_height: std_logic;
	signal select_draw_rgb_src: unsigned (1 downto 0);
	
	-- FIFO queue pyramid
	-- control
	signal fifo_enqueue      : std_logic := '0';
	signal fifo_enqueue_data : std_logic_vector(49 downto 0) := (others => '0');
	signal fifo_dequeue      : std_logic := '0';

	signal fifo_view_set_tail : std_logic := '0';
	signal fifo_view_next     : std_logic := '0';
	signal fifo_view_read     : std_logic := '0';

	-- status
	signal fifo_empty  : std_logic;
	signal fifo_full   : std_logic;
	signal fifo_count  : unsigned(3 downto 0);

	-- salida lectura
	signal fifo_view_data       : std_logic_vector(49 downto 0);
	signal fifo_view_data_valid : std_logic;


	signal sel_block_data: unsigned (1 downto 0);
	constant D_IN_BLOCK_DATA_INI: unsigned (49 downto 0):=
		to_unsigned(16#07E0#, 16) &
		to_unsigned(20, 9) &
		to_unsigned(80, 8) &
		to_unsigned(280, 9) &
		to_unsigned(160, 8);

	constant BLACK_SCREEN: unsigned (49 downto 0):=
		to_unsigned(16#0000#, 16) &
		to_unsigned(320, 9) &
		to_unsigned(240, 8) &
		to_unsigned(0, 9) &
		to_unsigned(0, 8);

	constant FIFO_INIT_RECT: unsigned (49 downto 0):=
		to_unsigned(16#F800#, 16) &
		to_unsigned(20, 9) &
		to_unsigned(80, 8) &
		to_unsigned(300, 9) &
		to_unsigned(80, 8);

	type estado is (init_q0,init_q1,inicio,e0,e1,e2,e2r,e2v,e2d,e2w,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12);
   --type estado is (inicio,e0,e1,e2,e3);
	signal epres, esig: estado;
	

begin 

-- INSTANCIA DE COLA FIFO PARA PYRAMID
    u_FIFO_queue : entity work.FIFO_queue
        port map(
            clk   => clk,
            rst   => reset,

            enqueue      => fifo_enqueue,
            enqueue_data => fifo_enqueue_data,
            dequeue      => fifo_dequeue,

            view_set_tail => fifo_view_set_tail,
            view_next     => fifo_view_next,
            view_read     => fifo_view_read,

            empty => fifo_empty,
            full  => fifo_full,
            count => fifo_count,

            view_data       => fifo_view_data,
            view_data_valid => fifo_view_data_valid
        );


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
			if load_r_desp='1' then r_desp_out <= d_in_r_desp;
			elsif desp_izq='1' then r_desp_out(7 downto 1)<=r_desp_out(6 downto 0);
				   	    r_desp_out(0)<='0';
			end if;
		end if;
	end process;

	d_in_r_desp<="01010000" - block_data_out(24 downto 17);
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


-- SUM/REST POSICI�N0
      	moving_block_x <= block_data_out(7 downto 0) - 1 when rest = '1' and block_data_out(7 downto 0) > to_unsigned(0, 8) 
			  else block_data_out(7 downto 0) + 1 when rest = '0' and block_data_out(7 downto 0) + block_data_out(24 downto 17)< to_unsigned(240, 8) 
			  else block_data_out(7 downto 0);

-- MUXER PRIMERA VEZ
	
	d_in_block_data <= D_IN_BLOCK_DATA_INI when sel_block_data = "01" else
			   block_data_out(49 downto 8) & moving_block_x when sel_block_data = "00" else
			   BLACK_SCREEN when sel_block_data = "10" else
			   (others => '0');

-- BIESTABLES

	BI_LCD_RS: process(clk, reset, change_dir)
	begin 
		if reset='1' then dir <= '0';
		elsif clk'event and clk='1' then
			if change_dir='1' then dir <= not dir;
		        end if;
		end if;
	end process;
	

	x_plus_w <= ('0'&block_data_out(7 downto 0)) + ('0'&block_data_out(24 downto 17));
	x_minor_equal_cero <= '1' when block_data_out(7 downto 0) <= x"00" else '0';
	x_plus_w_greater_equal_240 <= '1' when x_plus_w >= "011110000" else '0';

	change_dir <= move_block and (x_minor_equal_cero or x_plus_w_greater_equal_240);
	
	rest <= dir;
	
--MAPEO DE SALIDAS	
	
	r_RGB   <= x"0000" when select_draw_rgb_src="00" else
		   block_data_out(49 downto 34) when select_draw_rgb_src="01" else
		   unsigned(fifo_view_data(49 downto 34)) when select_draw_rgb_src="10" else
		   x"0000";
	r_width <= unsigned(fifo_view_data(24 downto 17)) when select_draw_r_width='1' else block_data_out(24 downto 17);
	y_pos   <= unsigned(fifo_view_data(16 downto 8)) when select_draw_y_pos='1' else block_data_out(16 downto 8);
	x_pos   <= unsigned(fifo_view_data(7 downto 0)) when select_draw_x_pos='1' else block_data_out(7 downto 0);
	r_height <= unsigned(fifo_view_data(33 downto 25)) when select_draw_r_height='1' else block_data_out(33 downto 25); 


--UNIDAD DE CONTROL (L GICA DE ESTADOS)  	

	process (clk,reset) --proceso s ncrono que registra el estado en cada flanco

	begin
		if reset='1' then epres<=init_q0; --reset as�ncrono
		elsif clk'event and clk='1' then epres<=esig;
		end if;
	end process;

	process (epres, move_block, draw_rect_done_rect, push_button, fifo_view_data_valid)
	begin 
		case (epres) is
			when init_q0 => esig <= init_q1;
			when init_q1 => esig <= inicio;
			when inicio => if push_button='1' then esig <=e0;
					else esig <= inicio;
					end if;
			when e0 => esig <= e1;
			when e1 => esig <= e2;
			when e2 => if draw_rect_done_rect='1' then esig <= e2r;
				   else esig <= e2;
				   end if;
			when e2r => esig <= e2v;
			when e2v => if fifo_view_data_valid='1' then esig <= e2d;
				    else esig <= e2v;
				    end if;
			when e2d => esig <= e2w;
			when e2w => if draw_rect_done_rect='1' then esig <= e3;
				    else esig <= e2w;
				    end if;
			when e3 => esig <= e4;
			when e4 => esig <= e5;
			when e5 => esig <= e6;
			when e6 => if move_block='1' then esig <= e7;
					else esig <= e6;
				   end if;
			when e7 => esig <= e8;
			when e8 => if draw_rect_done_rect='1' then esig <= e9;
				   else esig <= e8;
				   end if;
			when e9 => esig <= e10;
			when e10 => esig <= e11;
			when e11 => if draw_rect_done_rect='1' then esig <= e12;
				    else esig <= e11;
				    end if;
			when e12 => esig <= e6;
		end case;
	end process;

fifo_enqueue <= '1' when epres=init_q0 else '0';
fifo_enqueue_data <= std_logic_vector(FIFO_INIT_RECT) when epres=init_q0 else (others => '0');
fifo_dequeue <= '0';
fifo_view_set_tail <= '0';
fifo_view_next <= '0';
fifo_view_read <= '1' when epres=e2r else '0';

load_block_data <= '1' when epres=e0 or epres=e3 or epres=e9 else '0';
load_r_desp <= '1' when epres=e4 else '0';
desp_izq <= '1' when epres=e5 else '0';
delegate_draw <= '1' when epres=e1 or epres=e2d or epres=e7 or epres=e10 else '0';
ld_cicle_count <= '1' when epres=e12 else '0';
select_draw_r_rgb <= '1' when epres=e10 or epres=e1 or epres=e2d or epres=e2w or epres=e11 else '0';
select_draw_x_pos <= '1' when epres=e2d or epres=e2w else '0';
select_draw_y_pos <= '1' when epres=e2d or epres=e2w else '0';
select_draw_r_width <= '1' when epres=e2d or epres=e2w else '0';
select_draw_r_height <= '1' when epres=e2d or epres=e2w else '0';
select_draw_rgb_src <= "10" when epres=e2d or epres=e2w else
		       "01" when select_draw_r_rgb='1' else
		       "00";
sel_block_data <= "10" when epres=e0 else
		  "01" when epres=e3 else
		  "00";


end arch_stack_game_logic;

