LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.all;
USE IEEE.NUMERIC_STD.all;
 
ENTITY counter8 IS
  PORT (
    clk       : IN std_logic; 
    reset     : IN std_logic; 
    enable    : IN std_logic;
    load      : IN std_logic;
    data_ini  : IN std_logic_vector(7 DOWNTO 0);
    count     : OUT std_logic_vector(7 DOWNTO 0);
    tc        : OUT std_logic
  );
END counter8;
 
ARCHITECTURE arch1 OF counter8 IS
   SIGNAL cnt : unsigned(7 DOWNTO 0);
 
BEGIN
 
   PROCESS (clk, reset)
   BEGIN
     IF reset = '1' THEN
       cnt <= (others => '0');
     ELSIF clk'event AND clk='1' THEN
       IF load = '1' THEN
         cnt <= unsigned(data_ini);
       ELSIF enable='1' THEN
         cnt <= cnt + 1;
       END IF;
     END IF;
   END PROCESS;
 
   tc <= '1' WHEN cnt = "11111111" ELSE '0';
   count <= std_logic_vector(cnt);
 
END arch1;