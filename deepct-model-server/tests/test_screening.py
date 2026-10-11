import json
import zipfile

import h5py
import numpy as np
import pytest

from app.loaders.tensorflow import screen_model


def hdf5(path, graph):
    with h5py.File(path, 'w') as handle:
        handle.attrs['model_config'] = json.dumps(graph)


def graph(layer='Conv2D', **extra):
    return {'class_name': 'Functional', 'config': {'layers': [
        {'class_name': 'TimeDistributed', 'config': {'layer': {
            'class_name': layer, 'config': {}, **extra,
        }}}
    ]}}


def test_approved_nested_graph_is_accepted(tmp_path):
    path = tmp_path / 'model.h5'
    hdf5(path, graph())
    screen_model(path)


@pytest.mark.parametrize('layer,extra', [
    ('Lambda', {}), ('__lambda__', {}), ('function', {'config': 'eval'}),
    ('Conv2D', {'module': 'attacker'}), ('Conv2D', {'registered_name': 'Evil>Run'}),
])
def test_nested_unsafe_deserialization_is_rejected(tmp_path, layer, extra):
    path = tmp_path / 'model.h5'
    hdf5(path, graph(layer, **extra))
    with pytest.raises(ValueError):
        screen_model(path)


@pytest.mark.parametrize('kind', ['soft', 'external', 'external_dataset', 'virtual'])
def test_hdf5_links_and_external_storage_are_rejected(tmp_path, kind):
    path = tmp_path / 'model.h5'
    hdf5(path, graph())
    with h5py.File(path, 'a') as handle:
        if kind == 'soft':
            handle['unsafe'] = h5py.SoftLink('/anything')
        elif kind == 'external':
            handle['unsafe'] = h5py.ExternalLink('/outside.h5', '/')
        elif kind == 'external_dataset':
            handle.create_dataset('unsafe', (1,), external=[('/outside.bin', 0, 4)], dtype='f4')
        else:
            layout = h5py.VirtualLayout((1,), dtype='f4')
            layout[:] = h5py.VirtualSource('/outside.h5', 'data', shape=(1,))
            handle.create_virtual_dataset('unsafe', layout)
    with pytest.raises(ValueError):
        screen_model(path)


@pytest.mark.parametrize('member', ['../escape', '/absolute', 'assets/code.py', 'model.pkl'])
def test_keras_archive_rejects_unapproved_members(tmp_path, member):
    path = tmp_path / 'model.keras'
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('config.json', json.dumps(graph()))
        archive.writestr('model.weights.h5', b'unused because member screening must reject first')
        archive.writestr(member, 'bad')
    with pytest.raises(ValueError):
        screen_model(path)


def test_keras_archive_accepts_safe_graph_and_weights(tmp_path):
    weights = tmp_path / 'weights.h5'
    with h5py.File(weights, 'w') as handle:
        handle.create_dataset('data', data=[1, 2])
    path = tmp_path / 'model.keras'
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('config.json', json.dumps(graph()))
        archive.writestr('metadata.json', '{}')
        archive.write(weights, 'model.weights.h5')
    screen_model(path)


def test_keras_compression_bomb_is_rejected_before_expansion(tmp_path):
    path = tmp_path / 'model.keras'
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('config.json', ' ' * 2_000_000)
        archive.writestr('model.weights.h5', b'not read')
    with pytest.raises(ValueError):
        screen_model(path)


def test_string_activation_cannot_resolve_custom_callable(tmp_path):
    path = tmp_path / 'model.h5'
    hdf5(path, {'class_name': 'Dense', 'config': {'activation': 'attacker>execute'}})
    with pytest.raises(ValueError):
        screen_model(path)


def test_sparse_hdf5_dataset_cannot_expand_without_bound(tmp_path):
    path = tmp_path / 'model.h5'
    hdf5(path, graph())
    with h5py.File(path, 'a') as handle:
        handle.create_dataset('bomb', shape=(2**31,), dtype='f4', chunks=True)
    with pytest.raises(ValueError):
        screen_model(path)


def test_graph_string_initializer_cannot_resolve_registered_callable(tmp_path):
    path = tmp_path / 'model.h5'
    hdf5(path, {'class_name': 'Dense', 'config': {'kernel_initializer': 'Evil>execute'}})
    with pytest.raises(ValueError):
        screen_model(path)


