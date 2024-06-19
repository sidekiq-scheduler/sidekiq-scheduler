RSpec.describe SidekiqScheduler::Config do
  let(:config) { described_class.new(sidekiq_config: sidekiq_config) }
  let(:sidekiq_config) { SConfigWrapper.new.reset!(input_config) }
  let(:input_config) { {} }

  describe '#to_hash' do
    subject { config.to_hash }

    it 'returns a hash of the config' do
      expect(subject).to eq(
        {
          enabled: true,
          dynamic: false,
          dynamic_every: '5s',
          shedule: {},
          listened_queues_only: nil,
          rufus_scheduler_options: {}
        }
      )
    end
  end
end
