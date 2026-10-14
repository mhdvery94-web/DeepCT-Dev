"""Local workflow graph regression checks (Python + PyYAML).

Exercise failed-job propagation and model-only trigger admission, rather than
comparing YAML source text. Run: python -m unittest discover -s .github/tests -v
"""
import fnmatch
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]


def workflow(name):
    return yaml.safe_load((ROOT / '.github/workflows' / name).read_text())


def ancestors(jobs, job):
    needs = jobs[job].get('needs', [])
    if isinstance(needs, str):
        needs = [needs]
    result = set(needs)
    for dependency in needs:
        result.update(ancestors(jobs, dependency))
    return result


class ReleaseGates(unittest.TestCase):
    def test_failed_cpu_gate_blocks_every_deployment_and_publication(self):
        for name, targets in (
            ('release.yml', ['vercel', 'raspi', 'publish']),
            ('web-next.yml', ['deploy']),
        ):
            jobs = workflow(name)['jobs']
            for target in targets:
                with self.subTest(workflow=name, target=target):
                    cpu_gates = {job for job, config in jobs.items()
                                 if config.get('uses') == './.github/workflows/model-cpu.yml'}
                    failed_jobs = cpu_gates or {'missing-cpu-gate'}
                    self.assertTrue(ancestors(jobs, target) & failed_jobs,
                                    f'{name}/{target} can run after CPU tests fail')

    def test_model_only_push_runs_next_verification_on_release_branches(self):
        config = workflow('web-next.yml')
        # PyYAML uses YAML 1.1 where the unquoted GitHub key "on" is boolean.
        trigger = config.get('on', config.get(True))['push']
        for branch in ('develop', 'staging', 'main'):
            with self.subTest(branch=branch):
                branch_matches = any(fnmatch.fnmatchcase(branch, p) for p in trigger['branches'])
                paths = trigger.get('paths')
                path_matches = paths is None or any(fnmatch.fnmatchcase(
                    'deepct-model-server/app/uploads.py', p) for p in paths)
                self.assertTrue(branch_matches and path_matches,
                                f'model-only {branch} push skips Next checks/deployment gates')


if __name__ == '__main__':
    unittest.main()
