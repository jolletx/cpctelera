#!/usr/bin/env python3
"""Annotate Z80 assembly lines with their execution cycle count.

The script reads the instruction catalogue in Instruction.csv and the placeholder
substitutions in subtitutions.csv, then matches each source instruction against
those templates and inserts the cycle time at the start of the assembly comment.
"""

import argparse
import csv
import re
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

ROOT_DIR = Path(__file__).resolve().parent
DEFAULT_INSTRUCTION_CSV = ROOT_DIR / "Instruction.csv"
DEFAULT_SUBSTITUTIONS_CSV = ROOT_DIR / "subtitutions.csv"

NUMBER_TOKEN_PATTERN = r"(?:[<>])?(?:#)?(?:[A-Za-z_][A-Za-z0-9_]*(?:\s*[+-]\s*(?:[A-Za-z_][A-Za-z0-9_]*|[+-]?\d+|0x[0-9A-Fa-f]+|%[01]+|\$[0-9A-Fa-f]+))?|[+-]?\d+|0x[0-9A-Fa-f]+|%[01]+|\$[0-9A-Fa-f]+)"

PLACEHOLDER_DEFAULTS: Dict[str, List[str]] = {
    "r": ["a", "b", "c", "d", "e", "h", "l"],
    "s": ["ixh", "ixl", "iyh", "iyl"],
    "pp": ["bc", "de", "hl", "sp","af"],
    "qq": ["ix", "iy"],
    "d": ["d"],
    "n": ["n"],
    "nn": ["nn"],
    "b": ["b"],
    "cc": ["nz", "z", "nc", "c", "po", "pe", "p", "m"],
}


def read_csv_rows(path: Path) -> List[Dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        return list(reader)


def build_substitution_map(path: Path) -> Dict[str, List[str]]:
    substitution_map: Dict[str, List[str]] = {}
    for row in read_csv_rows(path):
        key = (row.get("input") or "").strip()
        if not key:
            continue
        values = [item.strip() for item in (row.get("linked") or "").split(",") if item.strip()]
        if not values:
            continue
        substitution_map[key] = values

    for key, values in PLACEHOLDER_DEFAULTS.items():
        substitution_map.setdefault(key, values)
    return substitution_map


def template_to_regex(template: str, substitution_map: Dict[str, List[str]]) -> str:
    text = template.strip()
    text = re.sub(r"\s+", " ", text)

    tokens = ["cc", "qq", "pp", "s", "r", "nn", "n", "d", "b"]
    token_markers = {}
    for token in tokens:
        marker = "__TOKEN_{}__".format(token)
        token_markers[marker] = token
        pattern = r"(?<![A-Za-z0-9_]){}(?![A-Za-z0-9_])".format(re.escape(token))
        text = re.sub(pattern, marker, text)

    escaped = re.escape(text)
    for marker, token in token_markers.items():
        pattern = {
            "r": r"(?:a|b|c|d|e|h|l)",
            "s": r"(?:ixh|ixl|iyh|iyl)",
            "pp": r"(?:bc|de|hl|sp|af)",
            "qq": r"(?:ix|iy)",
            "d": NUMBER_TOKEN_PATTERN,
            "n": NUMBER_TOKEN_PATTERN,
            "nn": NUMBER_TOKEN_PATTERN,
            "b": r"(?:[0-7]|b)",
            "cc": r"(?:nz|z|nc|c|po|pe|p|m)",
        }[token]
        escaped = escaped.replace(re.escape(marker), pattern)

    escaped = escaped.replace(r"\ ", r"\s+")
    escaped = escaped.replace(r"\,", r"\s*,\s*")
    return r"^" + escaped + r"$"


def expand_template(template: str, substitution_map: Dict[str, List[str]]) -> Set[str]:
    tokens = sorted(
        {token for token in substitution_map if re.search(rf"\b{re.escape(token)}\b", template)},
        key=len,
        reverse=True,
    )

    results: Set[str] = {template}
    for token in tokens:
        next_results: Set[str] = set()
        for candidate in results:
            if token not in candidate:
                next_results.add(candidate)
                continue
            for option in substitution_map.get(token, [token]):
                next_results.add(candidate.replace(token, option))
        results = next_results
    return results


def build_instruction_dictionary(
    instruction_path: Path,
    substitutions_path: Path,
) -> Tuple[Dict[str, str], List[Tuple[str, str]]]:
    substitution_map = build_substitution_map(substitutions_path)

    template_map: Dict[str, str] = {}
    regex_entries: List[Tuple[str, str]] = []
    for row in read_csv_rows(instruction_path):
        template = (row.get("Instruction") or "").strip()
        time_value = (row.get("Time") or "").strip()
        if not template or not time_value:
            continue

        template_map[template.lower()] = time_value
        regex_entries.append((template_to_regex(template, substitution_map), time_value))

    return template_map, regex_entries


DIRECTIVE_PREFIXES = (".", "#")
DIRECTIVE_NAMES = {
    "db", "dw", "ds", "defb", "defw", "defs", "equ", "set", "org", "include",
    "incbin", "macro", "endm", "end", "ifdef", "ifndef", "if", "else", "endif",
    "public", "extern", "global", "globl", "module", "section", "align",
}


def strip_assembly_code(line: str) -> Optional[str]:
    line = line.rstrip("\r\n")
    if not line.strip():
        return None
    line = line.split(";", 1)[0]
    line = line.strip()
    if not line:
        return None
    if re.match(r"^\.[A-Za-z_][A-Za-z0-9_]*\b", line):
        return None
    if line.startswith(DIRECTIVE_PREFIXES):
        return None
    if ":" in line:
        before, _, after = line.partition(":")
        before = before.strip()
        if before and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", before):
            line = after.strip()
    line = line.strip()
    if not line:
        return None
    first_token = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)", line)
    if first_token and first_token.group(1).lower() in DIRECTIVE_NAMES:
        return None
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s*=\s*", line):
        return None
    return line


