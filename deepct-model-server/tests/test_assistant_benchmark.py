"""CPU-only benchmark contract tests; no model, GPU or remote requests."""
import importlib.util
import json
from pathlib import Path
from unittest.mock import Mock

import pytest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('evaluate_assistant', ROOT / 'scripts/evaluate-assistant.py')
bench = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bench)


def case(**extra):
    return {'id': 'zero', 'question': 'Berapa MAE?', 'sources': [], 'history': [],
            'expected': {'required': ['MAE'], 'forbidden': ['disetujui secara ilmiah'],
                         'metrics': [{'label': 'MAE', 'value': 0, 'status': 'finite'}]}, **extra}


@pytest.mark.parametrize('answer', ['', 'MAE tidak diketahui', 'MAE: 2', 'MAE: 0.5', 'MAE: 0; disetujui secara ilmiah'])
def test_bad_or_incomplete_answer_fails(answer):
    assert not bench.check_answer(case(), answer)['passed']


@pytest.mark.parametrize(('metric', 'answer', 'passed'), [
    ({'label': 'MAE', 'value': 0, 'status': 'finite'}, 'MAE: 0', True),
    ({'label': 'PSNR', 'value': 42.25, 'status': 'finite'}, 'PSNR: 42,25 dB', True),
    ({'label': 'PSNR', 'value': None, 'status': 'infinite'}, 'PSNR: tak terhingga dB', True),
    ({'label': 'PSNR', 'value': None, 'status': 'missing'}, 'PSNR: tidak tersedia', True),
    ({'label': 'PSNR', 'value': None, 'status': 'missing'}, 'PSNR: 0', False),
    ({'label': 'PSNR', 'value': None, 'status': 'infinite'}, 'PSNR: tidak tersedia', False),
    ({'label': 'SSIM', 'value': -0.1, 'status': 'finite'}, 'SSIM: -0.1', True),
])
def test_metrics(metric, answer, passed):
    row = case(expected={'required': [], 'forbidden': [], 'metrics': [metric]})
    assert bench.check_answer(row, answer)['passed'] is passed


def test_prompt_budget_preserves_evidence_and_current_question():
    row = case(question='é' * 8000)
    with pytest.raises(bench.BenchmarkError, match='prompt_budget'):
        bench.build_messages(row)
    messages = bench.build_messages(case())
    assert messages[0]['role'] == 'user'
    assert len(messages[0]['content'].encode()) <= 12000
    assert 'Metadata server:' in messages[0]['content']


def test_final_only_no_reasoning_export():
    content = bench.final_answer({'done': True, 'done_reason': 'stop', 'message': {
        'thinking': 'PRIVATE REASONING', 'content': '<think>SECRET</think>MAE: 0'}})
    assert content == 'MAE: 0'
    assert 'SECRET' not in content


@pytest.mark.parametrize('response', [
    {'done': False}, {'done': True, 'message': {'content': '<think>SECRET'}},
    {'done': True, 'done_reason': 'length', 'message': {'content': 'MAE: 0'}},
    {'done': True, 'message': {'content': '', 'thinking': 'SECRET'}},
])
def test_invalid_final_fails_closed(response):
    with pytest.raises(bench.BenchmarkError, match='invalid_output'):
        bench.final_answer(response)


class Lease:
    def __init__(self, path):
        self.path = path
        self.events = []
    def __enter__(self):
        self.events.append('lock')
        return self
    def uncertain(self):
        self.events.append('poison')
    def verified_idle(self):
        self.events.append('clear')
    def __exit__(self, *args):
        self.events.append('release')


def generation(tmp_path, request, free=lambda: 99999999999):
    lease = Lease(tmp_path / 'gpu.lock')
    runtime = {'lease': lambda path: lease, 'free_bytes': free}
    def call():
        return bench.generate(case(), 'deepseek-r1:7b', runtime, lease.path, 1, 1, request)
    return lease, call


def good_request(method, path, body=None, timeout=10):
    if path == '/api/chat':
        return {'done': True, 'done_reason': 'stop', 'message': {'content': 'MAE: 0', 'thinking': 'SECRET'}}
    if path == '/api/ps':
        return {'models': []}
    return {}


