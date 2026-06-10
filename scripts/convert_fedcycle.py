#!/usr/bin/env python3
"""Convert the FedCycle dataset (Fehring/Marquette) to Velia's benchmark CSV.

FedCycle stores one row per (ClientID, CycleNumber) with a `LengthofCycle` (days) and NO period
dates or clinical segment labels. Velia's benchmark wants one row per period *start* date. Since the
engine only uses day-gaps between starts, we anchor each client at a fixed date and synthesize starts
by cumulatively summing their cycle lengths. Segment is set to `unknown` (use --irregular-from-data
in velia-bench to split the irregular subset by observed variability).

Source: https://epublications.marquette.edu/data_nfp/7/  (Fehring RJ, Marquette University).

Usage:
    python3 scripts/convert_fedcycle.py "FedCycleData071012 (2).csv" out.csv
"""
import csv
import sys
from datetime import date, timedelta

ANCHOR = date(2020, 1, 1)  # arbitrary; only day-gaps matter to the engine


def convert(src_path: str, out_path: str) -> None:
    # Group cycle lengths per client, ordered by CycleNumber.
    per_client: dict[str, list[tuple[int, int]]] = {}
    order: list[str] = []

    with open(src_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cid = (row.get("ClientID") or "").strip()
            if not cid:
                continue
            try:
                cyc = int(float(row.get("CycleNumber") or 0))
                length = int(float(row.get("LengthofCycle") or 0))
            except ValueError:
                continue
            if length <= 0:
                continue
            if cid not in per_client:
                per_client[cid] = []
                order.append(cid)
            per_client[cid].append((cyc, length))

    rows_out = 0
    clients_out = 0
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["user_id", "segment", "period_start"])
        for cid in order:
            lengths = [length for _, length in sorted(per_client[cid])]
            if len(lengths) < 4:  # need ≥5 starts to score predictions (benchmark minHistory=3)
                continue
            clients_out += 1
            start = ANCHOR
            w.writerow([cid, "unknown", start.isoformat()])
            rows_out += 1
            for length in lengths:
                start = start + timedelta(days=length)
                w.writerow([cid, "unknown", start.isoformat()])
                rows_out += 1

    print(f"Converted {clients_out} clients → {rows_out} period-start rows → {out_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
