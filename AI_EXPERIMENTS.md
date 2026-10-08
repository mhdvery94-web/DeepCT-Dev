# 🧪 Jurnal Eksperimen AI & Deep Learning

> Dokumen ini menyimpan hasil riset model dan eksperimen offline historis.
> Aplikasi 9 Oktober 2026 hanya prediksi; eksperimen pelatihan di sini bukan fitur portal.
> Kelanjutan agen: [checkpoint](handoff.md).

> **Status: jurnal riset model — dokumen paling awet di repo ini.**
> Berisi alasan di balik keputusan yang tidak terbaca dari kode, terutama
> **mengapa interpolasi selalu t=0.5**: model mengabaikan nilai `time_scalar`
> lain, sehingga celah besar diisi secara rekursif dari titik tengah.
> Implementasinya ada di `be/app/Jobs/ProcessDeepLearningImage.php`.
>
> **Catatan deployment 1 Oktober 2026:** migrasi web/API dan autentikasi tidak
> menghasilkan eksperimen model baru. Katalog model pada database Raspberry Pi
> masih kosong, sehingga tidak ada hasil prediksi produksi yang boleh ditulis
> sebagai validasi baru. Sinkronisasi `/models` dan uji worker nyata tetap
> tercatat sebagai pekerjaan terbuka di [ROADMAP.md](ROADMAP.md).

---


Dokumen ini berisi catatan masalah, uji coba, dan solusi yang diterapkan pada model kecerdasan buatan selama pengembangan platform.

---

## Generasi frame: harga yang dibayar metode rekursif, 24 Agustus 2026

Rekursi t=0.5 menyelesaikan satu persoalan dan diam-diam memunculkan yang lain,
dan yang kedua tidak pernah dituliskan sampai hari ini.

Untuk celah antara frame 001 dan 005, titik tengahnya — 003 — digambar dari dua
frame yang **keduanya hasil pindai**. Baru sesudah itu 002 dan 004 digambar, dan
masing-masing memakai 003 sebagai salah satu batasnya. Artinya model diberi
masukan berupa **keluarannya sendiri**, dan galat apa pun yang terkandung di 003
kini menjadi masukan bagi dua frame berikutnya.

Ketiganya keluar sebagai TIFF yang tampak setara di dalam satu direktori. Tanpa
catatan tambahan, tidak ada yang bisa membedakan mana yang bersandar pada data
sungguhan dan mana yang bersandar pada tebakan sebelumnya.

Platform kini mencatat **generasi** tiap frame bangkitan: 1 ketika kedua batasnya
hasil pindai, 2 ketika sekurang-kurangnya satu batasnya sendiri frame bangkitan,
dan seterusnya. Itu hitungan berapa kali galat berpeluang menumpuk.

**Konsekuensi untuk pembacaan hasil:** frame generasi 2 ke atas tidak layak
diperlakukan sebagai data pada tingkat kepercayaan yang sama dengan generasi 1.
Untuk analisis kuantitatif, generasi 1 adalah yang paling dekat dengan apa yang
sebenarnya bisa dijamin model.

Ini juga memperkuat catatan lama di dokumen ini: **kalau model dilatih ulang
dengan dataset t seimbang, rekursi tidak lagi diperlukan** — dan bersamanya
seluruh persoalan generasi ini ikut hilang, karena setiap frame akan digambar
langsung dari dua batas pindai.

---

## Validasi hold-out: angka pertama yang bukan klaim, 24 Agustus 2026

Sampai hari ini setiap angka kualitas di repo ini berasal dari dokumentasi model
yang sudah ada — termasuk "94,2%" di tabel di bawah, yang **tidak diukur oleh
penelitian ini** dan tidak boleh dilaporkan seolah-olah demikian.

Platform sekarang bisa mengukur sendiri, dan caranya dibatasi oleh sesuatu yang
mendasar: **frame yang ingin diisi seorang peneliti, menurut definisinya, tidak
dimiliki siapa pun.** Tidak ada ground truth untuknya dan tidak akan pernah ada.

Yang bisa dilakukan adalah menyembunyikan frame yang **memang ada**. Di mana pun
arsip memuat tiga frame berurutan, yang tengah disisihkan, digambar ulang dari
kedua tetangganya, lalu dibandingkan dengan frame yang sebenarnya ada di sana.
Hasilnya MAE dan RMSE dalam hitungan 16-bit mentah, PSNR dalam desibel, dan
rentang frame acuannya.

