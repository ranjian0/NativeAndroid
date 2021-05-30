#This makefile is meant to be included into a top level makefile for building android apk
#Change the APK Information in the top level makefile and add to android sources

# APK INFORMATION
APPNAME?=App
LABEL?=$(APPNAME)
APKFILE ?= $(APPNAME).apk
PACKAGENAME?=com.example.$(APPNAME)


#We've tested it with android version 22, 24, 28, 29 and 30.
#You can target something like Android 28, but if you set ANDROIDVERSION to say 22, then
#Your app should (though not necessarily) support all the way back to Android 22. 
ANDROIDVERSION?=24
ANDROIDTARGET?=$(ANDROIDVERSION)
ANDROID_FULLSCREEN?=y
ADB?=adb
UNAME := $(shell uname)


ifeq ($(UNAME), Linux)
OS_NAME = linux-x86_64
endif
ifeq ($(UNAME), Darwin)
OS_NAME = darwin-x86_64
endif
ifeq ($(OS), Windows_NT)
OS_NAME = windows-x86_64
endif

# Search list for where to try to find the SDK
SDK_LOCATIONS += $(ANDROID_HOME) $(ANDROID_SDK_ROOT) ~/Android/Sdk $(HOME)/Library/Android/sdk

#Just a little Makefile witchcraft to find the first SDK_LOCATION that exists
#Then find an ndk folder and build tools folder in there.
ANDROIDSDK?=$(firstword $(foreach dir, $(SDK_LOCATIONS), $(basename $(dir) ) ) )
NDK?=$(firstword $(ANDROID_NDK) $(ANDROID_NDK_HOME) $(wildcard $(ANDROIDSDK)/ndk/*) $(wildcard $(ANDROIDSDK)/ndk-bundle/*) )
BUILD_TOOLS?=$(lastword $(wildcard $(ANDROIDSDK)/build-tools/*) )

# fall back to default Android SDL installation location if valid NDK was not found
ifeq ($(NDK),)
ANDROIDSDK := ~/Android/Sdk
endif

# Verify if directories are detected
ifeq ($(ANDROIDSDK),)
$(error ANDROIDSDK directory not found)
endif
ifeq ($(NDK),)
$(error NDK directory not found)
endif
ifeq ($(BUILD_TOOLS),)
$(error BUILD_TOOLS directory not found)
endif

# load all required sources
ANDROIDSRCS:= $(NDK)/sources/android/native_app_glue/android_native_app_glue.c
ANDROIDSRCS+= extern/glfm/glfm_platform_android.c
ANDROIDSRCS+= $(shell find src -name "*.c")

# Android Cflags
ANDROID_CFLAGS?=#-ffunction-sections -Os -fdata-sections -Wall -fvisibility=hidden
ANDROID_CFLAGS+=-Os -DANDROID -DAPPNAME=\"$(APPNAME)\"
ifeq (ANDROID_FULLSCREEN,y)
ANDROID_CFLAGS +=-DANDROID_FULLSCREEN
endif
ANDROID_CFLAGS+= -Iextern/glfm -I$(NDK)/sources/android/native_app_glue -I$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include -I$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include/android  -fPIC -DANDROIDVERSION=$(ANDROIDVERSION)

# Android ldflags
ANDROID_LDFLAGS?=-Wl,--gc-sections -s
ANDROID_LDFLAGS += -lm -lGLESv3 -lEGL -landroid -llog -lOpenSLES -lz
ANDROID_LDFLAGS += -shared -uANativeActivity_onCreate

# Android compilers
ANDROID_CC_ARM64:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/aarch64-linux-android$(ANDROIDVERSION)-clang
ANDROID_CC_ARM32:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/armv7a-linux-androideabi$(ANDROIDVERSION)-clang
ANDROID_CC_x86:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/i686-linux-android$(ANDROIDVERSION)-clang
ANDROID_CC_x86_64=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/x86_64-linux-android$(ANDROIDVERSION)-clang
AAPT:=$(BUILD_TOOLS)/aapt

# Which binaries to build? Just comment/uncomment these lines:
ANDROID_TARGETS += build/makecapk/lib/arm64-v8a/lib$(APPNAME).so
ANDROID_TARGETS += build/makecapk/lib/armeabi-v7a/lib$(APPNAME).so
ANDROID_TARGETS += build/makecapk/lib/x86/lib$(APPNAME).so
ANDROID_TARGETS += build/makecapk/lib/x86_64/lib$(APPNAME).so

ANDROID_CFLAGS_ARM64:=-m64
ANDROID_CFLAGS_ARM32:=-mfloat-abi=softfp -m32
ANDROID_CFLAGS_x86:=-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32
ANDROID_CFLAGS_x86_64:=-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel

STOREPASS?=password
DNAME:="CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB"
KEYSTOREFILE:=my-release-key.keystore
ALIASNAME?=standkey

# Show Android Configuration
show_android_config:
	@echo "SDK and NDK paths"
	@echo "SDK:\t\t" $(ANDROIDSDK)
	@echo "NDK:\t\t" $(NDK)
	@echo "Build Tools:\t" $(BUILD_TOOLS)
	@echo
	@echo "Sources"
	@echo $(ANDROIDSRCS)
	@echo
	@echo "Android Build Targets"
	@echo $(ANDROID_TARGETS)


# Setup android requirements

keystore : $(KEYSTOREFILE)

$(KEYSTOREFILE) :
	keytool -genkey -v -keystore $(KEYSTOREFILE) -alias $(ALIASNAME) -keyalg RSA -keysize 2048 -validity 10000 -storepass $(STOREPASS) -keypass $(STOREPASS) -dname $(DNAME)

manifest: AndroidManifest.xml

AndroidManifest.xml :
	rm -rf src/AndroidManifest.xml
	PACKAGENAME=$(PACKAGENAME) \
		ANDROIDVERSION=$(ANDROIDVERSION) \
		ANDROIDTARGET=$(ANDROIDTARGET) \
		APPNAME=$(APPNAME) \
		LABEL=$(LABEL) envsubst '$$ANDROIDTARGET $$ANDROIDVERSION $$APPNAME $$PACKAGENAME $$LABEL' \
		< src/AndroidManifest.xml.template > src/AndroidManifest.xml


# Build android native library
folders:
	mkdir -p build/makecapk/lib/arm64-v8a
	mkdir -p build/makecapk/lib/armeabi-v7a
	mkdir -p build/makecapk/lib/x86
	mkdir -p build/makecapk/lib/x86_64

build/makecapk/lib/arm64-v8a/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p build/makecapk/lib/arm64-v8a
	$(ANDROID_CC_ARM64) $(ANDROID_CFLAGS) $(ANDROID_CFLAGS_ARM64) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/aarch64-linux-android/$(ANDROIDVERSION) $(ANDROID_LDFLAGS)

build/makecapk/lib/armeabi-v7a/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p build/makecapk/lib/armeabi-v7a
	$(ANDROID_CC_ARM32) $(ANDROID_CFLAGS) $(ANDROID_CFLAGS_ARM32) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/arm-linux-androideabi/$(ANDROIDVERSION) $(ANDROID_LDFLAGS)

build/makecapk/lib/x86/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p build/makecapk/lib/x86
	$(ANDROID_CC_x86) $(ANDROID_CFLAGS) $(ANDROID_CFLAGS_x86) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/i686-linux-android/$(ANDROIDVERSION) $(ANDROID_LDFLAGS)

build/makecapk/lib/x86_64/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p build/makecapk/lib/x86_64
	$(ANDROID_CC_x86) $(ANDROID_CFLAGS) $(ANDROID_CFLAGS_x86_64) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/x86_64-linux-android/$(ANDROIDVERSION) $(ANDROID_LDFLAGS)


makecapk.apk : $(ANDROID_TARGETS) AndroidManifest.xml
	mkdir -p build/makecapk/assets
	cp -r src/assets/* build/makecapk/assets
	rm -rf build/temp.apk
	$(AAPT) package -f -F build/temp.apk -I $(ANDROIDSDK)/platforms/android-$(ANDROIDVERSION)/android.jar -M src/AndroidManifest.xml -S src/res -A build/makecapk/assets -v --target-sdk-version $(ANDROIDTARGET)
	unzip -o build/temp.apk -d build/makecapk
	rm -rf build/makecapk.apk
	cd build/makecapk && zip -D9r ../makecapk.apk . && zip -D0r ../makecapk.apk ./resources.arsc ./AndroidManifest.xml
	jarsigner -sigalg SHA1withRSA -digestalg SHA1 -verbose -keystore $(KEYSTOREFILE) -storepass $(STOREPASS) build/makecapk.apk $(ALIASNAME)
	rm -rf build/$(APKFILE)
	$(BUILD_TOOLS)/zipalign -v 4 build/makecapk.apk build/$(APKFILE)
	#Using the apksigner in this way is only required on Android 30+
	$(BUILD_TOOLS)/apksigner sign --key-pass pass:$(STOREPASS) --ks-pass pass:$(STOREPASS) --ks $(KEYSTOREFILE) build/$(APKFILE)
	rm -rf build/temp.apk
	rm -rf build/makecapk.apk
	@ls -lh build/$(APKFILE)


# Android run on device

uninstall : 
	($(ADB) uninstall $(PACKAGENAME))||true

push : makecapk.apk
	@echo "Installing" $(PACKAGENAME)
	$(ADB) install -r build/$(APKFILE)

run : push
	$(eval ACTIVITYNAME:=$(shell $(AAPT) dump badging build/$(APKFILE) | grep "launchable-activity" | cut -f 2 -d"'"))
	$(ADB) shell am start -n $(PACKAGENAME)/$(ACTIVITYNAME)


