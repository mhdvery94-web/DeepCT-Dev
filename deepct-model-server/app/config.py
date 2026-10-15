import os
from dataclasses import dataclass, field
from pathlib import Path


def optional_budget(name):
    try:
        value = int(os.environ.get(name, ''))
        return value if 0 < value <= 2**63 - 1 else None
    except ValueError:
        return None


@dataclass(frozen=True)
class Settings:
    models_root: Path
    activation_file: Path
    inference_token: str = field(repr=False)
    management_token: str = field(repr=False)
    upload_origins: tuple[str, ...] = ()
    compatibility_gpu_bytes: int | None = None
    compatibility_address_bytes: int | None = None
    max_upload_bytes: int = 32 * 1024 * 1024
    gpu_lease_path: Path | None = None
    assistant_token: str = field(default='', repr=False)
    legacy_inference_token: str = field(default='', repr=False)
    legacy_proxy_enabled: bool = False
    assistant_gpu_bytes: int | None = None
    assistant_timeout_seconds: float = 180
    assistant_cleanup_seconds: float = 10
    assistant_metadata_mode: bool = False

    def __post_init__(self):
        for token in (self.inference_token, self.management_token):
            if not token or not token.isascii() or token != token.strip() or any(c.isspace() for c in token):
                raise ValueError('Both service bearer credentials must be configured')
        if self.inference_token == self.management_token:
            raise ValueError('Inference and management credentials must differ')
        if self.legacy_inference_token and (not self.legacy_inference_token.isascii()
                or any(c.isspace() for c in self.legacy_inference_token)):
            raise ValueError('Invalid legacy inference credential')
        if self.assistant_token:
            if (not self.assistant_token.isascii() or self.assistant_token != self.assistant_token.strip()
                    or any(c.isspace() for c in self.assistant_token)
                    or self.assistant_token in (self.inference_token, self.management_token, self.legacy_inference_token)):
                raise ValueError('Assistant credential must be separate and valid')
        if self.assistant_timeout_seconds <= 0 or self.assistant_cleanup_seconds <= 0:
            raise ValueError('Invalid assistant time limit')
        if self.max_upload_bytes <= 0:
            raise ValueError('Invalid upload limit')

    @classmethod
    def from_env(cls):
        return cls(
            gpu_lease_path=Path(os.environ['DEEPCT_GPU_LEASE_PATH']) if os.environ.get('DEEPCT_GPU_LEASE_PATH') else None,
            assistant_token=os.environ.get('DEEPCT_ASSISTANT_TOKEN', ''),
            assistant_metadata_mode=os.environ.get('DEEPCT_ASSISTANT_METADATA_MODE', '').lower() == 'true',
            legacy_inference_token=os.environ.get('DEEPCT_LEGACY_INFERENCE_TOKEN', ''),
            assistant_gpu_bytes=optional_budget('DEEPCT_ASSISTANT_GPU_BYTES'),
            assistant_timeout_seconds=optional_budget('DEEPCT_ASSISTANT_TIMEOUT_SECONDS') or 180,
            assistant_cleanup_seconds=optional_budget('DEEPCT_ASSISTANT_CLEANUP_SECONDS') or 10,
            legacy_proxy_enabled=os.environ.get('DEEPCT_LEGACY_PROXY_ENABLED', '').lower() == 'true',
            upload_origins=tuple(filter(None, os.environ.get('DEEPCT_UPLOAD_ORIGINS', '').split(','))),
            compatibility_gpu_bytes=optional_budget('DEEPCT_COMPATIBILITY_GPU_BYTES'),
            compatibility_address_bytes=optional_budget('DEEPCT_COMPATIBILITY_ADDRESS_BYTES'),
            models_root=Path(os.environ.get('DEEPCT_MODELS_ROOT', './deepct-models')),
            activation_file=Path(os.environ.get('DEEPCT_ACTIVATION_FILE', './deepct-state/activation.json')),
            inference_token=os.environ.get('DEEPCT_INFERENCE_TOKEN', ''),
            management_token=os.environ.get('DEEPCT_MANAGEMENT_TOKEN', ''),
        )