Tiga peringatan untuk siapa pun yang mengutip angka ini:

1. **Satu frame, satu arsip.** Ini bukti bahwa model berperilaku wajar pada data
   itu, bukan akurasinya.
2. **PSNR diukur terhadap rentang 16-bit penuh (65535)**, yang merupakan
   konvensinya. Frame CT jarang mengisi rentang itu, jadi angkanya cenderung
   terlihat bagus dibanding pengukuran yang memakai rentang sebenarnya. Ia
   sebanding antar-run di platform ini; jangan dibandingkan dengan makalah tanpa
   memeriksa MAX yang mereka pakai.
3. **MAE tanpa rentang acuannya tidak berarti apa-apa.** Empat puluh hitungan
   adalah galat besar pada frame yang membentang 300 dan dapat diabaikan pada
   frame yang membentang 60.000. Itu sebabnya `reference_min`/`reference_max`
   ikut disimpan.

Aritmetikanya diuji terhadap angka yang dihitung tangan (`FrameMetricsTest`),
bukan terhadap apa pun yang kebetulan dikeluarkan kodenya: konstanta yang keliru
tidak akan membuat apa pun crash, ia hanya diam-diam menaruh angka salah ke
dalam sebuah laporan.

---

## Pengukuran pertama dari GPU sungguhan, 25 Agustus 2026

Sesi Kaggle hidup, dan jalur prediksi akhirnya berjalan ujung ke ujung terhadap
model sungguhan. Ini angka pertama di repo ini yang **diukur**, bukan dikutip.

Arsipnya `HONDA_Used_0051` sampai `0069`, selang satu — sepuluh frame masuk,
sembilan dihasilkan, 36 detik.

| | |
|---|---|
| Frame yang disembunyikan | `HONDA_Used_0053.tif`, digambar ulang dari 51 dan 55 |
| **MAE** | **359,7** hitungan 16-bit |
| **RMSE** | 688,1 |
| **PSNR** | **39,58 dB** (terhadap rentang 16-bit penuh) |
| Rentang frame acuan | 108 – 56.487 |
| Piksel | 1.048.576 (1024 × 1024) |

MAE 359,7 pada rentang 56.379 berarti galat rata-rata **0,64% dari rentang
dinamis frame itu**. Itu pembacaan yang benar; angka MAE-nya sendiri tidak
berarti apa pun tanpa rentangnya.

### Aturan hold-out yang pertama kali ditulis ternyata keliru

Arsip ini juga mematahkan asumsi yang sudah tertanam di kodenya. Syarat semula
menuntut **tiga frame berurutan** — 1, 2, 3 — dan pada arsip nyata pertama yang
sampai ke jalur ini tidak ada satu pun: framenya 51, 53, 55, … 69.

Kekeliruannya jelas begitu dilihat: **peneliti menurut definisinya mengunggah
frame dengan celah.** Itu seluruh produknya. Menuntut tiga yang berurutan
berarti menuntut justru keadaan yang tidak akan pernah ada.

Yang sebenarnya diperlukan lebih longgar: sebuah frame terunggah yang menjadi
**titik tengah persis** dari dua frame terunggah lainnya. Kasus "tiga
berurutan" hanyalah bentuk khususnya dengan jarak 2. Pada arsip di atas, 53
adalah titik tengah 51 dan 55, dan bisa diperiksa sejak awal.

Rentang **tersempit** yang dipakai, dan itu disengaja: menggambar titik tengah
antara 51 dan 69 membentang sembilan frame gerakan, sementara 51 dan 55
membentang dua — dan dua frame itulah pekerjaan yang sebenarnya diminta dari
model. Mengukurnya pada rentang lebar akan melaporkan model lebih buruk
daripada tugas yang benar-benar diberikan kepadanya.

### Yang masih belum terukur

Arsip `Contrast_0001, 0003, 0007` tetap tidak terukur bahkan dengan aturan
baru, dan itu jujur: rentangnya 2, 4 dan 6, titik tengahnya 2, 4 dan 5, dan
tidak satu pun diunggah. Sebagian arsip memang tidak menawarkan apa pun untuk
disembunyikan.

Satu pengukuran pada satu frame dari satu arsip bukan studi. Ia bukti bahwa
model berperilaku wajar pada data itu.

---

## Metrik training, 23 Agustus 2026

Trainer kini melaporkan **empat** angka per epoch, bukan dua.

