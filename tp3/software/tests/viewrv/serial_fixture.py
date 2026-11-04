"""Controlled byte streams and virtual monotonic time, never shipped in the product."""

import heapq
import json
from functools import cache
from pathlib import Path


@cache
def literal(case_id="TEST-UART-007/C001"):
    catalog = json.loads(
        (Path(__file__).resolve().parents[3] / "docs/verification/cases.json").read_text()
    )
    group = next(group for group in catalog["groups"] if group["id"] == "TEST-UART-007")
    return bytes(
        next(case for case in group["cases"] if case["id"] == case_id)["expected"]["response_bytes"]
    )


class Clock:
    def __init__(self):
        self.now = 0.0
        self.events = []
        self.sequence = 0

    def __call__(self):
        return self.now

    def at(self, when, action):
        self.sequence += 1
        heapq.heappush(self.events, (when, self.sequence, action))

    def advance(self, end):
        while self.events and self.events[0][0] <= end:
            when, _, action = heapq.heappop(self.events)
            self.now = max(self.now, when)
            action()
        self.now = max(self.now, end)


class ScriptedPort:
    """Expected host writes, timed fragments/errors and pySerial-style read waits."""

    def __init__(self, clock, script=(), *, max_write=None):
        self.clock, self.script = clock, list(script)
        self.max_write = max_write
        self.offset = 0
        self.rx = bytearray()
        self.rx_error = None
        self.timeout = 0.05
        self.write_timeout = 0.2
        self.writes = []
        self.reads = []
        self.closed = False
        self.cancelled = 0
        self.flushed_output = 0

    def schedule(self, delay, value):
        def arrive():
            if isinstance(value, Exception):
                self.rx_error = value
            else:
                self.rx.extend(value)

        self.clock.at(self.clock() + delay, arrive)

    @property
    def in_waiting(self):
        self.clock.advance(self.clock())
        if self.rx_error:
            raise self.rx_error
        return len(self.rx)

    def write(self, data):
        if self.closed:
            raise OSError("Port closed")
        if not self.script:
            raise AssertionError(f"Unexpected UART write: {bytes(data).hex()}")
        expected, responses = self.script[0]
        count = min(len(data), len(expected) - self.offset, self.max_write or len(data))
        actual = bytes(data[:count])
        assert actual == expected[self.offset : self.offset + count], (actual, expected)
        self.writes.append((self.clock(), actual))
        self.offset += count
        if self.offset == len(expected):
            self.script.pop(0)
            self.offset = 0
            for delay, response in responses:
                self.schedule(delay, response)
        return count

    def read(self, size):
        self.reads.append((self.clock(), size, self.timeout))
        if self.closed:
            raise OSError("Port closed")
        end = self.clock() + self.timeout
        while True:
            self.clock.advance(self.clock())
            if self.rx_error:
                raise self.rx_error
            if len(self.rx) >= size or self.clock() >= end:
                break
            next_event = self.clock.events[0][0] if self.clock.events else end
            self.clock.advance(min(next_event, end))
        data = bytes(self.rx[:size])
        del self.rx[:size]
        return data

    def close(self):
        self.closed = True

    def cancel_write(self):
        self.cancelled += 1

    def reset_output_buffer(self):
        self.flushed_output += 1
