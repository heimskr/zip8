project('zip8', 'c')

zig = find_program('zig', required: true)

zip8_object = custom_target('gen-zig-build',
	input: 'build.zig',
	output: ['libzip8.a'],
	build_by_default: true,
	command: ['./make_lib.sh', '@INPUT@', '@OUTPUT@'],
	install_dir: get_option('libdir'),
	install: true
)

inc_dir = include_directories('src')

zip8_lib = static_library('zip8', [zip8_object[0]],
	include_directories: inc_dir
)

zip8 = declare_dependency(
	include_directories: inc_dir,
	link_with: zip8_lib
)