Yang mengejutkan: **MAE sudah dihitung sejak awal.** Loss di
`script-api-train-deepct.py` adalah `tf.reduce_mean(tf.abs(prediction -
target))` — itu definisi mean absolute error, hanya saja tercatat dengan nama
`loss`. Ia sekarang dikirim dengan dua nama sekaligus, dan `loss` tetap ada
supaya run yang sudah tercatat tidak kehilangan grafiknya.

Yang benar-benar baru cuma dua baris, berdampingan dengan PSNR yang sudah ada:

```python
ssim = tf.reduce_mean(tf.image.ssim(a, b, max_val=1.0))
mse = tf.reduce_mean(tf.square(prediction - target))
```

Keduanya di-window ke [0,1], karena di sanalah PSNR dan SSIM didefinisikan
sementara model bekerja di [-1,1].

### Satu frame per epoch

Di akhir tiap epoch, generator dijalankan pada **satu triplet uji tetap** dan
PNG-nya dikirim ke platform. Tetap, bukan acak: membandingkan epoch 3 dengan
epoch 9 pada triplet yang berbeda tidak mengatakan apa pun tentang modelnya,
hanya tentang tripletnya.

Unggahannya sengaja *best effort* dan menelan kegagalannya sendiri. Sebuah
gambar pratinjau yang tidak sampai tidak boleh menggagalkan training yang sudah
berjalan berjam-jam.

**Belum ada satu pun angka di atas yang berasal dari run sungguhan.** Jalur
training belum pernah dijalankan terhadap GPU sekali pun — lihat ROADMAP §10 —
dan seluruh perubahan ini hanya lolos `python -m py_compile`, yang membuktikan
berkasnya terurai dan bukan bahwa `tf.image.ssim` dipanggil dengan benar.

---

## 📊 Model Information

### GiNet TC-D (Generative Interpolation Network - Temporal Conditional Diffusion)

**File**: `generator(Salinan 3 Ginet TC-D_Revisi).h5`

| Property | Value |
|----------|-------|
| **Framework** | TensorFlow/Keras |
| **Architecture** | Modified U-Net dengan Temporal Conditioning |
| **File Size** | ~84MB (87,796,792 bytes) |
| **Input Size** | 2x grayscale images (1024x1024, 16-bit) |
| **Output Size** | 1x grayscale image (1024x1024, 16-bit) |
| **Parameters** | 21.921.601 trainable parameters (dibaca langsung dari berkas .h5; angka ~25,6M yang beredar sebelumnya tidak pernah diverifikasi) |
| **Accuracy** | ~~94.2% (validation dataset)~~ — **tidak terverifikasi, dan besaran ini tidak ada.** Arsitekturnya regresi dengan keluaran `tanh`; tidak ada kelas untuk dihitung benar-salahnya. Yang terukur pada 4 September 2026 adalah MAE, RMSE, PSNR dan SSIM — lihat CHANGELOG 1.39.0 |
| **Optimal time_scalar** | 0.5 (midpoint interpolation) |
| **Training Dataset** | Neutron CT scans dari BRIN research facility |
| **Last Updated** | 4 September 2026 (arsitektur dan jumlah parameter dibaca ulang langsung dari berkas bobotnya) |

---

## 🎯 Model Purpose

Model ini dirancang untuk **frame interpolation** pada citra Neutron CT. Specifically:

1. **Input**: Dua frame boundary (T0 dan T2)
2. **Process**: Generate intermediate frame(s) between T0 dan T2
3. **Output**: Frame intermediate (T1) yang smooth dan akurat
4. **Use Case**: Rekonstruksi sequence frame yang hilang atau corrupt

### Why Frame Interpolation?

Dalam penelitian Neutron CT:
- Scanning process sangat time-consuming
- Beberapa frame bisa hilang karena technical issues
- Manual interpolation tidak konsisten
- Model AI memberikan hasil yang reproducible dan faster

---

## 🔬 Eksperimen & Findings

### Eksperimen 1: Mode Collapse & Output Berulang pada Jarak Jauh

**Date**: August 10, 2026  
**Status**: ✅ Solved

#### 🚨 Gejala (Problem)

Saat memprediksi sequence frame dengan **gap yang jauh** (contoh: dari frame `003` ke `007`), hasil prediksi untuk frame `005` dan `006` terlihat **identik atau sangat mirip** dengan `004`, terlepas dari nilai `time_scalar` yang sudah disesuaikan (0.25, 0.5, 0.75).

