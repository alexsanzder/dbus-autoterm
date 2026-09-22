#!/usr/bin/env python3
"""
Extract real heater protocol frames from driver logs and save to JSON.

Usage:
    python3 extract_heater_data.py <log_file> <output_file>

Example:
    ssh root@10.106.178.134 'tail -1000 /data/log/dbus-autoterm/current' > driver.log
    python3 extract_heater_data.py driver.log real_heater_frames.json
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path


def parse_hex_string(hex_str: str) -> bytes:
    """Convert hex string to bytes."""
    try:
        return bytes.fromhex(hex_str.replace(' ', ''))
    except ValueError:
        return b''


def decode_status_frame(payload: str) -> dict:
    """Decode a 0x0F status frame payload."""
    try:
        data = bytes.fromhex(payload)
        if len(data) < 19:
            return {}
        
        return {
            'status_code_major': data[0],
            'status_code_minor': data[1],
            'internal_temperature_c': int.from_bytes([data[3]], signed=True),
            'external_temperature_c': int.from_bytes([data[4]], signed=True),
            'voltage_v': data[6] / 10.0,
            'heater_temperature_c': data[8] + 15,
            'fan_rpm_set': data[11],
            'fan_rpm_actual': data[12],
            'fuel_pump_frequency_hz': data[14] / 100.0,
        }
    except (IndexError, ValueError):
        return {}


def extract_frames_from_log(log_content: str) -> dict:
    """Extract protocol frames from driver log."""
    frames = {
        'rx_frames': [],
        'tx_frames': [],
        'timestamps': []
    }
    
    # Pattern for rx_frame: DEBUG:provider:rx_frame msg=0x0f device=0x04 payload=...
    rx_pattern = r'DEBUG:provider:rx_frame msg=(0x[0-9a-f]+) device=(0x[0-9a-f]+) payload=([0-9a-f]*)'
    # Pattern for tx_frame: DEBUG:provider:tx msg=0x0f device=0x03 payload=...
    tx_pattern = r'DEBUG:provider:tx msg=(0x[0-9a-f]+) device=(0x[0-9a-f]+) payload=([0-9a-f]*)'
    
    for line in log_content.split('\n'):
        # Extract RX frames
        rx_match = re.search(rx_pattern, line)
        if rx_match:
            msg_type, device, payload = rx_match.groups()
            frames['rx_frames'].append({
                'message_type': msg_type,
                'device': device,
                'payload': payload,
                'timestamp': datetime.now().isoformat()
            })
            if payload.startswith('0f'):  # Status frame
                decoded = decode_status_frame(payload)
                frames['rx_frames'][-1]['decoded'] = decoded
        
        # Extract TX frames
        tx_match = re.search(tx_pattern, line)
        if tx_match:
            msg_type, device, payload = tx_match.groups()
            frames['tx_frames'].append({
                'message_type': msg_type,
                'device': device,
                'payload': payload,
                'timestamp': datetime.now().isoformat()
            })
    
    return frames


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("Error: Missing log file argument")
        sys.exit(1)
    
    log_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2] if len(sys.argv) > 2 else 'real_heater_frames.json')
    
    if not log_file.exists():
        print(f"Error: Log file not found: {log_file}")
        sys.exit(1)
    
    print(f"Reading log file: {log_file}")
    log_content = log_file.read_text()
    
    print("Extracting protocol frames...")
    frames = extract_frames_from_log(log_content)
    
    # Create output JSON
    output = {
        'extraction_date': datetime.now().isoformat(),
        'source_file': str(log_file),
        'summary': {
            'total_rx_frames': len(frames['rx_frames']),
            'total_tx_frames': len(frames['tx_frames']),
            'status_frames_0x0f': len([f for f in frames['rx_frames'] if f['message_type'] == '0x0f']),
        },
        'frames': frames
    }
    
    # Save to file
    output_file.write_text(json.dumps(output, indent=2))
    print(f"\n✅ Saved {len(frames['rx_frames'])} RX frames and {len(frames['tx_frames'])} TX frames")
    print(f"📁 Output file: {output_file}")
    print(f"\nSummary:")
    print(f"  RX Frames: {output['summary']['total_rx_frames']}")
    print(f"  TX Frames: {output['summary']['total_tx_frames']}")
    print(f"  Status Frames (0x0F): {output['summary']['status_frames_0x0f']}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
