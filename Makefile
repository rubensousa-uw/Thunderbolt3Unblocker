# Experimental Intel-only build using Command Line Tools; never installs/loads.
SDK := /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
KH := $(SDK)/System/Library/Frameworks/Kernel.framework/Headers
OUT := build/manual
KEXT := $(OUT)/Thunderbolt3Unblocker.kext
FLAGS := -arch x86_64 -mkernel -fno-builtin -fno-stack-protector -D_FORTIFY_SOURCE=0 -isysroot $(SDK) -I$(KH) -Ixnu_override -Ixnu_override/zydis/include -I$(OUT)/zydis
CSRC := Thunderbolt3Unblocker/Thunderbolt3Unblocker.c xnu_override/xnu_override.c xnu_override/xnu_override_test.c xnu_override/zydis_stubs.c tests/kmod_entry.c
OBJ := $(CSRC:%.c=$(OUT)/%.o) $(OUT)/NVRAM.o
.PHONY: all test inspect-scan
all: $(KEXT)/Contents/MacOS/Thunderbolt3Unblocker
$(OUT)/%.o: %.c xnu_override/patch_decode.h $(OUT)/zydis/libZydis.a
	mkdir -p $(dir $@)
	clang $(FLAGS) -O0 -c $< -o $@
$(OUT)/NVRAM.o: Thunderbolt3Unblocker/NVRAM.cpp
	mkdir -p $(OUT)
	clang++ $(FLAGS) -fapple-kext -fno-exceptions -fno-rtti -c $< -o $@
$(OUT)/zydis/libZydis.a:
	cmake -S xnu_override/zydis -B $(OUT)/zydis -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DCMAKE_BUILD_TYPE=Debug -DZYDIS_BUILD_EXAMPLES=OFF -DZYDIS_BUILD_TOOLS=OFF -DCMAKE_C_FLAGS="-arch x86_64 -mkernel -fno-builtin -fno-stack-protector -D_FORTIFY_SOURCE=0"
	cmake --build $(OUT)/zydis -j4
$(KEXT)/Contents/MacOS/Thunderbolt3Unblocker: $(OBJ) $(OUT)/zydis/libZydis.a
	mkdir -p $(KEXT)/Contents/MacOS
	clang -arch x86_64 -nostdlib -Wl,-kext -Wl,-w $(OBJ) $(OUT)/zydis/libZydis.a -o $@
	cp Thunderbolt3Unblocker/Info.plist $(KEXT)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c 'Set :CFBundleDevelopmentRegion en' -c 'Set :CFBundleExecutable Thunderbolt3Unblocker' -c 'Set :CFBundleIdentifier es.govost.ryan.Thunderbolt3Unblocker' -c 'Set :CFBundleName Thunderbolt3Unblocker' -c 'Set :CFBundleShortVersionString 1.1.0' -c 'Set :CFBundleVersion 1.1.0' $(KEXT)/Contents/Info.plist
	codesign --force --sign - $(KEXT)
test:
	cmake -S xnu_override/zydis -B build/zydis-debug -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Debug -DZYDIS_BUILD_EXAMPLES=OFF -DZYDIS_BUILD_TOOLS=OFF
	cmake --build build/zydis-debug -j4
	clang -O0 -Ixnu_override/zydis/include -Ibuild/zydis-debug tests/patch_decode_test.c build/zydis-debug/libZydis.a -Wl,-w -o build/patch-decode-test
	./build/patch-decode-test

# Read-only analysis tool. Not linked into the kernel extension.
build/disassemble-bytes: tests/disassemble_bytes.c build/zydis-debug/libZydis.a
	clang -O0 -Ixnu_override/zydis/include -Ibuild/zydis-debug $< build/zydis-debug/libZydis.a -Wl,-w -o $@
inspect-scan: build/disassemble-bytes
	python3 tests/inspect_scan.py
