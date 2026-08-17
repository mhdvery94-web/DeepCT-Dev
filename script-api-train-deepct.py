"""
Training endpoint for the notebook — the twin of `script-api-deepct.py`.

Where the inference script exposes `POST /predict` over a tunnel and answers
with an interpolated TIFF, this one exposes `POST /train` and runs a training
job, reporting its progress back to the platform:

    Admin console ──POST /train──► this notebook ──heartbeat/checkpoint──► platform

Paste it into a Kaggle/Colab cell exactly like the inference script, copy the
printed URL into the admin console (Training → trainer URL), then press
"SEND TO TRAINER" on a queued job.

WHAT THIS TRAINS, AND WHAT IT DOES NOT
--------------------------------------
Read this before quoting any number it prints.

The reference notebook `models-ai/Evaluation_2_to_1_1kx1k_With_Logo.ipynb` is an
*evaluation* tool: it loads a folder of frames and generates the midpoint of
each consecutive pair. It contains no training code, no discriminator and no
loss. The original model is a GAN, and its discriminator is not in this
repository.

So what runs here is a **supervised fine-tune of the generator on an L1 pixel
loss** — the same layers, normalisation and geometry as the notebook, and a
loss that is derivable from the data alone. It is not the adversarial training
that produced the published weights, and results from it must not be reported
as though it were. See ROADMAP.md ("Belum dibangun, dan alasannya") and
AI_EXPERIMENTS.md.

What it *is* good for is the one thing the platform actually needs: the shipped
model was trained on a t-imbalanced dataset, which is why the platform
interpolates recursively at t=0.5 instead of asking for an arbitrary t. This
script samples t uniformly from the frame spacing available in the dataset
(`balanced_t`, on by default), which is precisely the experiment that would
make recursion unnecessary.

SETUP IN KAGGLE
---------------
The ngrok token is read from the environment — never paste it into this file,
it is a credential for the tunnel account and this file is committed.

    Add-ons → Secrets → add NGROK_AUTHTOKEN, then:

        import os
        from kaggle_secrets import UserSecretsClient
        os.environ["NGROK_AUTHTOKEN"] = UserSecretsClient().get_secret("NGROK_AUTHTOKEN")

    !pip install -q fastapi uvicorn nest_asyncio pyngrok tifffile

Then paste this file into the next cell and run `await serve()`.
"""

import io
import os
import random
import threading
import zipfile
from glob import glob

import numpy as np
import requests
import tensorflow as tf
from PIL import Image

import nest_asyncio
import uvicorn
from fastapi import BackgroundTasks, FastAPI
from pydantic import BaseModel

# Kaggle and Jupyter already own an event loop.
nest_asyncio.apply()

# ==========================================================================
# 1. Custom Keras layers — copied from the notebook, unchanged
#
#    The .h5 cannot be loaded without them, and they must stay byte-identical
#    to the notebook's: a redefined layer deserialises into a different model.
# ==========================================================================

@tf.keras.utils.register_keras_serializable(package="Custom")
class TimeMean(tf.keras.layers.Layer):
    def call(self, inputs):
        return tf.reduce_mean(inputs, axis=1)


@tf.keras.utils.register_keras_serializable(package="Custom")
class TimeLast(tf.keras.layers.Layer):
    def call(self, inputs):
        return inputs[:, -1, :, :, :]


@tf.keras.utils.register_keras_serializable(package="Custom")
class SkipFusion(tf.keras.layers.Layer):
    def __init__(self, filters=64, **kwargs):
        super().__init__(**kwargs)
        self.filters = filters
        self.conv = tf.keras.layers.Conv2D(filters, (1, 1), padding='same', activation='relu')

    def call(self, inputs):
        mean = tf.reduce_mean(inputs, axis=1)
        last = inputs[:, -1, :, :, :]
        fused = tf.concat([mean, last], axis=-1)
        return self.conv(fused)

    def get_config(self):
        config = super().get_config()
        config.update({"filters": self.filters})
        return config


