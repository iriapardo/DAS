library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FIFO_queue is
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;

        -- Operaciones (pulso de 1 ciclo)
        enqueue      : in  std_logic;
        enqueue_data : in  std_logic_vector(49 downto 0);
        dequeue      : in  std_logic;

        view_set_tail : in std_logic;
        view_next     : in std_logic;
        view_read     : in std_logic;

        -- Estado
        empty : out std_logic;
        full  : out std_logic;
        count : out unsigned(3 downto 0);

        -- Salida lectura
        view_data       : out std_logic_vector(49 downto 0);
        view_data_valid : out std_logic
    );
end entity;

architecture rtl of FIFO_queue is

    ------------------------------------------------------------------
    -- Componente RAM generado por Quartus
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
    signal head, tail, view_ptr : unsigned(3 downto 0) := (others => '0'); -- 0..10
    signal elem_count           : unsigned(3 downto 0) := (others => '0'); -- 0..11

    -- RAM
    signal ram_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal ram_data : std_logic_vector(49 downto 0) := (others => '0');
    signal ram_wren : std_logic := '0';
    signal ram_rden : std_logic := '0';
    signal ram_q    : std_logic_vector(49 downto 0);

    signal view_read_d : std_logic := '0';  -- para generar valid

    ------------------------------------------------------------------
    -- Función módulo 11
    ------------------------------------------------------------------
    function next11(x : unsigned(3 downto 0)) return unsigned is
    begin
        if x = to_unsigned(10,4) then
            return to_unsigned(0,4);
        else
            return x + 1;
        end if;
    end function;

begin

    ------------------------------------------------------------------
    -- Instancia de la RAM física
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
    -- Salidas de estado
    ------------------------------------------------------------------
    empty <= '1' when elem_count = 0  else '0';
    full  <= '1' when elem_count = 11 else '0';
    count <= elem_count;

    view_data <= ram_q;

    ------------------------------------------------------------------
    -- Lógica principal
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                head <= (others => '0');
                tail <= (others => '0');
                view_ptr <= (others => '0');
                elem_count <= (others => '0');

                ram_wren <= '0';
                ram_rden <= '0';

                view_read_d <= '0';
                view_data_valid <= '0';

            else

                -- defaults
                ram_wren <= '0';
                ram_rden <= '0';

                -- valid 1 ciclo después del read
                view_data_valid <= view_read_d;
                view_read_d <= view_read;

                ------------------------------------------------------------------
                -- Control de view (no toca RAM)
                ------------------------------------------------------------------
                if view_set_tail = '1' then
                    view_ptr <= tail;

                elsif view_next = '1' then
                    view_ptr <= next11(view_ptr);
                end if;

                ------------------------------------------------------------------
                -- Operaciones (una por ciclo)
                ------------------------------------------------------------------
                if enqueue = '1' then

                    if elem_count < 11 then
                        ram_addr <= std_logic_vector(resize(head,5));
                        ram_data <= enqueue_data;
                        ram_wren <= '1';

                        head <= next11(head);
                        elem_count <= elem_count + 1;
                    end if;

                elsif dequeue = '1' then

                    if elem_count > 0 then
                        tail <= next11(tail);
                        elem_count <= elem_count - 1;
                    end if;

                elsif view_read = '1' then

                    ram_addr <= std_logic_vector(resize(view_ptr,5));
                    ram_rden <= '1';

                end if;

            end if;
        end if;
    end process;

end architecture;
