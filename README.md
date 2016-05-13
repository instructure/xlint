# Xlint

[![Gem Version](https://badge.fury.io/rb/xlint.svg)](https://rubygems.org/gems/xlint)
[![Build Status](https://travis-ci.org/instructure/xlint.svg?branch=master)](https://travis-ci.org/instructure/xlint)
[![Code Climate](https://codeclimate.com/github/instructure/xlint/badges/gpa.svg)](https://codeclimate.com/github/instructure/xlint)
[![Coverage Status](https://coveralls.io/repos/github/instructure/xlint/badge.svg?branch=master)](https://coveralls.io/github/instructure/xlint?branch=master)
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
publishes the Gergich comments to Gerrit.

## Limitations

Xlint currently only detects changes to the deployment target within
Xcode .pbxproj files.

## Installation

[Gergich][gergich] and Gerrit must be configured as defined in the Gergich gem. If
[Gergich][gergich] works, then all you need to do is `gem install xlint` and Xlint
is ready for linting.

[gergich]: https://github.com/instructure/gergich

## Usage

Xlint requires patchset changes be saved to a file and the filepath
passed to Xlint as a command-line argument.

## Example

```
git diff HEAD~1 HEAD > changes.diff
xlint changes.diff
```
