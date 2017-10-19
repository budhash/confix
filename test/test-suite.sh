#test-suite

readonly __APPNAME=$( basename "${BASH_SOURCE[0]}" )
readonly __BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly __BASEDIRNAME=$( basename "$__BASEDIR" )
readonly __TIMESTAMP=$(date +%m-%d-%Y_%H-%M_%S)

readonly __TESTDIR=$__BASEDIR
readonly __CODEDIR=$__BASEDIR/..
readonly __SCRIPT=$__CODEDIR/confix

function _common.log() { echo "[info]: $@" 1>&2; }
function _common.log_pass() { echo "[PASS]: $@" 1>&2; }
function _common.log_fail() { echo "[FAIL]: $@" 1>&2; }

function _test(){
	_init
	_test_driver
	_cleanup
}	

function _test_driver(){
	for test in `cat $__APPNAME | grep "function __test_" | grep -v "grep" | awk '{print $2}' | awk -F'(' '{print $1}'`
	do
		$(eval ${test})
		if [[ $? -eq 0 ]]; then
			_common.log_pass $test
			#_cleanup
		else
			_common.log_fail $test
			#_cleanup
			exit 1
		fi			
	done
}

function _init(){
	readonly __DATA_CASSANDRA_MD5=1cb5233aafd7d04db352da0fb9c8a8e7
	readonly __DATA_LOG4J_MD5=04f5a61129e14a96034a60c2daaca66f
	readonly __DATA_PHP_MD5=92efb05ec8120dbc426d46533e07c3e8
	readonly __DATA_SIMPPROP_MD5=06443e2731bb7e5d4b1c1b458378b1ff	
	
	if hash md5 2>/dev/null; then
	    __MD5=md5
	else
	    __MD5=md5sum
	fi
}

## tests
function __setup_data(){
    cp -f $__TESTDIR/data/$1 .	
}


function __test_removeconfig_colonsep(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -c'#' -s':' -f $_data_file "<gc_warn_threshold_in_ms"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
	# < #gc_warn_threshold_in_ms: 1000
	---
	> gc_warn_threshold_in_ms: 1000
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_removeconfig_colonsep_invalid(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file "<invalid_key"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
	local expected=
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_addconfig_colonsep_uncommenting_existing(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file ">concurrent_compactors"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
	# < concurrent_compactors: 1
	---
	> #concurrent_compactors: 1
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_addconfig_colonsep_new_withoutval(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file ">new_param"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
	#nothing should be added here
	local expected=
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_addconfig_colonsep_new_withval(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file ">new_param=/some/val"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
# <           flow: FAST
< new_param:/some/val
---
>           flow: FAST
\\ No newline at end of file
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_updateconfig_colonsep_existingval(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file "gc_warn_threshold_in_ms=2001"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
	# < gc_warn_threshold_in_ms: 2001
	---
	> gc_warn_threshold_in_ms: 1000
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_updateconfig_colonsep_nonexistingval(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file "non_existing=value"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
	#nothing should be added here
	local expected=
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_updateconfig_colonsep_valwithslash(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file "commitlog_directory=/change/commitlog"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
	# < commitlog_directory: /change/commitlog
	---
	> commitlog_directory: /var/lib/cassandra/commitlog
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_updateconfig_colonsep_commentedkey(){
	local _data_file=log4j.properties
	__setup_data $_data_file
	$__SCRIPT -f log4j.properties "log4j.logger.com.endeca.itl.web.metrics=DEBUG"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
	# < log4j.logger.com.endeca.itl.web.metrics=DEBUG
	---
	> #log4j.logger.com.endeca.itl.web.metrics=INFO
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_updateconfig_multiple(){
	local _data_file=cassandra.yaml
	__setup_data $_data_file
	$__SCRIPT -s':' -f $_data_file "gc_warn_threshold_in_ms=2001" ">concurrent_compactors" "commitlog_directory=/change/commitlog"
	local returned=$(diff ./$_data_file ./data/$_data_file | sed '1d')
	
read -d '' local expected <<"EOF"
196c196
< commitlog_directory: /change/commitlog
---
> commitlog_directory: /var/lib/cassandra/commitlog
810c810
< concurrent_compactors: 1
---
> #concurrent_compactors: 1
1169c1169
< gc_warn_threshold_in_ms: 2001
---
> gc_warn_threshold_in_ms: 1000
EOF
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_output_to_different_file(){
	local _data_file=./data/cassandra.yaml
	$__SCRIPT -s':' -o cassandra.yaml.updated -f $_data_file ">new_param"
	local returned=$(diff ./$_data_file cassandra.yaml.updated | sed '1d')
	rm cassandra.yaml.updated
	#nothing should be added here
	local expected=
	local rethash=$(echo $returned | $__MD5)
	local exphash=$(echo $expected | $__MD5)
	if [[ $rethash == $exphash ]] ; then 
		return 0; 
	else 
		echo "[expected]: 
$expected" 1>&2;
		echo "[returned]:
$returned" 1>&2;
		return 1; 
	fi
}

function __test_output_to_console(){
	local _data_file=./data/log4j.properties
	$__SCRIPT -s':' -o- -f $_data_file ">new_param" > /dev/null
	if [[ "$(cat $_data_file | $__MD5)" == "$__DATA_LOG4J_MD5" ]] ; then 
		return 0; 
	else 
		return 1;
	fi	
}

function _cleanup(){
	rm -rf cassandra.yaml
	rm -rf log4j.properties
}
	
trap _cleanup 1 2 3 4 6 8 10 12 13 15
pushd $__BASEDIR >/dev/null
_test $@
popd >/dev/null
exit 0