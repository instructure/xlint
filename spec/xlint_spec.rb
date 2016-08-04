require_relative 'spec_helper'

describe Xlint do
  let(:dirty_patch) { 'spec/support/fixtures/7bd5b4c-7713b17.diff' }
  let(:clean_patch) { 'spec/support/fixtures/8cd7a2b-8741d11.diff' }
  let(:d7bd5b4c) { File.read('spec/support/fixtures/7bd5b4c-7713b17.diff') }
  let(:d8cd7a2b) { File.read('spec/support/fixtures/8cd7a2b-8741d11.diff') }
  let(:pdf_diff) { 'spec/support/fixtures/pdf.diff' }
  let(:file0) { 'APP.xcodeproj/project.pbxproj' }
  let(:file1) { 'APP.xcodeproj/xcshareddata/xcschemes/APP.xcscheme' }
  let(:body0) { File.read('spec/support/fixtures/body0.diff') }
  let(:body1) { File.read('spec/support/fixtures/body1.diff') }
  let(:body2) { File.read('spec/support/fixtures/body2.diff') }
  let(:line_number0) { 3194 }
  let(:line_number1) { 3247 }
  let(:line_number2) { 5651 }
  let(:line_number3) { 5664 }
  let(:message) { 'Deployment target changes should be approved by the team lead.' }
  let(:severity) { 'error' }

  before(:each) do
    ARGV.clear
    ENV.clear
    Xlint.clear
  end

  describe 'argument and env checks' do
    let(:arg_error) { 'usage: xlint path/to/some.diff' }
    let(:key_error) { 'ENV[GERGICH_KEY] not defined' }
    let(:project_error) { 'ENV[GERRIT_PROJECT] not defined' }

    it 'raises argument error when ARGV is empty' do
      expect { Xlint.check_args }.to raise_error(ArgumentError, arg_error)
    end

    it 'raises error when file does not exist' do
      ARGV << 'someArgument'
      expect { Xlint.check_args }.to raise_error(RuntimeError)
    end

    it 'does not raise error when file exists' do
      ARGV << dirty_patch
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
    it 'has empty comments when diff is clean' do
      Xlint.diff_file = clean_patch
      Xlint.build_draft
      expect(Xlint.comments.length).to eq 0
    end

    it 'has comments when diff is dirty' do
      Xlint.diff_file = dirty_patch
      Xlint.build_draft
      expect(Xlint.comments.length).to be > 0
    end

    it 'has well formed comments' do
      Xlint.diff_file = dirty_patch
      Xlint.build_draft
      expect(Xlint.comments.length).to be > 0
      expect(Xlint.comments[0][:path]).to eq file0
      expect(Xlint.comments[0][:position]).to eq line_number0
      expect(Xlint.comments[0][:message]).to eq message
      expect(Xlint.comments[0][:severity]).to eq severity
    end

    it 'handles invalid byte sequences' do
      Xlint.diff_file = pdf_diff
      expect { Xlint.build_draft }.to_not raise_error
    end
  end

  context 'gergich commands' do
    let(:bad_comments) { { someKey: 'someValue' } }
    let(:good_comments) { { path: 'somePath', position: 1234, message: 'someMessage', severity: 'error' } }
    let(:comment_error) { 'gergich comment command failed!' }
    let(:publish_error) { 'gergich publish command failed!' }
    let(:draft_label) { 'Code-Review' }
    let(:review_label) { 'Lint-Review' }
    let(:fail_message) { 'Xlint is worried about your commit' }
    let(:pass_message) { 'Xlint didn\'t find anything to complain about' }

    describe 'save_draft' do
      it 'does not raise error if comments are empty' do
        expect { Xlint.save_draft }.to_not raise_error
      end

      it 'raises error when comments are malformed' do
        Xlint.comments << bad_comments
        expect { Xlint.save_draft }.to raise_error(GergichError)
      end

      it 'has a default code-review score of zero' do
        Xlint.save_draft
        expect(Xlint.draft.labels[draft_label]).to be 0
      end

      it 'has a failure code-review score' do
        Xlint.comments << good_comments
        Xlint.save_draft
        expect(Xlint.draft.labels[draft_label]).to be(-2)
      end
    end

    describe 'build_label' do
      it 'adds labels when gergich_review_label is set' do
        ENV['GERGICH_REVIEW_LABEL'] = review_label
        Xlint.save_draft
        Xlint.build_label
        expect(Xlint.draft.labels[review_label]).to be_truthy
      end

      it 'adds failure label' do
        ENV['GERGICH_REVIEW_LABEL'] = review_label
        Xlint.comments << good_comments
        Xlint.save_draft
        Xlint.build_label
        expect(Xlint.draft.messages.length).to be 1
        expect(Xlint.draft.messages.first).to eq fail_message
        expect(Xlint.draft.labels[review_label]).to be(-1)
      end

      it 'add passing label' do
        ENV['GERGICH_REVIEW_LABEL'] = review_label
        Xlint.save_draft
        Xlint.build_label
        expect(Xlint.draft.messages.length).to be 1
        expect(Xlint.draft.messages.first).to eq pass_message
        expect(Xlint.draft.labels[review_label]).to be 1
      end
    end

    describe 'publish_draft' do
      it 'does not raise error if comments are empty' do
        expect { Xlint.save_draft }.to_not raise_error
      end

      it 'raises error when gerrit_base_url not set' do
        Xlint.comments << good_comments
        expect { Xlint.publish_draft }.to raise_error(GergichError)
      end

      it 'raises error when gerrit_host not set' do
        ENV['GERRIT_BASE_URL'] = 'someBase'
        Xlint.comments << good_comments
        expect { Xlint.publish_draft }.to raise_error(KeyError)
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
    context 'when git header line numbers match' do
      it 'detects deployment target changes' do
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

    context 'when git header line numbers do not match' do
      it 'detects deployment target changes' do
        changes = Xlint.patch_body_changes(body2, file0)
        offenses = Xlint.find_offenses(changes)
        expect(offenses.size).to eq 2
        expect(offenses[0][:path]).to eq file0
        expect(offenses[0][:position]).to eq line_number2
        expect(offenses[0][:message]).to eq message
        expect(offenses[0][:severity]).to eq severity
        expect(offenses[1][:path]).to eq file0
        expect(offenses[1][:position]).to eq line_number3
        expect(offenses[1][:message]).to eq message
        expect(offenses[1][:severity]).to eq severity
      end
    end
  end

  describe 'valid git header' do
    it 'returns thruthy when header has only one change' do
      expect(Xlint.valid_git_header?('@@ -0,0 +1 @@')).to be_truthy
    end

    it 'returns truthy when header has multiple adds and removals' do
      expect(Xlint.valid_git_header?('@@ -1,37 +1,63 @@')).to be_truthy
    end

    it 'returns truthy when header has only one removal and multiple adds' do
      expect(Xlint.valid_git_header?('@@ -1 +1,63 @@')).to be_truthy
    end

    it 'returns truthy when header has multiple removals and only one add' do
      expect(Xlint.valid_git_header?('@@ -1,37 +1 @@')).to be_truthy
    end

    it 'returns falsey when header is missing whitespace before removals' do
      expect(Xlint.valid_git_header?('@@-1 +1 @@')).to be_falsey
    end

    it 'returns falsey when header is missing whitespace after adds' do
      expect(Xlint.valid_git_header?('@@ -1 +1@@')).to be_falsey
    end

    it 'returns falsey when header is missing whitespace between removal and adds' do
      expect(Xlint.valid_git_header?('@@ -1+1 @@')).to be_falsey
    end

    it 'returns falsey when header is missing minus sign' do
      expect(Xlint.valid_git_header?('@@ 1 +1 @@')).to be_falsey
    end

    it 'returns falsey when header is missing plus sign' do
      expect(Xlint.valid_git_header?('@@ -1 1 @@')).to be_falsey
    end

    it 'returns falsey when header is missing signs' do
      expect(Xlint.valid_git_header?('@@ 1 1 @@')).to be_falsey
    end

    it 'returns falsey when header is missing leading @@ symbols' do
      expect(Xlint.valid_git_header?('-0,0 +1 @@')).to be_falsey
    end

    it 'returns falsey when header is missing trailing @@ symbols' do
      expect(Xlint.valid_git_header?('@@ -0,0 +1 ')).to be_falsey
    end
  end
end
