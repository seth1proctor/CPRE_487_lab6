----------------------------------------------------------------------------------
-- Output Storage Unit
--
-- Gregory Ling, 2024
----------------------------------------------------------------------------------

library work;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity output_storage is
    generic(
        DATA_WIDTH : integer := 32;
        BRAM_DATA_WIDTH : integer := 32;
        ADDR_WIDTH : integer := 32;
        DIM_WIDTH : integer := 8;
        C_TID_WIDTH : integer := 1;
        BRAM_ADDR_WIDTH : integer := 32
    );
    port(
        S_AXIS_TREADY : out std_logic;
        S_AXIS_TDATA  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        S_AXIS_TLAST  : in  std_logic;
        S_AXIS_TID    : in  std_logic_vector(C_TID_WIDTH-1 downto 0);
        S_AXIS_TVALID : in  std_logic;

        BRAM_addr : out std_logic_vector(32-1 downto 0); -- Updated to be 32 bits wide
        BRAM_din : out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
        BRAM_dout : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
        BRAM_en : out std_logic;
        BRAM_we : out std_logic_vector((BRAM_DATA_WIDTH/8)-1 downto 0);
        BRAM_rst : out std_logic;
        BRAM_clk : out std_logic;

        max_pooling : in std_logic;
        elements_per_channel : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        output_w : in std_logic_vector(DIM_WIDTH-1 downto 0);
        output_h : in std_logic_vector(DIM_WIDTH-1 downto 0);
        initial_offset : in std_logic_vector(ADDR_WIDTH-1 downto 0);

        conv_complete : out std_logic;
        conv_idle : in std_logic;
        clk : in std_logic;
        rst : in std_logic
    );
end output_storage;

architecture Behavioral of output_storage is
    signal current_addr : unsigned(32-1 downto 0) := (others => '0');
    signal write_data : std_logic_vector(BRAM_DATA_WIDTH-1 downto 0) := (others => '0');
    signal write_enable : std_logic := '0';
    signal pooling_max : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_ready : std_logic := '0';
    signal last_received : std_logic := '0';
    signal s_temp_axis_tready: std_logic := '0';

begin
    process(clk, rst)
    begin
        if rst = '1' then
            current_addr <= (others => '0');
            write_data <= (others => '0');
            write_enable <= '0';
            pooling_max <= (others => '0');
            data_ready <= '0';
            last_received <= '0';
        elsif rising_edge(clk) then
            if conv_idle = '1' then
                current_addr <= resize(unsigned(initial_offset), 32);
                write_enable <= '0';
                data_ready <= '0';
                last_received <= '0';
            elsif S_AXIS_TVALID = '1' and s_temp_axis_tready = '1' then
                -- Handle max pooling if enabled
                if max_pooling = '1' then
                    if unsigned(S_AXIS_TDATA) > pooling_max then
                        pooling_max <= unsigned(S_AXIS_TDATA);
                    end if;
                    if S_AXIS_TLAST = '1' then
                        write_data <= std_logic_vector(resize(pooling_max, BRAM_DATA_WIDTH));
                        write_enable <= '1';
                        pooling_max <= (others => '0');
                    else
                        write_enable <= '0';
                    end if;
                else
                    write_data <= std_logic_vector(resize(unsigned(S_AXIS_TDATA), BRAM_DATA_WIDTH));
                    write_enable <= '1';
                end if;

                -- Update address
                if S_AXIS_TLAST = '1' then
                    last_received <= '1';
                end if;
                current_addr <= current_addr + 1;
            else
                write_enable <= '0';
            end if;
        end if;
    end process;

    -- Assign output signals
    S_AXIS_TREADY <= not last_received;
    s_temp_axis_tready <= not last_received;
    BRAM_addr <= std_logic_vector(current_addr); -- 32-bit wide address
    BRAM_din <= write_data;
    BRAM_en <= '1';
    BRAM_we <= (others => write_enable);
    BRAM_rst <= rst;
    BRAM_clk <= clk;
    conv_complete <= last_received;

end Behavioral;
