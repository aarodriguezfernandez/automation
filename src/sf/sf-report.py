#!/usr/bin/env python3

import csv
import sys
from io import StringIO
import os
import json
from pathlib import Path

csv_file = sys.argv[1]
crawl_type = sys.argv[2]
site = sys.argv[3]

from datetime import datetime

# report_date = datetime.now().strftime("%Y-%m-%d %H:%M")
report_date = datetime.now().strftime("%Y-%m-%d")

report = StringIO()


def delta(name, current, previous_data):
    previous = previous_data.get(name)

    if previous is None:
        return str(current)

    diff = current - previous

    if diff > 0:
        return f"{current} (+{diff})"

    if diff < 0:
        return f"{current} ({diff})"

    return f"{current} (0)"

def out(text=""):
    print(text)
    report.write(text + "\n")

total = 0
indexable = 0
non_indexable = 0

missing_meta = 0
missing_h1 = 0
multiple_h1 = 0

empty_sections = 0
empty_section_urls = []

internal_301 = 0
internal_404 = 0
internal_404_urls = []
internal_404_sources = {}
external_404 = 0
external_404_urls = []
external_404_sources = {}


def base_filter(row):
    addr = row["Address"]

    if "?" in addr:
        return False

    if addr.endswith("/"):
        return False

    return True


with open(csv_file, newline="", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):

        if not base_filter(row):
            continue

        code = str(row["Status Code"])

        # 301s
        if code.startswith("3"):
            internal_301 += 1
            continue

        # 404s
        if code.startswith("4"):
            internal_404 += 1

            internal_404_urls.append({
                "url": row["Address"],
                "inlinks": row["Inlinks"],
            })

            continue

        total += 1

        if row["Indexability"] == "Indexable":
            indexable += 1
        else:
            non_indexable += 1

        if not row["Meta Description 1"].strip():
            missing_meta += 1

        if not row["H1-1"].strip():
            missing_h1 += 1

        if row["H1-2"].strip():
            multiple_h1 += 1

        try:
            if int(row["Empty Sections"] or 0) > 0:
                empty_sections += 1
                empty_section_urls.append(row["Address"])
        except ValueError:
            pass

# Metric and report generation folder
folder_name = os.path.basename(os.path.dirname(csv_file))

metrics = {
    "site": site,
    "crawl_type": crawl_type,
    "total": total,
    "indexable": indexable,
    "non_indexable": non_indexable,
    "internal_301": internal_301,
    "internal_404": internal_404,
    "missing_meta": missing_meta,
    "missing_h1": missing_h1,
    "multiple_h1": multiple_h1,
    "empty_sections": empty_sections,
    "empty_section_urls": sorted(empty_section_urls),
    "external_404": external_404,
    "external_404_urls": sorted([
        row["url"] for row in external_404_urls
    ]),
   
}

json_file = os.path.join(
    os.path.dirname(csv_file),
    f"{folder_name}-metrics.json"
)

with open(json_file, "w") as f:
    json.dump(metrics, f, indent=2)

current_dir = Path(os.path.dirname(csv_file))
exports_dir = current_dir.parent


current_metrics = Path(json_file)
current_dir = Path(os.path.dirname(csv_file))
exports_dir = current_dir.parent

matching_metrics = []

for p in exports_dir.glob("*/*-metrics.json"):
    if p == current_metrics:
        continue

    try:
        with open(p) as f:
            data = json.load(f)

        if data.get("site") == site and data.get("crawl_type") == crawl_type:
            matching_metrics.append(p)

    except Exception:
        pass

matching_metrics.sort(key=lambda p: p.stat().st_mtime)

previous_metrics = matching_metrics[-1] if matching_metrics else None

previous_data = {}

if previous_metrics:
    with open(previous_metrics) as f:
        previous_data = json.load(f)

    out()
    out(f"Previous metrics: {previous_metrics}")


out()
out(f"https://{site} - {report_date}")
out("=" * 35)
out(f"Total Addresses: {delta('total', total, previous_data)}")
out(f"Indexable: {delta('indexable', indexable, previous_data)}")
out(f"Non-Indexable: {delta('non_indexable', non_indexable, previous_data)}")
out(f"Internal 301s: {delta('internal_301', internal_301, previous_data)}")
if internal_404 == 0:
    out("No internal 404s")
else:
    out(f"Internal 404s: {delta('internal_404', internal_404, previous_data)}")
if internal_404_urls:
    out()
    out("Internal 404 URLs")
    out("-----------------")

    for row in internal_404_urls:
        url = row["url"]

        out(f"- {url}")

        for source in sorted(set(internal_404_sources.get(url, []))):
            out(f"    linked from: {source}")

out(f"Missing Meta Description: {delta('missing_meta', missing_meta, previous_data)}")
out(f"Missing H1: {delta('missing_h1', missing_h1, previous_data)}")
out(f"Multiple H1: {delta('multiple_h1', multiple_h1, previous_data)}")

import os

external_404_file = os.path.join(
    os.path.dirname(csv_file),
    "response_codes_external_client_error_(4xx).csv"
)

external_inlinks_file = os.path.join(
    os.path.dirname(csv_file),
    "external_client_error_(4xx)_inlinks.csv"
)

internal_inlinks_file = os.path.join(
    os.path.dirname(csv_file),
    "internal_client_error_(4xx)_inlinks.csv"
)

if os.path.exists(internal_inlinks_file):
    with open(internal_inlinks_file, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):

            if row["Status Code"] != "404":
                continue

            dest = row["Destination"]
            src = row["Source"]

            internal_404_sources.setdefault(dest, []).append(src)

if os.path.exists(external_inlinks_file):
    with open(external_inlinks_file, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):

            if row["Status Code"] != "404":
                continue

            dest = row["Destination"]
            src = row["Source"]
            anchor = row.get("Anchor", "").strip()

            external_404_sources.setdefault(dest, []).append({
                "source": src,
                "anchor": anchor,
            })

if os.path.exists(external_404_file):
    with open(external_404_file, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):

            if row["Status Code"] != "404":
                continue

            external_404 += 1

            external_404_urls.append({
                "url": row["Address"],
                "inlinks": row["Inlinks"]
            })

out(f"Empty Sections: {delta('empty_sections', empty_sections, previous_data)}")
if external_404 == 0:
    out("No external 404s")
else:
    out(f"External 404s: {delta('external_404', external_404, previous_data)}")
if external_404_urls:
    out()
    out("External 404 URLs")
    out("-----------------")

    for row in external_404_urls[:10]:
        url = row["url"]

        out(f"- {url}")

        seen = set()

        for item in external_404_sources.get(url, []):
            source = item["source"]
            anchor = item["anchor"]

            key = (source, anchor)
            if key in seen:
                continue
            seen.add(key)

            if anchor:
                out(f"    linked from: {source} | anchor: {anchor}")
            else:
                out(f"    linked from: {source}")


report_file = os.path.join(
    os.path.dirname(csv_file),
    f"{folder_name}-report.txt"
)

with open(report_file, "w", encoding="utf-8") as f:
    f.write(report.getvalue())

out()
out(f"Report saved: {report_file}")


