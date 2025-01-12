QEMUFLAGS = -machine q35 -smp 4 -drive file=foxos.img -m 1G -cpu qemu64 -drive if=pflash,format=raw,unit=0,file="ovmf/OVMF_CODE-pure-efi.fd",readonly=on -drive if=pflash,format=raw,unit=1,file="ovmf/OVMF_VARS-pure-efi.fd" -net none -serial stdio -soundhw pcspk
QEMUFLAGS_BIOS = -machine q35 -smp 4 -drive file=foxos.img -m 1G -cpu qemu64 -net none -serial stdio -soundhw pcspk

FOX_GCC_PATH=/usr/local/foxos-x86_64_elf_gcc

all:
	@make -C FoxOS-kernel setup -i TOOLCHAIN_BASE=$(FOX_GCC_PATH)
	make -C FoxOS-kernel TOOLCHAIN_BASE=$(FOX_GCC_PATH)
	@make -C FoxOS-programs setup -i TOOLCHAIN_BASE=$(FOX_GCC_PATH)
	make -C FoxOS-programs TOOLCHAIN_BASE=$(FOX_GCC_PATH)

./tmp/limine:
	@echo "Downloading latest limine release!"
	@mkdir -p ./tmp/limine
	@git clone https://github.com/limine-bootloader/limine.git --branch=latest-binary --depth=1 ./tmp/limine

img: all ./tmp/limine
	sh disk.sh $(FOX_GCC_PATH)

mac-img: all ./tmp/limine
	sh mac-disk.sh $(FOX_GCC_PATH)

vmdk: img
	qemu-img convert foxos.img -O vmdk foxos.vmdk

vdi: img
	qemu-img convert foxos.img -O vdi foxos.vdi

qcow2: img
	qemu-img convert foxos.img -O qcow2 foxos.qcow2

run: img
	qemu-system-x86_64 $(QEMUFLAGS)

run-dbg: img
	screen -dmS qemu qemu-system-x86_64 $(QEMUFLAGS) -s -S

run-vnc: img
	qemu-system-x86_64 $(QEMUFLAGS) -vnc :1

run-bios: img
	qemu-system-x86_64 $(QEMUFLAGS_BIOS)

run-dbg-bios: img
	screen -dmS qemu qemu-system-x86_64 $(QEMUFLAGS_BIOS) -s -S

run-vnc-bios: img
	qemu-system-x86_64 $(QEMUFLAGS_BIOS) -vnc :1

screenshot:
	echo "(make run-vnc-bios  &>/dev/null & disown; sleep 30; vncsnapshot localhost:1 foxos.jpg; killall qemu-system-x86_64)" | bash

clean:
	make -C FoxOS-kernel clean
	make -C FoxOS-programs clean
	rm foxos.img foxos.vmdk foxos.vdi foxos.qcow2

debug:
	deno run --allow-run debug.js

usb: all ./tmp/limine
	@read -p "Enter path to usb >> " usb_path; \
	mkdir -p $$usb_path/EFI/BOOT; \
	mkdir -p $$usb_path/EFI/FOXOS; \
	mkdir -p $$usb_path/BIN; \
	cp ./tmp/limine/BOOTX64.EFI $$usb_path/EFI/BOOT/BOOTX64.EFI; \
	cp FoxOS-kernel/bin/foxkrnl.elf $$usb_path/EFI/FOXOS/.; \
	cp limine.cfg $$usb_path/limine.cfg; \
	cp startup.nsh $$usb_path/startup.nsh; \
	cp FoxOS-programs/bin/test.elf $$usb_path/BIN/.;

losetup:
	gcc -xc -o losetup.elf losetup.c
	chmod u+s losetup.elf
	chmod g+s losetup.elf

	mv losetup.elf $(FOX_GCC_PATH)/bin/foxos-losetup -v
