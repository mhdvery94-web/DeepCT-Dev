"""
GPU-side client for the platform's managed training system.

Paste this into a Kaggle (or Colab) notebook cell, set the three values under
CONFIG, and run it. It claims a queued training job from the platform, fetches
the dataset, trains, and reports back.

WHAT THIS FILE IS AND IS NOT
----------------------------
It is the *protocol client*: claim, heartbeat, checkpoint, complete, fail. That
half is the platform's business and is finished.

It is **not** the training loop. `train_one_epoch()` below is a stub that
raises. Filling it in is research work — the discriminator architecture, the
loss, the augmentation — and writing it here from guesswork would produce a
model nobody could defend. Everything around it works today, so the researcher
only has to supply that one function.

WHY IT IS SHAPED LIKE THIS
--------------------------
A Kaggle session lasts 9-12 hours. Training takes days. So the session dying is
the *normal* course of events, not an error:

  - The worker checkpoints every CHECKPOINT_EVERY epochs. When the session
    dies, at most that many epochs are lost.
  - It heartbeats while it trains. The platform reclaims a job whose worker has
    been silent for 15 minutes and puts it back in the queue with the
    checkpoint intact.
  - On the next run, this same script claims that job again and resumes from
    the epoch the checkpoint reached.

Run it in a fresh session whenever the old one expires. That is the whole
operating procedure.
"""

import io
import os
import threading
import time
import zipfile

import requests

# ==========================================================================
# CONFIG
# ==========================================================================

# The platform's API root, including /api. Through the ngrok tunnel while the
# backend runs on a laptop; the real host once it is deployed.
API_BASE = os.environ.get("BRIN_API_BASE", "https://nucleus-drone-grueling.ngrok-free.dev/api")

# Generate with `php artisan training:token` on the server, put it in the
# server's .env as TRAINING_WORKER_TOKEN, and paste the same value here.
# Keep it out of any notebook you share.
WORKER_TOKEN = os.environ.get("BRIN_WORKER_TOKEN", "")

# Shown in the admin console so someone can tell two GPUs apart.
WORKER_LABEL = os.environ.get("BRIN_WORKER_LABEL", "kaggle-t4")

WORK_DIR = "/kaggle/working/brin-training"
CHECKPOINT_EVERY = 5      # epochs
HEARTBEAT_SECONDS = 60
POLL_SECONDS = 30         # how often to ask for work when the queue is empty

SESSION = requests.Session()
SESSION.headers.update({
    "Authorization": f"Bearer {WORKER_TOKEN}",
    "Accept": "application/json",
    # Without this ngrok serves its HTML interstitial instead of the API.
    "ngrok-skip-browser-warning": "true",
})


# ==========================================================================
# Protocol
# ==========================================================================

def claim():
    """Take the oldest queued job, or None when there is nothing to do."""
    response = SESSION.post(
        f"{API_BASE}/training/worker/claim",
        json={"worker_label": WORKER_LABEL},
        timeout=30,
    )
    response.raise_for_status()
    return response.json().get("data")


def fetch_dataset(job):
    """
    Put the dataset on local disk and return the directory it lives in.

    Two sources, because they solve different problems. A `url` dataset is
    fetched straight from wherever it lives — the right answer for anything
    large, since the platform may be a laptop behind a home connection. An
    `upload` dataset is pulled from the platform itself.
    """
    dataset = job["dataset"]
    target = os.path.join(WORK_DIR, f"dataset-{dataset['id']}")

    if os.path.isdir(target) and os.listdir(target):
        print(f"[dataset] already present at {target}")
        return target

    os.makedirs(target, exist_ok=True)

    if dataset["source_type"] == "url":
        url, headers = dataset["source_url"], {}
        print(f"[dataset] fetching {url}")
    else:
        url = f"{API_BASE}{dataset['download_path']}"
        headers = dict(SESSION.headers)
        print("[dataset] downloading from the platform")

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


def heartbeat(job_id, state):
    """
    Report liveness on a timer while training runs.

    Also the cancel channel: the platform answers `continue: false` when an
    administrator has stopped the job, and burning six more hours of GPU on
    work nobody wants is the failure this prevents.
    """
    while not state["stop"].is_set():
        try:
            response = SESSION.post(
                f"{API_BASE}/training/worker/jobs/{job_id}/heartbeat",
                json={
                    "current_epoch": state["epoch"],
                    "metrics": state["metrics"],
                },
                timeout=30,
            )
            body = response.json()

            if not body.get("data", {}).get("continue", True):
                print(f"[heartbeat] platform says stop: {body.get('message')}")
                state["cancelled"] = True
                state["stop"].set()
                return
        except Exception as error:                       # noqa: BLE001
            # A dropped heartbeat is not fatal; the reclaim window is 15
            # minutes and the next beat is a minute away.
            print(f"[heartbeat] failed, will retry: {error}")

        state["stop"].wait(HEARTBEAT_SECONDS)


