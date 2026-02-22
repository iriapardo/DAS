library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stack_game_logic is
  port (
		reset, clk: in std_logic;
		push_button: in std_logic;
		push_button_2: in std_logic;
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
	signal RGB_cont: unsigned (1 downto 0);
	signal incr_rgb_cont: std_logic;
	signal done_rgb_cont: std_logic;
	
	-- movimiento del bloque 
	signal moving_block_x: unsigned (7 downto 0);
	signal moving_block_RGB: unsigned (15 downto 0);
	signal rest: std_logic;

    signal dir: std_logic;
	signal x_plus_w: unsigned (8 downto 0);
	signal x_minor_equal_cero: std_logic;
	signal x_plus_w_greater_equal_240: std_logic;
	signal change_dir: std_logic;

	-- datapath de recorte
	signal bdo_x_plus_w: unsigned (8 downto 0);
	signal mux_bdo: std_logic;
	signal bdo_cmp_ref: unsigned (8 downto 0);
	signal fifo_is_right: std_logic;
	signal perfect: std_logic;
	signal left_left: std_logic;

	signal fvd_x_plus_w: unsigned (8 downto 0);
	signal mux_fvd: std_logic;
	signal fvd_cmp_ref: unsigned (8 downto 0);
	signal bdo_is_right: std_logic;

	signal end_game: std_logic;
	signal numpix_left: unsigned (8 downto 0);
	signal width_left_left: unsigned (8 downto 0);
	signal fvd_w_to_240: unsigned (7 downto 0);
	signal moving_block_x_pul: unsigned (7 downto 0);
	signal moving_block_y_pul: unsigned (8 downto 0);
	signal select_moving_block_w_pul: std_logic;
	signal moving_block_w_pul: unsigned (7 downto 0);
	signal moving_block_data: unsigned (49 downto 0);
	
	--Selección mapeo de salidas:
	signal select_draw_r_rgb: std_logic;
	signal select_draw_x_pos: std_logic;
	signal select_draw_y_pos: std_logic;
	signal select_draw_r_width: std_logic;
	signal select_draw_r_height: std_logic;
	signal select_draw_rgb_src: unsigned (1 downto 0);
	signal r_rgb_int: unsigned (15 downto 0);
	
	-- FIFO queue pyramid
	-- control
	signal fifo_enqueue      : std_logic := '0';
	signal fifo_enqueue_data : std_logic_vector(49 downto 0) := (others => '0');
	signal fifo_dequeue      : std_logic := '0';
	signal fifo_clear        : std_logic := '0';

	signal fifo_view_set_tail : std_logic := '0';
	signal fifo_view_set_last : std_logic := '0';
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
		to_unsigned(40, 8) &
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

	type estado is (init_q0,init_q1,inicio,e0,e1,e2,e2s,e2c,e2r,e2v,e2d,e2w,e2n,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12,e13,e14,e15);
   --type estado is (inicio,e0,e1,e2,e3);
	signal epres, esig: estado;
	signal draw_queue_idx: unsigned(3 downto 0);
	signal clr_draw_queue_idx: std_logic;
	signal inc_draw_queue_idx: std_logic;
	

begin 

-- INSTANCIA DE COLA FIFO PARA PYRAMID
    u_FIFO_queue : entity work.FIFO_queue
        port map(
            clk   => clk,
            rst   => reset,
            clear_queue => fifo_clear,

            enqueue      => fifo_enqueue,
            enqueue_data => fifo_enqueue_data,
            dequeue      => fifo_dequeue,

            view_set_tail => fifo_view_set_tail,
            view_set_last => fifo_view_set_last,
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
	desired_cicles<=to_unsigned(468750,19) - (to_unsigned(0,10)&r_desp_out);
		

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
	CONT_RGB: process(clk, reset, incr_rgb_cont, done_rgb_cont)
	begin
		if reset='1' then
			RGB_cont <= (others => '0');
		elsif clk'event and clk='1' then
			if done_rgb_cont='1' then
				RGB_cont <= (others => '0');
			elsif incr_rgb_cont='1' then
				RGB_cont <= RGB_cont + 1;
			end if;
		end if;
	end process;

	done_rgb_cont <= '1' when RGB_cont = "11" else '0';

	moving_block_RGB <= x"F800" when RGB_cont = "00" else -- rojo
			   x"FFE0" when RGB_cont = "01" else -- amarillo
			   x"001F" when RGB_cont = "10" else -- azul
			   x"07E0";                          -- verde

      	moving_block_x <= block_data_out(7 downto 0) - 1 when rest = '1' and block_data_out(7 downto 0) > to_unsigned(0, 8) 
			  else block_data_out(7 downto 0) + 1 when rest = '0' and block_data_out(7 downto 0) + block_data_out(24 downto 17)< to_unsigned(240, 8) 
			  else block_data_out(7 downto 0);

-- MUXER PRIMERA VEZ
	
	d_in_block_data <= D_IN_BLOCK_DATA_INI when sel_block_data = "01" else
			   moving_block_data when sel_block_data = "00" else
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

-- COMPONENTES DE RECORTE

	bdo_x_plus_w <= ('0' & block_data_out(7 downto 0)) + ('0' & block_data_out(24 downto 17));
	bdo_cmp_ref <= ('0' & block_data_out(7 downto 0)) when mux_bdo='0' else bdo_x_plus_w;

	fifo_is_right <= '1' when ('0' & unsigned(fifo_view_data(7 downto 0))) > bdo_cmp_ref else '0';
	perfect <= '1' when ('0' & unsigned(fifo_view_data(7 downto 0))) = bdo_cmp_ref else '0';
	left_left <= '1' when ('0' & unsigned(fifo_view_data(7 downto 0))) < bdo_cmp_ref else '0';

	fvd_x_plus_w <= ('0' & unsigned(fifo_view_data(7 downto 0))) + ('0' & unsigned(fifo_view_data(24 downto 17)));
	fvd_cmp_ref <= ('0' & unsigned(fifo_view_data(7 downto 0))) when mux_fvd='0' else fvd_x_plus_w;

	bdo_is_right <= '1' when ('0' & block_data_out(7 downto 0)) > fvd_cmp_ref else '0';
	end_game <= fifo_is_right or bdo_is_right;

	numpix_left <= bdo_cmp_ref - fvd_cmp_ref;
	width_left_left <= ('0' & block_data_out(24 downto 17)) - numpix_left;
	fvd_w_to_240 <= to_unsigned(240, 8) - unsigned(fifo_view_data(24 downto 17));
	moving_block_x_pul <= fvd_w_to_240 when dir='0' else to_unsigned(0, 8);
	moving_block_y_pul <= unsigned(fifo_view_data(16 downto 8)) - to_unsigned(20, 9);
	moving_block_w_pul <= numpix_left(7 downto 0) when select_moving_block_w_pul='0' else width_left_left(7 downto 0);
	moving_block_data <= block_data_out(49 downto 8) & moving_block_x when push_button_2='0' else
			     r_rgb_int & moving_block_w_pul & block_data_out(33 downto 25) & moving_block_y_pul & moving_block_x_pul;
	
--MAPEO DE SALIDAS	
	
	r_rgb_int <= x"0000" when select_draw_rgb_src="00" else
		     block_data_out(49 downto 34) when select_draw_rgb_src="01" else
		     unsigned(fifo_view_data(49 downto 34)) when select_draw_rgb_src="10" else
		     x"0000";
	r_RGB <= r_rgb_int;
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

	process (clk, reset)
	begin
		if reset='1' then
			draw_queue_idx <= (others => '0');
		elsif clk'event and clk='1' then
			if clr_draw_queue_idx='1' then
				draw_queue_idx <= (others => '0');
			elsif inc_draw_queue_idx='1' then
				draw_queue_idx <= draw_queue_idx + 1;
			end if;
		end if;
	end process;

	process (epres, move_block, draw_rect_done_rect, push_button, push_button_2, fifo_view_data_valid, draw_queue_idx, fifo_count)
	begin 
		case (epres) is
			when init_q0 => esig <= init_q1;
			when init_q1 => esig <= inicio;
			when inicio => if push_button='1' then esig <=e0;
					else esig <= inicio;
					end if;
			when e0 => esig <= e1;
			when e1 => esig <= e2;
			when e2 => if draw_rect_done_rect='1' then esig <= e2s;
				   else esig <= e2;
				   end if;
			when e2s => esig <= e2c;
			when e2c => if draw_queue_idx < fifo_count then esig <= e2r;
				    else esig <= e3;
				    end if;
			when e2r => esig <= e2v;
			when e2v => if fifo_view_data_valid='1' then esig <= e2d;
				    else esig <= e2v;
				    end if;
			when e2d => esig <= e2w;
			when e2w => if draw_rect_done_rect='1' then esig <= e2n;
				    else esig <= e2w;
				    end if;
			when e2n => esig <= e2c;
			when e3 => esig <= e4;
			when e4 => esig <= e5;
			when e5 => esig <= e6;
			when e6 => if push_button_2='0' then
								if move_block='0' then esig <= e6;
								else esig <= e7;
								end if;
						  else 
								esig <= e13;
						  end if;
	      --Dibujado del bloque en movimiento					  
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
			
			--Cálculo de recortes
			when e13 => if end_game='1' then esig <= init_q0;
							else esig <= e14;
							end if;
			when e14 => if left_left='1' then esig <= e15;
							else esig <= e6;
							end if;
			when e15 => esig <= e6;
		end case;
	end process;

fifo_enqueue <= '1' when epres=init_q0 else '0';
fifo_enqueue_data <= std_logic_vector(FIFO_INIT_RECT) when epres=init_q0 else (others => '0');
fifo_dequeue <= '0';
fifo_clear <= '1' when epres=e13 and end_game='1' else '0';
fifo_view_set_tail <= '1' when epres=e2s else '0';
fifo_view_set_last <= '0';
fifo_view_next <= '1' when epres=e2n else '0';
fifo_view_read <= '1' when epres=e2r else '0';
clr_draw_queue_idx <= '1' when epres=e2s else '0';
inc_draw_queue_idx <= '1' when epres=e2n else '0';

load_block_data <= '1' when epres=e0 or epres=e3 or epres=e9 or epres=e15 else '0';
load_r_desp <= '1' when epres=e4 else '0';
desp_izq <= '1' when epres=e5 else '0';
delegate_draw <= '1' when epres=e1 or epres=e2d or epres=e7 or epres=e10 else '0';
ld_cicle_count <= '1' when epres=e12 else '0';
incr_rgb_cont <= '0';
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
		  
mux_bdo <= '1' when epres=e13 or epres=e15 else '0';
mux_fvd <= '1' when epres=e13 or epres=e15 else '0';
select_moving_block_w_pul <= '1' when epres=e15 else '0';



end arch_stack_game_logic;

