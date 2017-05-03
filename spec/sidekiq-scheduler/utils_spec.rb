require 'sidekiq-scheduler/utils'

describe SidekiqScheduler::Utils do
  subject(:utils) { described_class }

  describe '.stringify_keys' do
    subject(:result) { utils.stringify_keys(object) }

    context 'with a Hash' do
      let(:object) do
        {
          some_symbol_key: 'symbol',
          'some_string_key' => 'string',
          [1, 2] => 'object',
          nesting: {
            level_1: {
              level_2: 2,
            }
          }
        }
      end

      let(:expected) do
        {
          'some_symbol_key' => 'symbol',
          'some_string_key' => 'string',
          '[1, 2]' => 'object',
          'nesting' => {
            'level_1' => {
              'level_2' => 2,
            }
          }
        }
      end

      it { should eq(expected) }
    end

    context 'with an Array' do
      let(:object) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            'some_string_key' => 'string',
            nesting: {
              level_1: {
                level_2: 2,
              }
            }
          }
        ]
      end

      let(:expected) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            'some_string_key' => 'string',
            'nesting' => {
              'level_1' => {
                'level_2' => 2,
              }
            }
          }
        ]
      end

      it { should eq(expected) }
    end

    context 'with some other object' do
      let(:object) { Object.new }

      let(:expected) { object }

      it { should eq(expected) }
    end
  end

  describe '.symbolize_keys' do
    subject(:result) { utils.symbolize_keys(object) }

    context 'with a Hash' do
      let(:object) do
        {
          some_symbol_key: 'symbol',
          'some_string_key' => 'string',
          'nesting': {
            'level_1': {
              'level_2': 2,
            }
          }
        }
      end

      let(:expected) do
        {
          some_symbol_key: 'symbol',
          some_string_key: 'string',
          nesting: {
            level_1: {
              level_2: 2,
            }
          }
        }
      end

      it { should eq(expected) }
    end

    context 'with an Array' do
      let(:object) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            some_symbol_key: 'symbol',
            'nesting' => {
              'level_1' => {
                'level_2' => 2,
              }
            }
          }
        ]
      end

      let(:expected) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            some_symbol_key: 'symbol',
            nesting: {
              level_1: {
                level_2: 2,
              }
            }
          }
        ]
      end

      it { should eq(expected) }
    end

    context 'with some other object' do
      let(:object) { Object.new }

      let(:expected) { object }

      it { should eq(expected) }
    end
  end
end
