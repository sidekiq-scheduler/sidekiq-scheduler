require "sidekiq-scheduler/job_presenter"

describe SidekiqScheduler::JobPresenter do
  let(:job_name) { "job_name" }
  let(:attributes) { {} }

  subject { described_class.new(job_name, attributes) }
  before { Sidekiq.redis(&:flushall) }

  describe "#next_time" do
    context "when the job has not a next time in redis" do
      it "returns nothing" do
        expect(subject.next_time).not_to be
      end
    end

    context "when the job has next time in redis" do
      before { Sidekiq::Scheduler.update_job_next_time(job_name, next_time) }
      let(:next_time) { Time.now }

      it "returns the parsed value" do
        expect(subject.next_time).to eq(subject.relative_time(next_time))
      end
    end
  end

  describe "#interval" do
    context "when the attributes has a cron key" do
      let(:attributes) { { "cron" => cron_value } }
      let(:cron_value) { "cron_value" }

      it "returns the value for it" do
        expect(subject.interval).to eq(cron_value)
      end
    end

    context "when the attributes does not have a cron key" do
      context "when the attributes has an interval key" do
        let(:attributes) { { "interval" => interval_value } }
        let(:interval_value) { "interval_value" }

        it "returns the value for it" do
          expect(subject.interval).to eq(interval_value)
        end
      end

      context "when the attributes does not have a cron key" do
        let(:attributes) { { "every" => every_value } }
        let(:every_value) { "every_value" }

        it "returns the value for every key" do
          expect(subject.interval).to eq(every_value)
        end
      end

    end
  end

  describe "#queue" do
    context "when the attributes has a queue key" do
      let(:attributes) { { "queue" => queue_value } }
      let(:queue_value) { "queue_value" }

      it "returns the value for it" do
        expect(subject.queue).to eq(queue_value)
      end
    end

    context "when the attributes has not a queue key" do
      it "returns the default value for it" do
        expect(subject.queue).to eq("default")
      end
    end
  end

  describe "#[]" do
    let(:params) { "params" }
    it "delegates the method to the attriutes" do
      expect(attributes).to receive(:[]).with(params)
      subject[params]
    end
  end

  describe ".build_collection" do
    subject { described_class.build_collection(schedule_hash) }

    context "when there is no schedule hash" do
      let(:schedule_hash) { nil }

      it "returns an empty array" do
        expect(subject).to eq([])
      end
    end

    context "when there is a schedule hash" do
      let(:schedule_hash) { { first_job_name: { }, second_job_name: { } } }

      it "initializes an object with the job's data" do
        expect(subject.map(&:name)).to eq([:first_job_name, :second_job_name])
      end
    end
  end
end
