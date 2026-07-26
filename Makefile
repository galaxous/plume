# Makefile
BINARY_NAME=plumectl
ALIAS_NAME=plume
SCRIPT_NAME=bin/plumectl
INSTALL_PATH=/usr/local/bin/$(BINARY_NAME)
ALIAS_PATH=/usr/local/bin/$(ALIAS_NAME)

install:
	@chmod +x $(SCRIPT_NAME)
	@sudo ln -sf $(CURDIR)/$(SCRIPT_NAME) $(INSTALL_PATH)
	@sudo ln -sf $(INSTALL_PATH) $(ALIAS_PATH)
	@echo "Utility '$(BINARY_NAME)' installed to $(INSTALL_PATH)"
	@echo "Alias '$(ALIAS_NAME)' installed to $(ALIAS_PATH)"

uninstall:
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(ALIAS_PATH)
	@echo "Utility removed."
