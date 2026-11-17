"""Interactive frontend; the same validated backend is used locally and in CI."""
from __future__ import annotations

import asyncio
import os
from pathlib import Path
import shlex
import signal

from textual.app import App, ComposeResult
from textual.containers import Horizontal, VerticalScroll
from textual.widgets import Button, Footer, Header, Input, Label, RichLog, Select, Static

ROOT = Path(__file__).resolve().parents[1]


def build_command(values: dict[str, str]) -> list[str]:
    target, mode, package = (values[k] for k in ('target', 'mode', 'package'))
    if target not in ('app', 'service') or mode not in ('debug', 'release'):
        raise ValueError('Choose a valid target and mode.')
    if package not in ('none', 'deb', 'rpm', 'appimage', 'pkg.tar.zst', 'all'):
        raise ValueError('Choose a valid package format.')
    jobs = values['jobs'].strip()
    if not jobs.isascii() or not jobs.isdecimal() or not 1 <= int(jobs) <= 256:
        raise ValueError('Parallel jobs must be an integer from 1 to 256.')
    if package != 'none' and (target != 'app' or mode != 'release'):
        raise ValueError('Packages require the app target in release mode.')
    if values['bundle'].strip() and (target != 'app' or package == 'none'):
        raise ValueError('An existing bundle requires app + a package format.')
    command = ['bash', str(ROOT / 'tools/build_backend.sh'), '--target', target,
               '--mode', mode, '--package', package, '--jobs', jobs]
    for field, flag in [('flutter', '--flutter'), ('output', '--output-dir'),
                        ('bundle', '--bundle-dir'), ('appimage', '--appimage-tool')]:
        value = values[field].strip()
        if '\x00' in value or '\n' in value:
            raise ValueError('Paths must not contain NUL or newline characters.')
        if value:
            command.extend((flag, os.path.expanduser(value)))
    return command


class BuildManager(App):
    TITLE = 'chkrootkit GUI · Build manager 1.0.0'
    CSS = '''
    Screen { layout: vertical; }
    #form { height: 17; padding: 0 2; }
    .row { height: 3; }
    .row Label { width: 22; content-align: left middle; }
    .row Input, .row Select { width: 1fr; }
    #actions { height: 3; padding: 0 2; }
    #status { height: 2; padding: 0 2; }
    RichLog { height: 1fr; border: round $accent; margin: 0 1; }
    '''
    BINDINGS = [('ctrl+b', 'build', 'Build'), ('ctrl+k', 'cancel', 'Cancel'),
                ('ctrl+q', 'quit', 'Quit')]
    process: asyncio.subprocess.Process | None = None

    def compose(self) -> ComposeResult:
        yield Header()
        with VerticalScroll(id='form'):
            for field, title, choices, default in [
                ('target', 'Target', ['app', 'service'], 'app'),
                ('mode', 'Mode', ['release', 'debug'], 'release'),
                ('package', 'Package', ['none', 'deb', 'rpm', 'appimage', 'pkg.tar.zst', 'all'], 'none')]:
                with Horizontal(classes='row'):
                    yield Label(title)
                    yield Select([(c, c) for c in choices], value=default, allow_blank=False, id=field)
            for field, title, value in [
                ('jobs', 'Parallel jobs (1–256)', str(min(os.cpu_count() or 4, 256))),
                ('flutter', 'Flutter executable', os.environ.get('FLUTTER_BIN', 'flutter')),
                ('output', 'Packages directory', 'build/packages'),
                ('bundle', 'Existing bundle (optional)', ''),
                ('appimage', 'appimagetool executable', os.environ.get('APPIMAGE_TOOL', 'appimagetool'))]:
                with Horizontal(classes='row'):
                    yield Label(title)
                    yield Input(value, id=field)
        with Horizontal(id='actions'):
            yield Button('Build', id='build', variant='primary')
            yield Button('Cancel', id='cancel', disabled=True)
            yield Button('Quit', id='quit')
        yield Static('Ready · Tab moves focus; scroll the form for packaging options.', id='status')
        yield RichLog(id='log', wrap=True, highlight=False)
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        {'build': self.action_build, 'cancel': self.action_cancel,
         'quit': self.action_quit}[event.button.id]()

    def action_build(self) -> None:
        if self.query_one('#build', Button).disabled:
            return
        values = {field: str(self.query_one('#' + field, Select).value)
                  for field in ('target', 'mode', 'package')}
        values.update({field: self.query_one('#' + field, Input).value
                       for field in ('jobs', 'flutter', 'output', 'bundle', 'appimage')})
        try:
            command = build_command(values)
        except ValueError as error:
            self.query_one('#status', Static).update(str(error))
            return
        self.query_one('#build', Button).disabled = True
        self.query_one('#cancel', Button).disabled = False
        self.query_one('#status', Static).update('Building…')
        self.query_one('#log', RichLog).write(shlex.join(command))
        self.run_worker(self.run_build(command), exclusive=True)

    async def run_build(self, command: list[str]) -> None:
        try:
            self.process = await asyncio.create_subprocess_exec(
                *command, cwd=ROOT, stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT, start_new_session=True)
            assert self.process.stdout
            async for line in self.process.stdout:
                self.query_one('#log', RichLog).write(line.decode(errors='replace').rstrip())
            code = await self.process.wait()
            self.query_one('#status', Static).update('Build complete.' if code == 0 else f'Build stopped (exit {code}). See the log.')
        except (OSError, ValueError) as error:
            self.query_one('#status', Static).update(f'Cannot start build: {error}')
        finally:
            self.process = None
            self.query_one('#build', Button).disabled = False
            self.query_one('#cancel', Button).disabled = True

    def action_cancel(self) -> None:
        process = self.process
        if process and process.returncode is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                return
            self.query_one('#status', Static).update('Cancelling…')
            self.set_timer(3, lambda: self.force_stop(process))

    @staticmethod
    def force_stop(process: asyncio.subprocess.Process) -> None:
        if process.returncode is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass

    async def on_unmount(self) -> None:
        process = self.process
        if process and process.returncode is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                await asyncio.wait_for(process.wait(), 3)
            except asyncio.TimeoutError:
                self.force_stop(process)
                await process.wait()
            except ProcessLookupError:
                pass

    def action_quit(self) -> None:
        if self.query_one('#build', Button).disabled and self.process is None:
            self.notify('The build is starting. Please wait before quitting.')
            return
        if self.process and self.process.returncode is None:
            self.action_cancel()
            self.notify('Build is stopping. Quit again after it stops.')
            return
        self.exit()


if __name__ == '__main__':
    BuildManager().run()