def collect_macro_names(lines: Sequence[str]) -> Set[str]:
    names: Set[str] = set()
    for line in lines:
        text = line.split(";", 1)[0].strip()
        match = re.match(r"^\.macro\s+([A-Za-z_][A-Za-z0-9_]*)\b", text, flags=re.IGNORECASE)
        if match:
            names.add(match.group(1).lower())
    return names


def match_instruction_time(code: str, regex_entries: Sequence[Tuple[str, str]]) -> Optional[str]:
    normalized = re.sub(r"\s+", " ", code).strip().lower()
    for regex_text, time_value in regex_entries:
        if re.fullmatch(regex_text, normalized, flags=re.IGNORECASE):
            return time_value
    return None


def infer_generic_time(code: str) -> Optional[str]:
    normalized = re.sub(r"\s+", " ", code).strip().lower()
    match = re.match(r"^([a-z_][a-z0-9_]*)\s*(.*)$", normalized)
    if not match:
        return None

    op, rest = match.groups()
    op = op.lower()
    rest = rest.strip()

    def is_immediate_value(value: str) -> bool:
        value = value.strip().lower()
        return value.startswith("#") or value.startswith("<#") or value.startswith(">#") or value.startswith("<") or value.startswith(">")

    if op == "ld" and "," in rest:
        lhs, rhs = [part.strip() for part in rest.split(",", 1)]
        lhs_norm = lhs.lower()
        rhs_norm = rhs.lower()
        reg_set = {"a", "b", "c", "d", "e", "h", "l", "ixh", "ixl", "iyh", "iyl"}
        if lhs_norm in reg_set and rhs_norm in reg_set:
            return "1"
        if lhs_norm in reg_set and is_immediate_value(rhs_norm):
            return "2"
        if lhs_norm in reg_set and rhs_norm.startswith("(") and "qq+d" in rhs_norm:
            return "5"
        if lhs_norm.startswith("(") and "qq+d" in lhs_norm and rhs_norm in reg_set:
            return "5"
        if lhs_norm in reg_set and rhs_norm.startswith("(") and rhs_norm in ("(hl)", "(bc)", "(de)"):
            return "2"
        if lhs_norm.startswith("(") and lhs_norm in ("(hl)", "(bc)", "(de)") and rhs_norm in reg_set:
            return "2"
        if lhs_norm.startswith("(") and lhs_norm.startswith("(hl)") and is_immediate_value(rhs_norm):
            return "3"
        if lhs_norm.startswith("(nn)") and rhs_norm in reg_set:
            return "4"
        if lhs_norm in {"hl", "bc", "de", "sp", "af"} and is_immediate_value(rhs_norm):
            return "3" if lhs_norm == "hl" else "6"
        if lhs_norm in {"hl", "bc", "de", "sp", "af"} and rhs_norm.startswith("("):
            return "5" if lhs_norm == "hl" else "6"

    if op in {"add", "adc", "sub", "sbc", "and", "xor", "or", "cp"} and "," in rest:
        lhs, rhs = [part.strip() for part in rest.split(",", 1)]
        lhs_norm = lhs.lower()
        rhs_norm = rhs.lower()
        if lhs_norm == "a" and rhs_norm.startswith("#"):
            return "2"
        if lhs_norm == "a" and rhs_norm in {"a", "b", "c", "d", "e", "h", "l", "ixh", "ixl", "iyh", "iyl"}:
            return "1"
        if lhs_norm == "a" and rhs_norm.startswith("(hl)"):
            return "2"
        if lhs_norm == "a" and "qq+d" in rhs_norm:
            return "5"

    if op in {"inc", "dec"}:
        operand = rest.lower()
        if operand in {"a", "b", "c", "d", "e", "h", "l", "ixh", "ixl", "iyh", "iyl"}:
            return "1"
        if operand in {"bc", "de", "hl", "sp", "af"}:
            return "2"
        if operand.startswith("(hl)"):
            return "3"
        if "qq+d" in operand:
            return "6"

    if op in {"add", "adc", "sub", "sbc", "and", "xor", "or", "cp"} and rest:
        operand = rest.lower()
        reg_set = {"a", "b", "c", "d", "e", "h", "l", "ixh", "ixl", "iyh", "iyl"}
        if operand in reg_set:
            return "1"
        if operand.startswith("#"):
            return "2"
        if operand.startswith("(") and operand in ("(hl)", "(bc)", "(de)"):
            return "2"
        if "qq+d" in operand:
            return "5"

    if op in {"rlc", "rrc", "rl", "rr", "sla", "sra", "sll", "srl"}:
        operand = rest.lower()
        if operand in {"a", "b", "c", "d", "e", "h", "l", "ixh", "ixl", "iyh", "iyl"}:
            return "2"
        if operand.startswith("(hl)"):
            return "4"
        if "qq+d" in operand:
            return "7"

    return None