custom_objects = {
    "SkipFusion": SkipFusion,
    "TimeMean": TimeMean,
    "TimeLast": TimeLast,
}

# ==========================================================================
# 2. Configuration
#
#    The image geometry and the normalisation window are the notebook's. They
#    are not tunable: the weights were trained against them, and changing one
#    silently produces a model that disagrees with the inference server.
# ==========================================================================

IMAGE_SIZE = (1024, 1024)
GLOBAL_MIN = 0.0
GLOBAL_MAX = 65535.0

BASE_MODEL_PATH = os.environ.get(
    "BASE_MODEL_PATH",
    "/kaggle/input/models/basiadyanna/deepct-unet/keras/v1/1/"
    "generator(Salinan 3 Ginet TC-D_Revisi).h5",
)
WORK_DIR = os.environ.get("WORK_DIR", "/kaggle/working/brin-training")
PORT = int(os.environ.get("PORT", "8080"))

CHECKPOINT_EVERY = 5
HEARTBEAT_SECONDS = 60

app = FastAPI(title="BRIN Neutron CT — training endpoint")

# One run at a time. A single GPU cannot train two jobs, and accepting a second
# would leave both slower and neither reportable.
_current = {"job_id": None}
_lock = threading.Lock()


# ==========================================================================
# 3. What the platform sends
# ==========================================================================

class Dataset(BaseModel):
    id: int | None = None
    name: str | None = None
    source_type: str = "url"
    source_url: str | None = None
    download_url: str | None = None
    checksum: str | None = None


class Callback(BaseModel):
    base_url: str
    worker_token: str
    heartbeat_seconds: int = 60


class TrainRequest(BaseModel):
    job_id: int
    name: str = ""
    total_epochs: int = 1
    resume_from_epoch: int = 0
    hyperparameters: dict = {}
    dataset: Dataset
    callback: Callback
    # Optional, and the platform does not send it today. Without it a resumed
    # job restarts from the base weights at the recorded epoch number, which is
    # worth knowing before reading a resumed run's loss curve.
    resume_checkpoint_url: str | None = None


# ==========================================================================
# 4. Data — frame triples built out of the dataset's own numbering
#
#    A dataset is a folder of numbered .tif frames, the same shape of thing a
#    researcher uploads for prediction. Every triple (i, i+m, i+gap) is a
#    training example: the model sees frames i and i+gap, is told t = m/gap,
#    and must produce frame i+m. The ground truth is a real frame, so no
#    labelling is needed and nothing about the loss has to be invented.
# ==========================================================================

def load_frame(path: str) -> np.ndarray:
    """One frame, exactly as the notebook loads it."""
    img = Image.open(path).convert("I").resize(IMAGE_SIZE)
    return np.array(img, dtype=np.float32)


def normalise(frame: np.ndarray) -> np.ndarray:
    return 2.0 * (frame - GLOBAL_MIN) / (GLOBAL_MAX - GLOBAL_MIN) - 1.0


def list_frames(dataset_dir: str) -> list[str]:
    paths = sorted(glob(os.path.join(dataset_dir, "**", "*.tif"), recursive=True))
    if len(paths) < 3:
        raise RuntimeError(
            f"{dataset_dir} holds {len(paths)} .tif frames; a triple needs at least 3."
        )
    return paths


def build_samples(frame_count: int, max_gap: int, balanced_t: bool):
    """
    Every (t0, target, t2, t) the dataset can supply.

    With `balanced_t` off this collapses to the midpoints only — t = 0.5, which
    is the distribution the shipped weights were trained on and the reason the
    platform has to interpolate recursively. On is the point of retraining.
    """
    samples = []
    for gap in range(2, max_gap + 1):
        for i in range(frame_count - gap):
            for m in range(1, gap):
                t = m / gap
                if balanced_t or abs(t - 0.5) < 1e-6:
                    samples.append((i, i + m, i + gap, t))
    if not samples:
        raise RuntimeError("No usable frame triples — is max_gap at least 2?")
    return samples


