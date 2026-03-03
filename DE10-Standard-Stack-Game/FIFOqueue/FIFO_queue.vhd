library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FIFO_queue is
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;
        clear_queue : in std_logic;

        enqueue      : in  std_logic;
        enqueue_data : in  std_logic_vector(49 downto 0);
        dequeue      : in  std_logic;

        view_set_tail : in std_logic;
        view_set_last : in std_logic;
        view_next     : in std_logic;
        view_read     : in std_logic;

        empty : out std_logic;
        full  : out std_logic;
        count : out unsigned(3 downto 0);

        view_data       : out std_logic_vector(49 downto 0);
        view_data_valid : out std_logic
    );
end FIFO_queue;

architecture arch_FIFO_queue of FIFO_queue is

    ------------------------------------------------------------------
    -- RAM
    ------------------------------------------------------------------
    component RAM_module is
        port(
            address : in  std_logic_vector(4 downto 0);
            clock   : in  std_logic;
            data    : in  std_logic_vector(49 downto 0);
            rden    : in  std_logic;
            wren    : in  std_logic;
            q       : out std_logic_vector(49 downto 0)
        );
    end component;

    ------------------------------------------------------------------
    -- Señales internas
    ------------------------------------------------------------------
    signal head       : unsigned(3 downto 0) := (others => '0');
    signal tail       : unsigned(3 downto 0) := (others => '0');
    signal view_ptr   : unsigned(3 downto 0) := (others => '0');
    signal elem_count : unsigned(3 downto 0) := (others => '0');

    signal ram_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal ram_data : std_logic_vector(49 downto 0) := (others => '0');
    signal ram_wren : std_logic := '0';
    signal ram_rden : std_logic := '0';
    signal ram_q    : std_logic_vector(49 downto 0);

    signal view_read_d : std_logic := '0';

    ------------------------------------------------------------------
    -- Funciones módulo 11
    ------------------------------------------------------------------
    function next11(x : unsigned(3 downto 0)) return unsigned is
    begin
        if x = to_unsigned(10,4) then
            return to_unsigned(0,4);
        else
            return x + 1;
        end if;
    end function;

    function prev11(x : unsigned(3 downto 0)) return unsigned is
    begin
        if x = to_unsigned(0,4) then
            return to_unsigned(10,4);
        else
            return x - 1;
        end if;
    end function;

begin

    ------------------------------------------------------------------
    -- INSTANCIA RAM
    ------------------------------------------------------------------
    u_ram : RAM_module
        port map(
            address => ram_addr,
            clock   => clk,
            data    => ram_data,
            rden    => ram_rden,
            wren    => ram_wren,
            q       => ram_q
        );

    ------------------------------------------------------------------
    -- SALIDAS DE ESTADO
    ------------------------------------------------------------------
    empty <= '1' when elem_count = 0  else '0';
    full  <= '1' when elem_count = 11 else '0';
    count <= elem_count;

    view_data <= ram_q;

    ------------------------------------------------------------------
    -- REG_HEAD
    ------------------------------------------------------------------
    REG_HEAD: process(clk, rst)
    begin
        if rst = '1' or clear_queue = '1' then
            head <= (others => '0');
        elsif clk'event and clk = '1' then
            if enqueue = '1' and elem_count < 11 then
                head <= next11(head);
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- REG_TAIL
    ------------------------------------------------------------------
    REG_TAIL: process(clk, rst)
    begin
        if rst = '1' or clear_queue = '1' then
            tail <= (others => '0');
        elsif clk'event and clk = '1' then
            if dequeue = '1' and elem_count > 0 then
                tail <= next11(tail);
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- REG_VIEW_PTR
    ------------------------------------------------------------------
    REG_VIEW_PTR: process(clk, rst)
    begin
        if rst = '1' or clear_queue = '1' then
            view_ptr <= (others => '0');
        elsif clk'event and clk = '1' then

            if view_set_tail = '1' then
                view_ptr <= tail;

            elsif view_set_last = '1' then
                if elem_count > 0 then
                    view_ptr <= prev11(head);
                else
                    view_ptr <= tail;
                end if;

            elsif view_next = '1' then
                view_ptr <= next11(view_ptr);
            end if;

        end if;
    end process;

    ------------------------------------------------------------------
    -- CONT_ELEM_COUNT
    ------------------------------------------------------------------
    CONT_ELEM_COUNT: process(clk, rst)
    begin
        if rst = '1' or clear_queue = '1' then
            elem_count <= (others => '0');
        elsif clk'event and clk = '1' then

            if enqueue = '1' and elem_count < 11 then
                elem_count <= elem_count + 1;

            elsif dequeue = '1' and elem_count > 0 then
                elem_count <= elem_count - 1;

            end if;

        end if;
    end process;

    ------------------------------------------------------------------
    -- REG_VIEW_VALID
    ------------------------------------------------------------------
    REG_VIEW_VALID: process(clk, rst)
    begin
        if rst = '1' or clear_queue = '1' then
            view_read_d <= '0';
            view_data_valid <= '0';
        elsif clk'event and clk = '1' then
            view_data_valid <= view_read_d;
            view_read_d <= view_read;
        end if;
    end process;

    ------------------------------------------------------------------
    -- CONTROL RAM (CONCURRENTE)
    ------------------------------------------------------------------
    ram_wren <= '1' when enqueue = '1' and elem_count < 11 else '0';

    ram_rden <= '1' when view_read = '1' else '0';

    ram_addr <= std_logic_vector(resize(head,5))
                when enqueue = '1' and elem_count < 11 else
                std_logic_vector(resize(view_ptr,5))
                when view_read = '1' else
                (others => '0');

    ram_data <= enqueue_data when enqueue = '1' else (others => '0');

end arch_FIFO_queue;