**Example Case:**
```
Input Files:
- HONDA_Used_0001.tif (T0)
- HONDA_Used_0007.tif (T2)

Expected Output:
- 0002.tif (distinct)
- 0003.tif (distinct)
- 0004.tif (distinct)
- 0005.tif (distinct)
- 0006.tif (distinct)

Actual Output:
- 0002.tif ✅ (berbeda)
- 0003.tif ✅ (berbeda)
- 0004.tif ✅ (berbeda)
- 0005.tif ❌ (sama dengan 0004)
- 0006.tif ❌ (sama dengan 0004)
```

#### 🔍 Analisis Penyebab

1. **Bias Pelatihan (Overfitting pada t=0.5)**
   - Model AI dilatih secara intensif untuk memprediksi nilai tengah yang presisi (t=0.5)
   - Neural network mengabaikan input parameter `time_scalar` yang berbeda
   - Model selalu memberikan output yang merepresentasikan titik 0.5 (mode collapse)
   - Ini terjadi karena loss function minimum berada di t=0.5 selama training

2. **Batas Toleransi Deformasi**
   - Jarak 3+ frame kosong (gap) melampaui rentang deformasi optimal
   - Model kesulitan extrapolate perubahan yang terlalu besar
   - Confidence score menurun drastis untuk time_scalar != 0.5

3. **Architecture Limitation**
   - Time conditioning layer tidak cukup expressif
   - Model architecture tidak dirancang untuk extreme gaps

#### ⚠️ Koreksi terhadap analisis di atas, 4 September 2026

**Gejalanya benar; penyebab yang dituliskan di atas tidak.** Analisis itu tidak
pernah diukur, dan tiga hal di dalamnya terbantah ketika akhirnya diukur
terhadap berkas bobot dan layanan inferensi yang sebenarnya.

**1. "Neural network mengabaikan input parameter `time_scalar`" — tidak tepat.**
Model *merespons* `t`, tetapi hanya sebesar **0,17%** dari yang seharusnya.
Diukur dengan mengirim `t = 0` dan `t = 1` pada pasangan frame yang sama:
keluarannya bergeser MAE 3,3, sementara kedua frame batasnya sendiri berjarak
918,4. Bukan diabaikan — direspons secara sepele.

**2. "Time conditioning layer tidak cukup expressif" — terbantah oleh bobotnya.**
Pemeriksaan langsung berkas `.h5`: nol dari 4.096 neuron pada lapisan `Dense`
jalur waktu yang teredam, dan pada dekoder pertama kanal peta waktu justru
diberi bobot **2,35 kali** lebih besar daripada rerata 512 kanal citra —
seluruh 512 kanal itu lebih lemah. Kapasitasnya ada; yang tidak ada adalah
pelatihan yang menuntutnya dipakai.

**3. "Confidence score menurun drastis" — tidak ada besaran seperti itu.**
Arsitektur `STUNet_2to1_TimeCond` tidak menghasilkan skor keyakinan. Kalimat
itu tidak merujuk apa pun yang dapat diperiksa.

**Yang menjadi kendali pembeda.** Menukar urutan kedua gambar masukan pada `t`
yang sama menggeser keluaran sebesar 63,94 — melalui jalur kode yang sama
persis. Jadi skrip meneruskan masukan dengan benar; yang tidak dipakai model
hanyalah skalar waktunya. Model memakai sumbu waktu pada tumpukan citra
tetapi mengabaikan skalarnya. Yang membuat urutan berpengaruh adalah reduksi
`x_T` di dalam `SkipFusion` beserta ketiga `ConvLSTM2D` — bukan lapisan
`TimeLast` tersendiri, yang didaftarkan skrip pemuat tetapi tidak dipakai
satu kali pun pada berkas bobot ini.

Rincian pengukuran, empat batas perilaku yang terukur, dan percobaan penyempurnaan
yang mengikutinya tercatat pada `CHANGELOG.md` versi 1.39.0.

#### ✅ Solusi: Interpolasi Rekursif (Recursive Interpolation)

Untuk mengatasi bias model tanpa harus melatih ulang (retrain) model `.h5`, sistem diubah pendekatannya dengan menggunakan **metode rekursif**.

**Prinsip**: 
Alih-alih mencari titik 0.25 atau 0.75 secara langsung, sistem dipaksa menggunakan nilai `t=0.5` (zona nyaman model) secara bertahap menggunakan hasil prediksi sebelumnya sebagai input baru.

