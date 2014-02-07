#
# WARNING: This package is deprecated.
#
# See RPC::ExtDirect::Config perldoc for the description
# of the instance-based configuration options to be used
# instead of the former global variables in this package.
#

package RPC::ExtDirect::Deserialize;

### PACKAGE GLOBAL VARIABLE ###
#
# Set it to true value to turn on debugging
#
# DEPRECATED. Use `debug_deserialize` or `debug` Config options instead.
#

our $DEBUG;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
#
# DEPRECATED. Use `exception_class_deserialize` or `exception_class`
# Config options instead.
#

our $EXCEPTION_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Request class name so it could be configured
#
# DEPRECATED. Use `request_class_deserialize` or `request_class`
# Config options instead.
#

our $REQUEST_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# JSON decoding options
#
# DEPRECATED. Use `json_options_deserialize` or `json_options`
# Config options instead.
#

our %JSON_OPTIONS;

1;
