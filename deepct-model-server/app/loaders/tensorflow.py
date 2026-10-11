"""Bounded graph screening, without importing TensorFlow at module import time."""
import json
import gc
import importlib.metadata
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path

import h5py

MAX_CONFIG = 1024 * 1024
MAX_EXPANDED = 2 * 1024**3
CLASSES = {
    'Functional', 'InputLayer', 'TimeDistributed', 'DTypePolicy', 'Conv2D',
    'GlorotUniform', 'Zeros', '__keras_tensor__', 'MaxPooling2D', 'ConvLSTM2D',
    'Orthogonal', 'Dense', 'Reshape', 'Concatenate', 'Conv2DTranspose',
    'TimeMean', 'TimeLast', 'SkipFusion',
    'Custom>TimeMean', 'Custom>TimeLast', 'Custom>SkipFusion',
}
CUSTOM_NAMES = {'Custom>TimeMean', 'Custom>TimeLast', 'Custom>SkipFusion'}
MODULES = {None, 'keras', 'keras.layers', 'keras.initializers'}
ACTIVATIONS = {'linear', 'relu', 'sigmoid', 'tanh', 'softmax'}


class TensorFlowLoader:
    def load(self, path):
        for package, expected in [('tensorflow', '2.17.0'), ('keras', '3.15.1')]:
            if importlib.metadata.version(package) != expected:
                raise ValueError('Unreviewed inference runtime')
        screen_model(path)
        import tensorflow as tf
        from ..adapters.ginet_tcd import custom_objects
        return tf.keras.models.load_model(
            str(path), custom_objects=custom_objects(tf), compile=False, safe_mode=True,
        )

    def release(self):
        import tensorflow as tf
        tf.keras.backend.clear_session()
        gc.collect()


def screen_graph(graph):
    nodes = 0
    def visit(value, depth=0):
        nonlocal nodes
        nodes += 1
        if depth > 64 or nodes > 50000:
            raise ValueError('Graph complexity limit exceeded')
        if isinstance(value, dict):
            if 'class_name' in value:
                name = value['class_name']
                if not isinstance(name, str) or name not in CLASSES:
                    raise ValueError('Unapproved serialized class')
                if value.get('module') not in MODULES:
                    raise ValueError('Unapproved module')
                registered = value.get('registered_name')
                if registered is not None and registered not in CUSTOM_NAMES:
                    raise ValueError('Unapproved registered object')
                if registered is not None and registered.split('>')[-1] != name.split('>')[-1]:
                    raise ValueError('Mismatched registered object')
            for key, child in value.items():
                if key in {'activation', 'recurrent_activation'} and child is not None:
                    if not isinstance(child, str) or child not in ACTIVATIONS:
                        raise ValueError('Unapproved activation')
                if key.endswith('_initializer') and isinstance(child, str) and child not in {'glorot_uniform', 'zeros', 'orthogonal'}:
                    raise ValueError('Unapproved initializer')
                if (key.endswith('_regularizer') or key.endswith('_constraint')) and child is not None:
                    raise ValueError('Unapproved regularizer or constraint')
                visit(child, depth + 1)
        elif isinstance(value, list):
            for child in value:
                visit(child, depth + 1)
    if not isinstance(graph, dict) or 'class_name' not in graph:
        raise ValueError('Missing model graph')
    visit(graph)


def _screen_hdf5(path, require_graph):
    with h5py.File(path, 'r') as handle:
        seen = set()
        expanded = 0
        def visit(group, depth=0):
            nonlocal expanded
            address = h5py.h5o.get_info(group.id).addr
            if address in seen:
                return
            seen.add(address)
            if depth > 64 or len(seen) > 50000:
                raise ValueError('HDF5 complexity limit exceeded')
            for name in group:
                if not isinstance(group.get(name, getlink=True), h5py.HardLink):
                    raise ValueError('HDF5 external/soft links forbidden')
                child = group[name]
                if isinstance(child, h5py.Group):
                    visit(child, depth + 1)
                elif isinstance(child, h5py.Dataset):
                    dtype = child.dtype
                    # nbytes bounds decoded data only for fixed numeric elements.
                    # Reject whole compound/array datatypes, including any nested
                    # vlen/reference fields; weight tensor axes belong in shape.
                    if (dtype.kind not in 'biufc' or dtype.fields is not None
                            or dtype.subdtype is not None or dtype.metadata):
                        raise ValueError('Unsupported HDF5 weight datatype')
                    expanded += child.nbytes
                    if expanded > MAX_EXPANDED:
                        raise ValueError('HDF5 expansion limit exceeded')
                    if child.external or child.is_virtual:
                        raise ValueError('External HDF5 storage forbidden')
        visit(handle)
        if require_graph:
            if 'model_config' not in handle.attrs or handle.attrs.get_id('model_config').get_storage_size() > MAX_CONFIG:
                raise ValueError('Missing or oversized HDF5 graph')
            raw = handle.attrs['model_config']
            if not isinstance(raw, (str, bytes)) or len(raw) > MAX_CONFIG:
                raise ValueError('Invalid HDF5 graph')
            screen_graph(json.loads(raw))


def screen_model(path):
    path = Path(path)
    if path.suffix == '.h5':
        _screen_hdf5(path, require_graph=True)
        return
    if path.suffix != '.keras':
        raise ValueError('Unsupported model format')
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        names = [member.filename for member in members]
        allowed = {'config.json', 'metadata.json', 'model.weights.h5'}
        if len(names) != len(set(names)) or not {'config.json', 'model.weights.h5'} <= set(names) or not set(names) <= allowed:
            raise ValueError('Unapproved archive members')
        total = 0
        for member in members:
            total += member.file_size
            mode = member.external_attr >> 16
            if stat.S_ISLNK(mode) or member.flag_bits & 1 or member.file_size / max(1, member.compress_size) > 200:
                raise ValueError('Unsafe archive member')
            limit = MAX_CONFIG if member.filename.endswith('.json') else MAX_EXPANDED
            if member.file_size > limit or total > MAX_EXPANDED:
                raise ValueError('Archive expansion limit exceeded')
        screen_graph(json.loads(archive.read('config.json')))
        with tempfile.TemporaryDirectory(prefix='deepct-keras-') as temporary:
            weights = Path(temporary) / 'model.weights.h5'
            with archive.open('model.weights.h5') as source, weights.open('wb') as target:
                shutil.copyfileobj(source, target, length=1024 * 1024)
            _screen_hdf5(weights, require_graph=False)
