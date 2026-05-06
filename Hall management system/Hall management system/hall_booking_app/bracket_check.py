import re

path = r"c:\jassim\8th sem\Hall management system\Hall management system\hall_booking_app\lib\main.dart"

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

pairs = {'(': ')', '[': ']', '{': '}'}
openers = set(pairs.keys())
closers = set(pairs.values())
stack = []

in_single = False
in_double = False
in_triple_single = False
in_triple_double = False

for i, line in enumerate(lines, start=1):
    j = 0
    while j < len(line):
        c = line[j]
        # String state machine
        if in_triple_single:
            if line.startswith("'''", j):
                in_triple_single = False
                j += 3
                continue
            j += 1
            continue
        if in_triple_double:
            if line.startswith('"""', j):
                in_triple_double = False
                j += 3
                continue
            j += 1
            continue
        if in_single:
            if c == "'":
                in_single = False
            elif c == '\\':
                j += 1
            j += 1
            continue
        if in_double:
            if c == '"':
                in_double = False
            elif c == '\\':
                j += 1
            j += 1
            continue

        if line.startswith("'''", j):
            in_triple_single = True
            j += 3
            continue
        if line.startswith('"""', j):
            in_triple_double = True
            j += 3
            continue
        if c == "'":
            in_single = True
            j += 1
            continue
        if c == '"':
            in_double = True
            j += 1
            continue

        if c in openers:
            stack.append((c, i))
        elif c in closers:
            if not stack:
                print(f"Unmatched closer {c} at line {i}")
                stack.append((c, i))
                break
            last, last_line = stack.pop()
            if pairs[last] != c:
                print(f"Mismatched {last} (line {last_line}) closed by {c} at line {i}")
                print('Stack at mismatch:')
                for cc, cl in stack[-10:]:
                    print(f'  {cc} at line {cl}')
                break
        j += 1

if stack:
    print('Unmatched openers:')
    for c, line in stack[-20:]:
        print(f"  {c} at line {line}")
else:
    print('All brackets matched.')
