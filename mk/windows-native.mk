# Native Windows (MSYS2 UCRT64) builds. Tries to mirror the Docker Windows workflow locally.

WINDOWS_NATIVE_BUILD_DIR ?= build/native-windows-$(CONFIG)
WINDOWS_NATIVE_PREFIX ?= $(shell cygpath -m "$(MINGW_PREFIX)" 2>/dev/null || echo /c/msys64/ucrt64)
WINDOWS_NATIVE_QT_PLUGINS ?= $(WINDOWS_NATIVE_PREFIX)/share/qt5/plugins
WINDOWS_NATIVE_ASSETS_DIR ?= build/assets

.PHONY: win-native win-native-client win-native-clients _windows-native-configure _windows-native-assets _windows-native-build _windows-native-build-client _windows-native-deploy _windows-native-deploy-client

ifeq ($(MSYSTEM),UCRT64)

# Configure CMake for MSYS2 UCRT64.

_windows-native-configure:
	@test -x "$(WINDOWS_NATIVE_PREFIX)/bin/c++.exe" || { echo 'MSYS2 UCRT64 toolchain not found. Install it or set WINDOWS_NATIVE_PREFIX.' >&2; exit 1; }
	$(CMAKE) -S . -B "$(WINDOWS_NATIVE_BUILD_DIR)" -G "$(GENERATOR)" \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DCMAKE_PREFIX_PATH="$(WINDOWS_NATIVE_PREFIX)" \
		-DAU_OUTPUT_ROOT="$(abspath $(WINDOWS_NATIVE_BUILD_DIR))"

# Build hashpack and generate sfx.har if needed.

_windows-native-assets: _windows-native-configure
	$(CMAKE) --build "$(WINDOWS_NATIVE_BUILD_DIR)" --target hashpack --parallel "$(PARALLEL)"
	@if [ ! -s "$(WINDOWS_NATIVE_ASSETS_DIR)/sfx.har" ]; then \
		mkdir -p "$(WINDOWS_NATIVE_ASSETS_DIR)"; \
		cd resources/audio/source && \
		"$(abspath $(WINDOWS_NATIVE_BUILD_DIR))/bin/hashpack.exe" -c "$(abspath $(WINDOWS_NATIVE_ASSETS_DIR))/sfx.har.tmp" "*.wav" && \
		test -s "$(abspath $(WINDOWS_NATIVE_ASSETS_DIR))/sfx.har.tmp" && \
		mv "$(abspath $(WINDOWS_NATIVE_ASSETS_DIR))/sfx.har.tmp" "$(abspath $(WINDOWS_NATIVE_ASSETS_DIR))/sfx.har"; \
	fi

# Build Windows clients.

_windows-native-build: _windows-native-assets
	$(CMAKE) --build "$(WINDOWS_NATIVE_BUILD_DIR)" --target clients --parallel "$(PARALLEL)"

# Build only the Windows scene client.

_windows-native-build-client: _windows-native-assets
	$(CMAKE) --build "$(WINDOWS_NATIVE_BUILD_DIR)" --target AuSceneClient --parallel "$(PARALLEL)"

# Deploy Qt, MSYS2 and plugin runtime dependencies.

_windows-native-deploy: _windows-native-build
	@for exe in AuSceneClient AuMailClient AuChatClient AuLauncher; do \
		if [ -f "$(WINDOWS_NATIVE_BUILD_DIR)/bin/$$exe.exe" ]; then \
			"$(WINDOWS_NATIVE_PREFIX)/bin/windeployqt-qt5.exe" --release "$(WINDOWS_NATIVE_BUILD_DIR)/bin/$$exe.exe" >/dev/null 2>&1 || true; \
		fi; \
	done
	cp "$(WINDOWS_NATIVE_PREFIX)/bin/"*.dll "$(WINDOWS_NATIVE_BUILD_DIR)/bin/"
	mkdir -p "$(WINDOWS_NATIVE_BUILD_DIR)/bin/platforms" \
		"$(WINDOWS_NATIVE_BUILD_DIR)/bin/imageformats" \
		"$(WINDOWS_NATIVE_BUILD_DIR)/bin/styles"
	cp "$(WINDOWS_NATIVE_QT_PLUGINS)/platforms/qwindows.dll" "$(WINDOWS_NATIVE_BUILD_DIR)/bin/platforms/"
	cp "$(WINDOWS_NATIVE_QT_PLUGINS)/imageformats/"*.dll "$(WINDOWS_NATIVE_BUILD_DIR)/bin/imageformats/"
	cp "$(WINDOWS_NATIVE_QT_PLUGINS)/styles/"*.dll "$(WINDOWS_NATIVE_BUILD_DIR)/bin/styles/"
	@echo "Windows native artifacts: $(WINDOWS_NATIVE_BUILD_DIR)"

# Deploy runtime dependencies for the Windows scene client only.

_windows-native-deploy-client: _windows-native-build-client
	"$(WINDOWS_NATIVE_PREFIX)/bin/windeployqt-qt5.exe" --release "$(WINDOWS_NATIVE_BUILD_DIR)/bin/AuSceneClient.exe" >/dev/null 2>&1 || true
	cp "$(WINDOWS_NATIVE_PREFIX)/bin/"*.dll "$(WINDOWS_NATIVE_BUILD_DIR)/bin/"
	mkdir -p "$(WINDOWS_NATIVE_BUILD_DIR)/bin/platforms" \
		"$(WINDOWS_NATIVE_BUILD_DIR)/bin/imageformats" \
		"$(WINDOWS_NATIVE_BUILD_DIR)/bin/styles"
	cp "$(WINDOWS_NATIVE_QT_PLUGINS)/platforms/qwindows.dll" "$(WINDOWS_NATIVE_BUILD_DIR)/bin/platforms/"
	cp "$(WINDOWS_NATIVE_QT_PLUGINS)/imageformats/"*.dll "$(WINDOWS_NATIVE_BUILD_DIR)/bin/imageformats/"
	cp "$(WINDOWS_NATIVE_QT_PLUGINS)/styles/"*.dll "$(WINDOWS_NATIVE_BUILD_DIR)/bin/styles/"
	@echo "Windows native client artifacts: $(WINDOWS_NATIVE_BUILD_DIR)"

win-native-clients: _windows-native-deploy

win-native-client: _windows-native-deploy-client

win-native: win-native-clients

else

# Not running in MSYS2 UCRT64.

win-native win-native-client win-native-clients:
	@echo "Run this target from an MSYS2 UCRT64 shell:" >&2
	@echo "  make win-native CONFIG=$(CONFIG)" >&2
	@exit 1

endif
