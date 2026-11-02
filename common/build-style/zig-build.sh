do_build() {
	local zig_target zig_cpu zig_target_args

	# TODO: This duplication between build-profiles and cross-profiles
	# is totally unnecessary. It would be nice if there was some way to
	# avoid it.
	if [ "$CROSS_BUILD" ]; then
		zig_target="${XBPS_CROSS_ZIG_TARGET}"
		zig_cpu="${XBPS_CROSS_ZIG_CPU}"
		zig_target_args="-Dtarget=${zig_target} -Dcpu=${zig_cpu}"
	else
		# A named target (x86_64-linux-gnu) is not the default target, so
		# zig treats the build as cross-compiling and drops the host include
		# paths: translate-c steps then cannot find X11/ or fontconfig/.
		zig_target_args=
	fi

	# Inform zig of the required libc include paths. zig 0.17 requires every
	# field to be present (cc_dir and darwin_sdk_dir included) and dropped
	# --global-cache-dir in favour of --cache-dir.
	# Native builds ask zig itself: hand-written paths point crt search at
	# usr/bin instead of usr/lib/../gcc/<triple>/<ver>/crtbegin.o.
	local zig_platform_args=
	if [ "$CROSS_BUILD" ]; then
		cat > xbps_zig_libc.txt <<-EOF
			include_dir=${XBPS_CROSS_BASE}/usr/include
			sys_include_dir=${XBPS_CROSS_BASE}/usr/include
			crt_dir=${XBPS_CROSS_BASE}/usr/lib
			msvc_lib_dir=
			kernel32_lib_dir=
			cc_dir=${XBPS_CROSS_BASE}/usr/bin
			darwin_sdk_dir=
		EOF
		zig_platform_args="--sysroot ${XBPS_CROSS_BASE}"
		zig_platform_args+=" --search-prefix ${XBPS_CROSS_BASE}/usr"
		zig_platform_args+=" --libc xbps_zig_libc.txt"
	else
		zig libc > xbps_zig_libc.txt
		zig_platform_args="--libc xbps_zig_libc.txt"
	fi

	# The Zig build system only has a single install step, there is no
	# way to build artifacts for a given prefix and then install those artifacts
	# to that prefix at some later time. Therefore, we build and install to the zig-out
	# directory and later copy the artifacts to the destdir in do_install().
	# We use zig-out to avoid path conflicts as it is the default install
	# prefix used by the zig build system.
	DESTDIR="zig-out" zig build \
		${makejobs} \
		${zig_platform_args} \
		--prefix /usr \
		--cache-dir /host/zig \
		--release=safe \
		--verbose \
		${zig_target_args} \
		install \
		${configure_args}
}

do_install() {
	cp -r zig-out/* "${DESTDIR}"
}