def batch_from(paths, samples, indices):
    pairs, times, targets = [], [], []
    for index in indices:
        i0, im, i2, t = samples[index]
        f0 = normalise(load_frame(paths[i0]))
        f2 = normalise(load_frame(paths[i2]))
        target = normalise(load_frame(paths[im]))

        pairs.append(np.stack([f0, f2], axis=0)[..., np.newaxis])
        times.append([t])
        targets.append(target[..., np.newaxis])

    return (
        tf.constant(np.stack(pairs), dtype=tf.float32),
        tf.constant(np.array(times), dtype=tf.float32),
        tf.constant(np.stack(targets), dtype=tf.float32),
    )


# ==========================================================================
# 5. The training step
#
#    L1 on the denormalised-to-[-1,1] frame, generator only. See the header:
#    there is no discriminator here and this is not the published method.
# ==========================================================================

_model = {"generator": None, "optimizer": None, "step": None}


def load_generator(path: str):
    print(f"[model] loading {path}")
    return tf.keras.models.load_model(path, custom_objects=custom_objects, compile=False)


def save_generator(generator, path: str) -> str:
    """
    Whole model, not just weights: the platform hands the file to whichever
    worker resumes the job, and that worker has no architecture to load into.
    """
    try:
        generator.save(path)
        return path
    except Exception as error:                            # noqa: BLE001
        # Some Keras 3 builds refuse the legacy .h5 container.
        fallback = path.replace(".h5", ".keras")
        print(f"[model] .h5 save failed ({error}); writing {fallback}")
        generator.save(fallback)
        return fallback


def prepare_model(learning_rate: float, checkpoint_path: str | None):
    if _model["generator"] is None:
        _model["generator"] = load_generator(checkpoint_path or BASE_MODEL_PATH)
        # beta_1=0.5 is the convention this family of image GANs is trained
        # with; it is a starting point, not a result.
        _model["optimizer"] = tf.keras.optimizers.Adam(
            learning_rate=learning_rate, beta_1=0.5
        )

        @tf.function
        def step(pair, time_scalar, target):
            with tf.GradientTape() as tape:
                prediction = _model["generator"]([pair, time_scalar], training=True)
                loss = tf.reduce_mean(tf.abs(prediction - target))
            gradients = tape.gradient(loss, _model["generator"].trainable_variables)
            _model["optimizer"].apply_gradients(
                zip(gradients, _model["generator"].trainable_variables)
            )
            psnr = tf.reduce_mean(
                tf.image.psnr((prediction + 1.0) / 2.0, (target + 1.0) / 2.0, max_val=1.0)
            )
            return loss, psnr

        _model["step"] = step

    return _model["generator"], _model["step"]


def train_one_epoch(request: TrainRequest, dataset_dir: str, epoch: int,
                    checkpoint_path: str | None):
    """Train one epoch; return (weights_path, metrics)."""
    hyper = request.hyperparameters or {}
    learning_rate = float(hyper.get("learning_rate", 1e-4))
    batch_size = int(hyper.get("batch_size", 1))
    max_gap = int(hyper.get("max_gap", 4))
    balanced_t = bool(hyper.get("balanced_t", True))
    steps_cap = int(hyper.get("steps_per_epoch", 0))

    generator, step = prepare_model(learning_rate, checkpoint_path)

    paths = list_frames(dataset_dir)
    samples = build_samples(len(paths), max_gap, balanced_t)

    order = list(range(len(samples)))
    random.shuffle(order)
    if steps_cap:
        order = order[: steps_cap * batch_size]

    losses, psnrs, batches = [], [], 0

    for start in range(0, len(order) - batch_size + 1, batch_size):
        pair, time_scalar, target = batch_from(
            paths, samples, order[start:start + batch_size]
        )
        loss, psnr = step(pair, time_scalar, target)

        losses.append(float(loss))
        psnrs.append(float(psnr))
        batches += 1

        if batches % 25 == 0:
            print(f"[epoch {epoch}] {batches} batches, l1={np.mean(losses):.5f}")

    metrics = {
        "loss": round(float(np.mean(losses)), 6),
        "psnr": round(float(np.mean(psnrs)), 4),
        "batches": batches,
        "samples": len(samples),
        "balanced_t": balanced_t,
    }
    print(f"[epoch {epoch}] done — {metrics}")

    os.makedirs(WORK_DIR, exist_ok=True)
    written = save_generator(
        generator, os.path.join(WORK_DIR, f"job-{request.job_id}-epoch-{epoch}.h5")
    )
    return written, metrics


