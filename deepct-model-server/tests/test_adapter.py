import io
from types import SimpleNamespace

import numpy as np
import pytest
import tifffile

from app.adapters.ginet_tcd import prepare_inputs, encode_prediction, custom_objects


def tiff(array):
    output = io.BytesIO()
    tifffile.imwrite(output, array)
    return output.getvalue()


def test_portable_uint16_frames_match_legacy_normalization_and_shape():
    first = tiff(np.zeros((3, 4), dtype=np.uint16))
    second = tiff(np.full((3, 4), 65535, dtype=np.uint16))
    pair, time = prepare_inputs(first, second, 0.5)
    assert pair.shape == (1, 2, 1024, 1024, 1)
    assert pair.dtype == np.float32
    assert np.all(pair[0, 0] == -1)
    assert np.all(pair[0, 1] == 1)
    np.testing.assert_array_equal(time, [[0.5]])


def test_resize_uses_legacy_pillow_integer_bicubic():
    from PIL import Image
    source = np.array([[0, 65535], [65535, 0]], dtype=np.uint16)
    pair, _ = prepare_inputs(tiff(source), tiff(source), 0.5)
    legacy = np.array(Image.open(io.BytesIO(tiff(source))).convert('I').resize((1024, 1024)), dtype=np.float32)
    np.testing.assert_array_equal(pair[0, 0, :, :, 0], 2.0 * legacy / 65535.0 - 1.0)


def test_postprocessing_clips_and_truncates_to_uint16_tiff():
    prediction = np.zeros((1, 1024, 1024, 1), dtype=np.float32)
    prediction[0, 0, :5, 0] = [-2, -1, 0, 1, 2]
    result = tifffile.imread(io.BytesIO(encode_prediction(prediction)))
    assert result.dtype == np.uint16
    assert result.shape == (1024, 1024)
    assert result[0, :5].tolist() == [0, 0, 32767, 65535, 65535]


@pytest.mark.parametrize('time', [0, 1, float('nan'), float('inf')])
def test_rejects_non_midpoint_time(time):
    frame = tiff(np.zeros((2, 2), dtype=np.uint16))
    with pytest.raises(ValueError):
        prepare_inputs(frame, frame, time)


@pytest.mark.parametrize('frame', [b'invalid', tiff(np.zeros((2, 2), dtype=np.uint8)), tiff(np.zeros((2, 2), dtype=np.float32))])
def test_rejects_non_uint16_tiff_input(frame):
    with pytest.raises(ValueError):
        prepare_inputs(frame, frame, 0.5)


def test_custom_layers_preserve_time_axes_and_explicit_fusion_filters():
    # TensorFlow is intentionally unavailable: exercise layer bodies with NumPy
    # and a minimal Conv2D boundary that captures its actual input.
    class Layer:
        def __init__(self, **kwargs):
            self.kwargs = kwargs
        def get_config(self):
            return self.kwargs.copy()
    class Conv2D:
        def __init__(self, filters, kernel, padding, activation):
            assert kernel == (1, 1) and padding == 'same' and activation == 'relu'
            self.filters = filters
        def __call__(self, inputs):
            return inputs
    tf = SimpleNamespace(
        keras=SimpleNamespace(layers=SimpleNamespace(Layer=Layer, Conv2D=Conv2D)),
        reduce_mean=np.mean, concat=lambda values, axis: np.concatenate(values, axis=axis),
    )
    objects = custom_objects(tf)
    inputs = np.array([[[[[2]]], [[[6]]]]], dtype=np.float32)
    assert objects['TimeMean']().call(inputs).item() == 4
    assert objects['TimeLast']().call(inputs).item() == 6
    for filters in [256, 128, 64, 32]:
        fusion = objects['SkipFusion'](filters=filters, name='skip')
        assert fusion.conv.filters == filters
        assert fusion.call(inputs).reshape(-1).tolist() == [4, 6]
        assert fusion.get_config() == {'name': 'skip', 'filters': filters}
