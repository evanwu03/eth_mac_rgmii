
import os
import sys
from pathlib import Path

# TB_DIR on path
TB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TB_DIR))

import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb_tools.runner import get_runner

from common.clock_reset import reset_dut
from common.clock_reset import start_clock



CLK_PERIOD_NS = 10
FRAME_LEN_BYTES = 60
NUM_FRAMES = 10


async def setup_dut(dut):
    """Initialize DUT inputs and start clock."""
    dut.i_reset_n.value = 0
    dut.m_axis_tready.value = 1

@cocotb.test()
async def test_packet_gen_runs_until_last_frame(dut):

    clk = dut.i_clk
    rst = dut.i_reset_n

    start_clock(clk, period_ns=CLK_PERIOD_NS)

    await setup_dut(dut)
    await reset_dut(clk, rst, active_low=True, cycles=2)

    dut.m_axis_tready.value = 1

    frame_count = 0
    byte_count = 0

    while frame_count < NUM_FRAMES:
        await RisingEdge(dut.i_clk
)

        valid = int(dut.m_axis_tvalid.value)
        ready = int(dut.m_axis_tready.value)
        last = int(dut.m_axis_tlast.value)

        if valid and ready:
            dut._log.info(
                f"frame={frame_count} byte={byte_count} "
                f"data=0x{int(dut.m_axis_tdata.value):02x} last={last}"
            )

            if last:
                assert byte_count == FRAME_LEN_BYTES - 1, (
                    f"TLAST asserted at byte {byte_count}, "
                    f"expected {FRAME_LEN_BYTES - 1}"
                )

                frame_count += 1
                byte_count = 0
            else:
                byte_count += 1

    # Give DUT one cycle to drop TVALID after final frame
    await RisingEdge(dut.i_clk)
    await ReadOnly()

    assert int(dut.m_axis_tvalid.value) == 0, (
        "m_axis_tvalid should deassert after NUM_FRAMES frames"
    )


    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut._log.info("packet_gen completed 10 frames successfully")

def test_packet_gen_runner():
    
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [ 
        proj_path / "rtl" / "packet_gen.sv",
        ]

    runner = get_runner(sim)

    parameters = {

    }

    runner.build(
        sources=sources,
        hdl_toplevel="packet_gen",
        parameters=parameters,
        build_dir="sim_build/packet_gen",
        always=True,
        clean=True
        
    )

    runner.test(
        hdl_toplevel="packet_gen",
        test_module="packet_gen",
        parameters=parameters,
        build_dir="sim_build/packet_gen",
        
    )

if __name__ == "__main__":
    test_packet_gen_runner()
