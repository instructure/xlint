require 'rubygems'
require_relative 'xlint/version'
require 'git_diff_parser'
require 'json'
require 'shellwords'

class Xlint
  class << self
    def check_args
      # reads git diff from file, file name in ARGV[0]
      raise ArgumentError, 'usage: xlint path/to/some.diff' unless ARGV.size == 1
    end

    def check_env
      raise 'ENV[GERGICH_KEY] not defined' unless ENV['GERGICH_KEY']
      raise 'ENV[GERRIT_PROJECT] not defined' unless ENV['GERRIT_PROJECT']
    end

    def build_draft
      @comments = []
      diff = Xlint.parse_git(File.read(ARGV[0]))
      diff.files.each do |file|
        patch = diff.find_patch_by_file(file)
        changes = Xlint.patch_body_changes(patch.body, file)
        @comments.concat(Xlint.find_offenses(changes))
      end
    end

    def save_draft
      return if @comments.empty?
      raise 'gergich comment command failed!' unless system("gergich comment #{Shellwords.escape(@comments.to_json)}")
    end

    def publish_draft
      return if @comments.empty?
      raise 'gergich publish command failed!' unless system('gergich publish')
    end

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
