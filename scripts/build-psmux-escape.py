"""Build a pinned psmux Escape fix under .local; never install or select it."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_HASH = '4de52692b7f13f886d13b2d507df8fde36bfda80491eebf865d73ed416d571a3'
READER_HASH = 'd9b0392977f3c4db2e88044f07abb2d2d4d521d25e72c2293e6f2fd7bd19e9d5'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / '.local/psmux-escape-build')
    parser.add_argument('--cargo', default='cargo')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Native Windows build only')
    if hashlib.sha256(args.source_archive.read_bytes()).hexdigest() != ARCHIVE_HASH:
        parser.error('Expected official v3.3.8 source archive SHA256; no output created')
    output = args.output.resolve()
    if not output.is_relative_to((ROOT / '.local').resolve()) or output.exists():
        parser.error('Output must be a new directory under this checkout .local')
    cargo = shutil.which(args.cargo)
    if not cargo:
        parser.error('Existing Cargo/Rust GNU toolchain required; nothing is installed automatically')
    with zipfile.ZipFile(args.source_archive) as archive:
        for entry in archive.infolist():
            if not (output / entry.filename).resolve().is_relative_to(output):
                parser.error('Archive path escapes output')
        archive.extractall(output)
    source = output / 'psmux-3.3.8'
    reader = source / 'src/ssh_input.rs'
    if hashlib.sha256(reader.read_bytes()).hexdigest() != READER_HASH:
        raise SystemExit('Unexpected reader source; nothing built')
    text = reader.read_text(encoding='utf-8')
    anchor = '                                key_vk_count += 1;\n'
    if text.count(anchor) != 1:
        raise SystemExit('Unexpected patch anchor; nothing built')
    patch = (
        '                                // Modifier-only events carry no key to emit.\n'
        '                                // Do not let them discard a preceding Escape.\n'
        '                                if matches!(key.virtual_key_code,\n'
        '                                    0x10 | 0x11 | 0x12 | 0xA0..=0xA5) {\n'
        '                                    continue;\n'
        '                                }\n'
    )
    reader.write_text(text.replace(anchor, anchor + patch), encoding='utf-8', newline='\n')
    env = os.environ.copy()
    env['CARGO_TARGET_DIR'] = str(output / 'target')
    env['CARGO_HOME'] = str(output / 'cargo-home')
    # A rustup proxy must fail rather than install the archive's requested tools.
    env['RUSTUP_AUTO_INSTALL'] = '0'
    subprocess.run([cargo, 'build', '--locked', '--release', '--bin', 'psmux',
                    '--target', 'x86_64-pc-windows-gnu'], cwd=source, env=env, check=True)
    binary = output / 'target/x86_64-pc-windows-gnu/release/psmux.exe'
    print('Built for isolated verification only:', binary)
    print('SHA256:', hashlib.sha256(binary.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
