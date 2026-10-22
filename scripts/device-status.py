#!/usr/bin/env python3
"""Unified read-only device inventory; run from the actual source checkout."""
import sys
sys.dont_write_bytecode = True
from device_status import main

if __name__ == '__main__':
    sys.exit(main())
