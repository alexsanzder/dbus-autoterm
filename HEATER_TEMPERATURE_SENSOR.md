# Using Heater's Internal Temperature Sensor

## Overview

The Autoterm AIR 2D heater has a built-in internal temperature sensor that can now be used as the primary room temperature sensor for heating control. This is useful when:

- You don't have an external room temperature sensor
- You want to use the heater's own readings for temperature control
- You want to avoid relying on the Raspberry Pi's system temperature

## Available Temperature Sensors

When the driver is running, you now have access to multiple temperature sensors:

### 1. **Heater Internal Sensor** (Recommended)
- **Name**: "Heater internal sensor"
- **Source**: Built-in sensor in the Autoterm AIR 2D
- **Typical Range**: 15-35°C for room temperature
- **Advantage**: Direct reading from the heater
- **Service ID**: `heater_internal`

### 2. **Heater Intake Sensor** (if external sensor connected)
- **Name**: "Heater intake sensor"
- **Source**: External temperature sensor connected to heater pin
- **Typical Range**: 0-50°C
- **Advantage**: Independent external measurement
- **Service ID**: `heater_external`

### 3. **Other Cerbo Sensors** (if available)
- **Name**: Various (e.g., "Camila GX", "Raspberry Pi", etc.)
- **Source**: Other D-Bus temperature services on the Cerbo
- **Typical Range**: 0-100°C (depends on sensor)
- **Advantage**: Flexible sensor options
- **Service ID**: Service name (e.g., `com.victronenergy.temperature.XXXX`)

## How to Select the Heater Internal Sensor

### Method 1: Via D-Bus Command (Terminal)

To set the heater's internal sensor as the primary room temperature source:

```bash
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /Settings/RoomTemperatureService \
  com.victronenergy.BusItem.SetValue \
  variant:string:"heater_internal"
```

### Method 2: Via Venus OS GUI

1. Open **Heater Settings** page
2. Look for **"Room Temperature Service"** option
3. Select **"Heater internal sensor"** from the dropdown
4. Settings are automatically saved

### Method 3: Via Configuration File

Edit `/data/apps/dbus-autoterm/config.ini`:

```ini
[driver]
room_temperature_service = heater_internal
```

Then restart the driver:

```bash
svc -d /service/dbus-autoterm
svc -u /service/dbus-autoterm
```

## Live Data Display

### Available Room Temperature Sensors (D-Bus Paths)

The driver automatically publishes available sensors to D-Bus:

```
/AvailableRoomSensors/Count                      → Number of available sensors
/AvailableRoomSensors/0/Name                     → Sensor 0 display name
/AvailableRoomSensors/0/Temperature              → Sensor 0 current temp (°C)
/AvailableRoomSensors/0/Service                  → Sensor 0 service ID
/AvailableRoomSensors/1/Name                     → Sensor 1 display name
/AvailableRoomSensors/1/Temperature              → Sensor 1 current temp (°C)
/AvailableRoomSensors/1/Service                  → Sensor 1 service ID
(etc. for additional sensors)
```

### Current Selection

```
/Settings/RoomTemperatureServiceText             → Selected sensor name
/Settings/RoomTemperatureService                 → Selected sensor ID
/Temperatures/Room                               → Current room temperature reading
/Temperatures/RoomSource                         → Source indicator
/Temperatures/RoomSourceText                     → Source display name
```

## Example: Monitoring Room Temperature Sensors

### Query all available sensors:

```bash
# Count
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /AvailableRoomSensors/Count \
  com.victronenergy.BusItem.GetValue

# Sensor 0
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /AvailableRoomSensors/0/Name \
  com.victronenergy.BusItem.GetValue

dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /AvailableRoomSensors/0/Temperature \
  com.victronenergy.BusItem.GetValue
```

### Current selection:

```bash
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /Settings/RoomTemperatureService \
  com.victronenergy.BusItem.GetValue

dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /Temperatures/Room \
  com.victronenergy.BusItem.GetValue
```

## Temperature Control Modes

When using the heater internal sensor, the temperature control works as follows:

### Power Mode
- Heater runs at a fixed power level (1-9)
- Room temperature is monitored but not used to control heating
- Useful for consistent output

### Temperature Mode
- Heater maintains a target temperature
- Uses the selected room temperature sensor to measure current temp
- Adjusts power level automatically to reach target
- **With heater internal sensor**: Heater will heat/cool air based on its own sensor reading

### Ventilation Mode
- Fan circulates air without active heating
- Room temperature is monitored
- Power level adjusts fan speed

### Heat + Ventilation Mode
- Combines heating and ventilation
- Room temperature controls both heat and fan speed
- Balances comfort with efficiency

## Real-World Usage Example

**Setup**: Autoterm AIR 2D in a van with only the heater's internal sensor (no external room sensor)

