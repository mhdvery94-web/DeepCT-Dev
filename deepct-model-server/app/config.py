import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    models_root: Path
    activation_file: Path
    inference_token: str = field(repr=False)
    management_token: str = field(repr=False)
    max_upload_bytes: int = 32 * 1024 * 1024

    def __post_init__(self):
        for token in (self.inference_token, self.management_token):
            if not token or not token.isascii() or token != token.strip() or any(c.isspace() for c in token):
                raise ValueError('Both service bearer credentials must be configured')
        if self.inference_token == self.management_token:
            raise ValueError('Inference and management credentials must differ')
        if self.max_upload_bytes <= 0:
            raise ValueError('Invalid upload limit')

    @classmethod
    def from_env(cls):
        return cls(
            models_root=Path(os.environ.get('DEEPCT_MODELS_ROOT', './deepct-models')),
            activation_file=Path(os.environ.get('DEEPCT_ACTIVATION_FILE', './deepct-state/activation.json')),
            inference_token=os.environ.get('DEEPCT_INFERENCE_TOKEN', ''),
            management_token=os.environ.get('DEEPCT_MANAGEMENT_TOKEN', ''),
        )
