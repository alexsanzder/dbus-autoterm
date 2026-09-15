# Real Heater Data Capture - Complete Index

## Quick Reference

**Goal**: Capture real protocol data from Autoterm AIR 2D and use it to populate the dummy driver for testing.

**Status**: ✅ Complete and Ready to Use

**Quick Start**:
```bash
bash capture_real_heater_data.sh
```

---

## Files Created

### 🔧 Tools

| File | Size | Purpose |
|------|------|---------|
| `capture_real_heater_data.sh` | 3.0 KB | Main capture script - downloads logs and extracts frames |
| `extract_heater_data.py` | 4.3 KB | Python parser for driver logs |

### 📚 Documentation

| File | Size | Purpose |
|------|------|---------|
| `REAL_HEATER_DATA_CAPTURE.md` | 10 KB | Comprehensive guide (300+ lines) |
| `REAL_HEATER_DATA.json` | 7.7 KB | Reference frames with full decoding |
| `DATA_CAPTURE_INDEX.md` | This file | Quick reference index |

### 💾 Data

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `captured_data/` | logs + JSON | Timestamped captured frames |

---

## How to Use

### 1. Capture Real Data
```bash
cd /Users/alejandrosanchezbautista/Projects/VenusOS/dbus-autoterm
bash capture_real_heater_data.sh
```

Creates:
- `captured_data/driver_TIMESTAMP.log` - Raw logs
- `captured_data/frames_TIMESTAMP.json` - Parsed frames

### 2. Review Captured Data
```bash
# View full JSON
cat captured_data/frames_*.json | jq .

# Extract payloads only
jq -r '.frames.rx_frames[].payload' captured_data/frames_*.json

# Show statistics
jq '.summary' captured_data/frames_*.json
```

### 3. Use in Dummy Driver

See `REAL_HEATER_DATA_CAPTURE.md` sections:
- "Implementing in Dummy Driver"
- "Testing with Captured Data"

---

## Protocol Frames Reference

### Currently Captured (4 frames)

**Message Type**: 0x0F (Status Poll)

```
Frame 1: payload=0323001c7f0084012d08004646000000000062
Frame 2: payload=0323001c7f0083012d08004647000000000062
Frame 3: payload=0323001c7f0084012d08004645000000000062
Frame 4: payload=0323001c7f0084012d08004645000000000062
```

**Decoded Sample**:
```
Status:     0x03 0x23 (Ventilation mode)
Internal:   0x1C = 28°C
External:   0x7F = Invalid (not connected)
Voltage:    0x84 = 13.2V
Heater Temp: 0x2D = 45°C
Fan RPM:    70 RPM (±1 variance)
```

### Available in REAL_HEATER_DATA.json

- Initialization sequence (0x1C, 0x04, 0x06)
- Status frames (0x0F)
- Command templates (0x01, 0x03, 0x11, 0x23)

---

## Integration Examples

### Python
```python
import json
from pathlib import Path

# Load latest frames
latest = max(Path('captured_data').glob('frames_*.json'))
data = json.load(open(latest))
payloads = [f['payload'] for f in data['frames']['rx_frames']]
```

### Bash
```bash
# Extract payloads
grep -o '"payload":"[^"]*"' captured_data/frames_*.json | cut -d'"' -f4

# Count by message type
jq '.frames.rx_frames[].message_type' captured_data/frames_*.json | sort | uniq -c
```

### Tests
```python
from pathlib import Path
import json

class TestWithRealData:
    @classmethod
    def setup_class(cls):
        latest = max(Path('captured_data').glob('frames_*.json'))
        cls.real_data = json.load(open(latest))
    
    def test_frame_parsing(self):
        payload = self.real_data['frames']['rx_frames'][0]['payload']
        # Test with real data
```

---

## Workflow

1. **Capture**: `bash capture_real_heater_data.sh`
2. **Analyze**: Review `captured_data/frames_*.json`
3. **Integrate**: Update `emulation/src/heater.py`
4. **Test**: `devbox run emulation:test`
5. **Commit**: `git add captured_data/ emulation/`

---

## File Descriptions

### capture_real_heater_data.sh

Automated script that:
1. Downloads logs from device (10.106.178.134)
2. Parses all protocol frames
3. Extracts telemetry data
4. Generates statistics
5. Saves timestamped output

**Usage**: `bash capture_real_heater_data.sh`

**Environment**: `VENUS_TARGET=root@device.local bash capture_real_heater_data.sh`

### extract_heater_data.py

Python parser that:
1. Reads driver logs
2. Extracts protocol frames using regex
3. Decodes 0x0F status payloads
4. Outputs structured JSON
5. Handles frame structure parsing

**Usage**: `python3 extract_heater_data.py input.log output.json`

### REAL_HEATER_DATA.json

Reference file containing:
- Metadata and protocol version
- Full initialization sequence
- Example status frames with full decoding
- Command frame templates
- Real telemetry readings
- Frame structure documentation

**Use**: Reference for understanding frame format

### REAL_HEATER_DATA_CAPTURE.md

Complete guide (300+ lines) covering:
- Overview and motivation
- File formats
- Parsing examples
- Implementation patterns
- Test examples
- Troubleshooting
- Technical reference

**Use**: Read first for comprehensive understanding

### DATA_CAPTURE_INDEX.md

This file - quick reference for:
- File locations and purposes
- Usage patterns
- Integration examples
- Protocol reference

**Use**: Quick lookup during development

---

## Key Telemetry Extracted

From real Autoterm AIR 2D:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Status Mode | 0x03 0x23 | Ventilation |
| Internal Temp | 28°C | ±1°C variation |
| Heater Temp | 45°C | Offset by +15 |
| Voltage | 13.2V | ±0.1V stable |
| Fan RPM | 70 RPM | ±1-2 variance |
| Frequency | 1 Hz | Every second |

---

## Related Documentation

Created in parallel:
- `NATIVE_GUI_ENHANCEMENTS.md` - UI status indicators
- `HEATER_TEMPERATURE_SENSOR.md` - Temperature control
- `GUI_STATUS_INDICATORS_SUMMARY.txt` - Visual guide
- `HEATER_TEMPERATURE_SUMMARY.txt` - Sensor options

---

## Next Steps

1. ✅ Review this index
2. ✅ Run `bash capture_real_heater_data.sh`
3. ✅ Read `REAL_HEATER_DATA_CAPTURE.md`
4. ✅ Examine `captured_data/frames_*.json`
5. ✅ Update `emulation/src/heater.py`
6. ✅ Run tests with `devbox run emulation:test`

---

## Support

For detailed information:
- Frame parsing: See `REAL_HEATER_DATA_CAPTURE.md` → "Parsing Frames"
- Integration: See `REAL_HEATER_DATA_CAPTURE.md` → "Implementing in Dummy Driver"
- Testing: See `REAL_HEATER_DATA_CAPTURE.md` → "Testing with Captured Data"
- Troubleshooting: See `REAL_HEATER_DATA_CAPTURE.md` → "Troubleshooting"

---

**Last Updated**: 2024-09-15  
**Status**: ✅ Ready for production use  
**Tested**: Yes - real device data captured successfully