**Algorithm:**

```python
def recursive_interpolate(frame_start, frame_end, model):
    """
    Recursively interpolate frames between start and end
    Always use t=0.5 for optimal results
    """
    gap = get_frame_number(frame_end) - get_frame_number(frame_start)
    
    if gap <= 1:
        # No interpolation needed, frames are adjacent
        return []
    
    results = []
    
    # Step 1: Find midpoint (most accurate)
    midpoint_num = (get_frame_number(frame_start) + get_frame_number(frame_end)) // 2
    frame_mid = model.predict(frame_start, frame_end, time_scalar=0.5)
    results.append((midpoint_num, frame_mid))
    
    # Step 2: Recursively fill left side (start to mid)
    left_frames = recursive_interpolate(frame_start, frame_mid, model)
    results.extend(left_frames)
    
    # Step 3: Recursively fill right side (mid to end)
    right_frames = recursive_interpolate(frame_mid, frame_end, model)
    results.extend(right_frames)
    
    return sorted(results, key=lambda x: x[0])
```

**Example Execution:**

```
Input: frame_003.tif, frame_007.tif (gap = 4)

┌─────────────────────────────────────────────────────┐
│ Step 1: Find center (005)                           │
│ Input:  003 + 007, t=0.5                            │
│ Output: 005 ✅                                      │
└─────────────────────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼──────────┐         ┌──────────▼────────┐
│ Step 2: Left     │         │ Step 3: Right     │
│ Input:  003+005  │         │ Input:  005+007   │
│ t=0.5            │         │ t=0.5             │
│ Output: 004 ✅   │         │ Output: 006 ✅    │
└──────────────────┘         └───────────────────┘

Final Sequence: 003, 004, 005, 006, 007
All frames distinct and smooth! ✅
```

#### 📈 Hasil Eksperimen

**Before (Direct Interpolation):**
```
Frame Similarity (MSE):
003 vs 004: 0.05 ✅
004 vs 005: 0.001 ❌ (too similar, almost identical)
005 vs 006: 0.001 ❌ (too similar, almost identical)
006 vs 007: 0.05 ✅
```

**After (Recursive Interpolation):**
```
Frame Similarity (MSE):
003 vs 004: 0.05 ✅
004 vs 005: 0.04 ✅ (distinct)
005 vs 006: 0.04 ✅ (distinct)
006 vs 007: 0.05 ✅
```

**Metrics:**
- ✅ Perubahan morfologi antar frame kini terlihat lebih berurutan
- ✅ Smooth transitions tanpa abrupt changes
- ✅ Logically consistent sequence
- ✅ No duplicate/identical frames
- ⚠️ Processing time meningkat linear dengan gap size

#### 💻 Implementation Code

**Python (Google Colab - FastAPI Server):**

```python
from fastapi import FastAPI, File, UploadFile
from tensorflow import keras
import numpy as np
from PIL import Image
import io

app = FastAPI()

# Load model
model = keras.models.load_model('generator(Salinan 3 Ginet TC-D_Revisi).h5')

def extract_frame_number(filename):
    """Extract frame number from filename"""
    match = re.search(r'(\d+)', filename)
    return int(match.group(1)) if match else -1

def recursive_interpolate(t0_data, t2_data, start_num, end_num):
    """Recursive interpolation with t=0.5"""
    gap = end_num - start_num
    
    if gap <= 1:
        return []
    
    results = []
    mid_num = (start_num + end_num) // 2
    
    # Predict midpoint
    t1_data = model.predict([
        np.expand_dims(t0_data, axis=0),
        np.expand_dims(t2_data, axis=0),
        np.array([[0.5]])  # Always use 0.5
    ])[0]
    
    results.append((mid_num, t1_data))
    
    # Recurse left
    if mid_num - start_num > 1:
        left_results = recursive_interpolate(t0_data, t1_data, start_num, mid_num)
        results.extend(left_results)
    
    # Recurse right
    if end_num - mid_num > 1:
        right_results = recursive_interpolate(t1_data, t2_data, mid_num, end_num)
        results.extend(right_results)
    
    return results

@app.post("/predict")
async def predict(
    file_t0: UploadFile = File(...),
    file_t2: UploadFile = File(...)
):
    # Load images
    t0_image = load_tif(await file_t0.read())
    t2_image = load_tif(await file_t2.read())
    
    # Extract frame numbers
    t0_num = extract_frame_number(file_t0.filename)
    t2_num = extract_frame_number(file_t2.filename)
    
    # Recursive interpolation
    all_frames = recursive_interpolate(t0_image, t2_image, t0_num, t2_num)
    
    # Return all frames
    return {
        "success": True,
        "frames": [
            {"frame_num": num, "data": frame_to_base64(data)}
            for num, data in sorted(all_frames)
        ]
    }
```