# ==========================================================================
# 6. Reporting back — the protocol a polling worker uses, unchanged
# ==========================================================================

def session_for(callback: Callback) -> requests.Session:
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {callback.worker_token}",
        "Accept": "application/json",
        "ngrok-skip-browser-warning": "true",
    })
    return session


def fetch_dataset(session: requests.Session, dataset: Dataset) -> str:
    target = os.path.join(WORK_DIR, f"dataset-{dataset.id}")

    if os.path.isdir(target) and os.listdir(target):
        print(f"[dataset] already present at {target}")
        return target

    os.makedirs(target, exist_ok=True)

    if dataset.source_type == "url" and dataset.source_url:
        url, headers = dataset.source_url, {}
    else:
        url, headers = dataset.download_url, dict(session.headers)

    print(f"[dataset] fetching {url}")
    response = requests.get(url, headers=headers, stream=True, timeout=1800)
    response.raise_for_status()

    payload = io.BytesIO()
    for chunk in response.iter_content(chunk_size=1 << 20):
        payload.write(chunk)

    payload.seek(0)
    with zipfile.ZipFile(payload) as archive:
        archive.extractall(target)

    print(f"[dataset] extracted to {target}")
    return target


def fetch_checkpoint(session: requests.Session, url: str) -> str:
    os.makedirs(WORK_DIR, exist_ok=True)
    path = os.path.join(WORK_DIR, "resume.h5")
    print(f"[checkpoint] fetching {url}")
    response = session.get(url, stream=True, timeout=1800)
    response.raise_for_status()
    with open(path, "wb") as handle:
        for chunk in response.iter_content(chunk_size=1 << 20):
            handle.write(chunk)
    return path


def heartbeat_loop(session, callback, job_id, state):
    """Liveness, and the channel a cancellation comes back on."""
    while not state["stop"].is_set():
        try:
            response = session.post(
                f"{callback.base_url}/training/worker/jobs/{job_id}/heartbeat",
                json={"current_epoch": state["epoch"], "metrics": state["metrics"]},
                timeout=30,
            )
            body = response.json()

            if not body.get("data", {}).get("continue", True):
                print(f"[heartbeat] platform says stop: {body.get('message')}")
                state["cancelled"] = True
                state["stop"].set()
                return
        except Exception as error:                        # noqa: BLE001
            # A dropped beat is not fatal: the reclaim window is 15 minutes and
            # the next beat is a minute away.
            print(f"[heartbeat] failed, will retry: {error}")

        state["stop"].wait(callback.heartbeat_seconds or HEARTBEAT_SECONDS)


def send_file(session, url, path, fields):
    with open(path, "rb") as handle:
        response = session.post(
            url,
            data=fields,
            files={"weights": (os.path.basename(path), handle)},
            timeout=900,
        )
    response.raise_for_status()
    return response


# ==========================================================================
# 7. The run
# ==========================================================================

