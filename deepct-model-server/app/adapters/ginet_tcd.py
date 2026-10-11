"""Approved legacy midpoint adapter; TensorFlow is supplied only when loading."""
import io

import numpy as np
import tifffile
from PIL import Image, UnidentifiedImageError


def prepare_inputs(first, second, time_scalar):
    if time_scalar != 0.5:
        raise ValueError('Only midpoint interpolation is supported')
    arrays = []
    for data in (first, second):
        try:
            with Image.open(io.BytesIO(data)) as image:
                if image.format != 'TIFF' or image.mode not in {'I;16', 'I;16B', 'I;16L'} or image.n_frames != 1:
                    raise ValueError('Expected one uint16 grayscale TIFF frame')
                if image.width * image.height > 16_777_216:
                    raise ValueError('Image dimensions exceed limit')
                # Deliberately preserve legacy convert(I) then default bicubic resize.
                arrays.append(np.array(image.convert('I').resize((1024, 1024)), dtype=np.float32))
        except (OSError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
            raise ValueError('Invalid TIFF image') from exc
    sequence = np.stack(arrays, axis=0)[..., np.newaxis]
    sequence = 2.0 * sequence / 65535.0 - 1.0
    return sequence[np.newaxis, ...], np.array([[time_scalar]], dtype=np.float32)


def encode_prediction(prediction):
    prediction = np.asarray(prediction)
    if prediction.shape != (1, 1024, 1024, 1) or not np.isfinite(prediction).all():
        raise ValueError('Invalid model output')
    pixels = np.clip((prediction[0, :, :, 0] + 1.0) / 2.0 * 65535.0, 0, 65535).astype(np.uint16)
    output = io.BytesIO()
    tifffile.imwrite(output, pixels)
    return output.getvalue()


def custom_objects(tf):
    class TimeMean(tf.keras.layers.Layer):
        def call(self, inputs):
            return tf.reduce_mean(inputs, axis=1)

    class TimeLast(tf.keras.layers.Layer):
        def call(self, inputs):
            return inputs[:, -1, :, :, :]

    class SkipFusion(tf.keras.layers.Layer):
        def __init__(self, filters=64, **kwargs):
            super().__init__(**kwargs)
            self.filters = filters
            self.conv = tf.keras.layers.Conv2D(filters, (1, 1), padding='same', activation='relu')

        def call(self, inputs):
            mean = tf.reduce_mean(inputs, axis=1)
            last = inputs[:, -1, :, :, :]
            return self.conv(tf.concat([mean, last], axis=-1))

        def get_config(self):
            config = super().get_config()
            config.update({'filters': self.filters})
            return config

    layers = {'TimeMean': TimeMean, 'TimeLast': TimeLast, 'SkipFusion': SkipFusion}
    return {**layers, **{f'Custom>{name}': layer for name, layer in layers.items()}}
