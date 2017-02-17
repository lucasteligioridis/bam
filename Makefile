INSTALL_DIR=/usr/local/bin
.PHONY: install, all

all:
	@echo "Please run 'make install'"

install:
	@echo "Installing binaries into ${INSTALL_DIR} directory"
	@cp bam.sh ${INSTALL_DIR}/bam
	@echo ""
	@echo "bam has successfully installed"
	@echo "type bam --help to get started"
