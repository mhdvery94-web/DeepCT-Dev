import json
import zipfile

import h5py
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
