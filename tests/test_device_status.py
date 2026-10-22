"""Read-only inventory fixtures; never execute profiles, tools, or clusters."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import device_status as ds


class DeviceStatusTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'repo'
        self.docs = Path(self.tmp.name) / 'redirected-documents'
        self.root.mkdir()
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts/environment.py').write_text('', encoding='utf-8')
        self.docs.mkdir()
        (self.root / '.local').mkdir()
        (self.root / 'powershell').mkdir()
        for name in ('aliases.ps1', 'git-completion.ps1', 'psmux.ps1',
                     'tab-completion.ps1', 'ssh-completion.ps1', 'ssh-fzf.ps1',
                     'history-fzf.ps1', 'prompt.omp.json'):
            (self.root / 'powershell' / name).write_text('', encoding='utf-8')
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, {}, clear=True).start()
        patch.object(ds.env, 'host_name', return_value='fixture-host').start()
        patch.object(ds.env.platform, 'system', return_value='Windows').start()
        patch.object(ds.env.platform, 'release', return_value='generic').start()
        patch.object(ds.env.platform, 'version', return_value='generic').start()
        patch.object(Path, 'home', return_value=Path(self.tmp.name) / 'home').start()
        patch.object(ds.shutil, 'which', return_value=None).start()
        patch.object(ds.env, 'inspect_existing', return_value={'configuration': []}).start()
        patch.object(ds, 'documents_directory', return_value=self.docs).start()
        patch.object(subprocess, 'run', side_effect=AssertionError('external execution forbidden')).start()
        patch.object(subprocess, 'Popen', side_effect=AssertionError('external execution forbidden')).start()
        patch.object(os, 'system', side_effect=AssertionError('shell execution forbidden')).start()

    def profile(self, text):
        path = self.docs / 'PowerShell/Microsoft.PowerShell_profile.ps1'
        path.parent.mkdir(exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def statuses(self, report=None):
        rows = report['checks'] if report else ds.profile_checks(self.root, self.docs)
        return {row['component']: row['status'] for row in rows}

    def record(self, filename, **extra):
        data = dict(schemaVersion=1, environment='windows-powershell',
                    host='fixture-host', components={})
        data.update(extra)
        (self.root / '.local' / filename).write_text(json.dumps(data), encoding='utf-8')

    def test_redirected_documents_used_and_lookup_failure_not_guessed(self):
        self.profile(". '" + str(self.root / 'powershell/aliases.ps1') + "'")
        self.assertEqual(self.statuses(ds.collect(self.root))['profile.PowerShell.aliases'], 'reference-found')
        with patch.object(ds, 'documents_directory', side_effect=OSError('private-secret')):
            report = ds.collect(self.root)
        self.assertEqual(self.statuses(report)['profiles'], 'unknown')
        self.assertNotIn('private-secret', json.dumps(report))

    def test_documents_api_uses_redirected_path_and_rejects_failure(self):
        # setUp replaces the lookup for inventory safety; inspect the real function
        # via its saved class-level reference without consulting Windows itself.
        def redirected(_window, folder, _token, flags, buffer):
            self.assertEqual((folder, flags), (5, 0))
            buffer.value = str(self.docs)
            return 0
        api = SimpleNamespace(shell32=SimpleNamespace(SHGetFolderPathW=redirected))
        with patch.object(ds.ctypes, 'windll', api, create=True):
            self.assertEqual(REAL_DOCUMENTS_DIRECTORY(), self.docs)
        api.shell32.SHGetFolderPathW = lambda *_args: 1
        with patch.object(ds.ctypes, 'windll', api, create=True):
            with self.assertRaises(OSError):
                REAL_DOCUMENTS_DIRECTORY()

    def test_literal_expected_wrong_duplicate_and_dynamic_loaders(self):
        source = self.root / 'powershell/aliases.ps1'
        cases = [(f". '{source}'", 'reference-found'),
                 (f". '{self.root / 'elsewhere/aliases.ps1'}'", 'mismatch'),
                 (f". '{source}'\n. '{source}'", 'mismatch'),
                 ('. "$repo/powershell/aliases.ps1"', 'unknown')]
        for text, expected in cases:
            with self.subTest(text=text):
                self.profile(text)
                self.assertEqual(self.statuses()['profile.PowerShell.aliases'], expected)

    def test_comments_and_here_strings_are_not_loaders(self):
        loader = f". '{self.root / 'powershell/aliases.ps1'}'"
        for text in ('# ' + loader, '<#\n' + loader + '\n#>',
                     "$text = @'\n" + loader + "\n'@", '$text = @"\n' + loader + '\n"@'):
            with self.subTest(text=text):
                self.profile(text)
                self.assertEqual(self.statuses()['profile.PowerShell.aliases'], 'missing')

    def test_quoted_or_escaped_comment_token_does_not_hide_later_loader(self):
        loader = f". '{self.root / 'powershell/aliases.ps1'}'"
        for prefix in ("Write-Host '<#'", 'Write-Host "<#"',
                       "Write-Host 'it''s <#'", 'Write-Host "`"<#"',
                       'Write-Host `<#', '# explanation contains <#'):
            with self.subTest(prefix=prefix):
                self.profile(prefix + '\n' + loader)
                self.assertEqual(self.statuses()['profile.PowerShell.aliases'], 'reference-found')

    def test_utf16_profile_literal_loader(self):
        self.profile('')
        path = self.docs / 'PowerShell/Microsoft.PowerShell_profile.ps1'
        path.write_bytes((f"# UTF16 profile\n. '{self.root / 'powershell/aliases.ps1'}'").encode('utf-16'))
        self.assertEqual(self.statuses()['profile.PowerShell.aliases'], 'reference-found')

    def test_terminal_directory_link_target_vs_independent_copy(self):
        source_dir = self.root / 'windows-terminal'
        source_dir.mkdir()
        source = source_dir / 'settings.json'
        source.write_text('{}', encoding='utf-8')
        localapp = Path(self.tmp.name) / 'LocalAppData'
        channel = localapp / 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'
        channel.parent.mkdir(parents=True)
        channel.write_text('{}', encoding='utf-8')
        with patch.dict(os.environ, {'LOCALAPPDATA': str(localapp)}):
            self.assertEqual(self.statuses(ds.collect(self.root))['windows-terminal.stable'], 'mismatch')
            # Simulate directory-junction resolution without requiring link privileges.
            resolve = Path.resolve
            def linked_resolve(path, *args, **kwargs):
                return resolve(source if path == channel else path, *args, **kwargs)
            with patch.object(Path, 'resolve', linked_resolve):
                self.assertEqual(self.statuses(ds.collect(self.root))['windows-terminal.stable'], 'reference-found')

    def test_prompt_explicit_different_source_and_missing_dependency(self):
        self.profile(f"oh-my-posh init pwsh --config '{self.root / 'custom.json'}' | Invoke-Expression\n"
                     f". '{self.root / 'powershell/tab-completion.ps1'}'")
        (self.root / 'powershell/history-fzf.ps1').unlink()
        statuses = self.statuses()
        self.assertEqual(statuses['profile.PowerShell.prompt'], 'mismatch')
        self.assertEqual(statuses['profile.PowerShell.history-fzf.ps1'], 'missing')
        (self.root / 'powershell/tab-completion.ps1').unlink()
        self.assertEqual(self.statuses()['profile.PowerShell.tab'], 'missing')

    def test_four_environments_only_windows_inspects_windows_paths(self):
        for system, release, expected in [('Windows', 'generic', 'windows-powershell'),
                                          ('Darwin', 'generic', 'macos'),
                                          ('Linux', 'microsoft', 'windows-wsl'),
                                          ('Linux', 'generic', 'linux')]:
            with self.subTest(environment=expected), patch.object(ds.env.platform, 'system', return_value=system), \
                    patch.object(ds.env.platform, 'release', return_value=release), \
                    patch.object(ds, 'documents_directory', return_value=self.docs) as lookup, \
                    patch.object(ds, 'profile_checks', return_value=[]) as profiles:
                report = ds.collect(self.root)
                self.assertEqual(report['environment'], expected)
                self.assertEqual(lookup.call_count, int(expected == 'windows-powershell'))
                self.assertEqual(profiles.call_count, int(expected == 'windows-powershell'))
                if expected != 'windows-powershell':
                    self.assertFalse(any(c['component'].startswith(('windows-terminal', 'mux.', 'autohotkey', 'profile.')) for c in report['checks']))

    def test_host_free_aliases_does_not_validate_foreign_setup_state(self):
        for filename in ('setup-state.json', 'powershell-aliases.json'):
            self.record(filename, host='foreign-host')
        statuses = self.statuses(ds.collect(self.root))
        self.assertEqual(statuses['record.setup-state.json'], 'mismatch')
        self.assertEqual(statuses['record.powershell-aliases.json'], 'present')

    def test_missing_invalid_schema_and_environment_records(self):
        check = lambda: ds.record_check(self.root, 'setup-state.json', 'windows-powershell')
        self.assertEqual(check()['status'], 'missing')
        path = self.root / '.local/setup-state.json'
        for content in ('private-secret', '[]', '{"components":{ },"schemaVersion":true}'):
            path.write_text(content, encoding='utf-8')
            result = check()
            self.assertEqual(result['status'], 'unknown')
            self.assertNotIn('private-secret', json.dumps(result))
        self.record('setup-state.json', environment='macos')
        self.assertEqual(check()['status'], 'mismatch')

    def test_linked_state_refused_before_read(self):
        original = Path.is_symlink
        for target in (self.root / '.local/setup-state.json', self.root / '.local'):
            with self.subTest(target=target), \
                    patch.object(Path, 'is_symlink', lambda path: path == target or original(path)), \
                    patch.object(ds, 'read_text', side_effect=AssertionError('linked record read')):
                self.assertEqual(ds.record_check(self.root, 'setup-state.json', 'windows-powershell')['status'], 'unknown')

    def test_selection_missing_matching_foreign_and_invalid(self):
        self.assertEqual(self.statuses(ds.collect(self.root))['environment.selection'], 'missing')
        for selection, expected in [({'host': 'fixture-host', 'environment': 'windows-powershell'}, 'present'),
                                     ({'host': 'foreign-host', 'environment': 'windows-powershell'}, 'mismatch'),
                                     ({'host': 'fixture-host', 'environment': 'macos'}, 'mismatch')]:
            with patch.object(ds.env, 'read_selection', return_value=selection):
                self.assertEqual(self.statuses(ds.collect(self.root))['environment.selection'], expected)
        with patch.object(ds.env, 'read_selection', side_effect=ds.env.EnvironmentError('private-secret')):
            report = ds.collect(self.root)
            self.assertEqual(self.statuses(report)['environment.selection'], 'unknown')
            self.assertNotIn('private-secret', json.dumps(report))

    def test_mux_disabled_missing_foreign_and_invalid(self):
        self.assertEqual(ds.mux_check(self.root)['status'], 'unknown')
        path = self.root / '.local/psmux.json'
        for data, expected in [({'schemaVersion': 1, 'enabled': False, 'host': 'fixture-host'}, 'not-selected'),
                               ({'schemaVersion': 1, 'enabled': True, 'host': 'fixture-host'}, 'present'),
                               ({'schemaVersion': 1, 'enabled': True, 'host': 'foreign'}, 'mismatch'),
                               ({'schemaVersion': 1, 'enabled': 'true'}, 'unknown')]:
            path.write_text(json.dumps(data), encoding='utf-8')
            self.assertEqual(ds.mux_check(self.root)['status'], expected)

    def test_collect_never_writes_or_executes(self):
        self.profile('# fixture profile')
        snapshot = lambda: {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        before = snapshot()
        with patch.object(Path, 'write_text', side_effect=AssertionError('write forbidden')), \
                patch.object(Path, 'write_bytes', side_effect=AssertionError('write forbidden')), \
                patch.object(Path, 'mkdir', side_effect=AssertionError('mkdir forbidden')), \
                patch.object(Path, 'unlink', side_effect=AssertionError('delete forbidden')), \
                patch.object(Path, 'rename', side_effect=AssertionError('rename forbidden')), \
                patch.object(Path, 'replace', side_effect=AssertionError('replace forbidden')), \
                patch.object(ds.env, 'write_selection', side_effect=AssertionError('state write forbidden'), create=True):
            report = ds.collect(self.root)
        self.assertEqual(before, snapshot())
        self.assertTrue(report['readOnly'])
        self.assertTrue(all(not row['runtimeVerified'] for row in report['checks']))

    def test_main_json_text_and_safe_errors(self):
        for args in (['--json'], []):
            output, errors = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                self.assertEqual(ds.main(['--repo', str(self.root)] + args), 0)
            if args:
                self.assertTrue(json.loads(output.getvalue())['readOnly'])
            else:
                self.assertIn('READ ONLY', output.getvalue())
        for args in (['--json'], []):
            output, errors = io.StringIO(), io.StringIO()
            with patch.object(ds, 'collect', side_effect=OSError('private-secret')), \
                    contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                self.assertEqual(ds.main(args), 2)
            self.assertNotIn('private-secret', output.getvalue() + errors.getvalue())
            if args:
                self.assertIn('error', json.loads(output.getvalue()))


REAL_DOCUMENTS_DIRECTORY = ds.documents_directory

if __name__ == '__main__':
    unittest.main()
