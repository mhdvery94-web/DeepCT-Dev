"""Only the management parent invokes this child with a verified private file."""
import sys
import resource


def main():
    gpu_budget, address_budget = int(sys.argv[2]), int(sys.argv[3])
    if gpu_budget <= 0 or address_budget <= 0:
        return 1
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_AS, (address_budget, address_budget))
    import numpy as np
    import tensorflow as tf
    from .loaders.tensorflow import TensorFlowLoader
    from .adapters.ginet_tcd import encode_prediction

    devices = tf.config.list_physical_devices('GPU')
    if not devices:
        return 1
    tf.config.set_visible_devices(devices[0], 'GPU')
    tf.config.set_logical_device_configuration(devices[0], [tf.config.LogicalDeviceConfiguration(memory_limit=gpu_budget / 1024**2)])
    tf.config.set_soft_device_placement(False)
    with tf.device('/GPU:0'):
        probe = tf.linalg.matmul(tf.ones((1, 1)), tf.ones((1, 1)))
        if 'GPU:0' not in probe.device:
            return 1
        model = TensorFlowLoader().load(sys.argv[1])
        pair = np.zeros((1, 2, 1024, 1024, 1), dtype=np.float32)
        output = model.predict([pair, np.array([[0.5]], dtype=np.float32)], verbose=0)
        encode_prediction(output)  # real adapter shape/finite/output validation
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(1) from None
