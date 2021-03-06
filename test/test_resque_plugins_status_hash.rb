require 'test_helper'

class TestResquePluginsStatusHash < Test::Unit::TestCase

  context "Resque::Plugins::Status::Hash" do
    setup do
      Resque.redis.flushall
      Resque::Plugins::Status::Hash.expire_in = nil
      @uuid = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid)
      Resque::Plugins::Status::Hash.set(@uuid, "my status")
      @uuid_with_json = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid, {"im" => "json"})
    end

    context ".get" do
      should "return the status as a Resque::Plugins::Status::Hash for the uuid" do
        status = Resque::Plugins::Status::Hash.get(@uuid)
        assert status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal 'my status', status.message
      end

      should "return false if the status is not set" do
        assert !Resque::Plugins::Status::Hash.get('whu')
      end

      should "decode encoded json" do
        assert_equal("json", Resque::Plugins::Status::Hash.get(@uuid_with_json)['im'])
      end
    end

    context ".set" do

      should "set the status for the uuid" do
        assert Resque::Plugins::Status::Hash.set(@uuid, "updated")
        assert_equal "updated", Resque::Plugins::Status::Hash.get(@uuid).message
      end

      should "return the status" do
        assert Resque::Plugins::Status::Hash.set(@uuid, "updated").is_a?(Resque::Plugins::Status::Hash)
      end

    end

    context ".create" do
      should "add an item to a key set" do
        before = Resque::Plugins::Status::Hash.status_ids.length
        Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid)
        after = Resque::Plugins::Status::Hash.status_ids.length
        assert_equal 1, after - before
      end

      should "return a uuid" do
        assert_match(/^\w{32}$/, Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid))
      end

      should "store any status passed" do
        uuid = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid, "initial status")
        status = Resque::Plugins::Status::Hash.get(uuid)
        assert status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal "initial status", status.message
      end

      should "expire keys if expire_in is set" do
        Resque::Plugins::Status::Hash.expire_in = 1
        uuid = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid, "new status")
        assert_contains Resque::Plugins::Status::Hash.status_ids, uuid
        assert_equal "new status", Resque::Plugins::Status::Hash.get(uuid).message
        sleep 2
        Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid)
        assert_does_not_contain Resque::Plugins::Status::Hash.status_ids, uuid
        assert_nil Resque::Plugins::Status::Hash.get(uuid)
      end

      should "store the options for the job created" do
        uuid = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid, "new", :options => {'test' => '123'})
        assert uuid
        status = Resque::Plugins::Status::Hash.get(uuid)
        assert status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal '123', status.options['test']
      end
    end

    context ".clear" do
      setup do
        Resque::Plugins::Status::Hash.clear
      end

      should "clear any statuses" do
        assert_nil Resque::Plugins::Status::Hash.get(@uuid)
      end

      should "clear any recent statuses" do
        assert Resque::Plugins::Status::Hash.status_ids.empty?
      end

    end

    context ".clear_completed" do
      setup do
        @completed_status_id = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid, {'status' => "completed"})
        @not_completed_status_id = Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid)
        Resque::Plugins::Status::Hash.clear_completed
      end
      
      should "clear completed status" do
        assert_nil Resque::Plugins::Status::Hash.get(@completed_status_id)
      end
      
      should "not clear not-completed status" do
        status = Resque::Plugins::Status::Hash.get(@not_completed_status_id)
        assert status.is_a?(Resque::Plugins::Status::Hash)
      end
    end
    
    context ".remove" do
      setup do
        Resque::Plugins::Status::Hash.remove(@uuid)
      end
      
      should "clear specify status" do
        assert_nil Resque::Plugins::Status::Hash.get(@uuid)
      end
    end

    context ".status_ids" do

      setup do
        @uuids = []
        30.times{ Resque::Plugins::Status::Hash.create(Resque::Plugins::Status::Hash.generate_uuid) }
      end

      should "return an array of job ids" do
        assert Resque::Plugins::Status::Hash.status_ids.is_a?(Array)
        assert_equal 32, Resque::Plugins::Status::Hash.status_ids.size # 30 + 2
      end

      should "let you paginate through the statuses" do
        assert_equal Resque::Plugins::Status::Hash.status_ids[0, 10], Resque::Plugins::Status::Hash.status_ids(0, 9)
        assert_equal Resque::Plugins::Status::Hash.status_ids[10, 10], Resque::Plugins::Status::Hash.status_ids(10, 19)
        # assert_equal Resque::Plugins::Status::Hash.status_ids.reverse[0, 10], Resque::Plugins::Status::Hash.status_ids(0, 10)
      end
    end

    context ".statuses" do

      should "return an array status objects" do
        statuses = Resque::Plugins::Status::Hash.statuses
        assert statuses.is_a?(Array)
        assert_same_elements [@uuid_with_json, @uuid], statuses.collect {|s| s.uuid }
      end

    end

    # context ".count" do
    #
    #   should "return a count of statuses" do
    #     statuses = Resque::Plugins::Status::Hash.statuses
    #     assert_equal 2, statuses.size
    #     assert_equal statuses.size, Resque::Plugins::Status::Hash.count
    #   end
    #
    # end

    context ".logger" do
      setup do
        @logger = Resque::Plugins::Status::Hash.logger(@uuid)
      end

      should "return a redisk logger" do
        assert @logger.is_a?(Redisk::Logger)
      end

      should "scope the logger to a key" do
        assert_match(/#{@uuid}/, @logger.name)
      end

    end

  end

end