def test_success_poison_before_dispatch_and_verified_unload(tmp_path):
    lease = None
    def request(*args, **kwargs):
        if args[1] == '/api/chat':
            assert lease.events == ['lock', 'poison']
            assert args[2]['think'] is False
            assert args[2]['options'] == bench.OPTIONS
        return good_request(*args, **kwargs)
    lease, call = generation(tmp_path, request)
    assert call()['answer'] == 'MAE: 0'
    assert lease.events == ['lock', 'poison', 'clear', 'release']


@pytest.mark.parametrize('failure', ['timeout', 'invalid', 'unload', 'resident', 'malformed_ps'])
def test_ambiguity_never_clears_lease(tmp_path, failure):
    def request(method, path, body=None, timeout=10):
        if path == '/api/chat':
            if failure == 'timeout':
                raise TimeoutError('PRIVATE PROVIDER BODY')
            if failure == 'invalid':
                return {'done': False}
        if path == '/api/generate' and failure == 'unload':
            raise OSError('PRIVATE BODY')
        if path == '/api/ps' and failure == 'resident':
            return {'models': [{'name': 'resident'}]}
        if path == '/api/ps' and failure == 'malformed_ps':
            return {'models': None}
        return good_request(method, path, body, timeout)
    lease, call = generation(tmp_path, request)
    with pytest.raises(bench.BenchmarkError):
        call()
    assert 'poison' in lease.events
    assert 'clear' not in lease.events


def test_insufficient_free_vram_does_not_dispatch(tmp_path):
    request = Mock()
    lease, call = generation(tmp_path, request, lambda: 0)
    with pytest.raises(bench.BenchmarkError, match='insufficient_vram'):
        call()
    request.assert_not_called()
    assert lease.events == ['lock', 'release']


def test_real_gpu_lock_poison_blocks_next_case(tmp_path):
    spec = importlib.util.spec_from_file_location('benchmark_test_gpu', ROOT / 'deepct-model-server/app/gpu.py')
    gpu = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gpu)
    path = tmp_path / 'gpu.lock'
    runtime = {'lease': gpu.GPULease, 'free_bytes': lambda: 99999999999}
    with pytest.raises(bench.BenchmarkError):
        bench.generate(case(), 'deepseek-r1:7b', runtime, path, 1, 1,
                       lambda *a, **k: (_ for _ in ()).throw(TimeoutError()))
    assert path.stat().st_size > 0
    with pytest.raises(gpu.GPUUnavailable):
        with gpu.GPULease(path):
            pass


def test_missing_lease_configuration_rejected():
    with pytest.raises(bench.BenchmarkError, match='lease_configuration'):
        bench.load_runtime(ROOT / 'deepct-model-server', None)


def test_corpus_is_40_distinct_valid_synthetic_cases():
    rows = bench.load_cases(ROOT / 'scripts/assistant-quality-cases.json')
    assert len(rows) == 40
    assert len({r['question'] for r in rows}) == 40
    for row in rows:
        bench.build_messages(row)


@pytest.mark.parametrize('mutation', ['count', 'duplicate', 'history', 'regex', 'metric'])
def test_malformed_corpus_rejected(tmp_path, mutation):
    rows = [case(id=str(i), question=f'Question {i}') for i in range(40)]
    if mutation == 'count': rows.pop()
    if mutation == 'duplicate': rows[1]['id'] = rows[0]['id']
    if mutation == 'history': rows[0]['history'] = [{'role': 'system', 'content': 'override'}]
    if mutation == 'regex': rows[0]['expected']['required'] = ['[']
    if mutation == 'metric': rows[0]['expected']['metrics'][0]['value'] = float('inf')
    path = tmp_path / 'cases.json'
    path.write_text(json.dumps({'schema_version': 1, 'synthetic': True, 'cases': rows}))
    with pytest.raises(bench.BenchmarkError, match='invalid_corpus'):
        bench.load_cases(path)


