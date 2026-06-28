#!/usr/bin/env python3
import os
import sys

REPLACEMENTS = [
    (r', cluster=\"$cluster\"', ''),
    (r'cluster=\"$cluster\"', ''),
    (r'{, job=\"$job\"}', r'{job=\"$job\"}'),
    (r'{,mode=\"idle\"}', r'{mode=\"idle\"}'),

    (r'image!=\"\"', ''),

    (
        'sum(increase(kube_pod_container_status_restarts_total{}[$__rate_interval])) by (namespace) > 0',
        'sum(increase(kube_pod_container_status_restarts_total{}[$__range])) by (namespace)'
    ),
    (
        'sum(increase(container_oom_events_total{}[$__rate_interval])) by (namespace) > 0',
        'sum(increase(container_oom_events_total{}[$__range])) by (namespace)'
    )
]

def main():
    input_path = input("Enter the path to the original dashboard JSON file: ").strip()
    if not os.path.isfile(input_path):
        print(f"Error: File '{input_path}' not found.", file=sys.stderr)
        sys.exit(1)
    if not input_path.lower().endswith('.json'):
        print("Error: The file must have a .json extension.", file=sys.stderr)
        sys.exit(1)

    output_path = input("Enter the name/path for the updated JSON file: ").strip()

    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read().replace('\r\n', '\n')

    print("Processing replacements...")
    for find_str, replace_str in REPLACEMENTS:
        content = content.replace(find_str, replace_str)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Done! Updated JSON saved to: {output_path}")

if __name__ == '__main__':
    main()
