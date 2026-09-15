# DIY USB Cable - Visual Wiring Diagram

## Complete Assembly Diagram

```
╔════════════════════════════════════════════════════════════════════════╗
║                    AUTOTERM AIR 2D USB UART CABLE                     ║
║                          Assembly Reference                           ║
╚════════════════════════════════════════════════════════════════════════╝


SIDE A: USB END (Connects to Raspberry Pi)
═══════════════════════════════════════════════════════════════════════

                              USB Connector
                              ┌─────────────┐
                              │   USB A     │
                              │   Type A    │
                              │             │
                          ┌───┴─────────────┴───┐
                          │                     │
                    To Raspberry Pi USB Port ←→│
                          │                     │
                          └────────────────┬────┘
                                           │
                          ┌────────────────▼────────────┐
                          │  Waveshare FT232R Adapter   │
                          │                             │
                          │  ┌──────────────────────┐   │
                          │  │ 1  2  3  4  5  6    │   │
                          │  └──┬──┬──┬──┬──┬──┬───┘   │
                          │     │  │  │  │  │  │       │
                          │     ▼  ▼  ▼  ▼  ▼  ▼       │
                          │     G  C  V  R  T  C       │
                          │     N  T  C  X  D  C       │
                          │     D  S     D  D  S       │
                          └─────┼──┼──┼──┼──┼──┼───────┘
                                │  │  │  │  │  │
                    ┌───────────┘  │  │  │  │  │
                    │              │  │  │  │  │
                 PIN 1            │  │  │  │  │
                 GND              │  │  │  │  │
                  ║               │  │  │  │  │
             (Black wire)         │  │  │  │  │
                  ║               │  │  │  │  │
                  ║           ┌───┘  │  │  │  │
                  ║           │      │  │  │  │
                  ║           │      │  │  │  │
                  ║        PIN 4     │  │  │  │
                  ║        RXD       │  │  │  │
                  ║        ║         │  │  │  │
                  ║    (Orange wire) │  │  │  │
                  ║        ║         │  │  │  │
                  ║        ║      ┌──┘  │  │  │
                  ║        ║      │     │  │  │
                  ║        ║      │     │  │  │
                  ║        ║      │  PIN 5 │  │
                  ║        ║      │  TXD  │  │
                  ║        ║      │  ║    │  │
                  ║        ║      │ (Yellow) │
                  ║        ║      │  ║    │  │
                  ║        ║      │  ║    │  │
                  └────────┴──────┴──┴────┴──┴── (Power lines - unused)
                         │         │      │
                   ┌─────┴─────────┴──────┘
                   │
           ┌───────▼────────┐
           │   Cable Bundle  │
           │                 │
           │ 3-wire assembly │
           │ (twisted pair)  │
           │                 │
           │ Black (GND)     │
           │ Orange (RXD)    │
           │ Yellow (TXD)    │
           │                 │
           │ ~1 meter        │
           │ (adjustable)    │
           │                 │
           └───────┬────────┘
                   │
                   │


SIDE B: HEATER END (Connects to Autoterm AIR 2D)
═══════════════════════════════════════════════════════════════════════

           ┌───────┬────────┐
           │   Cable end     │
           │  (heat shrink)  │
           │                 │
           │ Black (GND)     │
           │ Orange (RXD)    │
           │ Yellow (TXD)    │
           │                 │
           └───────┬────────┘
                   │
              ┌────▼──────────────────┐
              │ 4-pin DIN 43650       │
              │ (Heater Connector)    │
              │                       │
              │      Front View:      │
              │                       │
              │        ╔═══╗          │
              │        ║ 1 ║ ← +12V   │
              │    ╔═══╩═══╩═══╗      │
              │    ║ 4       2 ║      │
              │    ║     3     ║      │
              │    ╚═════════╝       │
              │                       │
              │  Pin 1: +12V (red)    │
              │  Pin 2: GND (black)   │
              │  Pin 3: TX (yellow)   │
              │  Pin 4: RX (green)    │
              │                       │
              └───────┬───────────────┘
                      │
              (Connected to heater body)


WIRING CONNECTIONS
═══════════════════════════════════════════════════════════════════════

Waveshare FTDI Pin → Wire Color → Heater Connector Pin
─────────────────────────────────────────────────────

  Pin 1 (GND)  ─→  BLACK wire  ─→  Pin 2 (GND)
       ║             ║              ║
       ║             ║              ║
  ┌────╨────────┬────╨──────────┬───╨──────┐
  │             │               │          │
  ▼             ▼               ▼          ▼


  Pin 4 (RXD)  ─→  ORANGE wire  ─→  Pin 3 (TX)
       ║             ║              ║
       ║             ║              ║
  ┌────╨────────┬────╨──────────┬───╨──────┐
  │             │               │          │
  ▼             ▼               ▼          ▼


  Pin 5 (TXD)  ─→  YELLOW wire  ─→  Pin 4 (RX)
       ║             ║              ║
       ║             ║              ║
  └────────────┬─────────────────────────┘
               │
         ⚠️  NOTE: TX/RX SWAPPED!
             This is correct for AIR 2D


DETAILED PIN LAYOUT
═══════════════════════════════════════════════════════════════════════

Waveshare FT232R Header (6-pin, 1x6 layout):

    LEFT END                           RIGHT END
    ════════════════════════════════════════════

    ┌───┬───┬───┬───┬───┬───┐
    │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │
    └───┴───┴───┴───┴───┴───┘
     │   │   │   │   │   │
     │   │   │   │   │   └─ CCS (unused)
     │   │   │   │   │
     │   │   │   │   └────── TXD ◄── YELLOW wire
     │   │   │   │
     │   │   │   └────────── RXD ◄── ORANGE wire
     │   │   │
     │   │   └──────────────── VCC (5V, unused for heater)
     │   │
     │   └────────────────── CTS (unused)
     │
     └────────────────────── GND ◄── BLACK wire


Autoterm AIR 2D Connector (4-pin DIN 43650, bottom view):

    FACING CONNECTOR (looking at back):

            ┌─────┐
            │  1  │  ← +12V to +16V DC
          / │     │ \
        /   │     │   \
       │ 4  │     │ 2  │
       │    │  3  │    │
        \   └─────┘   /
          \           /
            └─────────┘

    PIN ASSIGNMENTS (as labeled on heater):
    
    1 = Power Input (RED wire from power supply)
    2 = Ground (BLACK wire) ◄── connects to Waveshare Pin 1
    3 = Serial TX (YELLOW wire) ◄── connects to Waveshare Pin 4 (RXD)
    4 = Serial RX (GREEN wire) ◄── connects to Waveshare Pin 5 (TXD)


ASSEMBLY PHYSICAL LAYOUT
═════════════════════════════════════════════════════════════════════

                    [USB Port on Raspberry Pi]
                              ↑
                              │
                       USB Cable (included)
                              │
                              ▼
                    ┌─────────────────┐
                    │ Waveshare FTDI  │
                    │  Adapter Board  │
                    │  (PCB 50x20mm)  │
                    │                 │
                    │  ┌───────────┐  │
                    │  │ 1 2 3 4 5 │  │  ← Header pins (1x6)
                    │  └─┬─┬─┬─┬─┬─┘  │
                    └────┼─┼─┼─┼─┼────┘
                         │ │ │ │ │
            ┌────────────┐ │ │ │ │
            │            │ │ │ │ │
         BLACK       ORANGE YELLOW
            │            │ │ │ │
            │     ┌───────┘ │ │ │
            │     │   ┌─────┘ │ │
            │     │   │   ┌───┘ │
            │     │   │   │     │
            └─────┴───┴───┴─────┘
                    │
            Cable bundle
            (3-wire twisted)
                    │
           ~1 meter (adjustable)
                    │
                    ▼
            ┌───────────────┐
            │  Heat shrink  │
            │   tubing      │
            │  (color-coded)│
            └───────────────┘
                    │
                ┌───┴────┐
            BLACK ORANGE YELLOW
                │   │     │
                │   │     │
            ┌───▼───▼─────▼───┐
            │ 4-pin Connector │
            │ (to heater)     │
            │                 │
            │  Pin 2 (GND)    │ ◄── BLACK
            │  Pin 3 (TX)     │ ◄── ORANGE
            │  Pin 4 (RX)     │ ◄── YELLOW
            │  Pin 1 (+12V)   │ (not connected via this cable)
            │                 │
            └─────────────────┘
                    │
              (to Autoterm AIR 2D heater)


DATA FLOW DIAGRAM
═════════════════════════════════════════════════════════════════════

Heater sends data (TX):
    
    Autoterm AIR 2D       →  Pin 3 (TX) on connector
        ║                      ║
        ║                      ║ (YELLOW wire)
        ║                      ║
        ║                  Waveshare Pin 4 (RXD)
        ║                      ║
        ║                      ▼
        ║            [FTDI Chip converts USB]
        ║                      ║
        ║            /dev/ttyUSB0 on RPi
        ║                      ║
        └─────────────→  dbus-autoterm driver
                        parses frames


Raspberry Pi sends data (TXD):

    dbus-autoterm driver
        ║
        ║ Sends command frames
        ║
        ▼
    /dev/ttyUSB0 on RPi
        ║
        ║ [FTDI Chip converts to serial]
        ║
        ▼
    Waveshare Pin 5 (TXD)
        ║
        ║ (YELLOW wire)
        ║
        ▼
    Pin 4 (RX) on heater connector
        ║
        ▼
    Autoterm AIR 2D receives command


CABLE LENGTH & ROUTING
═════════════════════════════════════════════════════════════════════

Recommended Configuration:

    USB Adapter ─────── 1 meter cable ─────── Heater Connector
    
    • Shorter is better (reduces noise pickup)
    • Maximum: 3-5 meters at 9600 baud
    • Keep away from AC power lines
    • Avoid sharp bends (min. 25mm radius)
    • Use cable ties (not rubber bands)
    • Route through conduit if in noisy area


TESTING SETUP
═════════════════════════════════════════════════════════════════════

Before connecting to heater:

    1. Check physical connections at FTDI adapter
       • All 3 wires properly seated
       • No loose strands
       • Heat shrink covers all exposed leads

    2. Verify on Raspberry Pi
       • USB adapter detected: lsusb | grep FTDI
       • Serial device available: ls /dev/ttyUSB0
       • Permissions correct

    3. Test with serial monitor
       • minicom -D /dev/ttyUSB0 -b 9600
       • Should show heater init frames when powered

    4. Verify with driver
       • Restart service: svc -t /service/dbus-autoterm
       • Check logs: tail -f /data/log/dbus-autoterm/current
       • Should show "Connected" and frame data