def send_checkpoint(job_id, epoch, weights_path, metrics):
    with open(weights_path, "rb") as handle:
        response = SESSION.post(
            f"{API_BASE}/training/worker/jobs/{job_id}/checkpoint",
            data={
                "current_epoch": str(epoch),
                **{f"metrics[{k}]": str(v) for k, v in (metrics or {}).items()},
            },
            files={"weights": (os.path.basename(weights_path), handle)},
            timeout=600,
        )
    response.raise_for_status()
    print(f"[checkpoint] epoch {epoch} stored")


def send_complete(job_id, weights_path, metrics):
    with open(weights_path, "rb") as handle:
        response = SESSION.post(
            f"{API_BASE}/training/worker/jobs/{job_id}/complete",
            data={f"metrics[{k}]": str(v) for k, v in (metrics or {}).items()},
            files={"weights": (os.path.basename(weights_path), handle)},
            timeout=900,
        )
    response.raise_for_status()
    print("[complete] final weights delivered")


def send_failure(job_id, message):
    try:
        SESSION.post(
            f"{API_BASE}/training/worker/jobs/{job_id}/fail",
            json={"message": str(message)[:2000]},
            timeout=30,
        )
    except Exception as error:                           # noqa: BLE001
        # If we cannot even report the failure, the reclaim sweep will pick the
        # job up as stale, which is the safer of the two outcomes anyway.
        print(f"[fail] could not report: {error}")


# ==========================================================================
# The research half — yours to write
# ==========================================================================

def train_one_epoch(job, dataset_dir, epoch, checkpoint_path):
    """
    Train for a single epoch and return (weights_path, metrics).

    `checkpoint_path` is the previous epoch's weights, or None on the first
    epoch of a fresh job. Load from it to resume.

    Deliberately unimplemented: the notebook in `models-ai/` contains inference
    code only. The generator is a 25.6M-parameter GAN whose discriminator is
    not in this repository, and the loss, augmentation and balanced-t sampling
    are the entire point of the retraining exercise. Guessing at them here
    would produce numbers nobody could defend.

    Everything around this function already works — claim, resume, heartbeat,
    checkpoint, cancel, completion — so this is the only piece left.
    """
    raise NotImplementedError(
        "train_one_epoch() is the research half and has not been written yet. "
        "See AI_EXPERIMENTS.md and ARCHITECTURE.md 7."
    )


# ==========================================================================
# Runner
# ==========================================================================

def run_job(job):
    job_id = job["id"]
    total = job["total_epochs"]
    start_at = job.get("resume_from_epoch") or 0

    print(f"[job {job_id}] {job['name']}: epochs {start_at + 1}..{total}")
    if start_at:
        print(f"[job {job_id}] resuming from a checkpoint at epoch {start_at}")

    dataset_dir = fetch_dataset(job)

    state = {"epoch": start_at, "metrics": {}, "stop": threading.Event(), "cancelled": False}
    beat = threading.Thread(target=heartbeat, args=(job_id, state), daemon=True)
    beat.start()

    checkpoint_path = None

    try:
        for epoch in range(start_at + 1, total + 1):
            if state["cancelled"]:
                print(f"[job {job_id}] cancelled; stopping")
                return

            checkpoint_path, metrics = train_one_epoch(
                job, dataset_dir, epoch, checkpoint_path
            )

            state["epoch"] = epoch
            state["metrics"] = metrics or {}

            if epoch % CHECKPOINT_EVERY == 0 and epoch != total:
                send_checkpoint(job_id, epoch, checkpoint_path, metrics)

        send_complete(job_id, checkpoint_path, state["metrics"])

    except Exception as error:                           # noqa: BLE001
        print(f"[job {job_id}] failed: {error}")
        send_failure(job_id, error)
        raise
    finally:
        state["stop"].set()
        beat.join(timeout=5)


def main():
    if not WORKER_TOKEN:
        raise SystemExit(
            "Set BRIN_WORKER_TOKEN. Generate one on the server with "
            "`php artisan training:token`."
        )

    os.makedirs(WORK_DIR, exist_ok=True)
    print(f"[worker] {WORKER_LABEL} polling {API_BASE}")

    while True:
        try:
            job = claim()
        except Exception as error:                       # noqa: BLE001
            print(f"[worker] cannot reach the platform: {error}")
            time.sleep(POLL_SECONDS)
            continue

        if not job:
            print(f"[worker] nothing queued; waiting {POLL_SECONDS}s")
            time.sleep(POLL_SECONDS)
            continue

        try:
            run_job(job)
        except NotImplementedError as error:
            # Stop rather than spin: the job has been marked failed, and
            # claiming the next one would fail identically.
            raise SystemExit(str(error))
        except Exception:                                # noqa: BLE001
            # Already reported; take the next job.
            time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
