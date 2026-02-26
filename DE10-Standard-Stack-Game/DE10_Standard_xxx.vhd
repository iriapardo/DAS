library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DE10_Standard_xxx is
  port(
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(2 downto 0);
    UART_RX  : in  std_logic;
    LEDR     : out std_logic_vector(9 downto 0);
    HEX0     : out std_logic_vector(6 downto 0);
    HEX1     : out std_logic_vector(6 downto 0);

    LT24_LCD_ON  : out std_logic;
    LT24_RESET_N : out std_logic;
    LT24_CS_N    : out std_logic;
    LT24_RD_N    : out std_logic;
    LT24_RS      : out std_logic;
    LT24_WR_N    : out std_logic;
    LT24_D       : out std_logic_vector(15 downto 0)
  );
end;

architecture rtl of DE10_Standard_xxx is

  signal clk, reset, reset_l : std_logic;

  -- LT24
  signal cs_n, wr_n, rs : std_logic;
  signal init_done : std_logic;
  signal d : std_logic_vector(15 downto 0);

  -- LCD_CTRL <-> DRAWRECT
  signal set_cursor   : std_logic;
  signal draw_colour  : std_logic;
  signal x_col        : unsigned(7 downto 0);
  signal y_row        : unsigned(8 downto 0);
  signal rect_numpix  : unsigned(16 downto 0);
  signal rgb_colour   : unsigned(15 downto 0);
  signal done_cursor  : std_logic;
  signal done_colour  : std_logic;
  signal done_rect    : std_logic;

  -- STACK GAME outputs
  signal s_x_pos    : unsigned(7 downto 0);
  signal s_y_pos    : unsigned(8 downto 0);
  signal s_w        : unsigned(7 downto 0);
  signal s_h        : unsigned(8 downto 0);
  signal s_rgb      : unsigned(15 downto 0);
  signal s_lvl_tens : unsigned(3 downto 0);
  signal s_lvl_units: unsigned(3 downto 0);
  signal s_delegate_draw : std_logic;
  signal s_space_detected : std_logic;

  --------------------------------------------------------------------
  component LT24Setup
  port(
    clk, reset_l : in std_logic;
    LT24_LCD_ON, LT24_RESET_N, LT24_CS_N,
    LT24_RS, LT24_WR_N, LT24_RD_N : out std_logic;
    LT24_D : out std_logic_vector(15 downto 0);
    LT24_CS_N_Int, LT24_RS_Int,
    LT24_WR_N_Int, LT24_RD_N_Int : in std_logic;
    LT24_D_Int : in std_logic_vector(15 downto 0);
    LT24_Init_Done : out std_logic
  );
  end component;

  component LCD_CTRL
  port(
    reset, CLK : in std_logic;
    LCD_INIT_DONE : in std_logic;
    OP_SETCURSOR  : in std_logic;
    XCOL          : in std_logic_vector(7 downto 0);
    YROW          : in std_logic_vector(8 downto 0);
    OP_DRAWCOLOUR : in std_logic;
    RGB           : in std_logic_vector(15 downto 0);
    NUMPIX        : in std_logic_vector(16 downto 0);
    DONE_CURSOR, DONE_COLOUR : out std_logic;
    LCD_CSN, LCD_RS, LCD_WRN : out std_logic;
    LCD_DATA : out std_logic_vector(15 downto 0)
  );
  end component;

  component LCD_DRAWRECT
  port(
    reset, clk : in std_logic;
    rect_x     : in unsigned(7 downto 0);
    rect_y     : in unsigned(8 downto 0);
    rect_w     : in unsigned(7 downto 0);
    rect_h     : in unsigned(8 downto 0);
    rect_rgb   : in unsigned(15 downto 0);
    rect_draw  : in std_logic;
    ctrl_done_cursor : in std_logic;
    ctrl_done_colour : in std_logic;
    set_cursor : out std_logic;
    x_col      : out unsigned(7 downto 0);
    y_row      : out unsigned(8 downto 0);
    draw_colour: out std_logic;
    rgb_colour : out unsigned(15 downto 0);
    rect_numpix: out unsigned(16 downto 0);
    done_rect  : out std_logic
  );
  end component;

  component stack_game_logic
  port(
    reset, clk          : in std_logic;
    push_button         : in std_logic;
    --push_button_2       : in std_logic;
    draw_rect_done_rect : in std_logic;

    x_pos    : out unsigned(7 downto 0);
    y_pos    : out unsigned(8 downto 0);
    r_width  : out unsigned(7 downto 0);
    r_height : out unsigned(8 downto 0);
    r_RGB    : out unsigned(15 downto 0);
    lvl_tens : out unsigned(3 downto 0);
    lvl_units: out unsigned(3 downto 0);
    delegate_draw : out std_logic
  );
  end component;

  component uart_module
  port(
    clk            : in  std_logic;
    reset          : in  std_logic;
    uart_rx        : in  std_logic;
    space_detected : out std_logic
  );
  end component;

  component hex_7seg
  port(
    hex : in std_logic_vector(3 downto 0);
    dig : out std_logic_vector(6 downto 0)
  );
  end component;
  --------------------------------------------------------------------

