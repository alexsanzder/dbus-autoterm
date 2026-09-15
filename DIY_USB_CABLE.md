# DIY Autoterm AIR 2D USB UART Cable

## Overview

This guide documents the custom USB UART cable setup for connecting an Autoterm AIR 2D heater to a Raspberry Pi running Venus OS. The cable uses a Waveshare FTDI USB-UART adapter with custom wiring.

## Parts Required

### Hardware

| Item | Model | Specifications | Source |
|------|-------|----------------|--------|
| **USB UART Adapter** | Waveshare FT232R | FTDI FT232R chipset, BG04FCH9 variant | [Waveshare](https://www.waveshare.com) |
| **USB Cable** | USB A to Micro-B | Standard USB 2.0 (included with adapter) | Included |
| **Heater Connector** | 4-pin DIN 43650 | AIR 2D standard connector | Autoterm |
| **Jumper Wires** | 22-24 AWG | Stranded, color-coded (Black, White, Green, Red) | Electronics supplier |
| **Heat Shrink Tubing** | 3mm & 5mm | Various colors for identification | Electronics supplier |
| **Crimps/Solder** | Optional | For reliable connections | - |

### Tools

- Wire stripper (22-24 AWG)
- Soldering iron (optional, for most reliable connections)
- Hot glue gun (for strain relief)
- Multimeter (for verification)
- Pinout reference guide (below)

## Autoterm AIR 2D Connector Pinout

The heater uses a **4-pin DIN 43650** (circular connector):

```
        ╔═══╗
        ║ 1 ║  ← Pin 1: Power (+12V to +16V)
    ╔═══╩═══╩═══╗
    ║ 4       2 ║
    ║     3     ║
    ╚═════════╝

Pin 1: +12V Power Input (red)
Pin 2: Ground / GND (black)
Pin 3: Serial TX (heater transmits) → YELLOW
Pin 4: Serial RX (heater receives) → GREEN
```

**CRITICAL NOTE:** Pin 3 and Pin 4 are **not** labeled; they're identified by testing/documentation.

## Waveshare FT232R Pinout

The Waveshare FTDI adapter exposes 6 pins on a 1x6 header:

```
[USB Connector]
      |
      ↓
┌─────────────┐
│ 1 2 3 4 5 6 │  ← Header pins
└─────────────┘
  G R T R V C
  N E X X C C
  D D D D C S
```

Pin assignments (left to right when viewing the header):

| Pin | Signal | Voltage | Function |
|-----|--------|---------|----------|
| 1   | GND    | Ground  | Ground reference |
| 2   | CTS    | 3.3V    | Clear to Send (unused) |
| 3   | VCC    | 5V      | Power output (unused for heater) |
| 4   | RXD    | 3.3V    | Serial data **INPUT** (receives from heater) |
| 5   | TXD    | 3.3V    | Serial data **OUTPUT** (sends to heater) |
| 6   | CCS    | 3.3V    | Chip select (unused) |

**Pin Color Convention (Waveshare header, left to right):**
- Pin 1: Black wire (GND)
- Pin 2: Brown wire (CTS)
- Pin 3: Red wire (VCC)
- Pin 4: Orange wire (RXD)
- Pin 5: Yellow wire (TXD)
- Pin 6: Green wire (unused label, but often labeled as CCS)

## Critical Wiring: TX/RX Swap

### ⚠️ The Most Important Detail

**The heater TX and RX are swapped compared to standard UART conventions.**

This was discovered during testing - standard UART connection did not work, but reversing the wires established communication.

### Correct Wiring (TX/RX Swapped)

```
Autoterm AIR 2D Connector (4-pin DIN 43650)
    ↓
    
    Pin 2 (GND/Black)    →  Waveshare Pin 1 (GND/Black)
    Pin 3 (TX/Yellow)    →  Waveshare Pin 4 (RXD/Orange)   ← SWAP!
    Pin 4 (RX/Green)     →  Waveshare Pin 5 (TXD/Yellow)   ← SWAP!
    Pin 1 (Power/Red)    →  (Optional: 12V power if needed)
```

### Why the Swap?

The Autoterm AIR 2D documentation may have non-standard UART pin labeling, or the connector is designed from the device's perspective (TX = data it sends TO the device = RXD on adapter, etc.). The swap was verified through successful protocol handshake.

## Wiring Diagram

```
┌──────────────────────┐
│  Waveshare FTDI      │
│  USB ↔ UART Adapter  │
│                      │
│  [USB A Connector]   │
│         |            │
│    ┌────┴────┐       │
│    │ 1 2 3 4 │       │  ← Header pins
│    │   5 6   │       │     (6 pins total)
│    └────┬────┘       │
└─────────┼────────────┘
          │
    ┌─────┼─────┬──────────────┐
    │     │     │              │
   GND   RXD   TXD            (VCC/unused)
   (1)   (4)   (5)
    │     │     │
    │     │     │
BLACK  ORANGE YELLOW
    │     │     │
    ├─────┼─────┤
    │     │     │
    │     │     └─────┐
    │     └───────┐   │
    │             │   │
    │    ┌────────┼───┼───────┐
    │    │        │   │       │
    │    │    ┌───┴───┴───┐   │
    │    │    │  4-PIN    │   │
    │    │    │ DIN 43650 │   │
    │    │    └───┬───┬───┘   │
    │    │        │   │       │
    │    │    ┌───┘   │       │
    │    │    │ ┌─────┘       │
    │    │    │ │             │
    └────┼────┼─┼─────────────┘
        (2)  (4) (3)
        GND  RX  TX
        
To Heater Connector (4-pin DIN 43650):
    Pin 1 = +12V (red)
    Pin 2 = GND (black)      ← BLACK wire from Waveshare
    Pin 3 = TX (yellow)      ← YELLOW wire to Waveshare RXD
    Pin 4 = RX (green)       ← ORANGE wire to Waveshare TXD
```

## Step-by-Step Assembly

### Step 1: Prepare the Waveshare Adapter

1. If the adapter comes with pre-soldered header pins, you're ready
2. If not, solder the 1x6 header to the PCB
3. Verify USB connectivity by plugging into a computer:
   ```bash
   lsusb | grep FTDI
   ls -la /dev/tty* | grep USB
   ```

### Step 2: Prepare Wire Connections

For each of the three connections (GND, TX, RX):

1. **Strip wire ends:** Remove ~6mm of insulation from each end
2. **Pre-tin with solder (optional but recommended)** for solid connections
3. **Heat shrink labels:** Apply 3mm heat shrink tubing with labels:
   - Black: GND
   - Orange: RXD (from heater TX)
   - Yellow: TXD (to heater RX)

### Step 3: Connect to Waveshare Adapter

**Three-wire configuration** (minimum for operation):

```
Waveshare FTDI Adapter
┌─────────────────────┐
│ 1   2   3   4   5 6 │
│ │   │   │   │   │ │
│ │   │   │   │   │ │
└─┼───┼───┼───┼───┼─┘
  │   │   │   │   │
  │   │   │  (Orange)  ← Connect to Pin 4 (RXD)
  │   │   │   │   │
  │   │   │  (Yellow)  ← Connect to Pin 5 (TXD)
  │   │   │   │   │
  │  (Black)  │   │    ← Connect to Pin 1 (GND)
  │   │       │   │
  │   └───────┼───┘
  │           │
  └───────────┘
```

**Option 1: Direct Solder (Most Reliable)**
- Solder wires directly to header pins
- Use small amount of solder
- Apply heat shrink over connections
- Best for permanent installation

**Option 2: Jumper Connectors**
- Attach female crimp connectors to wire ends
- Insert into header socket
- Allows easy reconnection

### Step 4: Connect to Heater Connector

The 4-pin DIN 43650 connector on the heater:

1. **Identify pins** - Check heater documentation or use multimeter to identify GND and data pins
2. **Connect three wires:**
   - Black (GND from Waveshare Pin 1) → Heater Pin 2 (GND)
   - Orange (RXD from Waveshare Pin 4) → Heater Pin 3 (TX)
   - Yellow (TXD from Waveshare Pin 5) → Heater Pin 4 (RX)
3. **Strain relief:**
   - Apply hot glue around heater connector
   - Secure cable bundle with cable tie
   - Ensure wires won't bend sharply near connector

### Step 5: Secure the Cable

1. **Label each section:**
   - Waveshare end: "USB → FTDI"
   - Heater end: "→ Autoterm AIR 2D"
   - Middle section: Mark GND, RXD, TXD
2. **Apply heat shrink:**
   - 5mm shrink over entire connector sections
   - Color-code: Black (GND), Orange (RXD), Yellow (TXD)
3. **Cable routing:**
   - Keep away from high-current power lines
   - Route through cable conduit if in noisy environment
   - Avoid sharp bends (minimum 25mm radius)

## USB Device Setup on Raspberry Pi

### Step 1: Connect Cable

1. Plug USB end into Raspberry Pi USB port
2. Verify device is recognized:
   ```bash
   lsusb | grep FTDI
   ```
   Expected output:
   ```
   Bus 001 Device 005: ID 0403:6001 Future Technology Devices International, Ltd FT232 Serial (UART) IC
   ```

### Step 2: Check Serial Device

```bash
# List serial devices
ls -la /dev/tty*

# Should see /dev/ttyUSB0 (or higher number if multiple adapters)
```

### Step 3: Set Permissions (if needed)

On Venus OS, add the user to the `dialout` group:

```bash
usermod -a -G dialout $(whoami)
# Log out and log back in for group changes to take effect
```

### Step 4: Create Symlink (Optional)

For easier configuration, create a persistent symlink:

```bash
# Edit udev rule
cat > /etc/udev/rules.d/99-autoterm.rules << 'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="ttyAUTOTERM"
EOF

# Reload udev
udevadm control --reload-rules
udevadm trigger

# Verify symlink
ls -la /dev/ttyAUTOTERM
```

Then in config.ini:
```ini
[driver]
serial_device = /dev/ttyAUTOTERM
```

## Configuration

### config.ini

```ini
[driver]
backend = serial                    # Use real serial device
serial_device = /dev/ttyUSB0        # Or /dev/ttyAUTOTERM if symlink created
provider_data = simulated           # or "real" if capturing data
room_temperature_service = auto
poll_interval = 1.0
log_level = INFO
mock_dbus = false
```

### Protocol Parameters

The cable supports the AIR 2D protocol:
- **Baud Rate:** 9600
- **Data Bits:** 8
- **Stop Bits:** 1
- **Parity:** None (8N1)
- **Flow Control:** None
- **Handshake:** CRC16-Modbus

No special configuration needed - the adapter handles these automatically.

## Testing & Verification

### Test 1: Physical Connection

```bash
# Check device is present
ls -la /dev/ttyUSB0

# Check with dmesg
dmesg | grep -i ftdi | tail -5
```

**Expected:** Device file exists, FTDI detected in kernel logs

### Test 2: Serial Communication

Using `minicom` or `picocom`:

```bash
# Install if needed
apt-get install minicom

# Open serial connection
minicom -D /dev/ttyUSB0 -b 9600

# Or use picocom
picocom -b 9600 /dev/ttyUSB0
```

Expected behavior:
- Connection opens without errors
- Heater sends init sequence (0x1C frame) when powered on
- Heater responds to status poll (0x0F frame)

### Test 3: With dbus-autoterm Driver

```bash
# Check logs
tail -f /data/log/dbus-autoterm/current

# Verify frames are received
grep -E "0x[0-9A-F]{2}" /data/log/dbus-autoterm/current | head -10
```

Expected output:
```
INFO: Connected to heater device at /dev/ttyUSB0
INFO: Received init frame: 0x1C 0x...
INFO: Polling status: 0x0F 0x...
```

### Test 4: D-Bus Communication

```bash
# Query heater state
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /State \
  com.victronenergy.BusItem.GetValue

# Check telemetry
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /Telemetry/InternalTemperature \
  com.victronenergy.BusItem.GetValue
```

Expected: Values update in real-time

## Troubleshooting

### Problem: Device Not Recognized

**Symptoms:** `ls /dev/ttyUSB*` shows no device

**Solutions:**
1. Check USB connection - try different USB port
2. Check cable continuity with multimeter
3. Verify FTDI adapter firmware
   ```bash
   ftdi_eeprom --read eeprom.bin /dev/ttyUSB0 2>&1 | head -5
   ```
4. Try on another computer to isolate Raspberry Pi issue

### Problem: No Data Received

**Symptoms:** 
- Device connected but no frames in logs
- Status always shows "disconnected"

**Solutions:**
1. **Verify TX/RX swap:** Reverse pins 4 and 3 on heater connector
   ```
   Try: Pin 3 (yellow) → Waveshare TXD (Pin 5)
        Pin 4 (orange) → Waveshare RXD (Pin 4)
   ```
2. **Check baud rate:** Confirm protocol is 9600 baud
3. **Verify continuity:**
   ```bash
   # Waveshare pins to heater connector
   Black: GND → Pin 2 ✓
   Yellow: TXD → Pin 4 ✓
   Orange: RXD → Pin 3 ✓
   ```
4. **Check for power:** Heater needs 12-16V input on Pin 1 to be active

### Problem: Intermittent Connection

**Symptoms:**
- Connection drops and reconnects
- Occasional data corruption
- CRC errors in logs

**Solutions:**
1. **Check cable routing:**
   - Keep away from power lines
   - Ensure no sharp bends
   - Avoid fluorescent lights
2. **Improve shielding:**
   - Use shielded cable if possible
   - Ground shield at FTDI adapter end only
3. **Reduce cable length:**
   - Shorter cables have less susceptibility to noise
   - Maximum recommended: 3-5 meters for 9600 baud
4. **Check power supply:**
   - Ensure heater has stable 12-16V input
   - Heater power should be from same supply as Raspberry Pi ground

### Problem: CRC Errors

**Symptoms:** Frames received but CRC validation fails

**Solutions:**
1. Verify baud rate is exactly 9600
2. Check for noise in signal path (see intermittent connection above)
3. Capture frames and verify with protocol analyzer
   ```bash
   bash capture_real_heater_data.sh
   ```

## Advanced Configuration

### Multiple Adapters

If connecting multiple devices:

```bash
# List all FTDI adapters
lsusb | grep FTDI

# Check serial numbers
ftdi_find -l

# Create udev rules for each device
cat > /etc/udev/rules.d/99-ft232.rules << 'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A1B2C3D4", SYMLINK+="ttyHEATER"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="E5F6G7H8", SYMLINK+="ttyOTHER"
EOF
```

### Custom Baud Rates

If needed to change baud rate (unlikely for AIR 2D):

```bash
# View current settings
stty -a -F /dev/ttyUSB0

# Change baud rate
stty -F /dev/ttyUSB0 9600 cs8 -parenb -cstopb
```

## Parts Cost Estimate

| Item | Qty | Unit Cost | Total |
|------|-----|-----------|-------|
| Waveshare FTDI Adapter | 1 | $8-12 | $10 |
| Jumper Wires (pack of 40) | 1 | $5-8 | $6 |
| Heat Shrink Tubing Assortment | 1 | $4-6 | $5 |
| **Total** | | | **$21** |

*Prices approximate; check current suppliers*

## References

- Waveshare FT232R Documentation: https://www.waveshare.com/wiki/FT232R_USB_UART
- Autoterm AIR 2D Manual: See project `/docs/protocol.md`
- FTDI FT232R Datasheet: https://ftdichip.com/
- DIN 43650 Connector Pinout: Standard industrial connector spec

## Safety Notes

⚠️ **Important:**

1. **Power Safety:**
   - Heater operates on 12-16V DC
   - Adapter runs on USB power (5V, ~100-500mA)
   - Do NOT connect heater 12V directly to Raspberry Pi GPIO
   - Waveshare adapter has built-in voltage regulation

2. **Data Line Voltage:**
   - Waveshare outputs 3.3V logic levels
   - Heater expects standard UART levels
   - Most modern heaters accept 3.3V UART (check docs)
   - Level shifter may be needed if heater expects 5V (unlikely)

3. **Cable Management:**
   - Don't run near high-current power cables
   - Minimize cable length
   - Avoid coiling tightly (increases capacitance)
   - Use cable ties, not rubber bands (degrades rubber)

## Support & Issues

If experiencing issues:

1. Check logs:
   ```bash
   tail -100 /data/log/dbus-autoterm/current > logs.txt
   ```

2. Capture real data:
   ```bash
   bash capture_real_heater_data.sh
   ```

3. Run tests:
   ```bash
   devbox run dbus-autoterm:test
   ```

4. Review protocol reference:
   ```bash
   cat /path/to/project/docs/protocol.md
   ```

