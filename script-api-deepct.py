import os
import io
import hmac
from glob import glob
import numpy as np
import tensorflow as tf
from PIL import Image
import tifffile
import uvicorn
import asyncio
import nest_asyncio
from pyngrok import ngrok
from fastapi import Depends, FastAPI, Header, HTTPException, UploadFile, File, Form
from fastapi.responses import Response

# ==========================================================================
# 0. Menerapkan Nest Asyncio (Wajib untuk Kaggle/Jupyter)
# ==========================================================================
nest_asyncio.apply()

# ==========================================================================
# 1. Registrasi Custom Keras Layers
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
    "TimeLast": TimeLast
}

# ==========================================================================
# 2. Inisialisasi API dan Muat Model
# ==========================================================================
app = FastAPI()

# --------------------------------------------------------------------------
# Bobotnya dicari, bukan dituliskan.
#
# Kaggle menyusun path model yang dilampirkan dari slug, framework dan versi
# yang dipilih saat melampirkannya. `deepct-ai/tensorflow2/default/1`,
# `deepct-unet/keras/v1/1` dan `train-deepct/tensorflow2/version-1/1` adalah
# berkas yang sama pada tiga saat berbeda — melampirkan ulang model menulis
# ulang path-nya karena alasan yang tidak ada hubungannya dengan kode ini.
#
# Tiga salinan proyek ini membawa tiga path berbeda dan dua di antaranya salah.
# Path yang salah menyebabkan `[Errno 2] No such file or directory` sebelum
# inference tersedia. Temukan bobot dari lampiran model sesi saat ini.
# --------------------------------------------------------------------------
MODEL_SEARCH_ROOT = os.environ.get("MODEL_SEARCH_ROOT", "/kaggle/input")


def find_base_model() -> str | None:
    """Bobot generator di bawah /kaggle/input, atau None kalau tidak ada.

    `BASE_MODEL_PATH` tetap menang bila diisi: jawaban eksplisit mengalahkan
    pencarian, dan itulah jalan keluar untuk susunan yang tidak bisa ditebak
    fungsi ini. Diisi tapi tidak ada berarti galat, bukan kembali mencari —
    diam-diam melewati path yang diketik seseorang berarti memuat bobot yang
    bukan pilihan mereka.
    """
    declared = os.environ.get("BASE_MODEL_PATH", "").strip()
    if declared:
        if not os.path.exists(declared):
            raise RuntimeError(
                f"BASE_MODEL_PATH diisi {declared}, dan berkas itu tidak ada."
            )
        return declared

    found = sorted(
        glob(os.path.join(MODEL_SEARCH_ROOT, "**", "*.h5"), recursive=True)
        + glob(os.path.join(MODEL_SEARCH_ROOT, "**", "*.keras"), recursive=True)
    )
    if not found:
        return None

    # Dahulukan berkas bernama `generator`. Sebuah folder checkpoint bisa juga
    # memuat discriminator, dan memuat yang itu menghasilkan model yang jalan
    # dan mengembalikan omong kosong — hasil terburuk dari ketiganya, karena
    # tidak ada yang melempar.
    named = [p for p in found if "generator" in os.path.basename(p).lower()]
    return (named or found)[0]


print("Mencari bobot model di Kaggle Input...")
# --------------------------------------------------------------------------
# Kredensial ngrok — dan kenapa dua notebook tidak boleh berbagi satu.
#
# Satu akun ngrok gratis punya satu domain reserved, dan `ngrok.connect()`
# tanpa nama domain mengambil domain itu. Jadi notebook kedua yang menyala
# ditolak dengan **ERR_NGROK_334 "endpoint is already online"** — bukan karena
# kodenya salah, melainkan karena keduanya memakai kredensial yang sama.
#
# Ini pernah tidak terlihat karena notebook prediksi menempelkan token akun
# *lain* langsung di sel. Itu menyelesaikan bentrokannya secara kebetulan, dan
# membayar dengan kredensial polos di dalam kode.
#
# Urutannya: variabel lingkungan menang (itu yang dipakai sel pembuka
# notebook), lalu secret milik notebook ini sendiri, baru secret bersama.
# --------------------------------------------------------------------------
PREFERRED_NGROK_SECRET = "ngrok-predict"
SHARED_NGROK_SECRET = "ngrok-endpoint"


def resolve_ngrok_token(get_secret) -> str:
    """Kredensial ngrok untuk notebook ini.

    `get_secret` adalah `UserSecretsClient().get_secret` — dioper masuk supaya
    pemilihannya bisa diperiksa tanpa Kaggle.
    """
    from_env = os.environ.get("NGROK_AUTHTOKEN", "").strip()
    if from_env:
        return from_env

    for name in (PREFERRED_NGROK_SECRET, SHARED_NGROK_SECRET):
        try:
            value = (get_secret(name) or "").strip()
        except Exception:                                 # noqa: BLE001
            # Secret yang tidak ada melempar; itu keadaan biasa, bukan galat.
            continue
        if value:
            print(f"[ngrok] memakai Kaggle secret '{name}'")
            return value

    raise RuntimeError(
        "Tidak ada kredensial ngrok. Setel NGROK_AUTHTOKEN, atau buat Kaggle "
        f"secret '{PREFERRED_NGROK_SECRET}' (khusus notebook ini) atau "
        f"'{SHARED_NGROK_SECRET}' (dipakai bersama)."
    )


