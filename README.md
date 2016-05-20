# Xlint

[![Gem Version](https://badge.fury.io/rb/xlint.svg)](https://rubygems.org/gems/xlint)
[![Build Status](https://travis-ci.org/instructure/xlint.svg?branch=master)](https://travis-ci.org/instructure/xlint)
[![Code Climate](https://codeclimate.com/github/instructure/xlint/badges/gpa.svg)](https://codeclimate.com/github/instructure/xlint)
[![Coverage Status](https://coveralls.io/repos/github/instructure/xlint/badge.svg?branch=HEAD)](https://coveralls.io/github/instructure/xlint?branch=HEAD)
[![Dependency Status](https://gemnasium.com/badges/github.com/instructure/xlint.svg)](https://gemnasium.com/github.com/instructure/xlint)

Xlint is command-line tool for linting XCode project files and posting
comments on a [Gerrit](https://www.gerritcodereview.com/) review from a
CI environment. We developed this gem because its really easy to change
the deployment target of an app and have the change be missed in the
code review process. Xlint sees these changes and provides inline comments
in the Gerrit review.

## How does it work?

Xlint parses the changes in a patchset, and runs each change through
a validator. If the validator detects any issues, a [Gergich](https://rubygems.org/gems/gergich)
comment is created. After all the changes have been checked, Xlint
publishes the Gergich comments to Gerrit. If the CI environment has a variable for a Gerrit review label, Xlint will also post a reply to the label.

## Limitations

Xlint currently only detects changes to the deployment target within
Xcode .pbxproj files.

## Installation and Usage

[Gergich][gergich] and Gerrit must be configured as defined in the Gergich gem. If
[Gergich][gergich] works, then all you need to do is `gem install xlint` and Xlint
is ready for linting.

[gergich]: https://github.com/instructure/gergich

### Setup Gerrit and Gergich Environment Variables on Jenkins
* Install EnvInject Jenkins Plugin (Manage Jenkins > Manage Plugins > Available Filter: EnvInject)
Note: The Jenkins version on Cloudbees does not currently work with EnvInject.
* Add the following Global property (Jenkins Configuration > Global Properties)

> GERGICH_KEY
```
Name: GERGICH_KEY
Value: <access_key_for_gergich_user_on_gerrit>
```

* Check "This project is parameterized" (Job Configuration > General)
* Add the following String Parameters to (Job Configuration > General

> GERRIT_REFSPEC
```
Name: GERRIT_REFSPEC
Default Value: HEAD:refs/for
```

> GERRIT_BRANCH
```
Name: GERRIT_BRANCH
Default Value: develop 
```

> GERGICH_REVIEW_LABEL
```
Name: GERGICH_REVIEW_LABEL
Default Value: Lint-Review
```

* Check "Inject environment variables to the build process" (Job Configuration > Build Environment)

### Setup Lint-Review on Gerrit
In the meta/config branch of your Gerrit project, you need to add "Linter Bots" to your groups file, create the Lint-Review label, and grant access to bots in the project.config file.

> groups
```
# UUID                                Group Name
#
<uuid_for_developers_group>           Developers
<uuid_for_robots_group>               Robots
<uuid_for_administrators_group>       Administrators
<uuid_for_linter_bots_group>          Linter Bots
```

> project.config
```
[access "refs/*"]
    owner = group Administrators
    owner = group Developers
    read = group Robots
[label "Lint-Review"]
    function = AnyWithBlock
    abbreviation = L
    value = -2 Error
    value = -1 Warning
    value =  0 No score
    value = +1 Verified
    defaultValue = 0
[access "refs/heads/*"]
    label-Lint-Review = -2..1 group Linter Bots
```

* For additional information on Gerrit project labels, [review the Gerrit documentation](https://gerrit-review.googlesource.com/Documentation/config-labels.html)

* How do I checkout, commit, and push to the meta/config branch?
    * ``` git fetch origin refs/meta/config:refs/remotes/origin/meta/config ```
    * ``` git checkout meta/config ```
    * ``` git add project.config ```
    * ``` git commit -m "add Lint-Review" ```
    * ``` git push origin HEAD:refs/meta/config ```

### Setup Xlint to Run in Jenkins Job
Add the following to build script (Job Configuration > Build > Execute Shell > Command)
``` bash
#!/bin/bash --login

ruby -v

if ! gem list xlint -i; then
    gem install --no-document xlint
else
    gem update xlint
fi

git diff HEAD~1 HEAD > changes.diff
xlint changes.diff

# if using Fastlane
# fastlane lint

echo ''
echo 'Gergich Status:'
gergich status
```

Add a lint lane to Fastlane:
``` ruby
desc 'Xlint'
  lane :lint do
    if ENV['GERRIT_PROJECT']
      changes_diff = 'changes.diff'
      sh "git diff HEAD~1 HEAD > #{changes_diff}"
      begin
        sh "xlint #{changes_diff}"
      ensure
        File.delete(changes_diff) if File.exists?(changes_diff)
      end
    end
  end
```
