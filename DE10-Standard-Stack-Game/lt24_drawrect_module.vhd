library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_drawrect is
  port (
		reset, clk: in std_logic;
		rect_x: in unsigned (7 downto 0);
		rect_y: in unsigned (8 downto 0);
		rect_w: in unsigned (7 downto 0);
		rect_h: in unsigned (8 downto 0);
		rect_rgb: in unsigned (15 downto 0);
		rect_draw: in std_logic;
		ctrl_done_cursor: in std_logic;
		ctrl_done_colour: in std_logic;

		set_cursor: out std_logic;
		x_col: out unsigned (7 downto 0);
		y_row: out unsigned (8 downto 0);
		draw_colour: out std_logic;
		rgb_colour: out unsigned (15 downto 0);
		rect_numpix: out unsigned (16 downto 0);
		done_rect: out std_logic
	);

end lcd_drawrect;

architecture arch_lcd_drawrect of lcd_drawrect is 
	signal r_rect_x: unsigned (7 downto 0);
	signal r_rect_y: unsigned (8 downto 0);
	signal r_rect_w: unsigned (7 downto 0);
	signal r_rect_h: unsigned (8 downto 0);
	signal r_rect_rgb: unsigned (15 downto 0);

	signal incr: std_logic;
	signal done_cont: std_logic;
	signal cont_value: unsigned (8 downto 0);

	type estado is (e0,e1,e2,e3,e4);
	signal epres, esig: estado;
	

begin 

-- REGISTROS RECT_X, RECT_Y, RECT_W, RECT_H, RECT_RGB
	REG_RECT_X: process(clk, reset, rect_x, rect_draw)
	begin	
		if reset='1' then r_rect_x <= (others => '0');
		elsif clk'event and clk='1' and rect_draw='1' then r_rect_x <= rect_x;
		end if;
	end process;

	REG_RECT_Y: process(clk, reset, rect_y, rect_draw)
	begin	
		if reset='1' then r_rect_y <= (others => '0');
		elsif clk'event and clk='1' and rect_draw='1' then r_rect_y <= rect_y;
		end if;
	end process;

	REG_RECT_W: process(clk, reset, rect_w, rect_draw)
	begin	
		if reset='1' then r_rect_w <= (others => '0');
		elsif clk'event and clk='1' and rect_draw='1' then r_rect_w <= rect_w;
		end if;
	end process;

	REG_RECT_H: process(clk, reset, rect_h, rect_draw)
	begin	
		if reset='1' then r_rect_h <= (others => '0');
		elsif clk'event and clk='1' and rect_draw='1' then r_rect_h <= rect_h;
		end if;
	end process;

	REG_RECT_RGB: process(clk, reset, r_rect_rgb, rect_draw)
	begin	
		if reset='1' then r_rect_rgb <= (others => '0');
		elsif clk'event and clk='1' and rect_draw='1' then r_rect_rgb <= rect_rgb;
		end if;
	end process;

-- CONTADOR ALTURA RECTANGULO

	CONT_RECT_H: process(clk, reset, incr, done_cont, r_rect_h)
	begin 
		if reset='1' then cont_value <= (others => '0');
		elsif clk'event and clk='1' then
			if done_cont='1' then cont_value <= (others => '0');
			elsif incr='1' then cont_value <= cont_value + 1;
			end if;
		end if;
	end process;
	done_cont <= '1' when cont_value = r_rect_h else '0';

-- SUMADOR Y_ROW

	y_row <= r_rect_y + cont_value;

	x_col <= r_rect_x;
	
	rgb_colour <= r_rect_rgb;

	rect_numpix <= "000000000"&r_rect_w;
	
	done_rect <= done_cont;



--UNIDAD DE CONTROL (L�GICA DE ESTADOS)  	  
    	

	process (clk,reset) --proceso s�ncrono que registra el estado en cada flanco

	begin
		if reset='1' then epres<=e0; --reset as�ncrono
		elsif clk'event and clk='1' then epres<=esig;
		end if;
	end process;

	process (epres, rect_draw, ctrl_done_cursor, ctrl_done_colour, done_cont)
	begin 
		case (epres) is 
			when e0 => if rect_draw='1' then esig <= e1;
				   else esig <= e0;
				   end if;
			when e1 => if ctrl_done_cursor='1' then esig <= e2;
				   else esig <= e1;
				   end if;
			when e2 => if ctrl_done_colour='1' then esig <= e3;
				   else esig <= e2;
				   end if;
			when e3 => esig <= e4;	
			when e4 => if done_cont='1' then esig <= e0;
				   else esig <= e1;
				   end if;
		end case;
	end process;


set_cursor <= '1' when epres=e1 else '0';
draw_colour <= '1' when epres=e2 else '0';
incr <= '1' when epres=e3 else '0';




end arch_lcd_drawrect;
