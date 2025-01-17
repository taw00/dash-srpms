packages:=gmp backtrace

protobuf_native_packages =
protobuf_packages =

openssl_packages =

qt_packages =

qt_linux_packages:=

qrencode_linux_packages = qrencode
qrencode_android_packages = qrencode
qrencode_darwin_packages = qrencode
qrencode_mingw32_packages = qrencode

qt_android_packages=qt
qt_darwin_packages=qt
qt_mingw32_packages=qt

bdb_packages=
sqlite_package=sqlite

zmq_packages=

upnp_packages=
natpmp_packages=libnatpmp

multiprocess_packages = libmultiprocess capnp
multiprocess_native_packages = native_libmultiprocess native_capnp

usdt_linux_packages=systemtap

darwin_native_packages = native_ds_store native_mac_alias

ifneq ($(build_os),darwin)
darwin_native_packages += native_cctools native_libtapi

ifeq ($(strip $(FORCE_USE_SYSTEM_CLANG)),)
darwin_native_packages+= native_clang
endif

endif
