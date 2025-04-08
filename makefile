# Define variables
BIN_DIR = bin
TARGET_DIR = dfzf-daemon/target/release
ARCHIVE_NAME = dfzf_binaries.tar.gz
DEST_DIR = dfzf

# List all executable files in the bin and target directories
EXEC_BINS = $(shell find  $(BIN_DIR) $(TARGET_DIR) -maxdepth 1 -type f  -executable)

# Build target: Create a tar.gz archive with only executable files
.PHONY: build
build: $(ARCHIVE_NAME)

$(ARCHIVE_NAME): $(EXEC_BINS)
	@echo "Creating tar.gz archive with executable binaries..."
	@mkdir -p $(DEST_DIR)
	@cp $(EXEC_BINS) $(DEST_DIR)/
	@tar -czf $(ARCHIVE_NAME) -C $(DEST_DIR) .
	@rm -rf $(DEST_DIR)
	@echo "Archive $(ARCHIVE_NAME) created."

# Clean up generated files
.PHONY: clean
clean:
	rm -f $(ARCHIVE_NAME)

