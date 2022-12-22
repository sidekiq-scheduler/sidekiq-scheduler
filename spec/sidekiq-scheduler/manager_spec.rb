describe SidekiqScheduler::Manager do

  describe '.new' do
    subject { described_class.new(scheduler_config) }

    let(:scheduler_config) { SidekiqScheduler::Config.new(sidekiq_config: @sconfig.reset!(scheduler_options)) }
    let(:scheduler_options) do
      {
        scheduler: {
          enabled: enabled,
          dynamic: false,
          dynamic_every: '5s',
          listened_queues_only: true,
          schedule: { 'current' => ScheduleFaker.cron_schedule('queue' => 'default') }
        }
      }
    end

    before do
      @sconfig = SConfigWrapper.new
      SidekiqScheduler::Scheduler.instance = nil
      Sidekiq.instance_variable_set(:@schedule, nil)
    end

    context 'when enabled option is true' do
      let(:enabled) { true }

      it {
        expect(SidekiqScheduler::Scheduler.instance).to be_a(SidekiqScheduler::Scheduler)
      }

      it {
        expect { subject }.to change { Sidekiq.schedule }.to(scheduler_options[:scheduler][:schedule])
      }

      describe 'scheduler attributes' do
        subject do
          described_class.new(scheduler_config)
          SidekiqScheduler::Scheduler.instance
        end

        it {
          expect(subject.enabled).to eql(scheduler_options[:scheduler][:enabled])
        }

        it {
          expect(subject.dynamic).to eql(scheduler_options[:scheduler][:dynamic])
        }

        it {
          expect(subject.dynamic_every).to eql(scheduler_options[:scheduler][:dynamic_every])
        }

        it {
          expect(subject.listened_queues_only).to eql(scheduler_options[:scheduler][:listened_queues_only])
        }
      end
    end

    context 'when enabled option is false' do
      let(:enabled) { false }

      it {
        expect(SidekiqScheduler::Scheduler.instance).to be_a(SidekiqScheduler::Scheduler)
      }

      it {
        expect { subject }.not_to change { Sidekiq.schedule }
      }

      describe 'scheduler attributes' do
        subject do
          described_class.new(scheduler_config)
          SidekiqScheduler::Scheduler.instance
        end

        it {
          expect(subject.enabled).to eql(scheduler_options[:scheduler][:enabled])
        }

        it {
          expect(subject.dynamic).to eql(scheduler_options[:scheduler][:dynamic])
        }

        it {
          expect(subject.listened_queues_only).to eql(scheduler_options[:scheduler][:listened_queues_only])
        }

        it {
          expect(subject.listened_queues_only).to eql(scheduler_options[:scheduler][:listened_queues_only])
        }
      end
    end

    context 'when scheduler configuration is already set' do
      let(:enabled) { true }

      context 'when schedule is set' do
        before { Sidekiq.schedule = { previous: ScheduleFaker.cron_schedule } }

        it {
          expect { subject }.not_to change { Sidekiq.schedule }
        }

        context 'when enabled option is false' do
          let(:enabled) { false }

          it {
            expect { subject }.not_to change { Sidekiq.schedule }
          }
        end
      end

      context 'when scheduler options are set' do
        let(:previous_options) do
          {
            scheduler: {
              enabled: false,
              dynamic: true,
              dynamic_every: nil
            }
          }
        end

        before do
          sidekiq_previous_config = sidekiq_config_for_options(previous_options)
          previous_config = SidekiqScheduler::Config.new(sidekiq_config: sidekiq_previous_config)
          SidekiqScheduler::Scheduler.instance = SidekiqScheduler::Scheduler.new(previous_config)
        end

        describe 'scheduler attributes' do
          subject do
            described_class.new(scheduler_config)
            SidekiqScheduler::Scheduler.instance
          end

          it {
            expect(subject.enabled).to eql(previous_options[:scheduler][:enabled])
          }

          it {
            expect(subject.dynamic).to eql(previous_options[:scheduler][:dynamic])
          }

          it {
            expect(subject.dynamic_every).to eql(scheduler_options[:scheduler][:dynamic_every])
          }

          it {
            expect(subject.listened_queues_only).to eql(scheduler_options[:scheduler][:listened_queues_only])
          }
        end
      end
    end

    context 'when no options are passed' do
      let(:scheduler_options) { { scheduler: {} } }

      it do
        subject

        expect(SidekiqScheduler::Scheduler.instance).to be_a(SidekiqScheduler::Scheduler)
      end

      it {
        expect { subject }.to change { Sidekiq.schedule }.to({})
      }

      describe 'scheduler attributes' do
        subject do
          sidekiq_config = sidekiq_config_for_options(scheduler_options)
          described_class.new(SidekiqScheduler::Config.new(sidekiq_config: sidekiq_config))
          SidekiqScheduler::Scheduler.instance
        end

        it {
          expect(subject.enabled).to be_truthy
        }

        it {
          expect(subject.dynamic).to be_falsey
        }

        it {
          expect(subject.dynamic_every).to eql('5s')
        }
      end
    end
  end

  describe '#stop' do
    subject { manager.stop }

    let(:manager) do
      described_class.new(
        SidekiqScheduler::Config.new(
          sidekiq_config: sidekiq_config_for_options(
            {
              scheduler: {
                listened_queues_only: true,
                enabled: true,
                dynamic: true,
                dynamic_every: '5s',
                schedule: { 'current' => ScheduleFaker.cron_schedule('queue' => 'default') }
              },
            }
          )
        )
      )
    end

    it 'should call clear_schedule! method on SidekiqScheduler::Scheduler' do
      expect(manager.instance_variable_get(:@scheduler_instance)).to receive(:clear_schedule!)
      subject
    end
  end

  describe '#start' do
    subject { manager.start }

    let(:manager) do
      described_class.new(
        SidekiqScheduler::Config.new(
          sidekiq_config: sidekiq_config_for_options(
            {
              scheduler: {
                enabled: true,
                dynamic: true,
                dynamic_every: '5s',
                listened_queues_only: true,
                schedule: { 'current' => ScheduleFaker.cron_schedule('queue' => 'default') }
              },
            }
          )
        )
      )
    end

    it 'should call load_schedule! method on SidekiqScheduler::Scheduler' do
      expect(manager.instance_variable_get(:@scheduler_instance)).to receive(:load_schedule!)
      subject
    end
  end
end
