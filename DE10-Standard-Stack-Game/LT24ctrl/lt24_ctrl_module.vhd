library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_ctrl is
  generic (
	n : integer := 8;
	m : integer := 16
  ); 
  port (
		reset, clk: in std_logic;
		lcd_init_done: in std_logic;
		op_setcursor: in std_logic;
		xcol: in unsigned (n - 1  downto 0);
		yrow: in unsigned (n  downto 0);
		op_drawcolour: in std_logic;
		rgb: in unsigned (m - 1 downto 0);
		numpix: in unsigned (m downto 0);
		
		done_cursor: out std_logic;
 		done_colour: out std_logic;
 		lcd_csn: out std_logic;
		lcd_wrn: out std_logic;
		lcd_rs: out std_logic;
		lcd_data: out unsigned (m - 1 downto 0)
		
	);
end lcd_ctrl;


architecture arch_lcd_ctrl of lcd_ctrl is 
	signal ld_cursor: std_logic;
	signal ld_draw: std_logic;
	signal rx_col: unsigned (n - 1 downto 0);
	signal ry_row: unsigned (n downto 0); 
	signal r_rgb: unsigned (m - 1 downto 0); 

	--signal num_pix: unsigned (m downto 0);
	signal dec_pix: std_logic;
	signal end_pix: std_logic;
	signal rem_pix: unsigned (m downto 0);
	
	signal q_dat: unsigned (n-1 downto 0);
	signal cl_lcd_data: std_logic;
	
	signal mux_cd_out: unsigned(m-1 downto 0);

	signal ld_2c: std_logic;
	signal cl_dat: std_logic;
	signal inc_dat: std_logic;

	signal rs_dat: std_logic;
	signal rs_com: std_logic;
	
	type estado is (e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12,e13,e14);
	signal epres, esig: estado;


begin 

-- REGISTROS XCOL, YROW, RGB

	REG_XCOL: process(clk, reset, xcol, ld_cursor)
	begin	
		if reset='1' then rx_col <= (others => '0');
		elsif clk'event and clk='1' and ld_cursor='1' then rx_col <= xcol;
		end if;
	end process;

	REG_YROW: process(clk, reset, yrow, ld_cursor)
	begin	
		if reset='1' then ry_row <= (others => '0');
		elsif clk'event and clk='1' and ld_cursor='1' then ry_row <= yrow;
		end if;
	end process;

	REG_RGB: process(clk, reset, rgb, ld_draw)
	begin	
		if reset='1' then r_rgb <= (others => '0');
		elsif clk'event and clk='1' and ld_draw='1' then r_rgb <= rgb;
		end if;
	end process;

-- CONTADOR PIXELES

	CONT_PIX: process(clk, reset, numpix, ld_draw, dec_pix)
	begin 
		if reset='1' then rem_pix <= (others => '0');
		elsif clk'event and clk='1' then
			if ld_draw='1' then rem_pix <= numpix;
			elsif dec_pix='1' then rem_pix <= rem_pix - 1;
			end if;
		end if;
	end process;
	end_pix <= '1' when rem_pix = (x"0000"&'0') else '0';


-- CONTADOR PARA QDAT

	CONT_QDAT: process(clk, reset, inc_dat, cl_dat, ld_2c)
	begin 
		if reset='1' then q_dat <= (others => '0');
		elsif clk'event and clk='1' then
			if ld_2c='1' then q_dat <= x"06";
			elsif cl_dat='1' then q_dat <= (others => '0');
			elsif inc_dat='1' then q_dat <= q_dat + 1;
			end if;
		end if;
	end process;
		 
-- MUX

	mux_cd_out <= x"002A" when q_dat = x"00" else 
		      x"0000" when q_dat = x"01" else
		      x"00"&rx_col when q_dat = x"02" else
		      x"002b" when q_dat = x"03" else
		      x"000"&"000"&ry_row(8) when q_dat = x"04" else 
		      x"00"&ry_row(7 downto 0) when q_dat = x"05" else
		      x"002c" when q_dat = x"06" else
		      r_rgb;

	lcd_data <= mux_cd_out when cl_lcd_data = '0' else 
		    x"0000";


-- BIESTABLE:


	BI_LCD_RS: process(clk, reset, rs_com, rs_dat)
	begin 
		if reset='1' then lcd_rs <= '0';
		elsif clk'event and clk='1' then
			if rs_dat='1' then lcd_rs <= '1';
			elsif rs_com='1' then lcd_rs <= '0';
		        end if;
		end if;
	end process;



--UNIDAD DE CONTROL (L�GICA DE ESTADOS)  	  
    	

	process (clk,reset) --proceso s�ncrono que registra el estado en cada flanco

	begin
		if reset='1' then epres<=e0; --reset as�ncrono
		elsif clk'event and clk='1' then epres<=esig;
		end if;
	end process;

process (epres, lcd_init_done, op_setcursor, op_drawcolour, end_pix, q_dat)
	begin 
		case (epres) is 
			when e0 => if lcd_init_done='1' then 
					if op_setcursor='1' then esig <= e1;
				   	elsif op_drawcolour='1' then esig <= e14;
					else esig <= e0;
					end if;
				   else esig <= e0;
				   end if;
			when e1 => esig <= e2;
			when e2 => esig <= e3;
			when e3 => esig <= e4;
			when e4 => if q_dat=x"05" then esig <= e11;
				   elsif q_dat=x"02" then esig <= e12;
                                   elsif q_dat=x"06" then esig <= e5;
			           else esig <= e13;
				   end if;
			when e5 => esig <= e6;
			when e6 => esig <= e7;
			when e7 => esig <= e8;
			when e8 => esig <= e9;
			when e9 => if end_pix='1' then esig <= e10;
				   else esig <= e6;
				   end if;
			when e10 => esig <= e0;
			when e11 => esig <= e0;
			when e12 => esig <= e2;
			when e13 => esig <= e2;
			when e14 => esig <= e2; 
		end case;
	end process;

---sentencias de asignacion concurrente para cada se�al de control
cl_lcd_data<='1' when epres=e0 or epres=e1 or epres=e14 else '0';
ld_cursor<='1' when epres=e1 else '0';
cl_dat<='1' when epres=e1 else '0';
rs_com<='1' when epres=e1 or epres=e12 or epres=e14 else '0';
lcd_wrn<='0' when epres=e2 or epres=e6 else '1';
lcd_csn<='0' when epres=e2 or epres=e6 else '1';
inc_dat<='1' when epres=e5 or epres=e12 or epres=e13 else '0';
rs_dat<='1' when epres=e5 or epres=e13 else '0';
dec_pix<='1' when epres=e7 else '0';
done_colour<='1' when epres=e10 else '0';
done_cursor<='1' when epres=e11 else '0';
ld_draw<='1' when epres=e14 else '0';
ld_2c<='1' when epres=e14 else '0';

end arch_lcd_ctrl;



