#!/usr/bin/env python3
"""Compatibility entry point; brand geometry is shared with the SwiftUI app."""
from pathlib import Path
import subprocess

if __name__ == "__main__":
    project = Path(__file__).resolve().parent.parent
    subprocess.run(["bash", str(project / "Scripts/generate_brand_assets.sh")], check=True)
