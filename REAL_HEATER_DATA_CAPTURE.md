# Real Heater Data Capture & Usage Guide

## Overview

This guide explains how to capture real protocol data from an actual Autoterm AIR 2D heater and use it to populate the dummy/emulation driver for testing.

## Why Capture Real Data?

✅ **Authenticity** - Test with real protocol frames and telemetry  
✅ **Regression Testing** - Ensure emulation stays compatible with real device  
✅ **Development** - Write tests based on actual behavior  
✅ **Debugging** - Replay real scenarios to diagnose issues  

## Quick Start

### Step 1: Capture Data from Real Device

```bash
cd /Users/alejandrosanchezbautista/Projects/VenusOS/dbus-autoterm

# Run the capture script (automatically uses VENUS_TARGET or 10.106.178.134)
bash capture_real_heater_data.sh

# Or specify a different target
VENUS_TARGET=root@my-device.local bash capture_real_heater_data.sh
```

This creates:
- `captured_data/driver_TIMESTAMP.log` - Raw driver logs
- `captured_data/frames_TIMESTAMP.json` - Parsed protocol frames

### Step 2: Review Captured Data

```bash
# View the parsed frames
cat captured_data/frames_TIMESTAMP.json | jq .

# Count frame types
cat captured_data/frames_TIMESTAMP.json | jq '.summary'

# Show specific frames
cat captured_data/frames_TIMESTAMP.json | jq '.frames.rx_frames[0]'
```

### Step 3: Use in Dummy Driver

Copy relevant frames to your dummy driver implementation.

## File Formats

### Raw Log File (`driver_TIMESTAMP.log`)

```
@400000006aa94983231fc494 DEBUG:provider:rx_frame msg=0x0f device=0x04 payload=0323001c7f0084012d08004646000000000062
@400000006aa94984239e6e5c DEBUG:provider:rx_frame msg=0x0f device=0x04 payload=0323001c7f0084012d08004647000000000062
@400000006aa94985231992a4 DEBUG:provider:tx msg=0x0f device=0x03 payload=
```

### Parsed Frames JSON (`frames_TIMESTAMP.json`)

```json
{
  "extraction_date": "2024-09-15T15:36:22.901714",
  "source_file": "captured_data/driver_20240915_153621.log",
  "summary": {
    "total_rx_frames": 4,
    "total_tx_frames": 4,
    "status_frames_0x0f": 4
  },
  "frames": {
    "rx_frames": [
      {
        "message_type": "0x0f",
        "device": "0x04",
        "payload": "0323001c7f0084012d08004646000000000062",
        "timestamp": "2024-09-15T15:36:22.901674"
      }
    ],
    "tx_frames": [
      {
        "message_type": "0x0f",
        "device": "0x03",
        "payload": "",
        "timestamp": "2024-09-15T15:36:22.901636"
      }
    ]
  }
}
```

## Parsing Frames

### Status Frame (0x0F) Structure

Real captured payload: `0323001c7f0084012d08004646000000000062`

Decoded:
```
Byte  0-1:  Status code        0x03 0x23 = Ventilation mode
Byte  2:    Unknown            0x00
Byte  3:    Internal temp      0x1c = 28°C (signed)
Byte  4:    External temp      0x7f = Invalid (unsigned, 127°C invalid indicator)
Byte  5:    Unknown            0x00
Byte  6:    Voltage/10         0x84 = 13.2V
Byte  7:    Unknown            0x01
Byte  8:    Heater temp-15     0x2d = 45°C (add 15: 45+15=60°C)
Byte  9:    Unknown            0x08
Byte  10:   Unknown            0x00
Byte  11:   Fan RPM Set        0x46 = 70 RPM
Byte  12:   Fan RPM Actual     0x46 = 70 RPM
Byte  13-20: Unknown fields    0x00 00 00 00 00 00 00 62
```

## Implementing in Dummy Driver

### Location: `emulation/src/heater.py`

