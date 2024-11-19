----------------------------------------------------------------------------------
-- Dequantization Unit
--
-- Gregory Ling, 2024
----------------------------------------------------------------------------------

library work;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dequantization is
    generic(
        C_DATA_WIDTH : integer := 32;
        C_TID_WIDTH : integer := 1;
        C_OUT_WIDTH : integer := 8
    );
    port(
        S_AXIS_TREADY : out std_logic;
        S_AXIS_TDATA  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        S_AXIS_TLAST  : in  std_logic;
        S_AXIS_TID    : in  std_logic_vector(C_TID_WIDTH-1 downto 0);
        S_AXIS_TVALID : in  std_logic;

        relu : in std_logic;
        q_scale : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        q_zero : in std_logic_vector(C_OUT_WIDTH-1 downto 0);

        M_AXIS_TREADY : in  std_logic;
        M_AXIS_TDATA  : out std_logic_vector(C_OUT_WIDTH-1 downto 0);
        M_AXIS_TLAST  : out std_logic;
        M_AXIS_TID    : out std_logic_vector(C_TID_WIDTH-1 downto 0);
        M_AXIS_TVALID : out std_logic;

        clk : in std_logic;
        rst : in std_logic
    );
end dequantization;

architecture Behavioral of dequantization is
    -- Internal signals
    signal scaled_value : signed(C_OUT_WIDTH-1 downto 0);
    signal dequantized_value : signed(C_OUT_WIDTH downto 0);
    signal output_value : signed(C_OUT_WIDTH-1 downto 0);
    signal valid_data : std_logic := '0';
    signal last_signal : std_logic := '0';
    signal tid_signal : std_logic_vector(C_TID_WIDTH-1 downto 0) := (others => '0');

begin
    process(clk, rst)
    begin
        if rst = '1' then
            valid_data <= '0';
            last_signal <= '0';
            tid_signal <= (others => '0');
            M_AXIS_TDATA <= (others => '0');
        elsif rising_edge(clk) then
            if S_AXIS_TVALID = '1' and M_AXIS_TREADY = '1' then
                -- Dequantization calculation: scale * input + zero point
                scaled_value <= resize(signed(S_AXIS_TDATA) * signed(q_scale), C_OUT_WIDTH);
                dequantized_value <= scaled_value + signed(('0' & q_zero));

                -- Apply ReLU if enabled
                if relu = '1' then
                    if dequantized_value < 0 then
                        output_value <= (others => '0');
                    else
                        output_value <= dequantized_value(C_OUT_WIDTH-1 downto 0);
                    end if;
                else
                    output_value <= dequantized_value(C_OUT_WIDTH-1 downto 0);
                end if;

                -- Capture output signals
                valid_data <= '1';
                last_signal <= S_AXIS_TLAST;
                tid_signal <= S_AXIS_TID;
            else
                valid_data <= '0';
            end if;
        end if;
    end process;

    -- Output assignments
    S_AXIS_TREADY <= M_AXIS_TREADY;
    M_AXIS_TDATA <= std_logic_vector(output_value);
    M_AXIS_TVALID <= valid_data;
    M_AXIS_TLAST <= last_signal;
    M_AXIS_TID <= tid_signal;

end Behavioral;
