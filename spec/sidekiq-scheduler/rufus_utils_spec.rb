describe SidekiqScheduler::RufusUtils do
  subject(:utils) { described_class }

  describe '.normalize_schedule_options' do
    context 'with schedule only' do
      let(:args) { '10s' }

      it 'returns the schedule and empty options' do
        schedule, opts = utils.normalize_schedule_options(args)

        expect(schedule).to eq('10s')
        expect(opts).to eq({})
      end
    end

    context 'with schedule being contained in an array' do
      let(:args) { ['10s'] }

      it 'returns the schedule and empty options' do
        schedule, opts = utils.normalize_schedule_options(args)

        expect(schedule).to eq('10s')
        expect(opts).to eq({})
      end
    end

    context 'with schedule only and options' do
      let(:args) { utils.normalize_schedule_options(['10s', first_in: '5m']) }

      it 'returns both of them' do
        schedule, opts = utils.normalize_schedule_options(args)

        expect(schedule).to eq('10s')
        expect(opts).to include(first_in: '5m')
      end
    end

    context 'with extra options' do
      let(:args) { ['10s', { first_in: '5m' }, { tag: 'test' }] }

      it 'ignores them' do
        schedule, opts, extra = utils.normalize_schedule_options(args);

        expect(schedule).to eq('10s')
        expect(opts).to include(first_in: '5m')
        expect(extra).to be_nil
      end
    end

    context 'with options not being a Hash' do
      let(:args) { ['10s', true] }

      it 'returns an empty options hash' do
        schedule, opts = utils.normalize_schedule_options(args)

        expect(schedule).to eq('10s')
        expect(opts).to eq({})
      end
    end
  end
end
