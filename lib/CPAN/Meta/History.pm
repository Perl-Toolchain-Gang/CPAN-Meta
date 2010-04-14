# vi:tw=72
use 5.006;
use strict;
use warnings;
use autodie;
package CPAN::Meta::History;
# ABSTRACT: history of CPAN Meta Spec changes
1;

=head1 DESCRIPTION

The CPAN Meta Spec has gone through several evolutionary staged.  It was
originally written in HTML and later revised into POD (though published
in HTML generated from the POD).

This document reconstructs the changes in the CPAN Meta Spec based on
change logs, repository commit messages and the published HTML files.
In some cases, particularly prior to version 1.2, the exact sequence
when certain fields were introduced or changed is inconsistent between
sources.  When in doubt, the published HTML files for versions 1.0 to
1.4 as they existed when verison 2 was developed are used as the
definitive source.

Starting with version 2, the specification is part of the CPAN-Meta
distribution and will be published on CPAN as L<CPAN::Meta::Spec>.

=head1 HISTORY

=head2 Version 2

  - Revised spec examples as perl data structures rather than YAML

  - Switched to JSON serialization from YAML

  - Specified allowed version number formats

  - Replaced 'requires', 'build_requires', 'configure_requires',
    'recommends' and 'conflicts' with new 'prereqs' data structure
    divided by _phase_ (configure, build, test, runtime, etc.) and
    _relationship_ (requires, recommends, suggests, conflicts)

  - Added support for 'develop' phase for requirements for maintaining
    a list of authoring tools

  - Changed 'license' to a list and revised the set of valid licenses

  - Made dynamic_config mandatory to reduce confusion

  - Changed 'resources' subkey 'repository' to a hash that clarifies
    repository type, url for browsing and url for checkout

  - Changed 'resources' subkey 'bugtracker' to a hash for either web
    or mailto resource

  - Changed specification of 'optional_features':
      - Added formal specification and usage guide instead of just example
      - Changed to use new prereqs data structure instead of individual keys

  - Clarified intended use of 'author' as generalized contact list

  - Added 'release_status' field to indicate stable, testing or unstable
    status to provide hints to indexers

  - Added 'description' field for a longer description of the distribution

  - Formalized use of "x_" or "X_" for all custom keys not listed in the
    official spec

=head2 Version 1.4

  - Noted explicit support for 'perl' in prerequisites

  - Added 'configure_requires' prerequisite type

  - Changed 'optional_features'
      - example corrected to show map of maps instead of list of maps
        (though descriptive text said 'map' even in v1.3)
      - removed 'requires_packages', 'requires_os' and 'excluded_os'
        as valid subkeys

=head2 Version 1.3

  - Clarified that all prerequisites take version range specifications

  - Added 'no_index' subkey 'directory' and removed 'dir' to match
    actual usage in the wild

  - Added a 'repository' subkey to 'resources'

=head2 Version 1.2

  - Re-wrote and restructured spec in POD syntax

  - Changed 'name' to be mandatory

  - Changed 'license' to be mandatory

  - Added required 'abstract' field

  - Added required 'author' field

  - Added required 'meta-spec' field to define 'version' (and 'url')
    of the CPAN Meta Spec used for metadata

  - Added 'provides' field

  - Added 'no_index' field and deprecated 'private' field.  'no_index'
    subkeys include 'file', 'dir', 'package' and 'namespace'

  - Added 'keywords' field

  - Added 'resources' field with subkeys 'homepage', 'license',
    and 'bugtracker'

  - Added 'optional_features' field as an alterate under 'recommends'.
    Includes 'description', 'requires', 'build_requires', 'conflicts',
    'requires_packages', 'requires_os' and 'excluded_os' as valid subkeys

  - Removed 'license_uri' field

=head2 Version 1.1

  - Changed 'version' to be mandatory

  - Added 'private' field

  - Added 'license_uri' field

=head2 Version 1.0

  - Original release (in HTML format only)

  - Included 'name', 'version', 'license', 'distribution_type',
    'requires', 'recommends', 'build_requires', 'conflicts',
    'dynamic_config', 'generated_by'

=cut