def extract_existing_timing(line: str) -> Optional[Tuple[str, str]]:
    match = re.search(r";;\s*\[\s*([^\]]+)\s*\](.*)$", line)
    if not match:
        return None
    value = match.group(1).strip()
    suffix = match.group(2)
    return value, suffix


def inject_comment(line: str, time_value: str, update_existing: bool = False) -> Tuple[str, Optional[str], Optional[str]]:
    stripped = line.rstrip()
    timing = extract_existing_timing(stripped)
    if timing is not None:
        current_value, suffix = timing
        if not update_existing:
            return stripped, None, None
        if current_value == time_value:
            return stripped, None, None
        updated = re.sub(r";;\s*\[\s*[^\]]+\s*\]", ";; [{}]".format(time_value), stripped, count=1)
        return updated, current_value, time_value

    if ";;" in stripped:
        code_part, comment_part = stripped.split(";;", 1)
        text_before_comment = code_part.rstrip()
        spacing_before_comment = code_part[len(text_before_comment):]
        comment_text = comment_part.strip()
        if comment_text:
            return f"{text_before_comment}{spacing_before_comment};; [{time_value}] {comment_text}", None, None
        return f"{text_before_comment}{spacing_before_comment};; [{time_value}]", None, None
    return f"{stripped} ;; [{time_value}]", None, None


def process_file(source_path: Path, output_path: Path, instruction_csv: Path, substitutions_csv: Path, update_existing: bool = False) -> int:
    _, regex_entries = build_instruction_dictionary(instruction_csv, substitutions_csv)
    changed = 0
    output_lines: List[str] = []
    source_lines = source_path.read_text(encoding="utf-8").splitlines()
    macro_names = collect_macro_names(source_lines)

    for line_number, original_line in enumerate(source_lines, start=1):
        code = strip_assembly_code(original_line)
        if code is None:
            output_lines.append(original_line)
            continue

        first_token = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)", code)
        if first_token and first_token.group(1).lower() in macro_names:
            output_lines.append(original_line)
            continue

        time_value = match_instruction_time(code, regex_entries)
        if time_value is None:
            time_value = infer_generic_time(code)
        if time_value is None:
            first_word = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)", code)
            if first_word:
                raise SystemExit(
                    "Error: unrecognized Z80 instruction on line {}: {}\n"
                    "Check the mnemonic and operand form against Instruction.csv.\n"
                    "Examples: 'ld a,#0x12', 'jr z,label', 'call nz,target'".format(
                        line_number, code
                    )
                )
            output_lines.append(original_line)
            continue

        new_line, old_value, new_value = inject_comment(original_line, time_value, update_existing=update_existing)
        if old_value is not None and new_value is not None and old_value != new_value:
            print("Line {}: [{}] -> [{}]".format(line_number, old_value, new_value))
            changed += 1
        elif old_value is None and new_value is None and new_line != original_line:
            changed += 1
        output_lines.append(new_line)

    output_path.write_text("\n".join(output_lines) + "\n", encoding="utf-8")
    return changed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Insert Z80 cycle-count comments into an assembly source file.")
    parser.add_argument("--input", type=Path, required=True, help="Source file to annotate.")
    parser.add_argument("--output", type=Path, help="Destination file. Defaults to the input file in-place.")
    parser.add_argument("--instruction-csv", type=Path, default=DEFAULT_INSTRUCTION_CSV, help="CSV containing instruction templates and cycle times.")
    parser.add_argument("--substitutions-csv", type=Path, default=DEFAULT_SUBSTITUTIONS_CSV, help="CSV containing the placeholder substitutions.")
    parser.add_argument("--update-existing", action="store_true", help="Re-check and replace existing timing comments when a value is already present; prints line numbers with before/after values to stdout.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source_path = args.input
    if not source_path.exists():
        raise FileNotFoundError(f"Input file was not found: {source_path}")

    if args.output is None:
        destination = source_path
    else:
        destination = args.output
        destination.parent.mkdir(parents=True, exist_ok=True)

    changed = process_file(source_path, destination, args.instruction_csv, args.substitutions_csv, update_existing=args.update_existing)
    print(f"Updated {changed} instruction lines in {destination}")


if __name__ == "__main__":
    main()
