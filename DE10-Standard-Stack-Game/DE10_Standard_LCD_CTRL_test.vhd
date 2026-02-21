library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DE10_Standard_LCD_CTRL_test is
 port(
	-- CLOCK ----------------
	CLOCK_50	: in	std_logic;
	-- KEY ----------------
	KEY 		: in	std_logic_vector(0 downto 0);
	-- LEDR ----------------
   LEDR 		: out	std_logic_vector(9 downto 0);
	-- SW ----------------
	SW 			: in	std_logic_vector(9 downto 0);
	-- GPIO-LT24-UART ----------
	-- LCD --
 LT24_LCD_ON 	: out	std_logic;
 LT24_RESET_N	: out	std_logic;
 LT24_CS_N		: out	std_logic;
 LT24_RD_N		: out	std_logic;
 LT24_RS			: out	std_logic;
 LT24_WR_N		: out	std_logic;
 LT24_D			: out	std_logic_vector(15 downto 0)
	-- UART --
--	UART_RX		: in	std_logic;
	-- 7-SEG ----------------
--	HEX0	: out	std_logic_vector(6 downto 0);
--	HEX1	: out	std_logic_vector(6 downto 0);
--	HEX2	: out	std_logic_vector(6 downto 0);
--	HEX3	: out	std_logic_vector(6 downto 0);
--	HEX4	: out	std_logic_vector(6 downto 0);
--	HEX5	: out	std_logic_vector(6 downto 0);
); -- ***OJO*** ultimo de la lista sin ;

end;

architecture rtl of DE10_Standard_LCD_CTRL_test is 
	signal clk, reset, reset_l   : std_logic;
	
	component LT24Setup
	port(
      clk            : in      std_logic;
      reset_l        : in      std_logic;

      LT24_LCD_ON      : out std_logic;
      LT24_RESET_N     : out std_logic;
      LT24_CS_N        : out std_logic;
      LT24_RS          : out std_logic;
      LT24_WR_N        : out std_logic;
      LT24_RD_N        : out std_logic;
      LT24_D           : out std_logic_vector(15 downto 0);

      LT24_CS_N_Int        : in std_logic;
      LT24_RS_Int          : in std_logic;
      LT24_WR_N_Int        : in std_logic;
      LT24_RD_N_Int        : in std_logic;
      LT24_D_Int           : in std_logic_vector(15 downto 0);
      
      LT24_Init_Done       : out std_logic
	);
	end component;

	component LCD_CTRL
	port(
		reset,CLK			: in std_logic;

		LCD_INIT_DONE			: in std_logic;
		OP_SETCURSOR			: in std_logic;
		XCOL				: in std_logic_vector(7 downto 0);
		YROW				: in std_logic_vector(8 downto 0);
		OP_DRAWCOLOUR			: in std_logic;
		RGB				: in std_logic_vector(15 downto 0);
		NUMPIX				: in std_logic_vector(16 downto 0);
		DONE_CURSOR,DONE_COLOUR		: out std_logic;
		LCD_CSN,LCD_RS,LCD_WRN		: out std_logic;
		LCD_DATA			: out std_logic_vector(15 downto 0)
	);
	end component;
	
	signal cs_n : std_logic;
	signal wr_n : std_logic;
	signal rs : std_logic;
	signal tic1, tic2 : std_logic;
	signal init_done : std_logic;
	signal rgb : std_logic_vector(15 downto 0);
	signal d : std_logic_vector(15 downto 0);
	signal ciclos : unsigned(18 downto 0);
	signal pos : unsigned(7 downto 0);
	signal done_cursor  : std_logic;
	signal done_colour  : std_logic;

	
	
begin
	clk <= CLOCK_50;
	reset_l <= KEY(0);
	reset <= not(KEY(0));

	C1: LT24setup
	port map (
      clk => clk,
      reset_l => reset_l,

      LT24_LCD_ON => LT24_LCD_ON,
      LT24_RESET_N => LT24_RESET_N,
      LT24_CS_N => LT24_CS_N,
      LT24_RS => LT24_RS,
      LT24_WR_N => LT24_WR_N,
      LT24_RD_N => LT24_RD_N,
      LT24_D => LT24_D,

      LT24_CS_N_Int => cs_n,
      LT24_RS_Int => rs,
      LT24_WR_N_Int => wr_n,
      LT24_RD_N_Int => '1',
      LT24_D_Int => d,
      
      LT24_Init_Done => init_done
		);
	
	C2: LCD_CTRL
	port map (
		 clk => clk,
		 reset => reset,

		 LCD_INIT_DONE => init_done,
		 OP_SETCURSOR  => tic1,
		 XCOL => std_logic_vector(pos),
		 YROW => std_logic_vector('0' & pos),
		 OP_DRAWCOLOUR => tic2,
		 RGB => rgb,
		 NUMPIX => "0000000000" & SW(9 downto 3),

		 DONE_CURSOR => done_cursor,
		 DONE_COLOUR => done_colour,


		 LCD_CSN => cs_n,
		 LCD_RS  => rs,
		 LCD_WRN => wr_n,
		 LCD_DATA => d
	);
	
	LEDR(0) <= done_cursor;
	LEDR(1) <= done_colour;


	
	process (clk, reset)
	begin
		if reset = '1' then
			ciclos <= (others => '0');
		elsif (clk'event) and (clk='1') then
			ciclos <= ciclos + 1;
		end if;
	end process;
	
	tic1 <= '1' when ciclos = to_unsigned(0, 19)   else '0';
	tic2 <= '1' when ciclos = to_unsigned(2**18, 19)   else '0';
		
	process (clk, reset)
	begin
		if reset = '1' then
			pos <= (others => '0');
		elsif (clk'event) and (clk='1') then
			if tic1 = '1' then
				pos <= pos + 1;
			end if;
		end if;
	end process;
		
	
	rgb <= (15 downto 11 => SW(2), 10 downto 5 => SW(1), 4 downto 0 => SW(0));
		

end rtl;
