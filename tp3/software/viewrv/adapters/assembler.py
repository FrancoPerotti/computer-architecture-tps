"""Adapter to the independently delivered public assembler module."""

from importlib import import_module


class PythonAssembler:
    def assemble(self, source_text):
        return import_module("software.assembler").assemble(source_text)
