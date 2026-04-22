.PHONY: build install uninstall run clean

build:
	bash scripts/build-app-bundle.sh

install: build
	rm -rf /Applications/Pitwall.app
	cp -R build/Pitwall.app /Applications/
	codesign --verify --verbose /Applications/Pitwall.app
	@echo "Open Pitwall from /Applications — it will appear in your menu bar."

uninstall:
	-/Applications/Pitwall.app/Contents/MacOS/PitwallApp --unregister-login-item
	rm -rf /Applications/Pitwall.app
	@echo "Pitwall.app removed from /Applications."
	@echo "Application Support (~/Library/Application Support/Pitwall/) and Keychain items are preserved."

run: build
	open build/Pitwall.app

clean:
	rm -rf build/
