"""Optional cross-process GPU admission; durable fail-closed residency state."""
import fcntl
import os
from pathlib import Path


class GPUUnavailable(RuntimeError):
    pass


class GPULease:
    def __init__(self, path=None):
        self.path = Path(path) if path else None
        self.fd = None

    def __enter__(self):
        if self.path is None:
            return self
        try:
            self.fd = os.open(self.path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if os.fstat(self.fd).st_size:
                raise GPUUnavailable()
        except (OSError, GPUUnavailable):
            self.__exit__(None, None, None)
            raise GPUUnavailable('GPU unavailable') from None
        return self

    def uncertain(self):
        if self.fd is None:
            raise GPUUnavailable('Shared GPU containment is not configured')
        os.pwrite(self.fd, b'unverified residency\n', 0)
        os.fsync(self.fd)

    def verified_idle(self):
        os.ftruncate(self.fd, 0)
        os.fsync(self.fd)

    def __exit__(self, *args):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None
