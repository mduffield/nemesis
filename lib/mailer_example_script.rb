require 'lib/mailer'
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
