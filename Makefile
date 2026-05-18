# Automatically generate lists of sources using wildcards
AS_SOURCES = $(wildcard kernel/core/*.asm kernel/drivers/*.asm)
C_SOURCES  = $(wildcard kernel/*.cpp kernel/core/*.cpp kernel/drivers/*.cpp)
HEADERS    = $(wildcard kernel/*.h kernel/core/*.h kernel/drivers/*.h)

# Convert filenames to object files
OBJ   = ${C_SOURCES:.cpp=.o}
ASOBJ = ${AS_SOURCES:.asm=.o}

all: os.iso

os.iso: kernel.img
	cp $< iso
	mkisofs -o $@ -V LiziOS -b $< iso

# Run in QEMU
run: all
	qemu-system-x86_64 -monitor stdio -boot d -cdrom os.iso -m 1024M

# Build the bootable disk image
kernel.img: bin/bootsect.bin bin/kernel.bin
	dd if=/dev/zero of=kernel.img bs=512 count=2880
	dd seek=0 conv=notrunc if=bin/bootsect.bin of=kernel.img bs=512 count=1
	dd seek=1 conv=notrunc if=bin/kernel.bin  of=kernel.img bs=512 count=100

# Link the kernel binary
bin/kernel.bin: kernel/kernel_entry.o ${ASOBJ} ${OBJ}
	i686-elf-ld -m elf_i386 -T link.ld --oformat binary $^ -o $@

# Compile C++ sources
%.o: %.cpp ${HEADERS}
	i686-elf-g++ -Wall -m32 -ffreestanding -fno-asynchronous-unwind-tables \
	             -fno-pie -fno-rtti -fno-exceptions -c $< -o $@

# Assemble ASM sources
%.o: %.asm
	nasm -f elf32 $< -o $@

# Assemble boot sector
bin/%.bin: boot/%.asm
	nasm $< -f bin -o $@

# Disassemble for debugging
image.dis: kernel.img
	ndisasm -b 32 $< > $@

clean:
	rm -fr bin/*.bin bin/*.elf *.dis kernel.img iso/kernel.img os.iso
	rm -fr kernel/kernel_entry.o ${OBJ} ${ASOBJ}
