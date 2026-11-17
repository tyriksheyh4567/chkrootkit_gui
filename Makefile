.DEFAULT_GOAL := help
FLUTTER ?= flutter
PYTHON ?= python3
FORMAT ?= none
MODE ?= release
JOBS ?= 4
TUI_PYTHON := .venv-tui/bin/python

.PHONY: help tui build service package test clean-tui
help:
	@printf 'make tui       — interactive build manager\nmake build     — Linux application + service\nmake service   — C++ service\nmake package FORMAT=deb|rpm|appimage|pkg.tar.zst|all\nmake test      — checks and tests\n'

.venv-tui/.ready: tools/requirements-tui.txt
	$(PYTHON) -m venv .venv-tui
	$(TUI_PYTHON) -m pip install -r tools/requirements-tui.txt
	@touch $@

tui: .venv-tui/.ready
	$(TUI_PYTHON) tools/build_manager.py

build:
	bash tools/build_backend.sh --target app --mode "$(MODE)" --jobs "$(JOBS)" --flutter "$(FLUTTER)"
service:
	bash tools/build_backend.sh --target service --mode "$(MODE)" --jobs "$(JOBS)"
package:
	bash tools/build_backend.sh --target app --mode release --jobs "$(JOBS)" --flutter "$(FLUTTER)" --package "$(FORMAT)"
test:
	$(FLUTTER) pub get
	$(FLUTTER) analyze
	$(FLUTTER) test
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py'
clean-tui:
	rm -rf .venv-tui
