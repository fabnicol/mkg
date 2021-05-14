INSTALL_DIR=/usr/bin/mkg

.PHONY: all scripts_install clonezilla_install uninstall

all: 

clonezilla_install: clonezilla/restoredisk/isolinux.cfg clonezilla/savedisk/isolinux.cfg clonezilla/syslinux/isohdpfx.bin clonezilla/syslinux/isolinux.cfg
	[ ! -d $(INSTALL_DIR) ] && mkdir -p $(INSTALL_DIR) || true
	cp -rf clonezilla/ $(INSTALL_DIR)

scripts_install: scripts/*.sh
	[ ! -d $(INSTALL_DIR)/scripts ] && mkdir -p $(INSTALL_DIR)/scripts || true 
	cp -rf $^ $(INSTALL_DIR)/scripts

config_install: mkg .config ebuilds.list.minimal ebuilds.list.complete ebuilds.list.accept_keywords options options2 
	[ ! -d $(INSTALL_DIR) ] && mkdir -p $(INSTALL_DIR) || true
	cp -f $^ $(INSTALL_DIR)

install: clonezilla_install scripts_install config_install

uninstall: 
	rm -rf /usr/bin/mkg
