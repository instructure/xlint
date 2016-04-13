require_relative 'spec_helper'

describe 'Xlint' do
  let(:d7bd5b4c) { File.read('spec/support/fixtures/7bd5b4c-7713b17.diff') }
  let(:file0) { 'APP.xcodeproj/project.pbxproj' }
  let(:file1) { 'APP.xcodeproj/xcshareddata/xcschemes/APP.xcscheme' }
  let(:body0) { File.read('spec/support/fixtures/body0.diff') }
  let(:body1) { File.read('spec/support/fixtures/body1.diff') }

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
    let(:line_number0) { 3194 }
    let(:line_number1) { 3247 }
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
    let(:target) { /(DEPLOYMENT_TARGET =)/ }
    let(:line_number0) { 3194 }
    let(:line_number1) { 3247 }
    let(:message) { 'Deployment target changes should be approved by the team lead.' }
    let(:error) { 'error' }

    it 'detects changes to deployment target' do
      changes = Xlint.patch_body_changes(body0, file0)
      offenses = Xlint.find_offenses(changes)
      expect(offenses.size).to eq 2
      expect(offenses[0][:path]).to eq file0
      expect(offenses[0][:position]).to eq line_number0
      expect(offenses[0][:message]).to eq message
      expect(offenses[0][:severity]).to eq error
      expect(offenses[1][:path]).to eq file0
      expect(offenses[1][:position]).to eq line_number1
      expect(offenses[1][:message]).to eq message
      expect(offenses[1][:severity]).to eq error
    end
  end
end
