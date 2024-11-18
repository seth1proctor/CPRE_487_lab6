----------------------------------------------------------------------------------
-- Input & Filter Index Generator
--
-- Gregory Ling, 2024
----------------------------------------------------------------------------------

library work;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity index_gen is
    generic(
        DIM_WIDTH : integer := 32;
        INPUT_ADDR_WIDTH : integer := 32;
        FILTER_ADDR_WIDTH : integer := 32;
        OUTPUT_ADDR_WIDTH : integer := 32
    );
    port(
        filter_w : in std_logic_vector(DIM_WIDTH-1 downto 0); -- Filter dimension width (Filter width)
        filter_h : in std_logic_vector(DIM_WIDTH-1 downto 0); -- Filter dimension height (Filter height)
        filter_c : in std_logic_vector(DIM_WIDTH-1 downto 0); -- Filter dimension channels (Filter channels == Input channels)
        output_w : in std_logic_vector(DIM_WIDTH-1 downto 0); -- Output dimension width (Output width)
        output_h : in std_logic_vector(DIM_WIDTH-1 downto 0); -- Output dimension height (Output height)
        input_end_diff_fw : in std_logic_vector(INPUT_ADDR_WIDTH-1 downto 0); -- Amount to add to addr when completing a filter row
        input_end_diff_fh : in std_logic_vector(INPUT_ADDR_WIDTH-1 downto 0); -- Amount to add to addr when completing a filter column
        input_end_diff_fc : in std_logic_vector(INPUT_ADDR_WIDTH-1 downto 0); -- Amount to add to addr when completing a filter channel
        input_end_diff_ow : in std_logic_vector(INPUT_ADDR_WIDTH-1 downto 0); -- Amount to add to addr when completing an output row
        
        M_AXIS_TREADY : in std_logic;
        M_AXIS_TDATA_input_addr : out std_logic_vector(INPUT_ADDR_WIDTH-1 downto 0);
        M_AXIS_TDATA_filter_addr : out std_logic_vector(FILTER_ADDR_WIDTH-1 downto 0);
        M_AXIS_TLAST : out std_logic;
        M_AXIS_TVALID : out std_logic;

        conv_idle : in std_logic; -- When the convolution is idle, reset the index generator. Starts counting on falling edge
        rst : in std_logic;
        clk : in std_logic
    );
end index_gen;

architecture Behavioral of index_gen is
    signal input_addr : unsigned(INPUT_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal filter_addr : unsigned(FILTER_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal output_row : unsigned(DIM_WIDTH-1 downto 0) := (others => '0');
    signal output_col : unsigned(DIM_WIDTH-1 downto 0) := (others => '0');
    signal channel_count : unsigned(DIM_WIDTH-1 downto 0) := (others => '0');

    signal valid : std_logic := '0';
    signal last : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            input_addr <= (others => '0');
            filter_addr <= (others => '0');
            output_row <= (others => '0');
            output_col <= (others => '0');
            channel_count <= (others => '0');
            valid <= '0';
            last <= '0';
        elsif rising_edge(clk) then
            if conv_idle = '1' then
                input_addr <= (others => '0');
                filter_addr <= (others => '0');
                output_row <= (others => '0');
                output_col <= (others => '0');
                channel_count <= (others => '0');
                valid <= '0';
                last <= '0';
            elsif M_AXIS_TREADY = '1' then
                valid <= '1';

                if channel_count < unsigned(filter_c) - 1 then
                    channel_count <= channel_count + 1;
                    input_addr <= input_addr + unsigned(input_end_diff_fw);
                    filter_addr <= filter_addr + 1;
                elsif output_col < unsigned(output_w) - 1 then
                    channel_count <= (others => '0');
                    output_col <= output_col + 1;
                    input_addr <= input_addr + unsigned(input_end_diff_fh);
                elsif output_row < unsigned(output_h) - 1 then
                    channel_count <= (others => '0');
                    output_col <= (others => '0');
                    output_row <= output_row + 1;
                    input_addr <= input_addr + unsigned(input_end_diff_fc);
                else
                    last <= '1';
                end if;
            end if;
        end if;
    end process;

    M_AXIS_TDATA_input_addr <= std_logic_vector(input_addr);
    M_AXIS_TDATA_filter_addr <= std_logic_vector(filter_addr);
    M_AXIS_TVALID <= valid;
    M_AXIS_TLAST <= last;
end Behavioral;