def run_training(request: TrainRequest):
    job_id = request.job_id
    session = session_for(request.callback)
    state = {
        "epoch": request.resume_from_epoch,
        "metrics": {},
        "stop": threading.Event(),
        "cancelled": False,
    }

    beat = threading.Thread(
        target=heartbeat_loop,
        args=(session, request.callback, job_id, state),
        daemon=True,
    )
    beat.start()

    checkpoint_path = None
    base = request.callback.base_url

    try:
        dataset_dir = fetch_dataset(session, request.dataset)

        if request.resume_checkpoint_url:
            checkpoint_path = fetch_checkpoint(session, request.resume_checkpoint_url)
        elif request.resume_from_epoch:
            print(
                f"[job {job_id}] resuming at epoch {request.resume_from_epoch} from the "
                "base weights — the platform sent no checkpoint to resume from."
            )

        for epoch in range(request.resume_from_epoch + 1, request.total_epochs + 1):
            if state["cancelled"]:
                print(f"[job {job_id}] cancelled; stopping at epoch {epoch - 1}")
                return

            checkpoint_path, metrics = train_one_epoch(
                request, dataset_dir, epoch, checkpoint_path
            )

            state["epoch"] = epoch
            state["metrics"] = metrics or {}

            if epoch % CHECKPOINT_EVERY == 0 and epoch != request.total_epochs:
                send_file(
                    session,
                    f"{base}/training/worker/jobs/{job_id}/checkpoint",
                    checkpoint_path,
                    {"current_epoch": str(epoch),
                     **{f"metrics[{k}]": str(v) for k, v in (metrics or {}).items()}},
                )
                print(f"[checkpoint] epoch {epoch} stored")

        send_file(
            session,
            f"{base}/training/worker/jobs/{job_id}/complete",
            checkpoint_path,
            {f"metrics[{k}]": str(v) for k, v in state["metrics"].items()},
        )
        print(f"[job {job_id}] complete")

    except Exception as error:                            # noqa: BLE001
        print(f"[job {job_id}] failed: {error}")
        try:
            session.post(
                f"{base}/training/worker/jobs/{job_id}/fail",
                json={"message": str(error)[:2000]},
                timeout=30,
            )
        except Exception:                                 # noqa: BLE001
            # Unreportable: the reclaim sweep will treat it as stale, which is
            # the safer of the two outcomes.
            pass
    finally:
        state["stop"].set()
        beat.join(timeout=5)
        with _lock:
            _current["job_id"] = None


# ==========================================================================
# 8. Routes
# ==========================================================================

@app.post("/train")
def start_training(request: TrainRequest, background: BackgroundTasks):
    """
    Accept a job and start it in the background.

    Answers immediately. A request held open for the length of a multi-day
    training would time out on any network, and the platform deliberately gives
    this call a short timeout for exactly that reason.
    """
    with _lock:
        if _current["job_id"] is not None:
            return {
                "accepted": False,
                "message": f"Already training job {_current['job_id']}.",
            }
        _current["job_id"] = request.job_id

    background.add_task(run_training, request)

    return {
        "accepted": True,
        "job_id": request.job_id,
        "message": "Training started. Progress is reported to the platform.",
    }


@app.get("/")
def root():
    """Also what the platform's health check probes."""
    return {
        "service": "brin-training",
        "busy": _current["job_id"] is not None,
        "job_id": _current["job_id"],
    }


# ==========================================================================
# 9. Tunnel and server
# ==========================================================================

def open_tunnel() -> str | None:
    token = os.environ.get("NGROK_AUTHTOKEN")
    if not token:
        print(
            "NGROK_AUTHTOKEN is not set — serving on localhost only.\n"
            "In Kaggle: Add-ons → Secrets, then copy it into os.environ."
        )
        return None

    from pyngrok import ngrok

    ngrok.set_auth_token(token)
    url = ngrok.connect(PORT).public_url

    print("=" * 60)
    print(f"TRAINER URL: {url}")
    print("Register this in the admin console as the trainer URL, then press")
    print("SEND TO TRAINER on a queued job.")
    print("=" * 60)
    return url


async def serve():
    """Run in a notebook cell:  await serve()"""
    os.makedirs(WORK_DIR, exist_ok=True)
    open_tunnel()
    server = uvicorn.Server(uvicorn.Config(app, host="0.0.0.0", port=PORT))
    await server.serve()


if __name__ == "__main__":
    os.makedirs(WORK_DIR, exist_ok=True)
    open_tunnel()
    uvicorn.run(app, host="0.0.0.0", port=PORT)
