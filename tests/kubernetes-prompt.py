"""Render the real Kubernetes segment with fixtures only; never contact a cluster."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    executable = shutil.which('oh-my-posh')
    if not executable:
        raise SystemExit('Existing oh-my-posh is required; nothing is installed')
    theme = json.loads((ROOT / 'powershell/prompt.omp.json').read_text(encoding='utf-8-sig'))
    segment = next(s for s in theme['blocks'][0]['segments'] if s['type'] == 'kubectl')
    fixture_theme = copy.deepcopy(theme)
    fixture_theme['blocks'] = [{'type': 'prompt', 'alignment': 'left', 'segments': [segment]}]
    fixture_theme.pop('streaming', None)
    fixture_theme.pop('tooltips', None)
    with tempfile.TemporaryDirectory(prefix='dotfiles-kube-prompt-') as directory:
        temp = Path(directory)
        config = temp / 'theme.json'
        config.write_text(json.dumps(fixture_theme), encoding='utf-8')
        kube = temp / 'config'
        marker = temp / 'kubectl-called.txt'
        # Even if discovery checks for kubectl, any attempted execution is a failure.
        (temp / 'kubectl.cmd').write_text('@echo off\r\necho called > "' + str(marker) + '"\r\nexit /b 73\r\n')
        env = {k: v for k, v in os.environ.items() if not k.startswith('POSH_')}
        env.update(KUBECONFIG=str(kube), POSH_CACHE_DIR=str(temp / 'cache'),
                   XDG_CACHE_HOME=str(temp / 'cache'), PATH=str(temp))

        def render():
            env['POSH_SESSION_ID'] = str(uuid.uuid4())
            result = subprocess.run([executable, 'print', 'primary', '--config', str(config),
                                     '--shell', 'pwsh', '--plain'], env=env, cwd=temp,
                                    capture_output=True, text=True, encoding='utf-8', timeout=20, check=True)
            assert not marker.exists(), 'Prompt executed kubectl instead of reading local kubeconfig'
            assert 'ERROR' not in result.stdout, 'Template/configuration error'
            return result.stdout

        def fixture(current, namespace='fixture-ns'):
            data = {'apiVersion': 'v1', 'kind': 'Config', 'current-context': current,
                    'clusters': [{'name': 'fixture-cluster', 'cluster': {'server': 'https://127.0.0.1:1'}},
                                 {'name': 'other-cluster', 'cluster': {'server': 'https://127.0.0.1:1'}}],
                    'contexts': [{'name': 'fixture-context', 'context': {'cluster': 'fixture-cluster', 'namespace': namespace}},
                                 {'name': 'other-context', 'context': {'cluster': 'other-cluster', 'namespace': 'other-ns'}}]}
            kube.write_text(json.dumps(data), encoding='utf-8')

        fixture('fixture-context')
        assert 'fixture-cluster:fixture-ns' in render(), 'Current cluster/namespace absent'
        fixture('fixture-context', '')
        assert 'fixture-cluster:default' in render(), 'Default namespace absent'
        fixture('other-context')
        output = render()
        assert 'other-cluster:other-ns' in output and 'fixture-cluster' not in output, 'Stale context'
        (temp / 'kubectl.cmd').unlink()
        fixture('fixture-context')
        assert 'fixture-cluster:fixture-ns' in render(), 'Local parsing unexpectedly requires kubectl'
        kube.unlink()
        assert '☸' not in render(), 'Missing kubeconfig should hide Kubernetes'
        kube.write_text('not: [valid', encoding='utf-8')
        assert '☸' not in render(), 'Malformed kubeconfig should hide Kubernetes'
        print('PASS: current cluster/namespace, default namespace, context switch, absent/malformed config; no kubectl execution')


if __name__ == '__main__':
    main()
