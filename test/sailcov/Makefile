basename="nested_mapping_demo"
filename="${basename}.sail"
sail="/home/trdthg/repo/sail/sail"
sail_dir="/home/trdthg/repo/sail"
sailcov="/home/trdthg/repo/sail/sailcov/sailcov"

all: clear build_sail build_sailcov all_branch build_model taken cov diff 
build_and_run_c: build_model taken 

build_sail:
	cd ${sail_dir} && make

build_sailcov:
	cd ${sail_dir}/sailcov && make

all_branch:
	${sail} -no_warn -no_memo_z3 -c -c_include sail_coverage.h -c_coverage ${basename}.branches ${filename} -o ${basename} 

build_model:
	cc ${basename}.c ${sail_dir}/lib/*.c ${sail_dir}/lib/coverage/libsail_coverage.a -lgmp -lz -lpthread -ldl -I ${sail_dir}/lib -o ${basename}.bin

taken:
	./${basename}.bin -c ${basename}.taken

cov:
	${sailcov} --werror --all ${basename}.branches --taken ${basename}.taken ${filename}

diff:
	diff ${basename}.html ${basename}.expect

clear:
	rm -f ${basename}.taken ${basename}.bin ${basename}.branches ${basename}.html ${basename}.c
