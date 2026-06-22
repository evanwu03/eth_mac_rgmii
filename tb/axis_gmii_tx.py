
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
from cocotbext.eth import GmiiSink
from cocotb.handle import Immediate


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def size_list():
    # Ethernet frame length excluding FCS: 60 to 1514 bytes
    return [60, 61, 64, 128, 512, 1514]

def cycle_en():
    # clk is enable 75% of the time
    return itertools.cycle([1, 1, 1, 0])


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb")
        self.log.setLevel(logging.INFO)

        self._enable_generator = None
        self._enable_cr = None
        
        cocotb.start_soon(Clock(dut.i_clk, 2, unit="ns").start())

        self.source = AxiStreamSource(
            AxiStreamBus.from_prefix(dut, "s_axis"),
            dut.i_clk,
            dut.i_rst_n,
            reset_active_level=False,
        )

        self.sink = GmiiSink(
            data=dut.gmii_txd, 
            er=dut.gmii_tx_er, 
            dv=dut.gmii_tx_en, 
            clock=dut.i_clk, 
            reset=dut.i_rst_n,
            reset_active_level=False)
        
        # Set initial values
        dut.clk_enable.set(Immediate(1))
        dut.mii_select.set(Immediate(0))

        dut.cfg_tx_max_pkt_len.set(Immediate(0))
        dut.cfg_tx_ifg.set(Immediate(0))
        dut.cfg_tx_enable.set(Immediate(0))


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


    def set_enable_generator(self, generator=None):
        if self._enable_cr is not None:
            self._enable_cr.kill()
            self._enable_cr = None

        self._enable_generator = generator

        if self._enable_generator is not None:
            self._enable_cr = cocotb.start_soon(self._run_enable())

    def clear_enable_generator(self):
        self.set_enable_generator(None)

    async def _run_enable(self):
        for val in self._enable_generator:
            self.dut.clk_enable.value = val
            await RisingEdge(self.dut.i_clk)


@cocotb.test(timeout_time=100, timeout_unit="us")
@cocotb.parametrize(
    payload_lengths=[size_list],
    payload_data=[incrementing_payload],
    enable_gen=[None, cycle_en]
)
async def run_good_packet_test(dut, payload_lengths=None, payload_data=None, enable_gen=None):

    tb = TB(dut)

    dut.cfg_tx_ifg.value = 12
    dut.cfg_tx_max_pkt_len.value = 1514
    dut.cfg_tx_enable.value = 1
    dut.clk_enable.value = 1
    dut.mii_select.value = 0   # GMII mode

    if enable_gen is not None:
        tb.set_enable_generator(enable_gen())

    await tb.reset()

    test_frames = [payload_data(x) for x in payload_lengths()]

    total_bytes = 0
    total_pkts  = 0
    
    for test_data in test_frames:
       
        await tb.source.send(
            AxiStreamFrame(test_data, tid=0, tuser=0)
        )

        total_bytes += max(len(test_data), 60)+4
        total_pkts += 1
    
        # Wait on pending gmii rx frame
        rx_frame = await tb.sink.recv()
        rx_data = bytes(rx_frame.get_payload())

        assert rx_data == bytes(test_data), (
            f"GMII frame payload mismatch for length {len(test_data) + 4 }\n"
            f"expected: {bytes(test_data).hex()}\n"
            f"got:      {rx_data.hex()}"
        )

        assert rx_frame.check_fcs(), "Bad FCS on GMII frame"


    assert tb.sink.empty()


    # Add diagnostic checking here


    for _ in range(2):
        await RisingEdge(dut.i_clk)





def test_axis_gmii_runner():
    
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [ 
        proj_path / "rtl" / "axis_gmii_tx.sv",
        ]

    runner = get_runner(sim)

    parameters = {}

    parameters['DATA_W'] = 8

    runner.build(
        sources=sources,
        hdl_toplevel="axis_gmii_tx",
        parameters=parameters,
        build_dir="sim_build/axis_gmii_tx",
        always=True,
        clean=True
        
    )

    runner.test(
        hdl_toplevel="axis_gmii_tx",
        test_module="axis_gmii_tx",
        parameters=parameters,
        build_dir="sim_build/axis_gmii_tx",
        
    )

if __name__ == "__main__":
    test_axis_gmii_runner()