Example implementation:

```python
from dataclasses import dataclass, field
from typing import List
import struct

@dataclass
class RealHeaterFrames:
    """Real frames captured from actual AIR 2D"""
    
    # Status polling responses (0x0F)
    STATUS_RESPONSES = [
        bytes.fromhex("aa0413000f0323001c7f0084012d08004646000000000062"),
        bytes.fromhex("aa0413000f0323001c7f0083012d08004647000000000062"),
        bytes.fromhex("aa0413000f0323001c7f0084012d08004645000000000062"),
        bytes.fromhex("aa0413000f0323001c7f0084012d08004645000000000062"),
    ]
    
    # Initialization sequence
    INIT_SEQUENCE = [
        bytes.fromhex("aa03000001c95bd"),  # 0x1c request
        bytes.fromhex("aa00000001cd13d"),  # 0x1c response
        bytes.fromhex("aa0300000049f3d"),  # 0x04 request
        bytes.fromhex("aa0405000415b9004015053d"),  # 0x04 response
    ]


class DummyHeaterProvider:
    def __init__(self):
        self.real_frames = RealHeaterFrames()
        self.status_index = 0
    
    def get_next_status_response(self) -> bytes:
        """Cycle through real captured status frames"""
        frame = self.real_frames.STATUS_RESPONSES[self.status_index]
        self.status_index = (self.status_index + 1) % len(self.real_frames.STATUS_RESPONSES)
        return frame
```

### Varying Values Slightly

Real heater data varies naturally (±1-2). To simulate:

```python
import random

def add_realistic_variation(payload: str, variation_percent: float = 0.05) -> str:
    """Add small realistic variation to status values"""
    data = bytearray.fromhex(payload)
    
    # Vary fan RPM (±1-2)
    if len(data) > 12:
        data[11] += random.randint(-1, 1)  # Fan set
        data[12] += random.randint(-1, 1)  # Fan actual
    
    # Vary temperatures (±1)
    if len(data) > 8:
        data[3] += random.randint(-1, 1)  # Internal temp
        data[8] += random.randint(-1, 1)  # Heater temp
    
    return data.hex()
```

## Testing with Captured Data

### Unit Test Example

```python
import pytest
from emulation.src.heater import DummyHeaterProvider, RealHeaterFrames

class TestDummyHeaterWithRealData:
    
    def test_status_frame_format(self):
        """Verify captured status frames are valid"""
        for payload in RealHeaterFrames.STATUS_RESPONSES:
            assert payload[0] == 0xaa  # Preamble
            assert payload[1] == 0x04  # Response device byte
            assert payload[2] == 0x13  # Length
            assert payload[3] == 0x00
            assert payload[4] == 0x0f  # Message type
    
    def test_status_parsing(self):
        """Parse real captured status frames"""
        payload = bytes.fromhex("0323001c7f0084012d08004646000000000062")
        
        status_major = payload[0]
        status_minor = payload[1]
        internal_temp = int.from_bytes([payload[3]], signed=True)
        voltage = payload[6] / 10.0
        
        assert status_major == 0x03
        assert status_minor == 0x23
        assert internal_temp == 28
        assert voltage == 13.2
    
    def test_dummy_returns_real_frames(self):
        """Verify dummy driver cycles through real frames"""
        provider = DummyHeaterProvider()
        
        for i in range(10):
            frame = provider.get_next_status_response()
            assert frame[0] == 0xaa
            assert frame[4] == 0x0f
```

### Running Tests

```bash
# Run tests with real data
devbox run emulation:test

# Run specific test
devbox run pytest emulation/tests/test_heater.py::TestDummyHeaterWithRealData
```

## Data Repository

All captured real data is stored in:
- **Location**: `captured_data/` directory
- **Format**: JSON with timestamped frames
- **Naming**: `frames_YYYYMMDD_HHMMSS.json`

