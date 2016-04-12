require 'rubygems'
require_relative 'xlint/version'
require 'git_diff_parser'
require 'json'
require 'shellwords'

class Xlint
  class << self
    def parse_git(diff)
      GitDiffParser::Patches.parse(diff)
    end

    def patch_body_changes(body, file)
      result = []
      line_number = 0
      body.split("\n").each do |line|
        if line.start_with?('@@')
          line_number = starting_line_number(line)
          next
        end
        next if line.start_with?('-')
        result.push(file: file, line: line, line_number: line_number) if line.start_with?('+')
        line_number += 1
      end
      result
    end

    # expects git header in the form of: @@ -215,13 +215,7 @@
    def starting_line_number(header)
      str = header.split(' ')[1].split(',')[0]
      str.slice!('-')
      str.to_i
    end

    # only checks for deployment target changes,
    # we can add more rules in the future here
    def find_offenses(changes)
      offenses = []
      changes.each do |change|
        warnings = check_deployment_target(change)
        offenses.concat(warnings) unless warnings.empty?
      end
      offenses
    end

    def check_deployment_target(change)
      offenses = []
      if change[:file] =~ /(.pbxproj)/ && change[:line] =~ /(DEPLOYMENT_TARGET =)/
        offense = {
          path: change[:file],
          position: change[:line_number],
          message: 'Deployment target changes should be approved by the team lead.',
          severity: 'error'
        }
        offenses.push(offense)
      end
      offenses
    end
  end
end
