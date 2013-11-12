#
# WARNING: This package is deprecated.
#
# See RPC::ExtDirect::Config perldoc for the description
# of the instance-based configuration options to be used
# instead of the former global variables in this package.
#

package RPC::ExtDirect::Serialize;

use strict;

### PACKAGE GLOBAL VARIABLE ###
#
# Turn on for debugging
#
# DEPRECATED. Use `debug_serialize` or `debug` Config options instead.
#

our $DEBUG;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
#
# DEPRECATED. Use `exception_class_serialize` or `exception_class`
# Config options instead.
#

our $EXCEPTION_CLASS;

1;
