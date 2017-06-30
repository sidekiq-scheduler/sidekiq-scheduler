describe SidekiqScheduler::RufusUtils do

  describe '.normalize_schedule_options' do
    subject { described_class.normalize_schedule_options(args) }

    context 'with schedule only' do
      let(:args) { '10s' }

      it 'returns the schedule and empty options' do
        schedule, opts = subject

        expect(schedule).to eq('10s')
        expect(opts).to be_empty
      end
    end

    context 'with schedule being contained in an array' do
      let(:args) { ['10s'] }

      it 'returns the schedule and empty options' do
        schedule, opts = subject

        expect(schedule).to eq('10s')
        expect(opts).to be_empty
      end
    end

    context 'with schedule only and options' do
      let(:args) { ['10s', first_in: '5m'] }

      it 'returns both of them' do
        schedule, opts = subject

        expect(schedule).to eq('10s')
        expect(opts).to include(first_in: '5m')
      end
    end

    context 'with extra options' do
      let(:args) { ['10s', { first_in: '5m' }, { tag: 'test' }] }

      it 'ignores them' do
        schedule, opts, extra = subject

        expect(schedule).to eq('10s')
        expect(opts).to include(first_in: '5m')
        expect(extra).to be_nil
      end
    end

    context 'with options not being a Hash' do
      let(:args) { ['10s', true] }

      it 'returns an empty options hash' do
        schedule, opts = subject

        expect(schedule).to eq('10s')
        expect(opts).to be_empty
      end
    end
  end
end
