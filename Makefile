.PHONY: build clean test lint format open

# Default target
all: build

# Build the project
build:
	xcodebuild -project OpenSCADApp/OpenSCADApp.xcodeproj \
		-scheme OpenSCADApp \
		-configuration Debug \
		-destination 'platform=macOS' \
		build

# Build for release
release:
	xcodebuild -project OpenSCADApp/OpenSCADApp.xcodeproj \
		-scheme OpenSCADApp \
		-configuration Release \
		-destination 'platform=macOS' \
		build

# Clean build artifacts
clean:
	xcodebuild -project OpenSCADApp/OpenSCADApp.xcodeproj \
		-scheme OpenSCADApp \
		clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/OpenSCADApp-*

# Run tests
test:
	xcodebuild -project OpenSCADApp/OpenSCADApp.xcodeproj \
		-scheme OpenSCADApp \
		-destination 'platform=macOS' \
		test

# Lint Swift files using SwiftLint (if available)
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --path OpenSCADApp/OpenSCADApp; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Format Swift files using swift-format (if available)
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		find OpenSCADApp/OpenSCADApp -name "*.swift" -exec swift-format -i {} \; ; \
	else \
		echo "swift-format not installed. Install with: brew install swift-format"; \
	fi

# Open project in Xcode
open:
	open OpenSCADApp/OpenSCADApp.xcodeproj

# Archive for distribution
archive:
	xcodebuild -project OpenSCADApp/OpenSCADApp.xcodeproj \
		-scheme OpenSCADApp \
		-configuration Release \
		-archivePath build/OpenSCADApp.xcarchive \
		archive

# Help
help:
	@echo "Available targets:"
	@echo "  build    - Build the project in Debug configuration"
	@echo "  release  - Build the project in Release configuration"
	@echo "  clean    - Clean build artifacts"
	@echo "  test     - Run unit tests"
	@echo "  lint     - Lint Swift files (requires SwiftLint)"
	@echo "  format   - Format Swift files (requires swift-format)"
	@echo "  open     - Open project in Xcode"
	@echo "  archive  - Create archive for distribution"
	@echo "  help     - Show this help message"
