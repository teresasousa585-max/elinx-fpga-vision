"""Build deterministic CNN dataset manifests from filename labels.

The parent directory is deliberately not trusted: six verified digit-9 RAW
files currently live below ``new_capture/0``.  The filename is the dataset's
authoritative label contract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


FRAME_BYTES = 1280 * 720
NAME_RE = re.compile(
    r"^raw8_digit_(?P<label>[0-9])_"
    r"(?P<date>[0-9]{8})_(?P<time>[0-9]{6})_"
    r"(?P<millis>[0-9]{3})_(?P<sequence>[0-9]{4})\.raw$"
)


@dataclass(frozen=True)
class Sample:
    label: int
    path: Path
    relative_path: str
    sha256: str

    @property
    def name(self) -> str:
        return self.path.stem


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def collect_samples(workspace: Path, dataset: Path) -> list[Sample]:
    samples: list[Sample] = []
    errors: list[str] = []
    for path in sorted(dataset.rglob("*.raw"), key=lambda item: item.as_posix()):
        match = NAME_RE.fullmatch(path.name)
        if match is None:
            errors.append(f"invalid RAW filename: {path}")
            continue
        size = path.stat().st_size
        if size != FRAME_BYTES:
            errors.append(f"invalid RAW size {size}, expected {FRAME_BYTES}: {path}")
            continue
        try:
            relative = path.resolve().relative_to(workspace.resolve()).as_posix()
        except ValueError:
            errors.append(f"dataset path escapes workspace: {path}")
            continue
        samples.append(
            Sample(
                label=int(match.group("label")),
                path=path,
                relative_path=relative,
                sha256=file_sha256(path),
            )
        )

    duplicate_hashes = [
        digest for digest, count in Counter(item.sha256 for item in samples).items()
        if count > 1
    ]
    if duplicate_hashes:
        errors.append(f"duplicate RAW payload hashes: {', '.join(duplicate_hashes)}")
    if errors:
        raise ValueError("\n".join(errors))
    if not samples:
        raise ValueError(f"no complete RAW samples found below {dataset}")
    return samples


def manifest_text(samples: list[Sample]) -> str:
    return "".join(
        f"{sample.label} {sample.name} {sample.relative_path}\n"
        for sample in samples
    )


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    temporary.replace(path)


def main() -> int:
    workspace_default = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, default=workspace_default)
    parser.add_argument("--dataset", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=workspace_default / "sim/input/cnn/new_capture_manifest.txt",
    )
    parser.add_argument(
        "--smoke-output",
        type=Path,
        default=workspace_default / "sim/input/cnn/new_capture_smoke_manifest.txt",
    )
    parser.add_argument("--summary-output", type=Path)
    args = parser.parse_args()

    workspace = args.workspace.resolve()
    dataset = (args.dataset or workspace / "new_capture").resolve()
    samples = collect_samples(workspace, dataset)
    text = manifest_text(samples)
    write_atomic(args.output, text)

    first_by_label: dict[int, Sample] = {}
    for sample in samples:
        first_by_label.setdefault(sample.label, sample)
    missing = sorted(set(range(10)) - set(first_by_label))
    if missing:
        raise ValueError(f"dataset lacks labels required by smoke manifest: {missing}")
    smoke = [first_by_label[label] for label in range(10)]
    write_atomic(args.smoke_output, manifest_text(smoke))

    distribution = Counter(sample.label for sample in samples)
    misplaced = [
        sample.relative_path for sample in samples
        if sample.path.parent.name != str(sample.label)
    ]
    summary_path = args.summary_output or args.output.with_suffix(".json")
    summary = {
        "dataset": dataset.relative_to(workspace).as_posix(),
        "frame_bytes": FRAME_BYTES,
        "sample_count": len(samples),
        "label_distribution": {str(label): distribution[label] for label in range(10)},
        "misplaced_samples": misplaced,
        "manifest_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest().upper(),
        "smoke_count": len(smoke),
    }
    write_atomic(summary_path, json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
