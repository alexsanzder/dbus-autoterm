#!/bin/bash
# Capture real heater protocol data from remote device

set -e

# Configuration
VENUS_TARGET="${VENUS_TARGET:-root@10.106.178.134}"
LOG_PATH="/data/log/dbus-autoterm/current"
OUTPUT_DIR="./captured_data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         REAL HEATER DATA CAPTURE                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Target device: $VENUS_TARGET"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Download logs
echo "📥 Downloading logs from $VENUS_TARGET..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$VENUS_TARGET" "cat $LOG_PATH" > "$OUTPUT_DIR/driver_${TIMESTAMP}.log"

LOG_FILE="$OUTPUT_DIR/driver_${TIMESTAMP}.log"
echo "✅ Downloaded $(wc -l < "$LOG_FILE") lines"

# Extract frames
echo ""
echo "🔍 Extracting protocol frames..."
python3 extract_heater_data.py "$LOG_FILE" "$OUTPUT_DIR/frames_${TIMESTAMP}.json"

# Generate summary
echo ""
echo "📊 Generating summary..."
python3 - "$LOG_FILE" "$OUTPUT_DIR/frames_${TIMESTAMP}.json" << 'PYTHON'
import json
import sys

log_file = sys.argv[1]
json_file = sys.argv[2]

# Count frame types
with open(log_file) as f:
    content = f.read()
    
frame_types = {}
for line in content.split('\n'):
    if 'rx_frame msg=' in line:
        import re
        match = re.search(r'msg=(0x[0-9a-f]+)', line)
        if match:
            msg = match.group(1)
            frame_types[msg] = frame_types.get(msg, 0) + 1

print("\n📈 Frame type distribution:")
for msg_type in sorted(frame_types.keys()):
    count = frame_types[msg_type]
    print(f"   {msg_type}: {count} frames")

# Show sample data
with open(json_file) as f:
    data = json.load(f)
    
if data['frames']['rx_frames']:
    print("\n📨 Sample RX frames:")
    for i, frame in enumerate(data['frames']['rx_frames'][-3:]):
        print(f"   Frame {i}: {frame['message_type']} - payload: {frame['payload'][:32]}...")
        if 'decoded' in frame:
            decoded = frame['decoded']
            if decoded:
                print(f"      → Internal: {decoded.get('internal_temperature_c')}°C, " 
                      f"Heater: {decoded.get('heater_temperature_c')}°C, "
                      f"Voltage: {decoded.get('voltage_v')}V")
PYTHON

echo ""
echo "✅ Data capture complete!"
echo ""
echo "📁 Files saved to: $OUTPUT_DIR/"
echo "   - driver_${TIMESTAMP}.log (raw logs)"
echo "   - frames_${TIMESTAMP}.json (parsed frames)"
echo ""
echo "💡 Usage:"
echo "   1. Review captured data: less $OUTPUT_DIR/frames_${TIMESTAMP}.json"
echo "   2. Use in dummy driver: Update emulation/src/heater.py with frames"
echo "   3. Run tests: devbox run emulation:test"
echo ""