def explain_tunnel_failure(error) -> str | None:
    """Kalimat untuk ERR_NGROK_334, atau None kalau bukan itu masalahnya.

    pyngrok melempar bentrokan domain sebagai HTTP 502 dengan empat puluh baris
    traceback, dan satu-satunya bagian yang bisa ditindaklanjuti terkubur di
    dalam JSON di baris terakhir.
    """
    text = str(error)
    if "ERR_NGROK_334" not in text and "already online" not in text:
        return None

    return (
        "ERR_NGROK_334: domain ngrok akun ini sudah dipakai notebook "
        "lain yang sedang menyala. Satu akun gratis hanya punya satu "
        "domain, yang mungkin sedang dipakai notebook lain. "
        "Pilih satu: (a) buat Kaggle secret "
        f"'{PREFERRED_NGROK_SECRET}' berisi authtoken ngrok dari akun "
        "kedua, lalu jalankan ulang sel ini; atau (b) hentikan "
        "notebook satunya lebih dulu."
    )


model_path = find_base_model()

if not model_path:
    raise RuntimeError(
        "Tidak ada *.h5 atau *.keras di bawah "
        f"{MODEL_SEARCH_ROOT}. Lampirkan modelnya lewat panel Kaggle "
        "(Add Input -> Models), atau isi BASE_MODEL_PATH. Tanpa bobot, "
        "endpoint ini tidak punya apa pun untuk dilayani."
    )

print(f"Memuat {model_path}")
generator = tf.keras.models.load_model(model_path, custom_objects=custom_objects, compile=False)
print("✅ Model berhasil dimuat!")

GLOBAL_MIN = 0.0
GLOBAL_MAX = 65535.0

# ==========================================================================
# 2b. Rahasia bersama
#
#     Platform mengirim `Authorization: Bearer <token>` pada setiap panggilan
#     ke worker (lihat `App\Services\WorkerRequest`). Sampai berkas ini
#     memeriksanya, pengiriman itu tidak menahan apa pun.
#
#     Di Kaggle di balik terowongan bernama acak, ketiadaan pemeriksaan adalah
#     keamanan lewat ketidaktahuan — dan ia bertahan, karena tidak ada yang
#     menebak nama terowongannya. Begitu GPU pindah ke workstation dengan
#     alamat tetap di jaringan lab, ia tidak menahan apa-apa: siapa pun di
#     jaringan itu bisa memakai GPU-nya.
#
#     Kosong berarti terbuka, dan itu default-nya supaya tidak ada yang rusak
#     hari ini. Isi lewat Kaggle Secrets, lalu isi nilai yang sama di
#     Admin → Model Management → SHARED SECRET.
#
#         os.environ["WORKER_TOKEN"] = UserSecretsClient().get_secret("WORKER_TOKEN")
# ==========================================================================
WORKER_TOKEN = os.environ.get("WORKER_TOKEN", "").strip()


def require_token(authorization: str | None = Header(default=None)) -> None:
    """Menolak panggilan tanpa rahasia yang benar, kalau rahasianya diatur."""
    if not WORKER_TOKEN:
        return

    # compare_digest, bukan `==`: perbandingan string biasa berhenti pada byte
    # pertama yang berbeda, dan selisih waktunya bisa dipakai menebak token
    # karakter demi karakter.
    if not authorization or not hmac.compare_digest(
        authorization.strip(), f"Bearer {WORKER_TOKEN}"
    ):
        raise HTTPException(status_code=401, detail="Worker token tidak valid.")


if WORKER_TOKEN:
    print("🔒 Endpoint dilindungi rahasia bersama.")
else:
    print("⚠️  WORKER_TOKEN kosong — endpoint terbuka untuk siapa pun yang tahu URL-nya.")

# ==========================================================================
# 2c. Health check
#
#     Platform memeriksa akar terowongan setiap sepuluh detik lewat GET, bukan
#     POST /predict — sebuah probe tidak boleh membangunkan GPU. Sebelum route
#     ini ada, FastAPI menjawab 404 dan pemeriksanya memang menerima itu
#     sebagai "hidup", tapi log notebook jadi penuh 404 yang terlihat seperti
#     kesalahan padahal bukan.
#
#     Sengaja dibiarkan terbuka: ia tidak memulai apa pun, dan bisa memeriksa
#     terowongan dari peramban tanpa menempelkan kredensial ke bilah alamat
#     lebih berharga daripada menyembunyikan keberadaannya. `protected`
#     menjawab "rahasianya sudah berlaku atau belum" dalam satu lirikan.
# ==========================================================================
@app.get("/")
def root():
    return {
        "service": "brin-inference",
        "model_loaded": generator is not None,
        "protected": bool(WORKER_TOKEN),
        # Bobot mana yang benar-benar ditemukan sesi ini. Satu lirikan dari
        # peramban menjawab pertanyaan yang selama ini hanya bisa dijawab
        # dengan membaca log notebook.
        "base_model": model_path,
    }