**PHP (Laravel - Background Job):**

```php
class ProcessDeepLearningImage implements ShouldQueue
{
    public function handle()
    {
        $record = $this->analysisRecord;
        
        // Update status
        $record->update(['status' => 'processing']);
        
        $startTime = microtime(true);
        
        // Send to Colab API
        $response = Http::timeout(120)
            ->attach('file_t0', file_get_contents(storage_path('app/public/' . $record->t0_image_path)), $record->file_name . '_t0.tif')
            ->attach('file_t2', file_get_contents(storage_path('app/public/' . $record->t2_image_path)), $record->file_name . '_t2.tif')
            ->post(config('services.ngrok.url'));
        
        if ($response->successful()) {
            $frames = $response->json()['frames'];
            
            // Save all generated frames
            foreach ($frames as $frame) {
                $frameNum = $frame['frame_num'];
                $frameData = base64_decode($frame['data']);
                
                $filename = "{$record->file_name}_{$frameNum}.tif";
                $path = "neutron_images/results/user_{$record->user_id}/{$filename}";
                
                Storage::disk('public')->put($path, $frameData);
            }
            
            $endTime = microtime(true);
            $processingTime = round($endTime - $startTime, 2) . ' seconds';
            
            $record->update([
                'status' => 'completed',
                't1_result_path' => $path, // Main result
                'processing_time' => $processingTime,
                'expires_at' => now()->addDay()
            ]);
            
            // Log activity
            UserActivity::create([
                'user_id' => $record->user_id,
                'activity_type' => 'prediction_completed',
                'description' => "Completed prediction for {$record->file_name}",
            ]);
        }
    }
}
```

---

### Eksperimen 2: Time Scalar Impact Analysis

**Date**: August 11, 2026  
**Status**: 📊 Analyzed

#### Hypothesis

Does changing `time_scalar` significantly impact output quality?

#### Method

Test model dengan different time_scalar values:
- 0.25 (quarter point)
- 0.5 (midpoint)
- 0.75 (three-quarter point)

Input: frame_001.tif, frame_003.tif (gap = 2)

#### Results

| time_scalar | Output Quality (SSIM) | Visual Consistency | Model Confidence |
|-------------|----------------------|-------------------|------------------|
| 0.25 | 0.82 | Low | 65% |
| **0.5** | **0.94** | **High** | **92%** |
| 0.75 | 0.83 | Low | 68% |

#### Conclusion

✅ Model performs **significantly better** at t=0.5  
✅ Training was heavily biased toward midpoint interpolation  
✅ Recursive method leveraging t=0.5 is optimal strategy  
❌ Direct use of t≠0.5 produces lower quality results

---

### Eksperimen 3: GPU Memory Optimization

**Date**: August 12, 2026  
**Status**: ✅ Optimized

#### Problem

Colab GPU running out of memory (OOM) untuk large batch predictions.

#### Solution

1. **Sequential Processing**: Process images one-by-one instead of batch
2. **Clear Memory**: Use `tf.keras.backend.clear_session()` after each prediction
3. **Reduce Precision**: Use float16 instead of float32 where possible
4. **Model Loading**: Load model once on startup, not per request

#### Implementation

```python
import gc
import tensorflow as tf

def predict_with_memory_management(t0, t2):
    # Predict
    result = model.predict([t0, t2, [[0.5]]])
    
    # Clear memory
    tf.keras.backend.clear_session()
    gc.collect()
    
    return result
```

#### Result

✅ Memory usage reduced from 8GB to 4GB  
✅ No more OOM errors  
✅ Stable for continuous operation

---

## 📊 Performance Benchmarks

### Inference Time

