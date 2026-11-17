"""Native launch tests use fake scanners, never root scans or system installs."""
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest

PROJECT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('g++'), 'g++ missing')
class ServiceLaunchTest(unittest.TestCase):
    def test_symlinked_user_scanner_cwd_literal_arguments_and_validation(self):
        with tempfile.TemporaryDirectory(prefix='chk service ') as tmp:
            root = pathlib.Path(tmp)
            home = root / 'home'
            local = home / '.local/bin'
            local.mkdir(parents=True)
            release = root / 'release комплект'
            release.mkdir()
            scanner = release / 'chkrootkit'
            scanner.write_text('#!/bin/sh\nprintf "PWD=%s\\nARG=%s\\n" "$PWD" "$1"\nif read -r line; then echo BAD_STDIN; fi\nexit 0\n')
            scanner.chmod(0o755)
            link = local / 'chkrootkit'
            link.symlink_to(scanner)
            harness = root / 'harness.cc'
            harness.write_text('#define main helper_main\n#include "' + str(PROJECT / 'service/rootkit_service.cc') + '"\n#undef main\n' + r'''
#include <cassert>
int main(int argc, char** argv) {
  assert(argc == 4);
  std::string home = argv[1], path = argv[2], canonical = argv[3], cwd, error;
  std::vector<std::string> command;
  assert(AllowedScanPath("chkrootkit", path, home));
  assert(!AllowedScanPath("chkrootkit", home + "/.local/bin/other", home));
  assert(!AllowedScanPath("chkrootkit", "/tmp/chkrootkit", home));
  assert(PrepareScan("chkrootkit", path, "", &command, &cwd, &error, home));
  assert(command[0] == canonical);
  assert(AddScanRoot("chkrootkit", home, &command, &error));
  assert(command[command.size() - 2] == "-r");
  assert(command.back() == home);
  assert(!AddScanRoot("rkhunter", home, &command, &error));
  assert(!AddScanRoot("chkrootkit", home + "/missing", &command, &error));
  assert(!AddScanRoot("chkrootkit", "relative", &command, &error));
  assert(cwd == canonical.substr(0, canonical.find_last_of('/')));
  const auto result = RunCommand({command[0], "literal; touch NEVER_EXECUTE"}, cwd);
  assert(result.exit_code == 0);
  assert(result.output.find("PWD=" + cwd) != std::string::npos);
  assert(result.output.find("ARG=literal; touch NEVER_EXECUTE") != std::string::npos);
  assert(result.output.find("BAD_STDIN") == std::string::npos);
  assert(!PrepareScan("chkrootkit", path, "relative", &command, &cwd, &error, home));
  assert(!PrepareScan("chkrootkit", path, home + "/missing", &command, &cwd, &error, home));
  assert(!PrepareScan("unknown", path, "", &command, &cwd, &error, home));
}
''')
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(harness), '-o', str(root / 'check')], check=True, capture_output=True)
            subprocess.run([str(root / 'check'), str(home), str(link), str(scanner)], check=True)
            self.assertFalse((release / 'NEVER_EXECUTE').exists())

    def test_protocol_rejects_unknown_tools_and_executables(self):
        with tempfile.TemporaryDirectory() as tmp:
            binary = pathlib.Path(tmp) / 'service'
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(PROJECT / 'service/rootkit_service.cc'), '-o', str(binary)], check=True, capture_output=True)
            requests = [dict(id=1, op='scan', tool='unknown'), dict(id=2, op='scan', tool='chkrootkit', executable='/tmp/chkrootkit')]
            result = subprocess.run([str(binary)], input='\n'.join(map(json.dumps, requests)) + '\n', text=True, capture_output=True, check=True)
            messages = list(map(json.loads, result.stdout.splitlines()))
            self.assertTrue(messages[0]['ready'])
            for index, response in enumerate(messages[1:], 1):
                self.assertEqual(response['id'], index)
                self.assertIn('error', response)


if __name__ == '__main__':
    unittest.main()
