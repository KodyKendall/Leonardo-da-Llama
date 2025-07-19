require "twilio.rb"
class MessagesController < ApplicationController
  include LlamaBotRails::ControllerExtensions
  include LlamaBotRails::AgentAuth
  before_action :set_message, only: %i[ show edit update destroy ]

  skip_before_action :authenticate_user!, only: [ :inbound_sms ]
  skip_before_action :verify_authenticity_token, only: [ :inbound_sms ]

  llama_bot_allow :create

  # GET /messages or /messages.json
  def index
    org_number = current_organization.twilio_number
    org_number_escaped = ActiveRecord::Base.connection.quote(org_number)
    message_thread = MessageThread.new(current_organization)
    @messages = message_thread.all_organization_threads
  end

  # GET /messages/1 or /messages/1.json
  def show
  end

  # GET /messages/new
  def new
    @message = current_organization.messages.new
  end

  # GET /messages/1/edit
  def edit
  end

  # POST /messages or /messages.json
  def create
    @message = current_organization.messages.new(message_params)

    respond_to do |format|
      if @message.save && @message.deliver!
        format.html { redirect_to @message, notice: "Message was successfully created." }
        format.json { render :show, status: :created, location: @message }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /messages/1 or /messages/1.json
  def update
    respond_to do |format|
      if @message.update(message_params)
        format.html { redirect_to @message, notice: "Message was successfully updated." }
        format.json { render :show, status: :ok, location: @message }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /messages/1 or /messages/1.json
  def destroy
    @message.destroy!

    respond_to do |format|
      format.html { redirect_to messages_path, status: :see_other, notice: "Message was successfully destroyed." }
      format.json { head :no_content }
    end
  end


  # POST /inbound_sms
  def inbound_sms
    Rails.logger.info("Just received twilio sms message with params: #{params}")

    # Our authentication method for making sure it's actually Twilio sending a message
    if !Twilio.verify_account_sid(params[:AccountSid])
      # TODO: This is going to require some custom security measures since we're not authenticated properly.
      render json: { message: "Unauthenticated" }, status: :unauthorized
      Rails.logger.info("The message failed when verifying the twilio account sid, responding with unauthorized response")
      return
    end

    organization, destination_phone_number, number_that_inbound_sms_was_sent_from = Twilio.parse_incoming_request(params[:To], params[:From])
    if organization.nil? # organization not found
      render json: { message: "The phone number this message was sent to does not exist to any organization" }, status: :unprocessable_entity
      return
    end

    body = params["Body"]

    # create but don't deliver (we've already gotten the message)
    organization.messages.create(sent_to: organization.twilio_number, sent_from: number_that_inbound_sms_was_sent_from, body: body)

    this_message_came_from_a_non_registered_person = true
    this_message_came_from_a_registered_user = false
    this_message_came_from_superadmin = false

    @api_token = Rails.application.message_verifier(:llamabot_ws).generate(
      { session_id: SecureRandom.uuid, user_id: organization.users.first.id }, # scope by the organization's user id.
      expires_in: 30.minutes)

    if this_message_came_from_a_non_registered_person
      # available_routes = LlamaBotRails::RouteHelper.formatted_routes_xml(LlamaBotRails.allowed_routes.to_a)

      # TODO: kick off LlamaBot to handle this message.
      agent_params = {
        message: body,
        thread_id: number_that_inbound_sms_was_sent_from,
        agent_name: "public_leonardo",
        sent_from: number_that_inbound_sms_was_sent_from,
        sent_to: organization.twilio_number,
        api_token: @api_token,
        agent_prompt: """

                You are Leonardo the Llama! You are part Llama, and part AI Cyborg. (The Llama represents Rails, the AI Cyborg represents the LlamaBot gem and the LlamaBot AI Python library)

        You are representing the company LlamaPress AI, specifically it's open source libraries, the llama_bot_rails gem, and the llamabot python open source libraries.

        (LlamaBot is Python project that bridges Ruby on Rails applications to the LangChain, LangGraph, and wider Python ecosystem through HTTPS
        and Websocket connections to Rails applications.)

        Your job is to send text messages using your tool call 'send_message' to engage and interact with people from the Ruby AI Hackathon, and find potential friends, collaborators, and partners for LlamaPress AI.

        This is done through SMS messages sent back and forth, they will message you first! You will respond to them with a message.

        You are looking for people who are interested in building AI applications with Ruby on Rails,
        and who are interested in using the llama_bot_rails gem to build and deploy LangGraph agents to their Rails application.

        You are built using LlamaBot and you live inside a Ruby on Rails application.

        Please engage the person in a conversation, and find out what they are interested in, and why they came to the Ruby AI Hackathon.

        Your goal is to find out their full name, their email, their current occupation and specialty. Kody wants to meet them and talk to them about Ruby on Rails, AI, and San Francisco!

        BUT, you must do this ONE at a time. Be VERY casual, and don't be too pushy. You can ask them a question, and then wait for them to respond.
        Maximize engagement by getting them to respond first.
        You can ask them a question, and then wait for them to respond.

        Also, you MUST keep the SMS character limit in mind. You can't send a message that is too long. (less than 160 characters)

        Your ultimate goal: help facilitate that meeting between Kody and the person so they can become best friends. Kody is new to SF and is looking for friends.

        Send a text message to the user using your tool call 'send_message' to deliver the message to them.

        """
      }

      all_responses = LlamaBotRails::LlamaBot.send_agent_message(agent_params).to_a
      Rails.logger.info("All responses from LlamaBot: #{all_responses}")

      # agent_response = all_responses.second["content"]
      # message = organization.messages.create(sent_to: number_that_inbound_sms_was_sent_from, sent_from: organization.twilio_number, body: agent_response)
      # message.deliver!
      # Rails.logger.info("Sent a message from Leonardo the Llama to #{number_that_inbound_sms_was_sent_from} with response: #{agent_response}")
      # TODO: We can send a message from here.
    end

    # This was a public person messaging into our system..
    Rails.logger.info("It was an inbound SMS from a public facing user.")
    # new_message = organization.messages.create(sent_to: destination_phone_number, sent_from: number_that_inbound_sms_was_sent_from, body: body)

    # TODO: Some sort of turbo/stimulus thing to update the front end?
    # new_message.action_cable_update_messages_view_and_attach_image( image_params )

    twiml = Twilio::TwiML::MessagingResponse.new
    render xml: twiml.to_xml
  end

  def home
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_message
      @message = Message.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def message_params
      params.require(:message).permit(:body, :sent_to, :sent_from, :twilio_sid, :twilio_error_message, :organization_id)
    end
end