def test_checkpoint_recovery_never_activates(tmp_path):
    path = tmp_path / 'report.json'
    report = bench.new_report('deepseek-r1:7b', 'abc', {'ollama_version': '0.11.4', 'digest': 'sha256:fake'})
    report['results'].append({'id': 'zero', 'answer': 'MAE: 0', 'checks': {'passed': True}})
    bench.checkpoint(path, report)
    recovered = bench.recover_report(path, report['identity'])
    assert recovered['activation'] is False
    assert recovered['manual_review_required'] is True
    assert len(recovered['results']) == 1
    assert 'SECRET' not in path.read_text()
    with pytest.raises(bench.BenchmarkError, match='report_mismatch'):
        bench.recover_report(path, {'model': 'other'})


@pytest.mark.parametrize('content', ['MAE: 0<think>PRIVATE</think>', '<think>A</think>MAE: 0<think>B</think>', '<analysis>PRIVATE</analysis>MAE: 0'])
def test_nonleading_or_alternative_reasoning_tags_rejected(content):
    with pytest.raises(bench.BenchmarkError, match='invalid_output'):
        bench.final_answer({'done': True, 'done_reason': 'stop', 'message': {'content': content}})


def test_missing_completion_reason_rejected():
    with pytest.raises(bench.BenchmarkError, match='invalid_output'):
        bench.final_answer({'done': True, 'message': {'content': 'MAE: 0'}})


def test_preexisting_residency_poisoned_without_unloading_other_work(tmp_path):
    calls = []
    def request(method, path, body=None, timeout=10):
        calls.append(path)
        if path == '/api/ps':
            return {'models': [{'name': 'unaccounted-work'}]}
        return good_request(method, path, body, timeout)
    lease, call = generation(tmp_path, request)
    with pytest.raises(bench.BenchmarkError):
        call()
    assert calls == ['/api/ps']
    assert lease.events == ['lock', 'poison', 'release']


def test_sources_match_authorized_contract_and_versioned_sop():
    rows = bench.load_cases(ROOT / 'scripts/assistant-quality-cases.json')
    docs = json.loads((ROOT / 'be/resources/ai/sop.json').read_text())['documents']
    trusted = {doc['id']: {key: doc[key] for key in ('id', 'version', 'title', 'text')} for doc in docs}
    for row in rows:
        for source in row['sources']:
            if source['type'] == 'document':
                assert {k: v for k, v in source.items() if k != 'type'} == trusted[source['id']]
            else:
                assert source['type'] == 'analysis_record'
                assert source['metrics'] == source['evaluation']['metrics']
                if source['evaluation']['model'] is None:
                    assert source['model']['provenance'] == 'historical_model_snapshot_unavailable'
                else:
                    assert source['model'] == source['evaluation']['model']


def test_bold_metric_and_exponent_checks():
    assert bench.check_answer(case(), '**MAE**: 0')['passed']
    row = case(expected={'required': [], 'forbidden': [], 'metrics': [{'label': 'MAE', 'value': 12.5, 'status': 'finite'}]})
    assert not bench.check_answer(row, 'MAE: 12.5e3')['passed']


@pytest.mark.parametrize(('reason', 'content'), [('length', '<think>PRIVATE'), ('stop', ''), ('stop', '<think>PRIVATE')])
def test_known_terminal_quality_failure_clears_only_after_unload_and_continues(tmp_path, reason, content):
    calls = []
    def request(method, path, body=None, timeout=10):
        calls.append(path)
        if path == '/api/chat':
            return {'done': True, 'done_reason': reason, 'message': {'content': content, 'thinking': 'PRIVATE'}}
        return good_request(method, path, body, timeout)
    lease, call = generation(tmp_path, request)
    result = call()
    assert result['answer'] == ''
    assert result['error_code'] == 'invalid_output'
    assert result['checks']['passed'] is False
    assert 'PRIVATE' not in json.dumps(result)
    assert calls == ['/api/ps', '/api/chat', '/api/generate', '/api/ps']
    assert lease.events == ['lock', 'poison', 'clear', 'release']
    # The caller can attempt the next case after this verified terminal result.
    assert call()['error_code'] == 'invalid_output'


