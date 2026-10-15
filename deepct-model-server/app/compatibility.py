"""Trusted operator GPU admission and bounded, owned compatibility process."""
import os
import subprocess
import sys

from fastapi import HTTPException

from .gpu import GPULease, GPUUnavailable


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
        try:
            with self.registry.lock, GPULease(self.registry.gpu_lease_path) as lease:
                return self._run(directory, lease)
        except GPUUnavailable:
            raise HTTPException(503, 'GPU unavailable; compatibility remains untested') from None

    def _run(self, directory, lease):
        if gpu_free_bytes() < self.budget:
            raise HTTPException(503, 'GPU capacity unavailable; compatibility remains untested')
        with self.registry.lock, self.registry.verified_snapshot(directory) as (_, snapshot):
            # Existing inference residency itself consumes VRAM; admission must
            # fit alongside it. Never terminate another process to obtain room.
            # The child can outlive a killed parent, whose flock then disappears.
            # Persist before dispatch; exceptions/unknown child state stay poisoned.
            if lease.path is not None:
                lease.uncertain()
            try:
                result = subprocess.run([sys.executable, '-m', 'app.compatibility_child', str(snapshot), str(self.budget), str(self.address_budget)],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                        timeout=60, check=False, env=os.environ.copy())
            except (OSError, subprocess.SubprocessError):
                raise HTTPException(503, 'GPU compatibility unavailable or timed out') from None
            # run() returns only after reaping its child. A failed child is idle
            # too, but an exception or missing exit status does not prove that.
            if lease.path is not None and type(result.returncode) is int:
                lease.verified_idle()
            if result.returncode != 0:
                raise HTTPException(503, 'GPU compatibility failed; model remains inactive')
