KERNEL ?= $(shell uname -r)
KERNELDIR ?= /lib/modules/$(KERNEL)/build
LINUXINCLUDE := -I$(src)/include -I$(src)/include/uapi $(LINUXINCLUDE)

# make Kconfig conditionals always work
include $(KERNELDIR)/.config

ifeq ($(DEBUG),1)
DYNDBG = dyndbg=+p
endif

RPMBUILDOPTS = -bb --build-in-place \
               --define '_topdir /tmp/rpmbuild' \
               --define '_rpmdir .' \
               --define '_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm' \
               --define '_modules $(reverse)'

ifeq ($(BACKPORT_VERSION),)
ifneq ($(wildcard .git),)
BACKPORT_VERSION := $(shell git describe --always --tags --dirty | sed -E 's/^v//;s/([^-]*-g)/r\1/;s/-/./g;s/\.rc/rc/')
endif
endif

export BACKPORT_VERSION

ifndef CONFIG_REGMAP_MMIO
obj-m += regmap-mmio.o
endif

# modules to build (in insmod order)
ifndef CONFIG_REGMAP_SPI_AVMM
obj-m += regmap-spi-avmm.o
endif

obj-m += fpga-mgr.o
obj-m += fpga-bridge.o
obj-m += fpga-region.o
obj-m += fpga-image-load.o
obj-m += dfl.o
obj-m += dfl-fme.o
obj-m += dfl-afu.o
obj-m += dfl-intel-s10-iopll.o
obj-m += dfl-fme-mgr.o
obj-m += dfl-fme-region.o
obj-m += dfl-fme-br.o
obj-m += spi-altera-platform.o
obj-m += spi-altera-dfl.o
obj-m += dfl-hssi.o
obj-m += dfl-n3000-nios.o
obj-m += dfl-emif.o
obj-m += qsfp-mem.o
obj-m += intel-s10-phy.o
obj-m += intel-m10-bmc-core.o
obj-m += intel-m10-bmc-spi.o
obj-m += intel-m10-bmc-hwmon.o
obj-m += intel-m10-bmc-sec-update.o
obj-m += regmap-indirect-register.o
obj-m += s10hssi.o
obj-m += n5010-phy.o
obj-m += n5010-hssi.o
obj-m += intel-m10-bmc-pmci.o
obj-m += uio_dfl.o
obj-m += dfl-pci.o

regmap-mmio-y := drivers/base/regmap/regmap-mmio.o
regmap-spi-avmm-y := drivers/base/regmap/regmap-spi-avmm.o
dfl-y := drivers/fpga/dfl.o

dfl-afu-y := drivers/fpga/dfl-afu-main.o
dfl-afu-y += drivers/fpga/dfl-afu-region.o
dfl-afu-y += drivers/fpga/dfl-afu-dma-region.o
dfl-afu-y += drivers/fpga/dfl-afu-error.o

dfl-fme-y := drivers/fpga/dfl-fme-main.o
dfl-fme-y += drivers/fpga/dfl-fme-pr.o
dfl-fme-y += drivers/fpga/dfl-fme-perf.o
dfl-fme-y += drivers/fpga/dfl-fme-error.o

