# confix
[![Build Status](https://travis-ci.org/budhash/confix.png?branch=master)](https://travis-ci.org/budhash/confix)

# confix

## Summary
pure bash script to modify/update configuration files

## Status 
ALPHA

## License
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Introduction
pure bash script to modify/update configuration files.
 
See Usage and Examples for more details. 

## Installing

    curl -k https://raw.githubusercontent.com/budhash/confix/master/confix > confix; chmod +x confix

## Examples
- remove (comment out) an existing config element
    confix -c '#' -s':' -f cassandra.yaml "<gc_warn_threshold_in_ms"

- uncomment an existing config element (no action if the config key does not exist)
    confix -s':' -f cassandra.yaml ">concurrent_compactors"

- add a new config to the end of the file
    confix -s':' -f cassandra.yaml ">new_param=/some/val"

- update the value of an existing config element
    confix -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001"

- multiple commands
    confix -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001" ">concurrent_compactors" "commitlog_directory=/change/commitlog"

## Limitations
* NA

## Known Issues
* See [confix issues on GitHub](https://github.com/budhash/confix/issues) for open issues

## Authors / Contact
budhash (at) gmail

## Download
You can download this project in either [zip](http://github.com/budhash/confix/zipball/master) or [tar](http://github.com/budhash/confix/tarball/master) formats.

Or simply clone the project with [Git](http://git-scm.com/) by running:

    git clone git://github.com/budhash/confix
 
