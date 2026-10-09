const MAX_ARCHIVE_BYTES = 2 * 1024 ** 3;
const MAX_FRAME_BYTES = 50 * 1024 ** 2;
const encoder = new TextEncoder();
const crcTable = Uint32Array.from({ length: 256 }, (_, value) => {
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ value >>> 1 : value >>> 1;
  return value >>> 0;
});

export function validatePredictionFiles(files: File[]): "zip" | "tiff" {
  if (!files.length) throw new Error("Choose one ZIP archive or multiple numbered TIFF frames.");
  if (files.some((file) => !file.size)) throw new Error("Empty files cannot be uploaded.");
  if (files.length === 1 && /\.zip$/i.test(files[0].name)) {
    if (files[0].size > MAX_ARCHIVE_BYTES) throw new Error("The archive must be 2 GB or smaller.");
    return "zip";
  }
  if (!files.every((file) => /\.tiff?$/i.test(file.name))) {
    throw new Error("Choose one ZIP archive or TIFF frames only. Do not mix ZIPs and TIFFs.");
  }
  if (files.length < 2) throw new Error("Select at least two numbered TIFF frames.");
  if (files.some((file) => file.size > MAX_FRAME_BYTES)) throw new Error("Each TIFF frame must be 50 MB or smaller.");
  if (files.some((file) => !/\d/.test(file.name.replace(/\.tiff?$/i, "")))) {
    throw new Error("Include the frame number in each filename, for example frame_001.tif and frame_005.tif.");
  }
  const names = files.map((file) => file.name.toLowerCase());
  if (new Set(names).size !== names.length) throw new Error("Each TIFF frame must have a unique filename.");
  if (files.some((file) => /[\\/\x00]/.test(file.name) || encoder.encode(file.name).length > 255)) {
    throw new Error("Frame filenames must be simple names of at most 255 bytes.");
  }
  // Include ZIP headers, filenames, descriptors and its directory in the limit.
  const size = files.reduce((sum, file) => sum + file.size + 92 + encoder.encode(file.name).length * 2, 22);
  if (size > MAX_ARCHIVE_BYTES || files.length > 65535) throw new Error("The combined TIFF archive must be 2 GB or smaller.");
  return "tiff";
}

function record(size: number, write: (view: DataView) => void): ArrayBuffer {
  const buffer = new ArrayBuffer(size);
  write(new DataView(buffer));
  return buffer;
}

/** Store TIFFs without compression or full-file copies; original names survive.
 * CRC reads are bounded to 1 MB. Blob parts reference the original picked files.
 * The same files produce the same archive metadata for resumable uploads.
 */
export async function preparePredictionArchive(
  files: File[], onProgress: (percent: number) => void = () => {}, signal?: AbortSignal,
): Promise<File> {
  const kind = validatePredictionFiles(files);
  signal?.throwIfAborted();
  if (kind === "zip") return files[0];

  const parts: BlobPart[] = [];
  const directory: BlobPart[] = [];
  const manifest: string[] = [];
  let offset = 0;
  let directorySize = 0;
  let read = 0;
  const total = files.reduce((sum, file) => sum + file.size, 0);
  const ordered = [...files].sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
  for (const file of ordered) {
    const name = encoder.encode(file.name);
    let crc = 0xffffffff;
    for (let start = 0; start < file.size; start += 1024 ** 2) {
      signal?.throwIfAborted();
      const chunk = new Uint8Array(await file.slice(start, start + 1024 ** 2).arrayBuffer());
      signal?.throwIfAborted();
      for (const byte of chunk) crc = crcTable[(crc ^ byte) & 255] ^ crc >>> 8;
      read += chunk.length;
      onProgress(Math.round(read / total * 100));
    }
    crc = (crc ^ 0xffffffff) >>> 0;
    manifest.push(JSON.stringify([file.name, file.size, crc, file.lastModified]));
    parts.push(record(30, (view) => {
      view.setUint32(0, 0x04034b50, true);
      view.setUint16(4, 20, true);
      view.setUint16(6, 0x808, true); // UTF-8 + trailing data descriptor.
      view.setUint16(12, 33, true); // 1980-01-01, deterministic DOS date.
      view.setUint16(26, name.length, true);
    }), name, file, record(16, (view) => {
      view.setUint32(0, 0x08074b50, true);
      view.setUint32(4, crc, true);
      view.setUint32(8, file.size, true);
      view.setUint32(12, file.size, true);
    }));
    const entryOffset = offset;
    directory.push(record(46, (view) => {
      view.setUint32(0, 0x02014b50, true);
      view.setUint16(4, 20, true);
      view.setUint16(6, 20, true);
      view.setUint16(8, 0x808, true);
      view.setUint16(14, 33, true);
      view.setUint32(16, crc, true);
      view.setUint32(20, file.size, true);
      view.setUint32(24, file.size, true);
      view.setUint16(28, name.length, true);
      view.setUint32(42, entryOffset, true);
    }), name);
    offset += 46 + name.length + file.size;
    directorySize += 46 + name.length;
  }
  for (const part of directory) parts.push(part);
  parts.push(record(22, (view) => {
    view.setUint32(0, 0x06054b50, true);
    view.setUint16(8, files.length, true);
    view.setUint16(10, files.length, true);
    view.setUint32(12, directorySize, true);
    view.setUint32(16, offset, true);
  }));
  signal?.throwIfAborted();
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(manifest.join("\n"))));
  signal?.throwIfAborted();
  const fingerprint = Array.from(digest.slice(0, 8), (byte) => byte.toString(16).padStart(2, "0")).join("");
  return new File(parts, "ct-frames-" + fingerprint + ".zip", {
    type: "application/zip", lastModified: files.reduce((latest, file) => Math.max(latest, file.lastModified), 0),
  });
}
