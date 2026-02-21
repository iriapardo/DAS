library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_ctrl_tb is 

end;


architecture lcd_ctrl_tb_arch of lcd_ctrl_tb is

constant n : integer := 8;
constant m : integer := 16;

-- entradas del módulo

		signal reset: std_logic := '1';
		signal clk: std_logic := '0';
		signal lcd_init_done: std_logic := '0';
		signal op_setcursor: std_logic := '0';
		signal xcol: unsigned (n - 1  downto 0);
		signal yrow: unsigned (n  downto 0);
		signal op_drawcolor: std_logic := '0';
		signal rgb: unsigned (m - 1 downto 0);
		signal num_pix: unsigned (m downto 0);

-- salidas del módulo 

		signal done_cursor: std_logic := '0';
 		signal done_colour: std_logic := '0';
 		signal lcd_cs_n: std_logic := '0';
		signal lcd_wr_n: std_logic := '0';
		signal lcd_rs: std_logic := '0';
		signal lcd_data: unsigned (m - 1 downto 0);

component lcd_ctrl
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
		op_drawcolor: in std_logic;
		rgb: in unsigned (m - 1 downto 0);
		num_pix: in unsigned (m downto 0);
		
		done_cursor: out std_logic;
 		done_colour: out std_logic;
 		lcd_cs_n: out std_logic;
		lcd_wr_n: out std_logic;
		lcd_rs: out std_logic;
		lcd_data: out unsigned (m - 1 downto 0)
		
	);
end component; 

begin

DUT : lcd_ctrl
  -- GENERIC MAP (
  --   n => n,
  --   m => m
  -- )
  PORT MAP (
    clk            => clk,
    reset          => reset,

    lcd_init_done  => lcd_init_done,
    op_setcursor   => op_setcursor,
    xcol           => xcol,
    yrow           => yrow,

    op_drawcolor   => op_drawcolor,
    rgb            => rgb,
    num_pix        => num_pix,

    done_cursor    => done_cursor,
    done_colour    => done_colour,
    lcd_cs_n       => lcd_cs_n,
    lcd_wr_n       => lcd_wr_n,
    lcd_rs         => lcd_rs,
    lcd_data       => lcd_data
  );

 -- definicion reloj
  clk <= not clk after 10 ns;

process 
    begin

    wait ;
end process;

end;


