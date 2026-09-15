# DIY USB Cable - Quick Reference

## Waveshare FTDI to Autoterm AIR 2D Wiring

```
WAVESHARE FTDI ADAPTER          AUTOTERM AIR 2D (4-pin DIN 43650)
┌──────────────────────┐        ┌─────────────────┐
│ USB ║ 1 2 3 4 5 6    │        │  1   2   4   3  │
│     ║ ↓ ↓ ↓ ↓ ↓ ↓    │        │  ║   ║   ║   ║  │
│     ║ G C V R T C    │        │  +  GND RX  TX  │
│     ║ N T C X D C    │        │  12V    Green  │
│     ║ D S  D D S    │        │       Yellow    │
└──────────────────────┘        └─────────────────┘
      ║  ║  ║  ║ ║                  ║   ║  ║   ║
      ║  ║  ║  └─┼──────────────────┘   ║  ║   ║
      ║  ║  ║    │ RXD (Pin 4)          ║  ║   ║
      ║  ║  ║    └─ Heater TX (Pin 3) ◄─ ORANGE
      ║  ║  │
      ║  ║  └──────────────────────────────┐
      ║  │ VCC (Pin 3) - UNUSED           │
      ║  │                                │
      ║  └─ TXD (Pin 5) ─────► Heater RX (Pin 4) ◄─ YELLOW
      │
      └─ GND (Pin 1) ───────► Heater GND (Pin 2) ◄─ BLACK
```

## Wire Summary

| From | To | Color | Function |
|------|----|----|----------|
| Waveshare Pin 1 (GND) | Heater Pin 2 (GND) | **BLACK** | Ground |
| Waveshare Pin 4 (RXD) | Heater Pin 3 (TX) | **ORANGE** | Heater transmit → Adapter receive |
| Waveshare Pin 5 (TXD) | Heater Pin 4 (RX) | **YELLOW** | Adapter transmit → Heater receive |

⚠️ **TX/RX are SWAPPED - this is correct!**

## Device Setup (Raspberry Pi)

```bash
# Check device
ls /dev/ttyUSB0

# Test connection
minicom -D /dev/ttyUSB0 -b 9600

# Create persistent symlink (optional)
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="ttyAUTOTERM"' | \
  sudo tee /etc/udev/rules.d/99-autoterm.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Configuration

```ini
[driver]
backend = serial
serial_device = /dev/ttyUSB0      # or /dev/ttyAUTOTERM
provider_data = simulated
```

## Verification Commands

```bash
# Is adapter present?
lsusb | grep FTDI

# Is device connected?
ls -la /dev/ttyUSB0

# Can we read data?
tail -f /data/log/dbus-autoterm/current | grep -E "0x[0-9A-F]"

# Check telemetry
dbus-send --system --print-reply \
  --dest=com.victronenergy.heater.autoterm_air2d \
  /Telemetry/InternalTemperature \
  com.victronenergy.BusItem.GetValue
```

## Troubleshooting Checklist

- [ ] Waveshare adapter shows in `lsusb`
- [ ] Device file exists at `/dev/ttyUSB0`
- [ ] Wires connected: GND (Black), RXD (Orange to Pin 3), TXD (Yellow to Pin 4)
- [ ] Heater powered (12-16V on Pin 1)
- [ ] Baud rate set to 9600
- [ ] Service logs show "Connected" status
- [ ] Heater telemetry values appear in D-Bus

## Cable Specifications

- **Adapter:** Waveshare FT232R (FTDI chipset)
- **Protocol:** 9600 baud, 8N1
- **Voltage:** 3.3V logic (USB powered)
- **Max Length:** 3-5 meters
- **Interface:** USB 2.0

## Parts List

```
□ Waveshare FTDI USB-UART Adapter (1x)
□ Jumper wires 22-24 AWG (3x minimum)
□ Heat shrink tubing 3mm & 5mm
□ Wire stripper
□ Soldering iron (recommended)
```

## Key Discovery

The critical insight: **Pin 3 and Pin 4 on the heater connector are non-standard UART.**

```
Standard UART:           Autoterm AIR 2D:
TX → RXD                 TX ← RXD (REVERSED)
RX ← TXD                 RX ← TXD (SWAPPED)
```

This swap was discovered during hardware testing and verified with successful protocol handshake (0x1C init sequence).

