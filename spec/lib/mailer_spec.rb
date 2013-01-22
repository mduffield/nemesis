require 'spec_helper'

require 'lib/mailer'

describe "Mailer" do
  describe ".send_mail" do
    it "should send the EHLO" do
      Mailer.send_mail
    end
  end
end