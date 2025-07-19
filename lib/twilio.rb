module Twilio    
    require 'twilio-ruby'

    def Twilio.send_text(number, message, twilio_number = '') #if twilio number is blank, we will use the 'universal' twilio number defined in ENV.
        account_sid = ENV['TWILIO_SID']
        auth_token = ENV['TWILIO_AUTH']
        client = Twilio::REST::Client.new(account_sid, auth_token)
        twilio_number = twilio_number.present? ? twilio_number : ENV['TWILIO_NUMBER']

        client = Twilio::REST::Client.new(account_sid, auth_token)
        from = twilio_number
        to = number
        message_params = Hash.new
        message_params[:from] = from
        message_params[:to] = to
        message_params[:body] = message

        # client.messages.create( message_params )
        client.messages.create(
            from: from,
            to: to,
            body: message
            )
    end

    #Adds +1 before the phone number if it's not internationalized already
    def Twilio.internationalize(number)
        number_already_internationalized = number[0..1] == "+1"
        if (number_already_internationalized)
            return number
        else 
            return "+1" + number
        end
    end

    def Twilio.strip_internationalize(number)
        if number[0..1] == "+1"
            return number[2..-1]
        else
            return number
        end
    end

    def Twilio.purchase_available_phone_number(phone_number_to_purchase, organization, test_mode)
        @client = Twilio.get_client

        unless test_mode #only actually purchase this number if we're not in test mode.
            incoming_phone_number = @client.incoming_phone_numbers
                                        .create(phone_number: phone_number_to_purchase, friendly_name: "RUBY AI HACKATHON: #{organization.name}") #+1 is required here for internationalization.

            organization.update(twilio_number: phone_number_to_purchase)
        end
        
        return Twilio.set_up_messaging_and_call_url(phone_number_to_purchase, ENV['BASE_URL'])
    end

    def Twilio.set_up_messaging_and_call_url(phone_number, base_url)
        @client = Twilio.get_client

        internationalized_phone_number = Twilio.internationalize(phone_number)
        all_twilio_phone_numbers = @client.incoming_phone_numbers.list

        # matching_twilio_number = all_twilio_phone_numbers.find {|record| record.phone_number == internationalized_phone_number}
        matching_twilio_number = all_twilio_phone_numbers.find { |record| record.phone_number.gsub(/\D/, '') == internationalized_phone_number.gsub(/\D/, '') }

        unless matching_twilio_number.nil?
            # set the voice_url and sms_url to the given base url
            matching_twilio_number.update(voice_url: "#{base_url}/inbound_call", sms_url:"#{base_url}/inbound_sms")
            begin
                Twilio.setup_messaging_service_campaign(matching_twilio_number.sid, ENV["TWILIO_A2P_CAMPAIGN"], @client)
            rescue => e
                Rails.logger.error "Error setting up messaging service campaign: #{e.message}"
            end
        end

        return matching_twilio_number&.sid
    end

    def Twilio.setup_messaging_service_campaign(phone_number_sid, messaging_service_campaign_sid, client)
        phone_number = client.messaging
                      .v1
                      .services(messaging_service_campaign_sid)
                      .phone_numbers
                      .create(
                         phone_number_sid: phone_number_sid
                       )

    puts phone_number.sid
    end

    def Twilio.get_messaging_and_call_url(phone_number)
        @client = Twilio.get_client

        internationalized_phone_number = Twilio.internationalize(phone_number)
        all_twilio_phone_numbers = @client.incoming_phone_numbers.list

        matching_twilio_number = all_twilio_phone_numbers.find {|record| record.phone_number == internationalized_phone_number}
        unless matching_twilio_number.nil?
            return matching_twilio_number.sms_url, matching_twilio_number.voice_url
        end
    end

    def Twilio.find_available_phone_numbers(area_code)
        @client = Twilio.get_client

        local = @client.available_phone_numbers('US').local.list(
                                                            area_code: area_code,
                                                            limit: 8
                                                            )

        return local.map{|l| {number: l.friendly_name, city: l.locality, zip: l.postal_code}}
    end

    def Twilio.get_client
        account_sid = ENV['TWILIO_SID']
        auth_token = ENV['TWILIO_AUTH']
        Twilio::REST::Client.new(account_sid, auth_token)
    end
    
    #Validates that the Given sid matches the matching API SID. A basic security check when texts come in.
    def Twilio.verify_account_sid(sid)
        ENV["TWILIO_SID"] == sid
    end
    
    def Twilio.parse_incoming_request(to, from)
        #use the sub method to remove the "+1" prefix if present: removes the first two digits, which should be '+' and '1' for international codes. 
        destination_phone_number = Twilio.strip_internationalize(to)

        ##We're currently not supporting international codes, and our phone number validator doesn't take them, so we're going to remove these.
        number_that_inbound_request_was_sent_from = Twilio.strip_internationalize(from)


        organization = Organization.where(twilio_number: destination_phone_number).first
        if organization.nil?
            return nil
        end
        
        return organization, destination_phone_number, number_that_inbound_request_was_sent_from
    end
end