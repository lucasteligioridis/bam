INSTALL_DIR=/usr/local/bin
.PHONY: install, all

all:
	@echo "Please run 'make install'"

install:
	@cp bam.sh ${INSTALL_DIR}/bam
	@read -p "Enter your default regions (space separated):" regions; \
	echo $${regions} > $${HOME}/.bam.conf
	@echo "Installing binaries into ${INSTALL_DIR} directory"
	@echo ""
	@echo "bam has successfully installed"
	@echo "type bam --help to get started"