dfl-fme-br-y := drivers/fpga/dfl-fme-br.o
dfl-fme-mgr-y := drivers/fpga/dfl-fme-mgr.o
dfl-fme-region-y := drivers/fpga/dfl-fme-region.o
dfl-intel-s10-iopll-y := drivers/fpga/dfl-intel-s10-iopll.o
dfl-pci-y := drivers/fpga/dfl-pci.o
spi-altera-platform-y := drivers/spi/spi-altera-platform.o
spi-altera-platform-y += drivers/spi/spi-altera-core.o
spi-altera-dfl-y := drivers/spi/spi-altera-dfl.o
dfl-hssi-y := drivers/fpga/dfl-hssi.o
dfl-n3000-nios-y := drivers/fpga/dfl-n3000-nios.o
dfl-emif-y := drivers/memory/dfl-emif.o
fpga-bridge-y := drivers/fpga/fpga-bridge.o
fpga-mgr-y := drivers/fpga/fpga-mgr.o
fpga-region-y := drivers/fpga/fpga-region.o
fpga-image-load-y := drivers/fpga/fpga-image-load.o
qsfp-mem-y := drivers/net/phy/qsfp-mem.o
intel-s10-phy-y := drivers/net/phy/intel-s10-phy.o
intel-m10-bmc-core-y := drivers/mfd/intel-m10-bmc-core.o
intel-m10-bmc-spi-y := drivers/mfd/intel-m10-bmc-spi.o
intel-m10-bmc-hwmon-y := drivers/hwmon/intel-m10-bmc-hwmon.o
intel-m10-bmc-sec-update-y := drivers/fpga/intel-m10-bmc-sec-update.o
s10hssi-y := drivers/net/ethernet/intel/s10hssi.o
regmap-indirect-register-y := drivers/base/regmap/regmap-indirect-register.o
n5010-phy-y := drivers/net/ethernet/silicom/n5010-phy.o
n5010-hssi-y := drivers/net/ethernet/silicom/n5010-hssi.o
intel-m10-bmc-pmci-y := drivers/mfd/intel-m10-bmc-pmci.o
uio_dfl-y := drivers/uio/uio_dfl.o

# intermediates used when reversing modules list
count := $(words $(obj-m))
indices := $(shell seq $(count) -1 1)

# module names without .o suffix
modules := $(basename $(obj-m))

# module names in reverse order with _ instead of -
reverse := $(foreach i,$(indices),$(word $i,$(modules)))
reverse := $(subst -,_,$(basename $(reverse)))

# explicit rules used to call insmod and rmmod for all modules
rules_rmmod := $(addprefix rmmod_,$(reverse))
rules_insmod := $(addprefix insmod_,$(modules))

# compile all modules
all:
	@$(MAKE) -C $(KERNELDIR) M=$(CURDIR) modules

# install modules to /lib/modules/$(KERNEL)/extra
install:
	@$(MAKE) -C $(KERNELDIR) M=$(CURDIR) INSTALL_MOD_DIR=extra modules_install

# remove build artifacts
clean:
	@$(MAKE) -C $(KERNELDIR) M=$(CURDIR) clean
	@-rm *.rpm

$(rules_rmmod): rmmod_%:
	@if lsmod | grep -qE '\<$*\>'; then rmmod $*; fi

# Needed for uio_dfl
modprobe_uio:
	@modprobe uio

$(rules_insmod): insmod_%:
	@if ! lsmod | grep -q $* && test -f $*.ko; then \
		insmod $*.ko $(DYNDBG); \
	fi

rmmod: $(rules_rmmod)
insmod: modprobe_uio $(rules_insmod)
reload: rmmod insmod

# helper used to generate dynamic dkms config based on kernel config
dkms:
	@echo $(modules)

# build rpm packages
rpm: build/rpm/linux-dfl-backport.spec clean
	@rpmbuild $(RPMBUILDOPTS) $<

help:
	@echo "Build Usage:"
	@echo " make all	Build kernel modules"
	@echo " make install	Install kernel modules to /lib/modules/$$(uname -r)/extra"
	@echo " make clean	Remove build artifacts"
	@echo ""
	@echo "Package Usage:"
	@echo " make rpm	Build rpm package from source"
	@echo ""
	@echo "Test Usage:"
	@echo " make rmmod	Remove modules from running kernel"
	@echo " make insmod	Insert modules to running kernel"
	@echo " make reload	Combination of 'make rmmod' and 'make insmod'"
	@echo ""
	@echo "Build Arguments:"
	@echo " KERNEL		Kernel version to build against ($$(uname -r))"
	@echo " KERNELDIR	Path to kernel build dir (/lib/modules/<KERNEL>/build)"
	@echo ""
	@echo "Test Arguments:"
	@echo " DEBUG=<0|1>	Toggle dynamic debugging when inserting modules (0)"

.PHONY: all install clean rmmod insmod reload rpm help dkms
