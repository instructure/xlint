require_relative 'spec_helper'

describe Xlint do
  let(:d7bd5b4c) { File.read('spec/support/fixtures/7bd5b4c-7713b17.diff') }
  let(:d8cd7a2b) { File.read('spec/support/fixtures/8cd7a2b-8741d11.diff') }
  let(:file0) { 'APP.xcodeproj/project.pbxproj' }
  let(:file1) { 'APP.xcodeproj/xcshareddata/xcschemes/APP.xcscheme' }
  let(:body0) { File.read('spec/support/fixtures/body0.diff') }
  let(:body1) { File.read('spec/support/fixtures/body1.diff') }
  let(:line_number0) { 3194 }
  let(:line_number1) { 3247 }
  let(:message) { 'Deployment target changes should be approved by the team lead.' }
  let(:severity) { 'error' }

  before(:each) do
    ARGV.clear
    ENV.clear
  end

  after(:each) do
    ARGV.clear
    ENV.clear
  end

  describe 'argument and env checks' do
    let(:arg_error) { 'usage: xlint path/to/some.diff' }
    let(:key_error) { 'ENV[GERGICH_KEY] not defined' }
    let(:project_error) { 'ENV[GERRIT_PROJECT] not defined' }

    it 'raises argument error when ARGV is empty' do
      expect { Xlint.check_args }.to raise_error(ArgumentError, arg_error)
    end

    it 'does not raise argument error when ARGV is set' do
      ARGV << 'someArgument'
      expect { Xlint.check_args }.to_not raise_error
    end

    it 'raises runtime error when gergich_key not set' do
      expect { Xlint.check_env }.to raise_error(RuntimeError, key_error)
    end

    it 'raises runtime error when gerrit_project not set' do
      ENV['GERGICH_KEY'] = 'someKey'
      expect { Xlint.check_env }.to raise_error(RuntimeError, project_error)
    end

    it 'does not raise error when ENV variables set' do
      ENV['GERGICH_KEY'] = 'someKey'
      ENV['GERRIT_PROJECT'] = 'someProject'
      expect { Xlint.check_env }.to_not raise_error
    end
  end

  describe 'build_draft' do
    let(:dirty_patch) { 'spec/support/fixtures/7bd5b4c-7713b17.diff' }
    let(:clean_patch) { 'spec/support/fixtures/8cd7a2b-8741d11.diff' }

    it 'has empty comments when diff is clean' do
      ARGV << clean_patch
      Xlint.build_draft
      expect(Xlint.instance_variable_get(:@comments).length).to eq 0
    end

    it 'has comments when diff is dirty' do
      ARGV << dirty_patch
      Xlint.build_draft
      expect(Xlint.instance_variable_get(:@comments).length).to be > 0
    end

    it 'has well formed comments' do
      ARGV << dirty_patch
      Xlint.build_draft
      expect(Xlint.instance_variable_get(:@comments).length).to be > 0
      expect(Xlint.instance_variable_get(:@comments)[0][:path]).to eq file0
      expect(Xlint.instance_variable_get(:@comments)[0][:position]).to eq line_number0
      expect(Xlint.instance_variable_get(:@comments)[0][:message]).to eq message
      expect(Xlint.instance_variable_get(:@comments)[0][:severity]).to eq severity
    end
  end

  context 'gergich commands' do
    let(:bad_comments) { { someKey: 'someValue' } }
    let(:good_comments) { { path: 'somePath', position: 1234, message: 'someMessage', severity: 'error' } }
    let(:comment_error) { 'gergich comment command failed!' }
    let(:publish_error) { 'gergich publish command failed!' }

    describe 'save_draft' do
      it 'does not raise error if comments are empty' do
        Xlint.instance_variable_set(:@comments, [])
        expect { Xlint.save_draft }.to_not raise_error
      end

      it 'raises error when comments are malformed' do
        Xlint.instance_variable_set(:@comments, bad_comments)
        expect { Xlint.save_draft }.to raise_error(RuntimeError, comment_error)
      end
    end

    describe 'publish_draft' do
      it 'does not raise error if comments are empty' do
        Xlint.instance_variable_set(:@comments, [])
        expect { Xlint.save_draft }.to_not raise_error
      end

      it 'raises error when gerrit_base_url not set' do
        Xlint.instance_variable_set(:@comments, good_comments)
        expect { Xlint.publish_draft }.to raise_error(RuntimeError)
      end

      it 'raises error when gerrit_base_url not set' do
        ENV['GERRIT_BASE_URL'] = 'someBase'
        Xlint.instance_variable_set(:@comments, good_comments)
        expect { Xlint.publish_draft }.to raise_error(RuntimeError)
      end
    end
  end

  describe 'parse_git' do
    let(:empty_patch) { File.read('spec/support/fixtures/empty_patch.diff') }

    it 'parses empty patch' do
      expect(Xlint.parse_git(empty_patch)).to be_empty
    end

    it 'parses non-empty patch' do
      expect(Xlint.parse_git(d7bd5b4c)).not_to be_empty
    end

    it 'parses patch file names' do
      patch_body = Xlint.parse_git(d7bd5b4c)
      expect(patch_body.size).to eq 2
      expect(patch_body[0].file).to eq file0
      expect(patch_body[1].file).to eq file1
    end

    it 'parses patch body' do
      patch_body = Xlint.parse_git(d7bd5b4c)
      expect(patch_body.size).to eq 2
      expect(patch_body[0].body).to eq body0
      expect(patch_body[1].body).to eq body1
    end
  end

  describe 'patch_body_changes' do
    let(:header0) { File.read('spec/support/fixtures/header0.diff') }
    let(:header1) { File.read('spec/support/fixtures/header1.diff') }
    let(:start0) { 3191 }
    let(:start1) { 3244 }
    let(:modified) { /(^([+]|[-]))/ }

    it 'returns starting line number' do
      expect(Xlint.starting_line_number(header0)).to eq start0
      expect(Xlint.starting_line_number(header1)).to eq start1
    end

    it 'maps changes to file, line, and line number' do
      changes = Xlint.patch_body_changes(body0, file0)
      expect(changes.size).to eq 2
      expect(changes[0][:file]).to eq file0
      expect(changes[1][:file]).to eq file0
      expect(changes[0][:line]).to match modified
      expect(changes[1][:line]).to match modified
      expect(changes[0][:line_number]).to eq line_number0
      expect(changes[1][:line_number]).to eq line_number1
    end
  end

  describe 'deployment target changes' do
    it 'detects changes to deployment target' do
      changes = Xlint.patch_body_changes(body0, file0)
      offenses = Xlint.find_offenses(changes)
      expect(offenses.size).to eq 2
      expect(offenses[0][:path]).to eq file0
      expect(offenses[0][:position]).to eq line_number0
      expect(offenses[0][:message]).to eq message
      expect(offenses[0][:severity]).to eq severity
      expect(offenses[1][:path]).to eq file0
      expect(offenses[1][:position]).to eq line_number1
      expect(offenses[1][:message]).to eq message
      expect(offenses[1][:severity]).to eq severity
    end
  end
end
