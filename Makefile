QEMUFLAGS = -machine q35 -smp 4 -drive file=foxos.img -m 1G -cpu qemu64 -drive if=pflash,format=raw,unit=0,file="ovmf/OVMF_CODE-pure-efi.fd",readonly=on -drive if=pflash,format=raw,unit=1,file="ovmf/OVMF_VARS-pure-efi.fd" -net none -serial stdio

all:
	make -C FoxOS-bootloader
	make -C FoxOS-bootloader bootloader
	make -C FoxOS-kernel setup -i
	make -C FoxOS-kernel

img: all
	dd if=/dev/zero of=foxos.img bs=512 count=93750
	mkfs.vfat foxos.img -n FOXOS -F32
	mmd -i foxos.img ::/EFI
	mmd -i foxos.img ::/EFI/BOOT
	mmd -i foxos.img ::/EFI/FOXOS
	mcopy -i foxos.img FoxOS-bootloader/x86_64/bootloader/main.efi ::/EFI/BOOT
	mcopy -i foxos.img startup.nsh ::
	mcopy -i foxos.img FoxOS-kernel/bin/foxkrnl.elf ::/EFI/FOXOS

run: img
	qemu-system-x86_64 $(QEMUFLAGS)

run-dbg: img
	screen -dmS qemu qemu-system-x86_64 $(QEMUFLAGS) -s -S

clean:
	make -C FoxOS-kernel clean
	make -C FoxOS-bootloader clean
	rm foxos.img

debug:
	deno run --allow-run debug.js

usb: all
	@read -p "Enter path to usb >> " usb_path; \
	mkdir -p $$usb_path/EFI/BOOT; \
	mkdir -p $$usb_path/EFI/FOXOS; \
	cp FoxOS-bootloader/x86_64/bootloader/main.efi $$usb_path/EFI/BOOT/BOOTX64.EFI; \
	cp FoxOS-kernel/bin/foxkrnl.elf $$usb_path/EFI/FOXOS/.;
