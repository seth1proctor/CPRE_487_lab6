----------------------------------------------------------------------------------
-- Convolutional MAC Unit
--
-- Gregory Ling, 2024
----------------------------------------------------------------------------------

library work;
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity conv_mac is
  generic(
      C_DATA_WIDTH : integer := 32;
      C_OUTPUT_DATA_WIDTH : integer := 32
    );
    port (  
        S_AXIS_TREADY : out std_logic;
        S_AXIS_TDATA  : in  std_logic_vector(C_DATA_WIDTH*2-1 downto 0);
        S_AXIS_TLAST  : in  std_logic;
        S_AXIS_TVALID : in  std_logic;

        bias : in std_logic_vector(C_OUTPUT_DATA_WIDTH-1 downto 0);

        M_AXIS_TREADY : in  std_logic;
        M_AXIS_TDATA  : out std_logic_vector(C_OUTPUT_DATA_WIDTH-1 downto 0);
        M_AXIS_TLAST  : out std_logic;
        M_AXIS_TVALID : out std_logic;

        rst : in std_logic;
        clk : in std_logic
    );

end conv_mac;


architecture behavioral of conv_mac is

  signal output_result_internal, output_hold : signed(C_OUTPUT_DATA_WIDTH-1 downto 0);  -- Internal accumulator result

  -- Debug signals, used to monitor behavior
  signal mac_debug : std_logic_vector(31 downto 0);

begin

  process (clk)
  begin 
      if rising_edge(clk) then
          -- Reset condition
          if rst = '1' then
              output_result_internal <= resize(signed(bias), C_OUTPUT_DATA_WIDTH);
              S_AXIS_TREADY <= '0';
              M_AXIS_TLAST <= '0';
          elsif M_AXIS_TREADY = '0' then
              output_hold <= output_hold;
              output_result_internal <= output_result_internal;
              S_AXIS_TREADY <= '0';
              M_AXIS_TLAST <= '0';

          else
              if S_AXIS_TVALID = '1' then
                  if S_AXIS_TLAST = '1' then
                      output_result_internal <= resize(signed(bias), C_OUTPUT_DATA_WIDTH);
                      output_hold <= resize(signed(S_AXIS_TDATA(C_DATA_WIDTH*2-1 downto C_DATA_WIDTH)) * signed(S_AXIS_TDATA(C_DATA_WIDTH-1 downto 0)), C_OUTPUT_DATA_WIDTH) + output_result_internal;
                  else 
                      output_hold <= (others => 'X');
                      output_result_internal <= output_result_internal + resize(signed(S_AXIS_TDATA(C_DATA_WIDTH*2-1 downto C_DATA_WIDTH)) * signed(S_AXIS_TDATA(C_DATA_WIDTH-1 downto 0)), C_OUTPUT_DATA_WIDTH);
                  end if;
                  M_AXIS_TLAST <= '1';
                  S_AXIS_TREADY <= '1';   
              else 
                  output_result_internal <= output_result_internal;
                  M_AXIS_TLAST <= '1';
              end if;
          end if;
      end if;
      if falling_edge(clk) then
          if S_AXIS_TVALID = '1' and S_AXIS_TLAST = '1' then
              M_AXIS_TVALID <= '1';
              M_AXIS_TDATA <= std_logic_vector(output_hold);
          else
              M_AXIS_TDATA <= (others => 'X');
              M_AXIS_TVALID <= '0';
          end if;
      end if;
  end process;

  -- Debug signal (optional)
  mac_debug <= x"00000000";  -- Can be used to monitor internal states for debugging


end architecture behavioral;
