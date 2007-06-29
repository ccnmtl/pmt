# File: Error.pm
# Time-stamp: <Wed Jul 10 11:44:39 2002>

use strict;
use Error;

# define some exception types

package Error::NonexistantUser;
@Error::NonexistantUser::ISA = qw(Error::Simple);
1;

package Error::InactiveUser;
@Error::InactiveUser::ISA = qw(Error::Simple);
1;

package Error::BadPassword;
@Error::BadPassword::ISA = qw(Error::Simple);
1;

package Error::NoTemplateSpecified;
@Error::NoTemplateSpecified::ISA = qw(Error::Simple);
1;

package Error::BAD_SORTBY;
@Error::BAD_SORTBY::ISA = qw(Error::Simple);
1;

package Error::PASSWORD_MISMATCH;
@Error::PASSWORD_MISMATCH::ISA = qw(Error::Simple);
1;

package Error::INCORRECT_PASSWORD;
@Error::INCORRECT_PASSWORD::ISA = qw(Error::Simple);
1;

package Error::NO_IID;
@Error::NO_IID::ISA = qw(Error::Simple);
1;

package Error::NO_NID;
@Error::NO_NID::ISA = qw(Error::Simple);
1;

package Error::NO_PID;
@Error::NO_PID::ISA = qw(Error::Simple);
1;

package Error::NO_MID;
@Error::NO_MID::ISA = qw(Error::Simple);
1;

package Error::NO_DATE;
@Error::NO_DATE::ISA = qw(Error::Simple);
1;

package Error::NO_USER;
@Error::NO_USER::ISA = qw(Error::Simple);
1;

package Error::NO_USERNAME;
@Error::NO_USERNAME::ISA = qw(Error::Simple);
1;

package Error::NO_PASSWORD;
@Error::NO_PASSWORD::ISA = qw(Error::Simple);
1;

package Error::NO_EMAIL;
@Error::NO_EMAIL::ISA = qw(Error::Simple);
1;

package Error::NO_NAME;
@Error::NO_NAME::ISA = qw(Error::Simple);
1;

package Error::NO_TITLE;
@Error::NO_TITLE::ISA = qw(Error::Simple);
1;

package Error::MILESTONE_NOT_EMPTY;
@Error::MILESTONE_NOT_EMPTY::ISA = qw(Error::Simple);
1;

package Error::NO_TARGET_DATE;
@Error::NO_TARGET_DATE::ISA = qw(Error::Simple);
1;

package Error::NO_STATUS;
@Error::NO_TARGET_DATE::ISA = qw(Error::Simple);
1;

package Error::NO_ARGUMENTS;
@Error::NO_ARGUMENTS::ISA = qw(Error::Simple);
1;

package Error::NO_SUCH_ITEM;
@Error::NO_SUCH_ITEM::ISA = qw(Error::Simple);
1;

package Error::INVALID_STATUS;
@Error::INVALID_STATUS::ISA = qw(Error::Simple);
1;

package Error::NO_PRIORITY;
@Error::NO_PRIORITY::ISA = qw(Error::Simple);
1;

package Error::UNKNOWN_TYPE;
@Error::UNKNOWN_TYPE::ISA = qw(Error::Simple);
1;

package Error::NO_TYPE;
@Error::NO_TYPE::ISA = qw(Error::Simple);
1;

package Error::NO_COMMENT;
@Error::NO_COMMENT::ISA = qw(Error::Simple);
1;

package Error::NO_EID;
@Error::NO_EID::ISA = qw(Error::Simple);
1;

package Error::NO_SUBJECT;
@Error::NO_SUBJECT::ISA = qw(Error::Simple);
1;

package Error::UNKNOWN_PID;
@Error::UNKNOWN_PID::ISA = qw(Error::Simple);
1;

package Error::NO_CARETAKER;
@Error::NO_CARETAKER::ISA = qw(Error::Simple);
1;

package Error::INVALID_TARGET_DATE;
@Error::INVALID_TARGET_DATE::ISA = qw(Error::Simple);
1;

package Error::INVALID_DATE;
@Error::INVALID_DATE::ISA = qw(Error::Simple);
1;

package Error::INVALID_USERNAME;
@Error::INVALID_USERNAME::ISA = qw(Error::Simple);
1;

package Error::NO_URL;
@Error::NO_URL::ISA = qw(Error::Simple);
1;

package Error::PERMISSION_DENIED;
@Error::PERMISSION_DENIED::ISA = qw(Error::Simple);
1;

#Min's addition for handling case where project name has a slash
package Error::BAD_WIKI_CATEGORY_NAME;
@Error::BAD_WIKI_CATEGORY_NAME::ISA = qw(Error::Simple);
1;
