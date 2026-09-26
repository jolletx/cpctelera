from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
SCRIPT = ROOT / "z80_timing_comments.py"


def test_inserts_timing_comments(tmp_path):
    instruction_csv = tmp_path / "Instruction.csv"
    substitution_csv = tmp_path / "subtitutions.csv"
    source = tmp_path / "input.asm"
    output = tmp_path / "output.asm"

    instruction_csv.write_text(
        "Instruction;Time\n"
        "ld r,r;1\n"
        "jr cc,d;2/3\n"
        "call cc,nn;3/5\n"
        "add a,r;1\n"
        "nop;1\n",
        encoding="utf-8",
    )
    substitution_csv.write_text(
        "input;linked;type\n"
        "r;a,b,c,d,e,h,l;8bit register\n"
        "cc;nz,z,nc,c,po,pe,p,m;condition\n",
        encoding="utf-8",
    )
    source.write_text(
        "    ld      a,e                     ;; comment\n"
        "    jr      z,loop                 ;; jump\n"
        "    call    nz,target              ;; call\n"
        "    add     a,b                    ;; add\n"
        "    nop                            ;; done\n",
        encoding="utf-8",
    )

    subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--instruction-csv",
            str(instruction_csv),
            "--substitutions-csv",
            str(substitution_csv),
            "--input",
            str(source),
            "--output",
            str(output),
        ],
        check=True,
    )

    result = output.read_text(encoding="utf-8")
    assert ";; [1] comment" in result
    assert ";; [2/3] jump" in result
    assert ";; [3/5] call" in result
    assert ";; [1] add" in result
    assert ";; [1] done" in result


def test_accepts_byte_selection_immediates(tmp_path):
    instruction_csv = tmp_path / "Instruction.csv"
    substitution_csv = tmp_path / "subtitutions.csv"
    source = tmp_path / "input.asm"
    output = tmp_path / "output.asm"

    instruction_csv.write_text(
        "Instruction;Time\n"
        "ld a,n;2\n",
        encoding="utf-8",
    )
    substitution_csv.write_text(
        "input;linked;type\n",
        encoding="utf-8",
    )
    source.write_text(
        "    ld a,<#0x12\n"
        "    ld a,>#0x12\n",
        encoding="utf-8",
    )

    subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--instruction-csv",
            str(instruction_csv),
            "--substitutions-csv",
            str(substitution_csv),
            "--input",
            str(source),
            "--output",
            str(output),
        ],
        check=True,
    )

    result = output.read_text(encoding="utf-8")
    assert ";; [2]" in result
