"""Start the actual core with a controlled assembler only for integration tests."""

from software.tests.viewrv.faults import DelayedAssembler, FaultStorage
from software.viewrv.core.__main__ import run

if __name__ == "__main__":
    raise SystemExit(run(assembler=DelayedAssembler(), storage=FaultStorage()))