def test_keras_archive_rejects_duplicate_config(tmp_path):
    path = tmp_path / 'model.keras'
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('config.json', json.dumps(graph()))
        with pytest.warns(UserWarning, match='Duplicate name'):
            archive.writestr('config.json', json.dumps(graph('Lambda')))
        archive.writestr('model.weights.h5', b'not read')
    with pytest.raises(ValueError, match='archive members'):
        screen_model(path)


def test_keras_archive_rejects_symlink_metadata(tmp_path):
    import stat
    path = tmp_path / 'model.keras'
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('config.json', json.dumps(graph()))
        archive.writestr('model.weights.h5', b'not read')
        member = zipfile.ZipInfo('metadata.json')
        member.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(member, '/etc/passwd')
    with pytest.raises(ValueError, match='Unsafe archive member'):
        screen_model(path)


def model_container(tmp_path, dtype, suffix, payload=None):
    weights = tmp_path / 'model.h5'
    hdf5(weights, graph())
    with h5py.File(weights, 'a') as handle:
        dataset = handle.create_dataset('weights', shape=(1,), dtype=dtype)
        if payload is not None:
            dataset[0] = payload
    if suffix == '.h5':
        return weights
    path = tmp_path / 'model.keras'
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('config.json', json.dumps(graph()))
        archive.write(weights, 'model.weights.h5')
    return path


def forbid_dataset_reads(monkeypatch):
    def forbidden(*args, **kwargs):
        pytest.fail('screening decoded an HDF5 dataset payload')
    monkeypatch.setattr(h5py.Dataset, '__getitem__', forbidden)
    monkeypatch.setattr(h5py.Dataset, 'read_direct', forbidden)
    monkeypatch.setattr(h5py.Dataset, '__array__', forbidden)


@pytest.mark.parametrize('suffix', ['.h5', '.keras'])
def test_variable_length_payload_rejected_before_decoding(tmp_path, monkeypatch, suffix):
    path = model_container(tmp_path, h5py.vlen_dtype(np.dtype('uint8')), suffix,
                           payload=np.zeros(4096, dtype='uint8'))
    if suffix == '.h5':
        with h5py.File(path, 'r') as handle:
            assert handle['weights'].nbytes == 8
        # Reproduce the undercount directly; the archive additionally has its
        # own on-disk size budget, independent of decoded dataset allocation.
        monkeypatch.setattr('app.loaders.tensorflow.MAX_EXPANDED', 1024)
    forbid_dataset_reads(monkeypatch)
    with pytest.raises(ValueError, match='Unsupported HDF5 weight datatype'):
        screen_model(path)


@pytest.mark.parametrize('dtype', [
    h5py.string_dtype(),
    h5py.ref_dtype,
    h5py.regionref_dtype,
    np.dtype([('payload', h5py.vlen_dtype(np.dtype('uint8')))]),
    np.dtype((h5py.vlen_dtype(np.dtype('uint8')), (2,))),
    np.dtype([('nested', [('references', h5py.ref_dtype, (2,))])]),
    np.dtype('S16'),
    np.dtype('V16'),
    np.dtype([('numeric', 'f4')]),
    np.dtype(('f4', (2,))),
    h5py.enum_dtype({'one': 1, 'two': 2}, basetype='i4'),
], ids=['vlen-string', 'reference', 'region-reference', 'compound-vlen',
        'array-vlen', 'nested-compound-array-reference', 'fixed-string', 'opaque',
        'numeric-compound', 'numeric-array', 'enum'])
@pytest.mark.parametrize('suffix', ['.h5', '.keras'])
def test_unsupported_weight_datatypes_rejected_without_reading(tmp_path, monkeypatch, dtype, suffix):
    path = model_container(tmp_path, dtype, suffix)
    forbid_dataset_reads(monkeypatch)
    with pytest.raises(ValueError, match='Unsupported HDF5 weight datatype'):
        screen_model(path)


@pytest.mark.parametrize('dtype', ['f4', 'f8', 'i8', 'u2', 'bool', 'c8'])
@pytest.mark.parametrize('suffix', ['.h5', '.keras'])
def test_fixed_numeric_weights_remain_accepted_without_reading(tmp_path, monkeypatch, dtype, suffix):
    path = model_container(tmp_path, np.dtype(dtype), suffix)
    forbid_dataset_reads(monkeypatch)
    screen_model(path)
