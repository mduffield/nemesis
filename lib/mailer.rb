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

    @from_name="From Name"
    @from_email="noreply@example.com"
    @to_name="To Name"
    @to_email="tester@example.com"
    @subject="Test Subject Line"
    @message="Test message body. Please do not reply to this.\r\nIt won't work anyway."
  end

  def from
    @from_email
  end

  def from_domain
    _,from_domain = @from_email.split("@");
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

