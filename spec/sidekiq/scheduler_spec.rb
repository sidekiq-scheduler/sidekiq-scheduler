describe Sidekiq::Scheduler do
  it 'should be an alias of SidekiqScheduler::Scheduler' do
    expect(described_class).to eql(SidekiqScheduler::Scheduler)
  end
end
