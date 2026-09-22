# Real vs Dummy Data Mode Switching

## Overview

The dbus-autoterm driver now supports switching between two data modes:

1. **Simulated Mode** (default) - Uses generated dummy data
2. **Real Mode** - Uses actual protocol data captured from a real Autoterm heater

This allows you to test the driver with authentic protocol frames when a real device is available, and fall back to simulated data for UI testing without hardware.

## Configuration

### Config File Setting

In `/data/apps/dbus-autoterm/config.ini`:

```ini
[driver]
provider_data = simulated    # or "real"
```

### Options

- `simulated` (default): Uses generated dummy heater data
- `real`: Loads actual captured protocol frames from `captured_data/frames_*.json`

## How It Works

### Simulated Mode (Default)

```python
# Uses DummyHeaterProvider with generated data
provider = DummyHeaterProvider(use_real_data=False)
```

- Generates realistic heater behavior
- Simulates state transitions (starting, running, cooling down)
- Gradually increases temperatures
- Natural fan RPM variations
- No hardware needed

### Real Mode

```python
# Uses DummyHeaterProvider with captured real data
provider = DummyHeaterProvider(use_real_data=True)
```

- Loads JSON frames from `captured_data/`
- Cycles through real protocol frames captured from actual device
- Preserves authentic sensor variations (±1-2°C, ±1 RPM)
- Uses real CRC16 checksums
- Requires captured data files

## Switching Modes

### Via SSH

```bash
# Switch to real mode
ssh root@10.106.178.134 'sed -i "s/provider_data = .*/provider_data = real/" /data/apps/dbus-autoterm/config.ini'
ssh root@10.106.178.134 'svc -t /service/dbus-autoterm'

# Switch to simulated mode
ssh root@10.106.178.134 'sed -i "s/provider_data = .*/provider_data = simulated/" /data/apps/dbus-autoterm/config.ini'
ssh root@10.106.178.134 'svc -t /service/dbus-autoterm'
```

### Direct Edit

1. Connect to device
2. Edit `/data/apps/dbus-autoterm/config.ini`
3. Change `provider_data` value
4. Restart service: `svc -t /service/dbus-autoterm`

## Capturing Real Data

Before using real mode, capture data from an actual heater:

```bash
cd /path/to/dbus-autoterm
VENUS_TARGET=root@10.106.178.134 bash capture_real_heater_data.sh
```

This creates:
- `captured_data/driver_TIMESTAMP.log` - Raw logs
- `captured_data/frames_TIMESTAMP.json` - Parsed protocol frames

## Implementation Details

### DummyHeaterProvider Initialization

```python
# Simulated (default)
provider = DummyHeaterProvider()  # use_real_data=False

# Real (with captured data)
provider = DummyHeaterProvider(use_real_data=True)
```

### Real Data Loading

When `use_real_data=True`:
1. Looks for latest `captured_data/frames_*.json`
2. Extracts 0x0F (status) frames
3. Cycles through frames on each refresh
4. Parses payload bytes into telemetry

### Frame Cycling

```
Frame 1 → Frame 2 → Frame 3 → Frame 4 → Frame 1 → ...
```

Real frames are cycled continuously, showing natural sensor variations captured from actual device.

## Use Cases

### Development & Testing

| Scenario | Mode | Notes |
|----------|------|-------|
| UI development (no device) | Simulated | Works offline, no hardware needed |
| Integration testing | Simulated | Predictable, reproducible behavior |
| Protocol validation | Real | Verify driver handles actual data |
| Regression testing | Real | Catch incompatibilities early |
| Demo/demo without device | Simulated | Works anywhere |
| Troubleshooting | Real | Use actual heater behavior |

## Fallback Behavior

If real mode is selected but data is unavailable:

1. Check `captured_data/` for JSON files
2. If none found → warn and fall back to simulated mode
3. If parsing fails → warn and fall back to simulated mode
4. Driver continues operating normally

No interruptions or crashes.

## Log Output

### Starting in Simulated Mode

```
INFO: Using simulated dummy heater data
```

### Starting in Real Mode (Success)

```
INFO: Loading real heater data from captured frames...
INFO: Loaded 4 real heater frames from frames_20240915_153621.json
```

### Starting in Real Mode (Fallback)

```
WARNING: No captured real data found in captured_data/. Falling back to simulated data.
```

## Troubleshooting

### "No captured real data found"

**Solution**: Run the capture script first
```bash
bash capture_real_heater_data.sh
```

### "Error parsing real data frame"

**Possible causes**:
- Corrupted JSON file
- Incomplete frame data
- Invalid hex payload

**Solution**: Delete the file and recapture
```bash
rm captured_data/frames_*.json
bash capture_real_heater_data.sh
```

### Mode doesn't switch

**Check**:
1. Config file was edited: `cat /data/apps/dbus-autoterm/config.ini`
2. Service restarted: `svc -t /service/dbus-autoterm`
3. Logs show new mode: `tail -f /data/log/dbus-autoterm/current`

## Configuration Example

### Full Config with Mode Switching

```ini
[driver]
backend = dummy
provider_data = real              # ← Real or simulated mode
serial_device = /dev/ttyUSB0
room_temperature_service = auto
poll_interval = 1.0
log_level = INFO
mock_dbus = false

[dbus]
service_name = com.victronenergy.heater.autoterm_air2d
device_instance = 287
product_name = Autoterm AIR 2D
firmware_version = 0.1.0
hardware_version = AIR2D
connection = UART
```

## Integration with Testing

### Test with Real Data

```python
import pytest
from pathlib import Path

class TestWithRealData:
    def setup_method(self):
        # Switch to real mode for this test
        self.provider = DummyHeaterProvider(use_real_data=True)
    
    def test_real_frame_parsing(self):
        snapshot = self.provider.refresh()
        assert snapshot.telemetry.battery_voltage_v > 0
        assert snapshot.connected
```

### Test with Simulated Data

```python
class TestWithSimulatedData:
    def setup_method(self):
        # Default simulated mode
        self.provider = DummyHeaterProvider(use_real_data=False)
    
    def test_state_transitions(self):
        self.provider.start(...)
        assert self.provider.get_snapshot().phase == HeaterPhase.STARTING
```

## Performance Notes

- **Simulated Mode**: Minimal CPU overhead, generates data on demand
- **Real Mode**: Loads JSON file once at startup, cycles through frames (~50 bytes each), no additional I/O

Both modes have negligible performance impact.

## Future Enhancements

Potential improvements:
- Interpolate between real frames (smoother data)
- Record and replay complete sessions
- Mix real and simulated data per-field
- Store frame history for trend analysis

