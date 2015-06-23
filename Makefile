
softinstall install: isroot install_require install_wub
	cp -an conf/* /etc/.
	(cd lib; for d in *; do rm -rf /usr/local/lib/$$d; ln -sf -T $$PWD/$$d /usr/local/lib/$$d; done)
	(cd bkr; for f in *; do ln -sf -T $$PWD/$$f /usr/local/bin/$$f; done)
	(cd utils; for f in *; do ln -sf -T $$PWD/$$f /usr/local/bin/$$f; done)
	(cd www; for f in *; do ln -sf -T $$PWD/$$f /opt/wub/docroot/$$f; done)

hardinstall: isroot install_require install_wub
	cp -an conf/* /etc/.
	cd lib; for d in *; do rm -fr /usr/local/lib/$$d; done
	cp -arf lib/* /usr/local/lib/.
	cp -afl bkr/* utils/* /usr/local/bin/.
	cp -afl www/* /opt/wub/docroot/.

install_wub: isroot install_tclsh8.6
	@[ -d /opt/wub ] || { \
	wget http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/wub.tar.bz2 -O /opt/wub.tar.bz2; \
	tar jxf /opt/wub.tar.bz2 -C /opt; }

install_tclsh8.6: isroot
	@which tclsh8.6 || { yum install gcc && ./utils/tcl8.6_install.sh && ./utils/tcllib_install.sh && ./utils/tdom_install.sh; }

install_require: isroot
	@rpm -q tcl || yum install -y tcl #package that in default RHEL repo
	@rpm -q tcl-devel || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite || yum install -y sqlite #package that in default RHEL repo
	@rpm -q procmail || yum install -y procmail #package that in default RHEL repo
	@rpm -q sqlite-tcl || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo
	@yum install -y tcllib || [ -d /usr/lib/tcllib[0-9]* ] || { yum install -y gcc && ./utils/tcllib_install.sh; }
	@yum install -y tdom   || [ -d /usr/local/lib/tdom[0-9]* ] || { yum install -y gcc && ./utils/tdom_install.sh; }

rpm: isroot
	./build_rpm.sh

isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
