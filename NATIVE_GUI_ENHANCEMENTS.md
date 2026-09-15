# Native GUI Enhancements - Status Indicators

## Overview

The native GUI HeaterPage.qml has been enhanced with a **real-time status indicator header** that displays live telemetry data about the heater operation. This provides users with instant visibility into critical system parameters without navigating to additional pages.

## Changes Made

### New Status Indicator Header

A horizontal status bar has been added below the tab bar that displays:

#### 1. **Connection Status** (Green/Red indicator)
- Shows D-Bus communication status
- 🟢 Green = Connected and healthy
- 🔴 Red = Communication alarm active
- Icon: Connected indicator with color-based feedback

#### 2. **Battery Voltage** (with icon)
- Displays current battery voltage in volts (V)
- Format: `XX.X V`
- Updates in real-time
- Icon: Battery symbol
- **Example**: `13.2 V`

#### 3. **Fan RPM** (with icon)
- Shows actual fan RPM (rotations per minute)
- Format: `XXX RPM`
- Updates as the fan speed changes
- Icon: Propeller symbol
- **Example**: `70 RPM`

#### 4. **Heater Temperature** (with icon)
- Displays the combustion chamber/heater temperature
- Format: `XXX°C`
- Useful for monitoring heating performance
- Icon: Fire/flame symbol
- **Example**: `145°C`

#### 5. **Internal Temperature** (with icon)
- Shows the internal sensor reading
- Format: `XX°C`
- Helps diagnose sensor issues
- Icon: Thermometer symbol
- **Example**: `28°C`

### Visual Design

- **Header Height**: 56px (compact, always visible)
- **Background**: Light gray with subtle border
- **Separators**: Vertical divider lines between indicators
- **Icons**: Victron Venus OS standard icons
- **Layout**: Horizontal row with responsive spacing
- **Font**: System theme fonts with proper hierarchy

### Data Sources

All indicators pull live data from the D-Bus service:

```
/Dc/0/Voltage                  → Battery Voltage
/Status/FanRpmActual           → Fan RPM Actual
/Temperatures/Heater           → Heater Temperature
/Temperatures/Internal         → Internal Temperature
/Alarms/Communication          → Connection Status
```

## Layout Changes

### Before
```
[TabBar]
[Empty space]
[Heater Controls - Mode Cards]
[Status Text]
[Action Button]
[Circular Ring Display]
```

### After
```
[TabBar]
[Status Indicator Header] ← NEW
   [Connected] [Battery 13.2V] | [Fan 70 RPM] | [Heater 145°C] | [Internal 28°C]
[Heater Controls - Mode Cards]
[Status Text]
[Action Button]
[Circular Ring Display]
```

## Benefits

✅ **At-a-glance monitoring** - No need to navigate to separate pages  
✅ **Real-time updates** - All values refresh continuously  
✅ **Professional appearance** - Clean, organized layout  
✅ **Comprehensive telemetry** - 5 critical parameters displayed  
✅ **Color-coded status** - Green/red for connection health  
✅ **Responsive design** - Adapts to screen sizes  
✅ **Consistent theming** - Uses Venus OS design system  

## Display Examples

### Heater Off (Standby)
```
🟢 Connected | Battery 13.2 V | Fan 0 RPM | Heater 25°C | Internal 22°C
```

### Heater Starting
```
🟢 Connected | Battery 13.2 V | Fan 15 RPM | Heater 85°C | Internal 22°C
```

### Heater Running
```
🟢 Connected | Battery 13.1 V | Fan 70 RPM | Heater 145°C | Internal 28°C
```

### Communication Issue
```
🔴 Alarm | Battery -- V | Fan -- RPM | Heater -- | Internal --
```

## Technical Implementation

### New VeQuickItem Bindings Added
```qml
VeQuickItem { id: batteryVoltage; uid: root.bindPrefix + "/Dc/0/Voltage" }
VeQuickItem { id: fanRpmSet; uid: root.bindPrefix + "/Status/FanRpmSet" }
VeQuickItem { id: fanRpmActual; uid: root.bindPrefix + "/Status/FanRpmActual" }
VeQuickItem { id: heaterTemperature; uid: root.bindPrefix + "/Temperatures/Heater" }
VeQuickItem { id: internalTemperature; uid: root.bindPrefix + "/Temperatures/Internal" }
VeQuickItem { id: fuelPumpFrequency; uid: root.bindPrefix + "/Status/FuelPumpFrequency" }
VeQuickItem { id: communicationAlarm; uid: root.bindPrefix + "/Alarms/Communication" }
```

### Component Structure
- **Container**: Rectangle with gray background and border
- **Layout**: Horizontal Row with evenly spaced items
- **Indicators**: Item wrappers containing Icon + Text Column pairs
- **Separators**: Thin vertical lines for visual grouping
- **Theming**: Uses Theme.color_* and Theme.font_size_* for consistency

## Future Enhancements

Possible additions to the status header:

- 📊 Fuel pump frequency (Hz)
- 📈 Runtime counter (hh:mm format)
- ⏱️ State indicator (Off/Starting/Running/Cooling)
- 🔊 Error indicator if ErrorCode ≠ 0
- 📡 Signal strength indicator
- ⚙️ Power level display (in Power mode)
- 🎯 Target temperature display (in Temperature mode)

## Files Modified

- `dbus-autoterm/native-gui/Victron/VenusOS/pages/HeaterPage.qml`
  - Added: statusIndicatorHeader Rectangle (238 lines)
  - Added: 7 new VeQuickItem bindings
  - Modified: contentScope anchoring to account for header
  - **Total added**: ~250 lines of QML

## Deployment

To deploy to a Venus OS system:

```bash
scp native-gui/Victron/VenusOS/pages/HeaterPage.qml \
    root@<venus-ip>:/data/apps/dbus-autoterm/native-gui/Victron/VenusOS/pages/
```

Then reload the GUI (typically via Settings → Display → Reload GUI or restart the system).

## Testing

To verify the changes are working:

1. Open the native GUI Heater page
2. Confirm the status header appears below the tab bar
3. Verify all 5 indicators display data:
   - Battery voltage shows a number
   - Fan RPM shows 0 when off, increases when running
   - Heater temperature increases when heater is active
   - Internal temperature shows room temperature
   - Connection status is green (unless communication error)
4. Start the heater and watch values update in real-time
5. Stop the heater and verify RPM and temps decrease

## Troubleshooting

**Header not visible?**
- Ensure `root.hasHeater` is true (heater service is connected)
- Check that D-Bus service is running

**Values showing as "--"?**
- Check if VeQuickItem UIDs are correct
- Verify heater service is providing those data points
- Check D-Bus communication is healthy (green indicator)

**Icons not displaying?**
- Verify icon paths exist in Venus OS theme
- Check Theme.color_* values are defined
- Ensure QML file has proper imports (QtQuick.Controls.impl as CP)

## Version Info

- **Created**: 2024-09-15
- **QML Version**: Qt 6 (Victron Venus OS v3.x)
- **Compatibility**: Heater services using D-Bus com.victronenergy.heater.* interface
- **Dependencies**: VeQuickItem from Victron.VenusOS, Theme system
