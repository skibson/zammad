# Copyright (C) 2012-2014 Zammad Foundation, http://zammad-foundation.org/

class FormController < ApplicationController

  def config
    return if !enabled?

    api_path  = Rails.configuration.api_path
    http_type = Setting.get('http_type')
    fqdn      = Setting.get('fqdn')

    endpoint = "#{http_type}://#{fqdn}#{api_path}/form_submit"

    config = {
      enabled:  Setting.get('form_ticket_create'),
      endpoint: endpoint,
    }

    render json: config, status: :ok
  end

  def submit
    return if !enabled?

    # validate input
    errors = {}
    if !params[:name] || params[:name].empty?
      errors['name'] = 'required'
    end
    if !params[:email] || params[:email].empty?
      errors['email'] = 'required'
    end
    if params[:email] !~ /@/
      errors['email'] = 'invalid'
    end
    if !params[:body] || params[:body].empty?
      errors['body'] = 'required'
    end

    if errors && !errors.empty?
      render json: {
        errors: errors
      }, status: :ok
      return
    end

    name = params[:name].strip
    email = params[:email].strip.downcase

    customer = User.find_by(email: email)
    if !customer
      roles = Role.where( name: 'Customer' )
      customer = User.create(
        firstname: name,
        lastname: '',
        email: email,
        password: '',
        active: true,
        roles: roles,
        updated_by_id: 1,
        created_by_id: 1,
      )
    end

    ticket = Ticket.create(
      group_id: 1,
      customer_id: customer.id,
      title: '',
      state_id: Ticket::State.find_by( name: 'new' ).id,
      priority_id: Ticket::Priority.find_by( name: '2 normal' ).id,
      updated_by_id: customer.id,
      created_by_id: customer.id,
    )

    article = Ticket::Article.create(
      ticket_id: ticket.id,
      type_id: Ticket::Article::Type.find_by( name: 'web' ).id,
      sender_id: Ticket::Article::Sender.find_by( name: 'Customer' ).id,
      body: params[:body],
      from: email,
      subject: '',
      internal: false,
      updated_by_id: customer.id,
      created_by_id: customer.id,
    )

    result = {}
    render json: result, status: :ok
  end

  private

  def enabled?
    return true if Setting.get('form_ticket_create')
    response_access_deny
    false
  end

end