begin

  clk     <= CLOCK_50;
  reset_l <= KEY(0);
  reset   <= not KEY(0);

  --------------------------------------------------------------------
  -- LT24
  --------------------------------------------------------------------
  C1: LT24Setup
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

  --------------------------------------------------------------------
  -- LCD CTRL
  --------------------------------------------------------------------
  C2: LCD_CTRL
  port map (
    clk => clk,
    reset => reset,
    LCD_INIT_DONE => init_done,

    OP_SETCURSOR  => set_cursor,
    XCOL          => std_logic_vector(x_col),
    YROW          => std_logic_vector(y_row),

    OP_DRAWCOLOUR => draw_colour,
    RGB           => std_logic_vector(rgb_colour),
    NUMPIX        => std_logic_vector(rect_numpix),

    DONE_CURSOR => done_cursor,
    DONE_COLOUR => done_colour,

    LCD_CSN  => cs_n,
    LCD_RS   => rs,
    LCD_WRN  => wr_n,
    LCD_DATA => d
  );

  --------------------------------------------------------------------
  -- STACK GAME LOGIC
  --------------------------------------------------------------------
  U_UART: uart_module
  port map (
    clk => clk,
    reset => reset,
    uart_rx => UART_RX,
    space_detected => s_space_detected
  );

  U_GAME: stack_game_logic
  port map (
    clk   => clk,
    reset => reset,
    push_button => s_space_detected or not(KEY(1)),
    --push_button_2 => s_space_detected,
    draw_rect_done_rect => done_rect,

    x_pos    => s_x_pos,
    y_pos    => s_y_pos,
    r_width  => s_w,
    r_height => s_h,
    r_RGB    => s_rgb,
    lvl_tens => s_lvl_tens,
    lvl_units => s_lvl_units,
    delegate_draw => s_delegate_draw
  );

  --------------------------------------------------------------------
  -- DRAWRECT
  --------------------------------------------------------------------
  U_RECT: LCD_DRAWRECT
  port map (
    clk => clk,
    reset => reset,

    rect_x   => s_x_pos,
    rect_y   => s_y_pos,
    rect_w   => s_w,
    rect_h   => s_h,
    rect_rgb => s_rgb,

    rect_draw => s_delegate_draw,

    ctrl_done_cursor => done_cursor,
    ctrl_done_colour => done_colour,

    set_cursor  => set_cursor,
    x_col       => x_col,
    y_row       => y_row,
    draw_colour => draw_colour,
    rgb_colour  => rgb_colour,
    rect_numpix => rect_numpix,

    done_rect => done_rect
  );

  --------------------------------------------------------------------
  -- 7-SEG LEVEL DISPLAY
  --------------------------------------------------------------------
  U_HEX_UNITS: hex_7seg
  port map (
    hex => std_logic_vector(s_lvl_units),
    dig => HEX0
  );

  U_HEX_TENS: hex_7seg
  port map (
    hex => std_logic_vector(s_lvl_tens),
    dig => HEX1
  );

  -- Debug opcional
  LEDR(0) <= init_done;
  LEDR(1) <= s_delegate_draw;
  LEDR(2) <= done_rect;
  LEDR(3) <= s_space_detected;
  LEDR(4) <= UART_RX;
  LEDR(9 downto 5) <= (others => '0');

end rtl;