# ==========================================================================
# 3. Endpoint Prediksi (output .tiff)
#
#     Satu-satunya yang dipanggil platform. `/predict_png` dan `/generate_gif`
#     pernah ada di sini dan dibuang: PNG pratinjau dirender Laravel sendiri di
#     `App\Services\TiffPreview` (PHP murni, tanpa ekstensi imaging), dan GIF
#     digantikan penampil stack di dalam aplikasi yang bisa di-scrub seperti
#     ImageJ. Keduanya tidak pernah dipanggil siapa pun, dan endpoint yang
#     tidak dipanggil hanya menambah permukaan yang harus dijaga.
# ==========================================================================
@app.post("/predict", dependencies=[Depends(require_token)])
async def predict_images(
    file_t0: UploadFile = File(...),
    file_t2: UploadFile = File(...),
    time_scalar: float = Form(...) 
):
    print(f"\n==================================================")
    print(f"📥 [INFO] Menerima request interpolasi (TIFF)...")
    print(f"⏱️  [INFO] Target Frame (time_scalar) : {time_scalar:.3f}")

    async def process_upload(file_upload):
        image_bytes = await file_upload.read()
        img = Image.open(io.BytesIO(image_bytes)).convert("I")
        img = img.resize((1024, 1024))
        return np.array(img, dtype=np.float32)

    try:
        arr_t0 = await process_upload(file_t0)
        arr_t2 = await process_upload(file_t2)

        input_seq = np.stack([arr_t0, arr_t2], axis=0)
        input_seq = np.expand_dims(input_seq, axis=-1)
        input_seq = 2.0 * (input_seq - GLOBAL_MIN) / (GLOBAL_MAX - GLOBAL_MIN) - 1.0

        input_pair = input_seq[np.newaxis, ...]
        time_scalar_arr = np.array([[time_scalar]], dtype=np.float32)

        print(f"🚀 [INFO] Memulai inferensi AI di GPU Kaggle...")
        pred = generator.predict([input_pair, time_scalar_arr], verbose=0)[0, :, :, 0]

        pred_denorm = (pred + 1.0) / 2.0 * (GLOBAL_MAX - GLOBAL_MIN) + GLOBAL_MIN
        pred_16bit = np.clip(pred_denorm, 0, 65535).astype(np.uint16)

        out_io = io.BytesIO()
        tifffile.imwrite(out_io, pred_16bit)
        out_io.seek(0)

        print(f"✅ [SUKSES] Frame berhasil dibuat dan dikirim (TIFF)!")
        print(f"==================================================\n")

        return Response(content=out_io.read(), media_type="image/tiff")

    except Exception as e:
        print(f"❌ [ERROR] Proses gagal: {str(e)}")
        return {"error": str(e)}

# ==========================================================================
# 4. Menjalankan Ngrok & Server
# ==========================================================================
from kaggle_secrets import UserSecretsClient

PORT = 8000

ngrok.set_auth_token(resolve_ngrok_token(UserSecretsClient().get_secret))

# Tutup tunnel lama kalau sel ini dijalankan ulang. Ini hanya mematikan agen
# ngrok di notebook ini — ia tidak bisa melepaskan domain yang dipegang
# notebook lain, yang justru penyebab ERR_NGROK_334.
ngrok.kill()

# `NGROK_DOMAIN` menyematkan domain reserved bila memang punya satu untuk
# notebook ini; tanpa itu ngrok yang memilihkan.
tunnel_options = {"addr": PORT, "proto": "http"}
_domain = os.environ.get("NGROK_DOMAIN", "").strip()
if _domain:
    tunnel_options["domain"] = _domain

try:
    tunnel = ngrok.connect(**tunnel_options)
except Exception as error:                                # noqa: BLE001
    _said = explain_tunnel_failure(error)
    if _said:
        # pyngrok melempar ini sebagai HTTP 502 dengan empat puluh baris
        # traceback; satu-satunya bagian yang bisa ditindaklanjuti terkubur
        # di JSON baris terakhir.
        raise RuntimeError(_said) from error
    raise

public_url = tunnel.public_url

print("=" * 60)
print("URL API ANDA:")
print(f"- [PREDIKSI TIF] : {public_url}/predict")
print(f"  Daftarkan URL lengkap di atas (dengan /predict) di Admin -> Model Management.")
print("=" * 60)

# Menjalankan server pada event loop notebook Kaggle
config = uvicorn.Config(
    app=app,
    host="0.0.0.0",
    port=PORT,
    log_level="info",
)

server = uvicorn.Server(config)
await server.serve()
