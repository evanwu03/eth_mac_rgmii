
import os
import sys
import itertools
from pathlib import Path
import logging


# TB_DIR on path
TB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TB_DIR))


import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from cocotb_tools.runner import get_runner
from cocotbext.axi import (AxiStreamFrame, AxiStreamBus, AxiStreamSource, AxiStreamMonitor)
from cocotb.handle import Immediate


# Test Helpers
def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = len(cocotb.top.s_axis_tdata)
    byte_width = data_width // 8
    return list(range(1, byte_width*4+1)) + [512] + [1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.i_clk, 2, unit="ns").start())

        self.source = AxiStreamSource(
            AxiStreamBus.from_prefix(dut, "s_axis"),
            dut.i_clk,
            dut.i_rst_n,
            reset_active_level=False,
        )

        self.s_axis_monitor = AxiStreamMonitor(
            AxiStreamBus.from_prefix(dut, "s_axis"),
            dut.i_clk,
            dut.i_rst_n,
            reset_active_level=False,
        )

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())


    async def reset(self):
        self.dut.i_rst_n.set(Immediate(1))
        for _ in range(2): 
            await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.set(Immediate(0))
        for _ in range(2):
            await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.set(Immediate(1))
        for _ in range(2):
            await RisingEdge(self.dut.i_clk)



@cocotb.test(timeout_time=10, timeout_unit="us")
@cocotb.parametrize(
    payload_lengths=[size_list],
    payload_data=[incrementing_payload],
    idle_inserter=[None, cycle_pause],
)
async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None):

    tb = TB(dut)

    await tb.reset()
    tb.set_idle_generator(idle_inserter)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        frame = AxiStreamFrame(test_data)
        await tb.source.send(frame)
        test_frames.append(frame)

    for test_frame in test_frames:
        mon_frame = await tb.s_axis_monitor.recv()
        assert mon_frame.tdata == test_frame.tdata

    assert tb.s_axis_monitor.empty()

    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)



def test_axis_rgmii_tx_py():
    
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [ 
        proj_path / "rtl" / "axis_rgmii_tx.sv",
        ]

    runner = get_runner(sim)

    parameters = {}

    parameters['DATA_W'] = 8

    runner.build(
        sources=sources,
        hdl_toplevel="axis_rgmii_tx",
        parameters=parameters,
        build_dir="sim_build/axis_rgmii_tx",
        always=True,
        clean=True
        
    )

    runner.test(
        hdl_toplevel="axis_rgmii_tx",
        test_module="axis_rgmii_tx",
        parameters=parameters,
        build_dir="sim_build/axis_rgmii_tx",
        
    )

if __name__ == "__main__":
    test_axis_rgmii_tx_py()