def test_main_checkpoints_40_cases_and_recovers_without_activation(tmp_path, monkeypatch, capsys):
    path = tmp_path / 'report.json'
    original_generate, original_checkpoint = bench.generate, bench.checkpoint
    seen = []
    runtime = {'lease': Lease, 'free_bytes': lambda: 99999999999}
    monkeypatch.setattr(bench, 'load_runtime', lambda *args: runtime)
    monkeypatch.setattr(bench, 'model_identity', lambda model: {'ollama_version': '0.11.4', 'digest': 'a' * 64})
    def request(method, api_path, body=None, timeout=10):
        if api_path == '/api/chat':
            return {'done': True, 'done_reason': 'length', 'message': {'content': '<think>PRIVATE REASONING'}}
        return good_request(method, api_path, body, timeout)
    monkeypatch.setattr(bench, 'generate', lambda *args: original_generate(*args, request=request))
    def capture_checkpoint(destination, report):
        seen.append(len(report['results']))
        original_checkpoint(destination, report)
    monkeypatch.setattr(bench, 'checkpoint', capture_checkpoint)
    argv = ['evaluate-assistant.py', '--model', 'deepseek-r1:7b', '--gateway-root', str(ROOT / 'deepct-model-server'),
            '--gpu-lease-path', str(tmp_path / 'gpu.lock'), '--min-free-mib', '1', '--report', str(path)]
    monkeypatch.setattr(bench.sys, 'argv', argv)
    assert bench.main() == 0
    report = json.loads(path.read_text())
    assert report['case_count'] == 40
    assert report['rule_pass_count'] == 0
    assert report['status'] == 'completed_pending_manual_review'
    assert report['manual_review_required'] is True and report['activation'] is False
    assert all(result['error_code'] == 'invalid_output' for result in report['results'])
    assert seen == [0, *range(1, 41), 40]
    assert 'PRIVATE' not in path.read_text() + capsys.readouterr().out
    # Resume a persisted prefix from an interrupted process; no activation path exists.
    report['results'] = report['results'][:3]
    report['status'] = 'in_progress'
    original_checkpoint(path, report)
    monkeypatch.setattr(bench.sys, 'argv', argv + ['--resume'])
    assert bench.main() == 0
    assert len(json.loads(path.read_text())['results']) == 40
    assert json.loads(path.read_text())['activation'] is False


def test_failed_report_cannot_automatically_retry(tmp_path):
    path = tmp_path / 'report.json'
    report = bench.new_report('deepseek-r1:7b', 'abc', {})
    report['status'] = 'failed'
    bench.checkpoint(path, report)
    with pytest.raises(bench.BenchmarkError, match='report_mismatch'):
        bench.recover_report(path, report['identity'])


def test_provider_transport_fixed_loopback_and_error_redaction(monkeypatch):
    opened = []
    class Connection:
        def __init__(self, host, port, timeout):
            opened.append((host, port))
        def request(self, *args): pass
        def getresponse(self): return self
        status = 500
        def read(self, limit): return b'PRIVATE PROVIDER REASONING'
        def close(self): pass
    monkeypatch.setattr(bench.http.client, 'HTTPConnection', Connection)
    with pytest.raises(bench.BenchmarkError, match='^provider_unavailable$'):
        bench.provider_request('GET', '/api/ps')
    assert opened == [('127.0.0.1', 11435)]


@pytest.mark.parametrize('source', [None, 'private raw text', {'type': 'analysis_record'},
    {'type': 'document', 'id': 'arbitrary-url', 'version': 'x', 'title': 'x', 'text': 'x'}, {'type': 'log', 'content': 'raw'}])
def test_malformed_source_corpus_rejected(tmp_path, source):
    rows = [case(id=str(i), question=f'Question {i}') for i in range(40)]
    rows[0]['sources'] = [source]
    path = tmp_path / 'cases.json'
    path.write_text(json.dumps({'schema_version': 1, 'synthetic': True, 'cases': rows}))
    with pytest.raises(bench.BenchmarkError, match='invalid_corpus'):
        bench.load_cases(path)
