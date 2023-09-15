# SPDX-License-Identifier: GPL-2.0

# to check robot warnings
ccflags-y += -Wunused-but-set-variable -Wold-style-declaration -Wint-to-pointer-cast

obj-$(CONFIG_USB_NET_QMI_WWAN) += qmi_wwan_q.o

all:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) clean
