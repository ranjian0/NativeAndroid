include makefiles/Android.mk 

android: makecapk.apk
android_run: uninstall run

clean :
	rm -rf build
