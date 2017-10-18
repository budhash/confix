#test-suite

readonly __APPNAME=$( basename "${BASH_SOURCE[0]}" )
readonly __BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly __BASEDIRNAME=$( basename "$__BASEDIR" )
readonly __TIMESTAMP=$(date +%m-%d-%Y_%H-%M_%S)

readonly __TESTDIR=$__BASEDIR
readonly __CODEDIR=$__BASEDIR/..
readonly __SCRIPT=$__CODEDIR/confix

function _common.log_pass() { echo "[PASS]: $@" 1>&2; }
function _common.log_fail() { echo "[FAIL]: $@" 1>&2; }

function _test(){
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

## tests
function __setup_data(){
    cp -f $__TESTDIR/data/cassandra.yaml .	
}

function __test_removeconfig_colonsep(){
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml "<gc_warn_threshold_in_ms"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
read -d '' local expected <<"EOF"
	# < #gc_warn_threshold_in_ms: 1000
	---
	> gc_warn_threshold_in_ms: 1000
EOF
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml "<invalid_key"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
	local expected=
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml ">concurrent_compactors"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
read -d '' local expected <<"EOF"
	# < concurrent_compactors: 1
	---
	> #concurrent_compactors: 1
EOF
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml ">new_param"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
	#nothing should be added here
	local expected=
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml ">new_param=/some/val"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
read -d '' local expected <<"EOF"
# <           flow: FAST
< new_param:/some/val
---
>           flow: FAST
\\ No newline at end of file
EOF
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
read -d '' local expected <<"EOF"
	# < gc_warn_threshold_in_ms: 2001
	---
	> gc_warn_threshold_in_ms: 1000
EOF
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml "non_existing=value"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
	#nothing should be added here
	local expected=
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml "commitlog_directory=/change/commitlog"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
read -d '' local expected <<"EOF"
	# < commitlog_directory: /change/commitlog
	---
	> commitlog_directory: /var/lib/cassandra/commitlog
EOF
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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
	__setup_data
	$__SCRIPT -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001" ">concurrent_compactors" "commitlog_directory=/change/commitlog"
	local returned=$(diff ./cassandra.yaml ./data/cassandra.yaml | sed '1d')
	
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
	local rethash=$(echo $returned | md5)
	local exphash=$(echo $expected | md5)
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

function _cleanup(){
	rm -rf cassandra.yaml
}
	
trap _cleanup 1 2 3 4 6 8 10 12 13 15
pushd $__BASEDIR
_test $@
popd
exit 0