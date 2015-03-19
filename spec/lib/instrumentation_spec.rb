require 'spec_helper'

class InstrumentationExampleClient < ActiveRestClient::Base
  base_url "http://www.example.com"
  get :fake, "/fake", fake:"{\"result\":true, \"list\":[1,2,3,{\"test\":true}], \"child\":{\"grandchild\":{\"test\":true}}}"
  get :real, "/real"
end

describe ActiveRestClient::Instrumentation do
  it "should save a load hook to include the instrumentation" do
    hook_tester = double("HookTester")
    expect(hook_tester).to receive(:include).with(ActiveRestClient::ControllerInstrumentation)
    ActiveSupport.run_load_hooks(:action_controller, hook_tester)
  end

  it "should call ActiveSupport::Notifications.instrument when making any request" do
    expect(ActiveSupport::Notifications).to receive(:instrument).with("request_call.active_rest_client", {:name=>"InstrumentationExampleClient#fake"})
    InstrumentationExampleClient.fake
  end

  it "should call ActiveSupport::Notifications#request_call when making any request" do
    expect_any_instance_of(ActiveRestClient::Instrumentation).to receive(:request_call).with(an_instance_of(ActiveSupport::Notifications::Event))
    InstrumentationExampleClient.fake
  end


  it "should log time spent in each API call" do
    expect_any_instance_of(ActiveRestClient::Connection).
      to receive(:get).
      with("/real", an_instance_of(Hash)).
      and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", response_headers:{}, status:200)))
    expect(ActiveRestClient::Logger).to receive(:debug).with(/ActiveRestClient.*ms\)/)
    expect(ActiveRestClient::Logger).to receive(:debug).at_least(:once).with(any_args)
    InstrumentationExampleClient.real
  end


  it "should report the total time spent" do
    # Create a couple of classes to fake being part of ActionController (that would normally call this method)
    class InstrumentationTimeSpentExampleClientParent
      def append_info_to_payload(payload) ; {} ; end
      def self.log_process_action(payload) ; [] ; end
    end

    class InstrumentationTimeSpentExampleClient < InstrumentationTimeSpentExampleClientParent
      include ActiveRestClient::ControllerInstrumentation

      def test
        payload = {}
        append_info_to_payload(payload)
        self.class.log_process_action(payload)
      end
    end

    messages = InstrumentationTimeSpentExampleClient.new.test
    expect(messages.first).to match(/ActiveRestClient.*ms.*call/)
  end
end
