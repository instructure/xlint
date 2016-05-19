require 'rubygems'
require_relative 'xlint/version'
require 'git_diff_parser'
require 'json'
require 'shellwords'
require 'gergich'

class Xlint
  class << self
    attr_accessor :diff_file, :draft, :comments

    def clear
      @diff_file = nil
      @draft.reset! if draft
      @comments = []
    end

    def check_args
      # reads git diff from file, file name in ARGV[0]
      raise ArgumentError, 'usage: xlint path/to/some.diff' unless ARGV.size == 1
      @diff_file = ARGV.first
      raise "File does not exist: #{diff_file}" unless File.exist?(diff_file)
    end

    def check_env
      raise 'ENV[GERGICH_KEY] not defined' unless ENV['GERGICH_KEY']
      raise 'ENV[GERRIT_PROJECT] not defined' unless ENV['GERRIT_PROJECT']
    end

    def build_draft
      @comments = []
      # GitDiffParser::Patches.parse(cp932 text) raises ArgumentError: invalid byte sequence in UTF-8
      # https://github.com/packsaddle/ruby-git_diff_parser/issues/91
      diff_data = File.read(diff_file)
      diff_data.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      diff = Xlint.parse_git(diff_data)
      diff.files.each do |file|
        patch = diff.find_patch_by_file(file)
        changes = Xlint.patch_body_changes(patch.body, file)
        @comments.concat(Xlint.find_offenses(changes))
      end
    end

    def save_draft
      @draft = Gergich::Draft.new
      comments.each do |comment|
        draft.add_comment(comment[:path], comment[:position], comment[:message], comment[:severity])
      end
    end

    def build_label
      return unless ENV['GERGICH_REVIEW_LABEL']
      score = comments.empty? ? 1 : -1
      message = comments.empty? ? 'Xlint didn\'t find anything to complain about' : 'Xlint is worried about your commit'
      draft.add_message(message)
      draft.add_label(ENV['GERGICH_REVIEW_LABEL'], score)
    end

    def publish_draft
      Gergich::Review.new.publish!
    end

    def publish
      check_args
      check_env
      build_draft
      save_draft
      build_label
      publish_draft
    end

    def parse_git(diff)
      GitDiffParser::Patches.parse(diff)
    end

    def patch_body_changes(body, file)
      result = []
      line_number = 0
      body.split("\n").each do |line|
        if valid_git_header?(line)
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

    def valid_git_header?(line)
      line =~ /^(@{2})\s([-]{1}[0-9]*(,[0-9]*)?)\s([+][0-9]*(,[0-9]*)?)\s(@{2})$/
    end
  end
end