Example files:
```
captured_data/
├── driver_20240915_153621.log
├── frames_20240915_153621.json
├── driver_20240915_153645.log
└── frames_20240915_153645.json
```

## Comparing Real vs Dummy

### Side-by-Side Comparison

```bash
# Get real status payload
REAL_PAYLOAD=$(cat captured_data/frames_*.json | jq -r '.frames.rx_frames[0].payload')

# Get dummy status payload  
DUMMY_PAYLOAD=$(python3 -c "from emulation.src.heater import DummyHeaterProvider; print(DummyHeaterProvider().get_next_status_response().hex())")

echo "Real:  $REAL_PAYLOAD"
echo "Dummy: $DUMMY_PAYLOAD"
```

## Protocol Frame Reference

Based on real captured data:

### Initialization (First 6 frames after startup)

1. **0x1C** - Initialization request (client → heater)
2. **0x1C** - Acknowledgement (heater → client)
3. **0x04** - Get settings (client → heater)
4. **0x04** - Settings response (heater → client)
5. **0x06** - Get version (client → heater)
6. **0x06** - Version response (heater → client)

### Polling Loop (every ~1 second)

- **0x0F** - Status request (client → heater)
- **0x0F** - Status response (heater → client)

### Commands (on user action)

- **0x01** - Start heater
- **0x03** - Stop heater
- **0x11** - Set temperature
- **0x23** - Start ventilation

## Extracting Custom Data

### Create Custom Frames from Log

```bash
# Extract only 0x0F responses
grep "rx_frame msg=0x0f" captured_data/driver_*.log

# Save to new file
grep "rx_frame msg=0x0f" captured_data/driver_*.log > real_status_frames.txt

# Convert to hex array
grep -o "payload=[0-9a-f]*" real_status_frames.txt | \
  sed 's/payload=/bytes.fromhex("/' | \
  sed 's/$/"),/' | \
  sort | uniq
```

### Parse All Frames

```python
import json
import glob

all_frames = []
for json_file in glob.glob('captured_data/frames_*.json'):
    with open(json_file) as f:
        data = json.load(f)
        all_frames.extend(data['frames']['rx_frames'])

print(f"Total frames collected: {len(all_frames)}")

# Group by message type
by_type = {}
for frame in all_frames:
    msg_type = frame['message_type']
    if msg_type not in by_type:
        by_type[msg_type] = []
    by_type[msg_type].append(frame)

for msg_type in sorted(by_type.keys()):
    print(f"{msg_type}: {len(by_type[msg_type])} frames")
```

## Troubleshooting

### No frames captured?
- Check heater is running (not in standby)
- Verify logs are being written to `/data/log/dbus-autoterm/current`
- Ensure driver is in serial mode (not dummy)

### Incorrect frame format?
- Verify CRC is correct (last 2 bytes)
- Check preamble is `0xAA`
- Ensure payload length matches byte 3

### Parser errors?
- Check JSON is valid: `jq empty captured_data/frames_*.json`
- Verify hex strings have even length
- Ensure all frames have complete data

## Documentation Files

- **`REAL_HEATER_DATA.json`** - Manual sample of real frames and interpretations
- **`capture_real_heater_data.sh`** - Script to capture and extract data
- **`extract_heater_data.py`** - Python parser for log files

## Next Steps

1. ✅ Run `bash capture_real_heater_data.sh` to collect current device data
2. ✅ Review `captured_data/frames_*.json` to understand frame structure
3. ✅ Update `emulation/src/heater.py` with real frames
4. ✅ Write tests in `emulation/tests/test_heater.py`
5. ✅ Run test suite: `devbox run emulation:test`
6. ✅ Commit captured data to repo for regression testing

## Version History

- **v1.0** - Initial capture tools and documentation
  - `capture_real_heater_data.sh` - Automated capture script
  - `extract_heater_data.py` - Frame parser
  - `REAL_HEATER_DATA_CAPTURE.md` - This guide
  - `REAL_HEATER_DATA.json` - Sample captured data
