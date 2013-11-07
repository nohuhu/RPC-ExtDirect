#
# WARNING: This package is deprecated.
#
# See RPC::ExtDirect::Serializer perldoc for the description
# of the instance-based configuration options to be used instead
# of the former global variables in this package.
#

package RPC::ExtDirect::Deserialize;

use strict;
use warnings;

### PACKAGE GLOBAL VARIABLE ###
#
# Set it to true value to turn on debugging
# DEPRECATED
#

our $DEBUG;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Exception class name so it could be configured
# DEPRECATED
#

our $EXCEPTION_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# Set Request class name so it could be configured
# DEPRECATED
#

our $REQUEST_CLASS;

### PACKAGE GLOBAL VARIABLE ###
#
# JSON decoding options
# DEPRECATED
#

our %JSON_OPTIONS;

1;
