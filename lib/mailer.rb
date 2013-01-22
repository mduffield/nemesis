#!/usr/bin/ruby

require 'socket'
require 'rubygems'
require 'thread'
require 'timeout'

module SMTP
  def self.send_mail(message, socket)

    response = get_response(socket)
    unless response.match(/^220 (.+?)/)
      message.finish(response)
    else
      socket.print("HELO "+message.from_domain+"\r\n")
      response = get_response(socket)
      unless response.match(/^250 (.+?)/)
        message.finish(response)
      else
        #  print response

        socket.print("MAIL FROM:<"+message.from+">\r\n")
        response = get_response(socket)
        unless response.match(/^250 (.+?)/)
          message.finish(response)
        else
          #    print response

          socket.print("RCPT TO:<"+message.to+">\r\n")
          response = get_response(socket)
          unless response.match(/^250 (.+?)/)
            message.finish(response)
          else
            #      print response

            socket.print("DATA\r\n")
            response = get_response(socket)
            unless response.match(/^354 (.+?)/)
              message.finish(response)
            else
              #        print response

              socket.print(message.message+"\r\n.\r\n")
              response = get_response(socket)
              message.finish(response)
              #print response
            end
          end
        end
      end
      socket.print("QUIT\r\n")
      response = get_response(socket)
      #print response
    end
  end

  def self.get_MX_server(domain)
    require 'resolv'
    mx = nil
    Resolv::DNS.open do |dns|
      mail_servers = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
      return domain unless mail_servers and not mail_servers.empty?
      highest_priority = mail_servers.first
      mail_servers.each do |server|
        highest_priority = server if server.preference < highest_priority.preference
      end
          mx = highest_priority.exchange.to_s
    end
    mx
  end

  def self.get_response(socket)
    begin
      response = Timeout.timeout(20) do
        socket.recv(1000)
      end
    rescue Timeout::Error
      response = "Connection terminated unexpectedly"
    else
      response = response.split('\r\n')
      response = response.last
    end
    puts response
    response
  end
end

class Message
  def initialize(ip, mx_group_id)
    # Get message from DB here using ip and mx_group_id below....
    @ip = ip
    @mx_group_id = mx_group_id

    @from_name="Matt"
    @from_email="mduffield@sig2noise.net"
    @to_name="Matt Duffield"
    #@to_email="tester@blackhole1.sytes.net"
    @to_email="tester@xxx.nonextist.safd"
#    @to_email="mduffield@gmail.com"
    @subject="Hello Sir"
    @message="Please do not reply to this.\r\nIt won't work anyway."
  end

  def from
    @from_email
  end

  def from_domain
    user,from_domain = @from_email.split("@");
    from_domain
  end

  def to
    @to_email
  end

  def to_domain
    user,to_domain = @to_email.split("@");
    to_domain
  end

  def message
    mess = "From: \""+@from_name+"\" <"+@from_email+">\r\n"
    mess += "To: \""+@to_name+"\" <"+@to_email+">\r\n"
    mess += "Subject: "+@subject+"\r\n"
    mess += @message
    mess
  end


  def finish(response)
    # Insert response info into db here...
    print "Message finished..."+response+"\n"
  end
end

class Mailer

  def initialize(ip, mx_group_id, speed)
    @ip = ip
    @mx_group_id = mx_group_id
    @speed = speed
    @mThread = nil
  end

  def control_speed
    time_per_email = 1.0/@speed
    time_taken = Time.now - @start_time
    time_to_sleep = time_per_email - time_taken
    puts time_to_sleep
    sleep time_to_sleep unless time_to_sleep < 0
  end

  def run
    until false
      @start_time = Time.now
      @speed = $mailer_config.get_speed(@ip,@mx_group_id)
      puts @speed
      message = Message.new(@ip,@mx_group_id)
      host = SMTP.get_MX_server(message.to_domain)
      port = 25

      begin
        @socket = TCPSocket.new(host, port, @ip)
      rescue SocketError => ex
        message.finish("Unable to connect: #{ex.message}")
      else
        puts retval.inspect
        puts "sending mail"
        SMTP.send_mail(message, @socket)
      end
      @socket.close
      print "\n-------#{@speed}-------\n"
      control_speed
    end
  end
end

class MailerConfig
  def initialize
    @mConfig = {}
  end
  def add(ip, mx_group_id, speed)
    @mConfig[ip] = {} if @mConfig[ip].nil?
    @mConfig[ip][mx_group_id] = speed
  end
  def get_speed(ip, mx_group_id)
    @mConfig[ip][mx_group_id]
  end
end

#OPEN DB CONNECTION HERE TO SHARE?

#get all the mx_group_id ip combos and start mailers
#keep track of them and kill as necessary in the main loop
#also start new ones and adjust speeds
mailerThreads = {} 

$mailer_config = MailerConfig.new

# loop through configurations here to start all threads
ip = "192.168.1.107"
mx_group_id = 1
speed = 1 
$mailer_config.add(ip, mx_group_id, speed)


mailerThreads[ip] = {} if mailerThreads[ip].nil?
100.times do #simulate 100 threads on different dg's 
mailerThreads[ip][mx_group_id] = Thread.new do 
  mail = Mailer.new(ip, mx_group_id, speed)
  mail.run
end
mx_group_id+=1
$mailer_config.add(ip, mx_group_id, mx_group_id)
end
# end initial loop

#start thread to do bounce processing and such
#and to watch for new ips and start threads, kill others, etc.
#also start thread to do activations?

#mailerThreads.each { |key,thread| thread.each { |key2, th| th.detach } }

#main program loop
until false
  #loop just for testing crap
  (1..100).step(1) do |x|
#    speed+=0.1
    $mailer_config.add(ip, x, 0.1)
  end
  sleep 0.01
end
