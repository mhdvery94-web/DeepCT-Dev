"""
Training endpoint for the GPU host — the push half of the training system.

This is the counterpart to the inference server you already run: a FastAPI app
in a Kaggle/Colab notebook, exposed over a tunnel, whose URL you register in
the platform. Where the inference server exposes `POST /predict`, this exposes
`POST /train`.

    Admin console  ──POST /train──►  this notebook  ──heartbeat/checkpoint──►  platform

Register the URL as TRAINING_TRAINER_URL on the server (or paste it into the
dispatch dialog), press "SEND TO TRAINER" on a queued job, and training starts.

WHY THE REPORTING HALF STILL MATTERS
------------------------------------
Pushing only solves *starting*. It does not change the fact that a Kaggle
session lasts 9-12 hours while training takes days. So this file still:

  - answers the POST immediately and trains on a background thread, because a
    request held open for a multi-day run would time out on any network;
  - heartbeats while it trains, so the platform can tell a live run from a dead
    one, and so a cancelled job stops instead of burning GPU hours;
  - checkpoints every few epochs, so a dead session costs epochs rather than
    days.

If the session dies, the platform returns the job to `queued` with its
checkpoint. Press "SEND TO TRAINER" again from a fresh notebook — or leave
`training_worker.py` polling — and it resumes from the epoch it reached.

WHAT IS NOT HERE
----------------
`train_one_epoch()` — the same stub as in `training_worker.py`, and deliberately
so. The discriminator is not in this repository, and the loss, augmentation and
balanced-t sampling are the point of the retraining exercise. Everything around
it is finished.
"""

import io
import os
import threading
import zipfile

import nest_asyncio
import requests
import uvicorn
from fastapi import BackgroundTasks, FastAPI
from pydantic import BaseModel

# Kaggle/Jupyter already own an event loop.
nest_asyncio.apply()

WORK_DIR = "/kaggle/working/brin-training"
CHECKPOINT_EVERY = 5
HEARTBEAT_SECONDS = 60

app = FastAPI(title="BRIN Neutron CT — training endpoint")

# One run at a time: a single GPU cannot train two jobs, and accepting a second
# would leave both slower and neither reportable.
_current = {"job_id": None, "stop": None}
_lock = threading.Lock()


# ==========================================================================
# What the platform sends
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


# ==========================================================================
# Reporting back — the same protocol a polling worker uses
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
        except Exception as error:                       # noqa: BLE001
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
# The research half — yours to write
# ==========================================================================

def train_one_epoch(request: TrainRequest, dataset_dir: str, epoch: int,
                    checkpoint_path: str | None):
    """
    Train one epoch; return (weights_path, metrics).

    `checkpoint_path` is the previous epoch's weights, or None on a fresh run.
    Load from it to resume — that is how a job carried over from a dead session
    continues instead of restarting.

    Left unimplemented on purpose. See the module docstring.
    """
    raise NotImplementedError(
        "train_one_epoch() is the research half and has not been written yet."
    )


# ==========================================================================
# The run
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

    except Exception as error:                           # noqa: BLE001
        print(f"[job {job_id}] failed: {error}")
        try:
            session.post(
                f"{base}/training/worker/jobs/{job_id}/fail",
                json={"message": str(error)[:2000]},
                timeout=30,
            )
        except Exception:                                # noqa: BLE001
            # Unreportable: the reclaim sweep will treat it as stale, which is
            # the safer of the two outcomes.
            pass
    finally:
        state["stop"].set()
        beat.join(timeout=5)
        with _lock:
            _current["job_id"] = None


# ==========================================================================
# Routes
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


if __name__ == "__main__":
    os.makedirs(WORK_DIR, exist_ok=True)

    # Expose it however you already expose the inference server, and register
    # the resulting public URL in the admin console.
    uvicorn.run(app, host="0.0.0.0", port=8080)
