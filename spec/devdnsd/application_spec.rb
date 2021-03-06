# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "spec_helper"

describe DevDNSd::Application do
  before(:each) do
    allow(Bovem::Logger).to receive(:default_file).and_return("/dev/null")
    allow(DevDNSd::Application).to receive(:instance).and_return(application)
    allow(Kernel).to receive(:exit)
  end

  def create_application(overrides = {})
    DevDNSd::Application.new(Bovem::Application.create(run: false) {
      option :configuration, [], {default: overrides["configuration"] || "/dev/null"}
      option :tld, [], {default: overrides["tld"] || "dev"}
      option :port, [], {type: Integer, default: overrides["port"] || 7771}
      option :pid_file, [:P, "pid-file"], {type: String, default: overrides["pid_file"] || "/var/run/devdnsd.pid"}
      option :log_file, [:l, "log-file"], {default: overrides["log_file"] || "/dev/null"}
      option :log_level, [:L, "log-level"], {type: Integer, default: overrides["log_level"] || 1}
    }, :en)
  end

  let(:log_file) { "/tmp/devdnsd-test-log-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:application){ create_application({"log_file" => log_file, "configuration" => "/dev/null"}) }
  let(:executable) { ::Pathname.new(::File.dirname((__FILE__))) + "../../bin/devdnsd" }
  let(:sample_config) { ::Pathname.new(::File.dirname((__FILE__))) + "../../config/devdnsd_config.sample" }
  let(:resolver_path) { "/tmp/devdnsd-test-resolver-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:launch_agent_path) { "/tmp/devdnsd-test-agent-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  describe "#initialize" do
    it "should setup the logger" do
      expect(application.logger).not_to be_nil
    end

    it "should fallback logger to STDOUT" do
      allow_any_instance_of(DevDNSd::Application).to receive(:read_configuration)
      expect(Bovem::Logger).to receive(:create).with($stdout, level: Logger::INFO)
      create_application({"log_file" => "/invalid/logger"})
    end

    it "should setup the configuration" do
      expect(application.config).not_to be_nil
    end

    it "should abort with an invalid configuration" do
      allow_any_instance_of(Bovem::Logger).to receive(:fatal)
      allow_any_instance_of(Bovem::Logger).to receive(:warn)
      path = "/tmp/devdnsd-test-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}"
      file = ::File.new(path, "w")
      file.write("config.port = ")
      file.close

      expect_any_instance_of(DevDNSd::Application).to receive(:shutdown).and_call_original
      create_application({"configuration" => file.path, "log_file" => log_file})
      ::File.unlink(path)
    end

    it "should abort when the log file is invalid" do
      allow_any_instance_of(Bovem::Logger).to receive(:fatal)
      allow_any_instance_of(Bovem::Logger).to receive(:warn)
      expect_any_instance_of(DevDNSd::Application).to receive(:shutdown).and_call_original
      create_application({"pid_file" => "/invalid/pid", "log_file" => "/dev/null"})
    end
  end

  describe ".run" do
    it "should run the server" do
      expect(application).to receive(:perform_server)
      DevDNSd::Application.run
    end
  end

  describe ".quit" do
    it "should quit the application" do
      allow(application).to receive(:instance).and_call_original
      DevDNSd::Application.quit
    end

    it "should return with error code 1 in case of errors" do
      allow(application).to receive(:shutdown).and_raise(RuntimeError)
      expect(Kernel).to receive(:exit).with(1)
      expect { DevDNSd::Application.quit }.not_to raise_error
    end
  end

  describe ".check_ruby_implementation" do
    it "won't run on JRuby" do
      stub_const("JRuby", true)
      expect(Kernel).to receive(:exit).with(0)
      expect(Kernel).to receive(:puts)
      DevDNSd::Application.check_ruby_implementation
    end
  end

  describe ".instance" do
    before(:each) do
      allow(DevDNSd::Application).to receive(:instance).and_call_original
    end

    let(:bovem) {
      Bovem::Application.create(run: false) do
        option :configuration, [], {default: "/dev/null"}
        option :tld, [], {default: "dev"}
        option :port, [], {type: Integer, default: 7771}
        option :pid_file, [:P], {type: String, default: "/var/run/devdnsd.pid"}
        option :log_file, [], {default: "/dev/null"}
        option :log_level, [:L], {type: Integer, default: 1}
      end
    }

    it "should create a new instance" do
      expect(DevDNSd::Application.instance(bovem)).to be_a(DevDNSd::Application)
    end

    it "should always return the same instance" do
      other = DevDNSd::Application.instance(bovem)
      expect(DevDNSd::Application).not_to receive(:new)
      expect(DevDNSd::Application.instance(bovem)).to eq(other)
      expect(DevDNSd::Application.instance).to eq(other)
    end

    it "should recreate an instance" do
      other = DevDNSd::Application.instance(bovem)
      expect(DevDNSd::Application.instance(bovem, :en, true)).not_to be(other)
    end
  end

  describe "#process_file_path" do
    let(:application){ create_application({"log_file" => log_file, "configuration" => sample_config}) }

    it "returns the default file" do
      expect(DevDNSd::Application.instance.process_file_path).to eq("/var/run/devdnsd.pid")
    end

    it "return the set file" do
      DevDNSd::Application.instance.config.pid_file = "/this/is/a/daemon.pid"
      expect(DevDNSd::Application.instance.process_file_path).to eq("/this/is/a/daemon.pid")
    end
  end

  describe "#log_file_path" do
    let(:application){ create_application({"log_file" => log_file, "configuration" => sample_config}) }

    it "returns the default file" do
      expect(DevDNSd::Application.instance.log_file_path).to eq(log_file)
    end

    it "return the set file" do
      DevDNSd::Application.instance.config.log_file = "/this/is/a/daemon.log"
      expect(DevDNSd::Application.instance.log_file_path).to eq("/this/is/a/daemon.log")
    end
  end

  describe "#working_directory" do
    let(:application){ create_application({"log_file" => log_file, "configuration" => sample_config}) }

    it "returns the default path" do
      expect(DevDNSd::Application.instance.working_directory).to eq("/var/run")
    end

    it "return the set path basing on the PID file" do
      DevDNSd::Application.instance.config.pid_file = "/this/is/a/daemon.pid"
      expect(DevDNSd::Application.instance.working_directory).to eq("/this/is/a")
    end
  end

  describe "#log_directory" do
    let(:application){ create_application({"log_file" => log_file, "configuration" => sample_config}) }

    it "returns the default path" do
      expect(DevDNSd::Application.instance.log_directory).to eq(File.dirname(log_file))
    end

    it "return the set path basing on the PID file" do
      DevDNSd::Application.instance.config.log_file = "/this/is/a/daemon.log"
      expect(DevDNSd::Application.instance.log_directory).to eq("/this/is/a")
    end
  end

  describe "#daemon_name" do
    let(:application){ create_application({"log_file" => log_file, "configuration" => sample_config}) }

    it "returns the default name" do
      expect(DevDNSd::Application.instance.daemon_name).to eq("devdnsd")
    end

    it "return the set name basing on the PID file" do
      DevDNSd::Application.instance.config.pid_file = "/this/is/a/daemon.pid"
      expect(DevDNSd::Application.instance.daemon_name).to eq("daemon")
    end
  end

  describe "#perform_server" do
    let(:application) { create_application({"log_file" => log_file, "configuration" => sample_config, "port" => 60771}) }

    it "should free resources correctly" do
      application.perform_server
      application.shutdown
      application.perform_server
      application.shutdown
    end

    it "should setup callbacks" do
      expect_any_instance_of(RubyDNS::RuleBasedServer).to receive(:on).with(:start)
      expect_any_instance_of(RubyDNS::RuleBasedServer).to receive(:on).with(:stop)
      application.perform_server
      application.shutdown
    end

    describe "using rules" do
      def test_resolve(host = "match_1.dev", type = "ANY", nameserver = "127.0.0.1", port = 60771, logger = nil)
        devdnsd_resolv(host, type, nameserver, port, logger)
      end

      around(:each) do |example|
        app = application
        app.perform_server
        example.call
        app.shutdown
      end

      it "should iterate the rules" do
        expect(application.config.rules).to receive(:each).at_least(1)
        test_resolve
      end

      it "should call process_rule" do
        expect_any_instance_of(DevDNSd::Application).to receive(:process_rule).at_least(1)
        test_resolve
      end

      describe "should correctly resolve hostnames" do
        it "basing on a exact pattern" do
          expect(test_resolve("match_1.dev")).to eq(["10.0.1.1", :A])
          expect(test_resolve("match_2.dev")).to eq(["10.0.2.1", :MX])
          expect(test_resolve("match_3.dev")).to eq(["10.0.3.1", :A])
          expect(test_resolve("match_4.dev")).to eq(["cowtech.it", :CNAME])
        end

        it "basing on a regexp pattern" do
          expect(test_resolve("match_5_11.dev")).to eq(["ns.cowtech.it", :NS])
          expect(test_resolve("match_5_22.dev")).to eq(["ns.cowtech.it", :NS])
          expect(test_resolve("match_6_33.dev")).to eq(["10.0.6.33", :PTR])
          expect(test_resolve("match_6_44.dev")).to eq(["10.0.6.44", :PTR])
          expect(test_resolve("match_7_55.dev")).to eq(["10.0.7.55", :A])
          expect(test_resolve("match_7_66.dev")).to eq(["10.0.7.66", :A])
          expect(test_resolve("match_8_77.dev")).to eq(["10.0.8.77", :PTR])
          expect(test_resolve("match_8_88.dev")).to eq(["10.0.8.88", :PTR])
        end

        it "and return multiple or only relevant answsers" do
          expect(test_resolve("match_10.dev")).to eq([["10.0.10.1", :A], ["10.0.10.2", :MX]])
          expect(test_resolve("match_10.dev", "MX")).to eq(["10.0.10.2", :MX])
        end

        it "and reject invalid matches (with or without rules)" do
          expect(test_resolve("match_9.dev")).to eq([])
          expect(test_resolve("invalid.dev")).to eq([])
        end
      end
    end
  end

  describe "#process_rule" do
    class FakeTransaction
      attr_reader :resource_class

      def initialize(cls = Resolv::DNS::Resource::IN::ANY)
        @resource_class = cls
      end

      def respond!(*_)
        true
      end
    end

    let(:application){ create_application({"log_file" => log_file, "configuration" => sample_config}) }
    let(:transaction){ FakeTransaction.new }

    it "should match a valid string request" do
      rule = application.config.rules[0]
      expect(application.process_rule(rule, rule.resource_class, nil, transaction)).to be_truthy
    end

    it "should match a valid string request with specific type" do
      rule = application.config.rules[1]
      expect(application.process_rule(rule, rule.resource_class, nil, transaction)).to be_truthy
    end

    it "should match a valid string request with a block" do
      rule = application.config.rules[2]
      expect(application.process_rule(rule, rule.resource_class, nil, transaction)).to be_truthy
    end

    it "should match a valid string request with a block" do
      rule = application.config.rules[3]
      expect(application.process_rule(rule, rule.resource_class, nil, transaction)).to be_truthy
    end

    it "should match a valid regexp request" do
      rule = application.config.rules[4]
      mo = rule.match_host("match_5_12.dev")
      expect(application.process_rule(rule, rule.resource_class, mo, transaction)).to be_truthy
    end

    it "should match a valid regexp request with specific type" do
      rule = application.config.rules[5]
      mo = rule.match_host("match_6_34.dev")
      expect(application.process_rule(rule, rule.resource_class, mo, transaction)).to be_truthy
    end

    it "should match a valid regexp request with a block" do
      rule = application.config.rules[6]
      mo = rule.match_host("match_7_56.dev")
      expect(application.process_rule(rule, rule.resource_class, mo, transaction)).to be_truthy
    end

    it "should match a valid regexp request with a block and specific type" do
      rule = application.config.rules[7]
      mo = rule.match_host("match_8_78.dev")
      expect(application.process_rule(rule, rule.resource_class, mo, transaction)).to be_truthy
    end

    it "should return false for a false block" do
      rule = application.config.rules[8]
      expect(application.process_rule(rule, rule.resource_class, nil, transaction)).to be_falsey
    end

    it "should return nil for a nil reply" do
      rule = application.config.rules[0]
      rule.reply = nil
      expect(application.process_rule(rule, rule.resource_class, nil, transaction)).to be_nil
    end
  end

  describe "#dns_update" do
    it "should update the DNS cache" do
      allow(Kernel).to receive(:system).and_return("EXECUTED")
      application.dns_update
    end
  end

  describe "#osx?" do
    it "should return the correct information" do
      stub_const("RbConfig::CONFIG", {"host_os" => "darwin foo"})
      expect(application.osx?).to be_truthy
      stub_const("RbConfig::CONFIG", {"host_os" => "another"})
      expect(application.osx?).to be_falsey
    end
  end

  describe "#resolver_path" do
    it "should return the resolver file basing on the configuration" do
      expect(application.resolver_path).to eq("/etc/resolver/#{application.config.tld}")
    end

    it "should return the resolver file basing on the argument" do
      expect(application.resolver_path("foo")).to eq("/etc/resolver/foo")
    end
  end

  describe "#launch_agent_path" do
    it "should return the agent file with a default name" do
      expect(application.launch_agent_path).to eq(ENV["HOME"] + "/Library/LaunchAgents/it.cowtech.devdnsd.plist")
    end

    it "should return the agent file with a specified name" do
      expect(application.launch_agent_path("foo")).to eq(ENV["HOME"] + "/Library/LaunchAgents/foo.plist")
    end
  end

  describe "#manage_aliases" do
    it "should override configuration" do
      expect_any_instance_of(DevDNSd::Application).to receive(:manage_address)
      application.manage_aliases(:add, "MESSAGE", {aliases: 10})
      expect(application.config.aliases).to eq(10)
    end

    it "should log an error if no interfaces are found" do
      expect_any_instance_of(DevDNSd::Application).to receive(:compute_addresses).and_return([])
      expect(application.logger).to receive(:error).with("MESSAGE")
      expect(application.manage_aliases(:add, "MESSAGE", {aliases: 10})).to be_falsey
    end

    it "should call #manage_address for each address" do
      expect_any_instance_of(DevDNSd::Application).to receive(:manage_address).with("OPERATION", IPAddr.new("10.0.0.1"), "DRY_RUN").and_return(true)
      expect_any_instance_of(DevDNSd::Application).to receive(:manage_address).with("OPERATION", IPAddr.new("10.0.0.2"), "DRY_RUN").and_return(true)
      expect_any_instance_of(DevDNSd::Application).to receive(:manage_address).with("OPERATION", IPAddr.new("10.0.0.3"), "DRY_RUN").and_return(true)
      expect(application.manage_aliases("OPERATION", "MESSAGE", {aliases: 3, dry_run: "DRY_RUN"})).to be_truthy
    end
  end

  describe "#manage_address" do
    it "should show a right message to the user" do
      expect(application.logger).to receive(:info).with(/.+.*3.*\/.*5.*.+ *Adding.* address .*10.0.0.3.* to interface .*lo0.*/)
      application.manage_address(:add, "10.0.0.3")

      expect(application.logger).to receive(:info).with(/.+.*3.*\/.*5.*.+ *Removing.* address .*10.0.0.3.* from interface .*lo0.*/)
      application.manage_address(:remove, "10.0.0.3")
    end

    it "should call the right system command" do
      expect_any_instance_of(DevDNSd::Application).to receive(:execute_command).with("sudo ifconfig lo0 alias 10.0.0.3 > /dev/null 2>&1")
      application.manage_address(:add, "10.0.0.3")

      expect_any_instance_of(DevDNSd::Application).to receive(:execute_command).with("sudo ifconfig lo0 -alias 10.0.0.3 > /dev/null 2>&1")
      application.manage_address(:remove, "10.0.0.3")
    end

    it "should return true if the command succeded" do
      application.config.add_command = "echo {{interface}}"
      expect(application.manage_address(:add, "10.0.0.3")).to be_truthy
    end

    it "should return false if the command failed" do
      expect(application.manage_address(:add, "10.0.0.256")).to be_falsey
    end

    it "should respect dry-run mode" do
      expect_any_instance_of(DevDNSd::Application).not_to receive(:execute_command)
      expect(application.logger).to receive(:info).with(/.+.*3.*\/.*5.*.+ I will .*add.* address .*10.0.0.3.* to interface .*lo0.*/)
      expect(application.logger).to receive(:info).with(/.+.*3.*\/.*5.*.+ I will .*remove.* address .*10.0.0.3.* from interface .*lo0.*/)

      application.manage_address(:add, "10.0.0.3", true)
      application.manage_address(:remove, "10.0.0.3", true)
    end
  end

  describe "#compute_addresses" do
    describe "should use only the explicit list if given" do
      before(:each) do
        application.config.addresses = ["10.0.0.1", "::1", "INVALID 1", "10.0.0.2", "INVALID 2", "2001:0db8:0::0:1428:57ab"]
      end

      it "considering all address" do
        expect(application.compute_addresses).to eq(["10.0.0.1", "::1", "10.0.0.2", "2001:0db8:0::0:1428:57ab"])
      end

      it "considering only IPv4" do
        expect(application.compute_addresses(:ipv4)).to eq(["10.0.0.1", "10.0.0.2"])
        application.config.addresses = ["::1", "INVALID 1"]
        expect(application.compute_addresses(:ipv4)).to eq([])
      end

      it "considering only IPv6" do
        expect(application.compute_addresses(:ipv6)).to eq(["::1", "2001:0db8:0::0:1428:57ab"])
        application.config.addresses = ["10.0.0.1", "INVALID 1"]
        expect(application.compute_addresses(:ipv6)).to eq([])
      end
    end

    describe "should compute a sequential list of address" do
      it "considering all address" do
        application.config.start_address = "10.0.1.1"
        expect(application.compute_addresses).to eq(["10.0.1.1", "10.0.1.2", "10.0.1.3", "10.0.1.4", "10.0.1.5"])

        application.config.start_address = "10.0.0.1"
        application.config.aliases = 3
        expect(application.compute_addresses).to eq(["10.0.0.1", "10.0.0.2", "10.0.0.3"])

        application.config.start_address = "10.0.1.1"
        application.config.aliases = -1
        expect(application.compute_addresses).to eq(["10.0.1.1"])
      end

      it "considering only IPv4" do
        application.config.start_address = "::1"
        expect(application.compute_addresses(:ipv4)).to eq([])
      end

      it "considering only IPv6" do
        application.config.start_address = "10.0.0.1"
        expect(application.compute_addresses(:ipv6)).to eq([])
      end
    end
  end

  describe "#ipv4?" do
    it "correctly detects valid IPv4 address" do
      expect(application.ipv4?("10.0.0.1")).to be_truthy
      expect(application.ipv4?("255.0.0.1")).to be_truthy
      expect(application.ipv4?("192.168.0.1")).to be_truthy
    end

    it "rejects other values" do
      expect(application.ipv4?("10.0.0.256")).to be_falsey
      expect(application.ipv4?("10.0.0.-1")).to be_falsey
      expect(application.ipv4?("::1")).to be_falsey
      expect(application.ipv4?("INVALID")).to be_falsey
      expect(application.ipv4?(nil)).to be_falsey
    end
  end

  describe "#ipv6?" do
    it "correctly detects valid IPv4 address" do
      expect(application.ipv6?("2001:0db8:0000:0000:0000:1428:57ab")).to be_truthy
      expect(application.ipv6?("2001:0db8:0:000:00:1428:57ab")).to be_truthy
      expect(application.ipv6?("2001:0db8:0::1428:57ab")).to be_truthy
      expect(application.ipv6?("2001::")).to be_truthy
      expect(application.ipv6?("::1")).to be_truthy
      expect(application.ipv6?("::2:1")).to be_truthy
      expect(application.ipv6?("2011::10.0.0.1")).to be_truthy
      expect(application.ipv6?("2011::0:10.0.0.1")).to be_truthy
    end

    it "rejects other values" do
      expect(application.ipv6?("::H")).to be_falsey
      expect(application.ipv6?("192.168.0.256")).to be_falsey
      expect(application.ipv6?("INVALID")).to be_falsey
      expect(application.ipv6?(nil)).to be_falsey
    end
  end

  describe "#action_start" do
    it "should call perform_server in foreground" do
      application = create_application({"log_file" => log_file})
      application.instance_variable_set(:@command, Bovem::Command.new {
        option :foreground, [:n, "foreground"], {default: true}
      })

      allow_any_instance_of(DevDNSd::Application).to receive(:perform_server)
      application.action_start
    end

    it "should start the daemon" do
      application = create_application({"log_file" => log_file})
      application.instance_variable_set(:@command, Bovem::Command.new {
        option :foreground, [:n, "foreground"], {default: false}
      })

      expect(::DevDNSd::Application).to receive(:start)
      application.action_start
    end

    it "should check for availability of fork" do
      application.config.foreground = false

      allow(Process).to receive(:respond_to?).and_return(false)
      allow_any_instance_of(DevDNSd::Application).to receive(:perform_server)
      expect(application.logger).to receive(:warn)

      application.action_start
      expect(application.config.foreground).to be_truthy
    end
  end

  describe "#action_stop" do
    it "should stop the daemon" do
      expect(::DevDNSd::Application).to receive(:stop)
      application.action_stop
    end
  end

  describe "#action_restart" do
    it "should stop and restart the server" do
      expect_any_instance_of(DevDNSd::Application).to receive(:action_stop)
      expect_any_instance_of(DevDNSd::Application).to receive(:action_start)
      application.action_restart
    end
  end

  describe "#action_status" do
    it "should get the status of the daemon when running" do
      expect(Process::Daemon::ProcessFile).to receive(:status).and_return(:running)
      expect(DevDNSd::Application.controller).to receive(:pid).and_return(123)

      expect(application.logger).to receive(:info).with("The server is running with process ID \e[1m123\e[0m.")
      application.action_status
    end

    it "should get the status of the daemon when stopped" do
      expect(Process::Daemon::ProcessFile).to receive(:status).and_return(:stopped)
      expect(DevDNSd::Application.controller).to receive(:pid).and_return(123)

      expect(application.logger).to receive(:info).with("The server is stopped.")
      application.action_status
    end

    it "should get the status of the daemon when crashed" do
      expect(Process::Daemon::ProcessFile).to receive(:status).and_return(:unknown)
      expect(application.class).to receive(:crashed?).and_return(true)

      expect(application.logger).to receive(:info).with("The server crashed. See the log for more information.")
      application.action_status
    end

    it "should get the status of the daemon when unknown" do
      expect(Process::Daemon::ProcessFile).to receive(:status).and_return(:unknown)
      expect(application.class).to receive(:crashed?).and_return(false)

      expect(application.logger).to receive(:info).with("The server status is unknown.")
      application.action_status
    end
  end

  describe "#action_install" do
    before(:each) do
      allow(application).to receive(:osx?).and_return(true)
      allow(application).to receive(:execute_command)
      expect(Kernel).to receive(:system).at_least(1)
    end

    it "should create the resolver" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow_any_instance_of(DevDNSd::Application).to receive(:create_resolver) {|_, path| FileUtils.touch(path) }
      application.action_install
      expect(::File.exists?(resolver_path)).to be_truthy

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should create the agent" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      application.action_install
      expect(::File.exists?(application.launch_agent_path)).to be_truthy

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should update the DNS cache" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      expect_any_instance_of(DevDNSd::Application).to receive(:dns_update)
      application.action_install

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not create an invalid resolver" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return("/invalid/resolver")
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return("/invalid/agent")
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow_any_instance_of(DevDNSd::Application).to receive(:create_agent).and_return(true)
      expect_any_instance_of(Bovem::I18n).to receive(:resolver_creating).and_raise(ArgumentError)
      expect(application.logger).to receive(:error).with("Cannot create the resolver file.")
      application.action_install

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not create an invalid agent" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return("/invalid/agent")
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      expect(application.logger).to receive(:error).with("Cannot create the launch agent.")
      application.action_install

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not load an invalid agent" do
      allow(application).to receive(:execute_command) do |command|
        command =~ /^launchctl/ ? raise(StandardError) : true
      end

      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow_any_instance_of(DevDNSd::Application).to receive(:create_agent).and_return(true)
      expect(application.logger).to receive(:error).with("Cannot load the launch agent.")
      application.action_install

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should raise an exception if not running on OSX" do
      allow_any_instance_of(DevDNSd::Application).to receive(:osx?).and_return(false)
      expect(application.logger).to receive(:fatal).with("Install DevDNSd as a local resolver is only available on MacOSX.")
      expect(application.action_install).to be_falsey
    end
  end

  describe "#action_uninstall" do
    before(:each) do
      allow(application).to receive(:osx?).and_return(true)
      allow(application).to receive(:execute_command)
      expect(Kernel).to receive(:system).at_least(1)
    end

    it "should remove the resolver" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      application.action_install
      application.action_uninstall
      expect(::File.exists?(resolver_path)).to be_falsey

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not remove an invalid resolver" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return("/invalid/resolver")
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return("/invalid/agent")
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow(application).to receive(:unload_agent).and_return(true)
      expect_any_instance_of(Bovem::I18n).to receive(:resolver_deleting).and_raise(ArgumentError)
      expect(application.logger).to receive(:warn)
      expect(application.logger).to receive(:warn).with("Cannot delete the resolver file.")

      application.action_uninstall

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should remove the agent" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow(Bovem::Logger).to receive(:default_file).and_return($stdout)
      application.action_install
      application.action_uninstall
      expect(::File.exists?(application.launch_agent_path)).to be_falsey

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not fail if the agent cannot be removed" do
      allow_any_instance_of(DevDNSd::Application).to receive(:resolver_path).and_return(resolver_path)
      allow_any_instance_of(DevDNSd::Application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow(File).to receive(:delete).and_raise(RuntimeError)
      allow(Bovem::Logger).to receive(:default_file).and_return($stdout)
      application.action_install
      application.action_uninstall

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not delete an invalid resolver" do
      allow(application).to receive(:resolver_path).and_return("/invalid/resolver")
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      application.action_install
      expect(application.logger).to receive(:warn).at_least(1)
      application.action_uninstall

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not delete an invalid agent" do
      allow(application).to receive(:resolver_path).and_return(resolver_path)
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      application.action_install
      expect(application.logger).to receive(:warn).at_least(1)
      application.action_uninstall

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not unload invalid agent" do
      allow(application).to receive(:resolver_path).and_return(resolver_path)
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      application.action_install
      allow(application).to receive(:execute_command).and_raise(StandardError)
      allow(application).to receive(:dns_update)
      expect(application.logger).to receive(:warn).at_least(1)
      application.action_uninstall

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should update the DNS cache" do
      allow(application).to receive(:resolver_path).and_return(resolver_path)
      allow(application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      application.action_install
      expect_any_instance_of(DevDNSd::Application).to receive(:dns_update)
      application.action_uninstall

      ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should raise an exception if not running on OSX" do
      allow_any_instance_of(DevDNSd::Application).to receive(:osx?).and_return(false)
      expect(application.logger).to receive(:fatal).with("Install DevDNSd as a local resolver is only available on MacOSX.")
      expect(application.action_uninstall).to be_falsey
    end
  end

  describe "#action_add" do
    it "should #manage_aliases" do
      expect_any_instance_of(DevDNSd::Application).to receive(:manage_aliases).with(:add, "No valid addresses to add to the interface found.", {a: 1})
      application.action_add({a: 1})
    end
  end

  describe "#action_remove" do
    it "should #manage_aliases" do
      expect_any_instance_of(DevDNSd::Application).to receive(:manage_aliases).with(:remove, "No valid addresses to remove from the interface found.", {a: 1})
      application.action_remove({a: 1})
    end
  end
end