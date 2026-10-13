"""Trusted operator GPU admission and bounded, owned compatibility process."""
import os
import subprocess
import sys

from fastapi import HTTPException


def gpu_free_bytes():
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=memory.free', '--format=csv,noheader,nounits', '--id=0'],
                                capture_output=True, text=True, timeout=5, check=True)
        value = result.stdout.strip()
        if not value.isdecimal():
            raise ValueError()
        return int(value) * 1024**2
    except (OSError, ValueError, subprocess.SubprocessError):
        raise HTTPException(503, 'GPU capacity unavailable') from None


class Compatibility:
    def __init__(self, registry, budget, address_budget=None):
        self.registry = registry
        self.budget = budget
        self.address_budget = address_budget

    def __call__(self, directory):
        if any(type(value) is not int or value <= 0 for value in (self.budget, self.address_budget)):
            raise HTTPException(503, 'GPU compatibility containment is not configured')
        if gpu_free_bytes() < self.budget:
            raise HTTPException(503, 'GPU capacity unavailable; compatibility remains untested')
        with self.registry.lock, self.registry.verified_snapshot(directory) as (_, snapshot):
            # Existing inference residency itself consumes VRAM; admission must
            # fit alongside it. Never terminate another process to obtain room.
            try:
                result = subprocess.run([sys.executable, '-m', 'app.compatibility_child', str(snapshot), str(self.budget), str(self.address_budget)],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                        timeout=60, check=False, env=os.environ.copy())
            except (OSError, subprocess.SubprocessError):
                raise HTTPException(503, 'GPU compatibility unavailable or timed out') from None
            if result.returncode != 0:
                raise HTTPException(503, 'GPU compatibility failed; model remains inactive')