**Configuration**:
```ini
[driver]
mode = 1                              # Temperature control mode
room_temperature_service = heater_internal
target_temperature = 20               # Maintain 20°C
```

**Operation**:
1. User sets target to 20°C
2. Heater internal sensor reads current temp: 15°C
3. Heater turns on at full power
4. As air heats up, sensor reading increases
5. At 18°C: Heater reduces to medium power
6. At 19°C: Heater reduces to low power
7. At 20°C: Heater cycles on/off to maintain temperature

## Advantages of Using Heater Internal Sensor

✅ **No additional hardware needed** - Works with heater alone
✅ **Real-time response** - Sensor is at heat source
✅ **Automatic switching** - No manual configuration needed
✅ **Fallback option** - Available even if external sensors fail
✅ **Compact solution** - Simplified wiring and installation
✅ **Cost effective** - No extra temperature sensors to buy

## Limitations to be Aware Of

⚠️ **Location bias** - Sensor is inside heater, may read hotter than room
⚠️ **Startup transient** - First reading may be high when heater turns on
⚠️ **Not room-wide** - Only reflects local heat source, not average room temp
⚠️ **Calibration** - Offset may be needed (current calibration: ±0)

## Sensor Comparison Table

| Feature | Heater Internal | External Sensor | Cerbo Sensor |
|---------|-----------------|-----------------|--------------|
| **Location** | Inside heater | Room or intake | Cerbo GX |
| **Installation** | Built-in | Requires wiring | Automatic |
| **Accuracy** | ±2°C | ±0.5°C | ±1°C |
| **Response time** | ~5 seconds | ~10 seconds | ~15 seconds |
| **Requires external hardware** | No | Yes | No |
| **Best for** | Temperature control | Precision | Multi-purpose |
| **Cost** | Free (included) | $$ | Included |

## Troubleshooting

### Sensor not appearing in available list
- Check service is running: `svc -u /service/dbus-autoterm`
- Verify D-Bus connection is healthy
- Check heater is powered and communicating

### Temperature reads as "--"
- Heater might be disconnected
- D-Bus communication error
- Check USB cable connection

### Heater not responding to temperature changes
- Verify "heater_internal" is selected
- Check mode is set to "Temperature" or "Heat+Vent"
- Confirm target temperature is set

### Temperature seems unstable
- Normal for first 5-10 seconds after startup
- Heater may need calibration offset
- Check if other heaters/fans are interfering

## Configuration Persistence

Your room temperature sensor selection is automatically saved to:

```
/data/apps/dbus-autoterm/config.ini
```

It will be remembered across restarts:

```ini
[driver]
room_temperature_service = heater_internal
```

## Technical Details

### D-Bus Integration

The room temperature service is exposed as:

**Current Setting**:
- Path: `/Settings/RoomTemperatureService`
- Writable: Yes
- Values: `"auto"` | `"heater_internal"` | `"heater_external"` | service IDs

**Display Text**:
- Path: `/Settings/RoomTemperatureServiceText`
- Writable: No
- Example: `"Heater internal sensor"`

**Room Temperature Reading**:
- Path: `/Temperatures/Room`
- Readable: Yes
- Unit: °C
- Updates: ~1 second

## Example: Switch sensors every 10 seconds (for testing)

```bash
#!/bin/bash
# Test script to switch between sensors

for i in {1..5}; do
  echo "=== Iteration $i ==="
  
  echo "Selecting: Heater internal sensor"
  dbus-send --system --print-reply \
    --dest=com.victronenergy.heater.autoterm_air2d \
    /Settings/RoomTemperatureService \
    com.victronenergy.BusItem.SetValue variant:string:"heater_internal"
  sleep 3
  
  echo "Current temperature:"
  dbus-send --system --print-reply \
    --dest=com.victronenergy.heater.autoterm_air2d \
    /Temperatures/Room \
    com.victronenergy.BusItem.GetValue
  
  echo "Selecting: Auto (other sensors)"
  dbus-send --system --print-reply \
    --dest=com.victronenergy.heater.autoterm_air2d \
    /Settings/RoomTemperatureService \
    com.victronenergy.BusItem.SetValue variant:string:"auto"
  sleep 3
  
  echo "Current temperature:"
  dbus-send --system --print-reply \
    --dest=com.victronenergy.heater.autoterm_air2d \
    /Temperatures/Room \
    com.victronenergy.BusItem.GetValue
done
```

## Version History

- **v0.1.0**: Initial implementation
  - Added heater internal sensor as available option
  - Auto-detection of available sensors
  - D-Bus paths for room temperature control
  - Configuration file persistence

## Related Documentation

- [Native GUI Enhancements](./NATIVE_GUI_ENHANCEMENTS.md) - How to display sensor data in the UI
- [Protocol Reference](./docs/protocol.md) - Heater communication protocol
- [Implementation Guide](./docs/implementation.md) - System architecture