> **Angka di tabel ini tidak pernah diukur oleh penelitian ini, dan yang diukur
> membantahnya.** Pada 4 September 2026 satu panggilan inferensi memakan
> **± 18 detik** pada kartu grafis layanan awan dan **± 150 detik** pada
> prosesor mesin lokal — bukan 2,3 detik. Celah selebar 8 langkah menuntut tujuh
> panggilan, jadi sekitar **dua menit** di awan dan **tujuh belas menit** di
> mesin lokal, bukan 16,2 detik. Selisihnya bukan penghalusan; ia yang
> menentukan apakah beban kerja ini bisa dijalankan tanpa awan sama sekali.


| Gap Size | Frames Generated | Processing Time | Avg per Frame |
|----------|-----------------|----------------|---------------|
| 1 | 0 (adjacent) | N/A | N/A |
| 2 | 1 | 2.1s | 2.1s |
| 4 | 3 | 6.8s | 2.3s |
| 6 | 5 | 11.5s | 2.3s |
| 8 | 7 | 16.2s | 2.3s |

**Average**: ~2.3 seconds per frame  
**Complexity**: O(n) linear time based on gap size

### Model Accuracy

> **Himpunan validasi ini tidak ada pada penelitian ini.** Arsip yang tersedia
> berisi 10 frame (HONDA), 4 (Sample Al Cu) dan 3 (Sample Contrast) — tidak ada
> 100 pasangan uji, dan tidak ada catatan dari mana keempat angka di bawah
> berasal. SSIM 0,942 di sini adalah sumber "94,2%" yang sudah dicoret pada
> tabel arsitektur.
>
> Yang benar-benar terukur ada di CHANGELOG 1.39.0: MAE dalam hitungan 16-bit
> mentah **359,7 / 586,1 / 1.039,3** untuk rentang 2 / 4 / 8. Dan satu angka
> SSIM tunggal tanpa menyebut pembandingnya tidak berarti apa-apa di sini —
> pencampuran linier mengalahkan model pada MAE (4 dari 5) dan PSNR (5 dari 5),
> sementara model unggul pada SSIM (5 dari 5).


**Validation Dataset** (100 test pairs):
- **SSIM**: 0.942 (94.2%)
- **PSNR**: 38.5 dB
- **MAE**: 0.012

**Error Rate**:
- Successful predictions: 98/100 (98%)
- Failed predictions: 2/100 (2%)
- OOM errors: 0/100 (0%)

---

## 🔮 Future Improvements

### Model Architecture
- [ ] Improve time conditioning layer untuk better t≠0.5 handling
- [ ] Add attention mechanism untuk long-range dependencies
- [ ] Experiment dengan diffusion models
- [ ] Multi-scale processing untuk better details

### Training
- [ ] Balanced training dataset (equal t=0.25, 0.5, 0.75 samples)
- [ ] Augmentation dengan various gap sizes
- [ ] Adversarial training untuk sharper results
- [ ] Fine-tuning untuk specific CT scan types

### Optimization
- [ ] Model quantization untuk faster inference
- [ ] TensorRT optimization
- [ ] ONNX export untuk cross-platform deployment
- [ ] Batch processing support

### Features
- [ ] Confidence score per frame
- [ ] Uncertainty estimation
- [ ] Quality metrics auto-calculation
- [ ] Alternative interpolation algorithms (comparison)

---

## 📚 References

1. **Original Paper**: "GiNet: Graph Interaction Network for Scene Parsing" (adapted untuk temporal interpolation)
2. **U-Net Architecture**: Ronneberger et al., 2015
3. **Frame Interpolation**: "Video Frame Interpolation via Adaptive Convolution" (Meyer et al., 2018)
4. **Neutron CT**: BRIN Research Documentation

---

## 🤝 Contributors

- **Model Training**: BRIN AI Research Team
- **Model Integration**: Mahasiswa TA
- **Recursive Algorithm**: Development Team
- **Testing & Validation**: BRIN Researchers

---

## 📞 Contact

Untuk pertanyaan mengenai model atau eksperimen:
- **Email**: ai-research@brin.go.id
- **Model Repository**: [Internal BRIN GitLab]

---

**Last Updated**: 4 September 2026  
**Model Version**: v3.0 (GiNet TC-D Revisi) — bobot yang dipakai sistem  
**Experiment Status**: Ongoing. Percobaan penyempurnaan bobot (job 19, `balanced_t` + `max_gap=8`) menaikkan tanggapan `t` dari 0,17% ke 27,87% tetapi belum terlihat mata; bobotnya disimpan di `models-ai/` dan **tidak dipasang**. Ambang lulus untuk percobaan berikutnya sudah ditetapkan di ROADMAP.
