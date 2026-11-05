#!/usr/bin/env python3
"""Prints average power per rail in mW, as JSON, from a perfetto trace taken with
android_power_config { collect_power_rails: true } on devices that have rail meters."""
import json
import sys

POWER_RAILS_FIELD = 40  # TracePacket.power_rails


def read_varint(data, i):
    shift = value = 0
    while True:
        byte = data[i]
        i += 1
        value |= (byte & 0x7f) << shift
        shift += 7
        if byte < 0x80:
            return value, i


def fields(data):
    i = 0
    while i < len(data):
        key, i = read_varint(data, i)
        number, wire_type = key >> 3, key & 7
        if wire_type == 0:
            value, i = read_varint(data, i)
        elif wire_type == 2:
            length, i = read_varint(data, i)
            value, i = data[i:i + length], i + length
        elif wire_type == 1:
            value, i = data[i:i + 8], i + 8
        elif wire_type == 5:
            value, i = data[i:i + 4], i + 4
        else:
            raise ValueError(f"unknown wire type {wire_type}")
        yield number, value


names, first, last = {}, {}, {}
with open(sys.argv[1], "rb") as trace:
    for number, packet in fields(trace.read()):
        if number != 1:
            continue
        for packet_field, rails in fields(packet):
            if packet_field != POWER_RAILS_FIELD:
                continue
            for rail_field, rail in fields(rails):
                if rail_field not in (1, 2):
                    continue
                entry = dict(fields(rail))
                if rail_field == 1:
                    names[entry.get(1, 0)] = entry[2].decode()
                elif rail_field == 2:
                    index = entry.get(1, 0)
                    first.setdefault(index, (entry.get(2, 0), entry.get(3, 0)))
                    last[index] = (entry.get(2, 0), entry.get(3, 0))

print(json.dumps({
    name: (last[i][1] - first[i][1]) / (last[i][0] - first[i][0])  # uWs / ms = mW
    for i, name in names.items()
    if i in first and last[i][0] > first[i][0]
}))
