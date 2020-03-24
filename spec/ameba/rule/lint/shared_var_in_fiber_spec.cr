require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SharedVarInFiber do
    subject = SharedVarInFiber.new

    it "doesn't report if there is only local shared var in fiber" do
      s = Source.new %(
        spawn do
          i = 1
          puts i
        end

        Fiber.yield
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if there is only block shared var in fiber" do
      s = Source.new %(
        10.times do |i|
          spawn do
            puts i
          end
        end

        Fiber.yield
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if there a spawn macro is used" do
      s = Source.new %(
        i = 0
        while i < 10
          spawn puts(i)
          i += 1
        end

        Fiber.yield
      )
      subject.catch(s).should be_valid
    end

    it "reports if there is a shared var in spawn" do
      s = Source.new %(
        i = 0
        while i < 10
          spawn do
            puts(i)
          end
          i += 1
        end

        Fiber.yield
      )
      subject.catch(s).should_not be_valid
    end

    it "reports reassigned reference to shared var in spawn" do
      s = Source.new %(
        channel = Channel(String).new
        n = 0

        3.times do
          n = n + 1
          spawn do
            m = n
            channel.send m
          end
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "doesn't report reassigned reference to shared var in block" do
      s = Source.new %(
        channel = Channel(String).new
        n = 0

        3.times do
          n = n + 1
          m = n
          spawn do
            channel.send m
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "does not report block is called in a spawn" do
      s = Source.new %(
        def method(block)
          spawn do
            block.call(10)
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports multiple shared variables in spawn" do
      s = Source.new %(
        foo, bar, baz = 0, 0, 0
        while foo < 10
          baz += 1
          spawn do
            puts foo
            puts foo + bar + baz
          end
          foo += 1
        end
      )
      subject.catch(s).should_not be_valid
      s.issues.size.should eq 3
      s.issues[0].location.to_s.should eq ":5:10"
      s.issues[0].end_location.to_s.should eq ":5:12"
      s.issues[0].message.should eq "Shared variable `foo` is used in fiber"

      s.issues[1].location.to_s.should eq ":6:10"
      s.issues[1].end_location.to_s.should eq ":6:12"
      s.issues[1].message.should eq "Shared variable `foo` is used in fiber"

      s.issues[2].location.to_s.should eq ":6:22"
      s.issues[2].end_location.to_s.should eq ":6:24"
      s.issues[2].message.should eq "Shared variable `baz` is used in fiber"
    end

    it "reports rule, location and message" do
      s = Source.new %(
        i = 0
        i += 1
        spawn { i }
      ), "source.cr"

      subject.catch(s).should_not be_valid
      s.issues.size.should eq 1

      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:3:9"
      issue.end_location.to_s.should eq "source.cr:3:9"
      issue.message.should eq "Shared variable `i` is used in fiber"
    end
  end
end
