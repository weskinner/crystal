require "fiber"
require "event"
require "http/server"

def spawn(&block)
  Fiber.new(&block).resume
end

class EventScheduler
  INSTANCE = EventScheduler.new

  def initialize
    @eb = Event::Base.new
  end

  def wait_fd_read(fd)
    @eb.add_fd_read_event fd, callback, callback_arg
    Fiber.yield
  end

  def wait_time(time)
    @eb.add_timer_event time, callback, callback_arg
  end

  def callback
    Event.callback do |s, flags, data|
      fiber = data as Fiber
      fiber.resume
    end
  end

  def callback_arg
    Fiber.current.not_nil! as Void*
  end

  def run_loop
    @eb.run_loop
  end
end

class FileDescriptorIO
  def read(slice : Slice(UInt8), count)
    EventScheduler::INSTANCE.wait_fd_read(@fd)
    previous_def
  end
end

class TCPServer
  def accept
    EventScheduler::INSTANCE.wait_fd_read(@sock)
    previous_def
  end
end

class HTTP::Server
  def listen
    spawn { previous_def }
  end

  def handle_client(sock)
    spawn { previous_def }
  end
end


def sleep(time)
  EventScheduler::INSTANCE.wait_time(time)
  Fiber.yield
end

redefine_main do |main|
  {{main}}
  EventScheduler::INSTANCE.run_loop
end
